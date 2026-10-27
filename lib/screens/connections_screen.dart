import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';

import '../models/connection.dart';
import '../services/connection_store.dart';
import '../services/ssh_service.dart';
import 'connection_edit_screen.dart';
import 'terminal_screen.dart';
import 'tmux_sessions_screen.dart';

enum _OpenMode { auto, shell, tmux }

/// Home screen: the list of saved connections.
class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key, required this.store, required this.ssh});

  final ConnectionStore store;
  final SshService ssh;

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  List<SshConnection> _connections = [];
  bool _loading = true;
  String? _connectingId;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await widget.store.loadConnections();
    if (!mounted) return;
    setState(() {
      _connections = list;
      _loading = false;
    });
  }

  Future<void> _edit([SshConnection? existing]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ConnectionEditScreen(store: widget.store, existing: existing),
      ),
    );
    if (saved == true) _reload();
  }

  Future<void> _delete(SshConnection c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${c.name}"?'),
        content: const Text('The saved password or key will be removed from this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await widget.store.delete(c.id);
      _reload();
    }
  }

  Future<bool> _confirmHostKey(HostKeyCheck check) async {
    if (!mounted) return false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(check.changed ? Icons.warning_amber : Icons.verified_user),
        title: Text(check.changed ? 'Host key changed!' : 'Unknown host'),
        content: SelectableText(
          check.changed
              ? 'The key for ${check.host}:${check.port} is different from the one you trusted '
                  'before. This could mean someone is intercepting the connection.\n\n'
                  'Previous:\n${check.previousFingerprint}\n\nNew:\n${check.fingerprint}'
              : 'First connection to ${check.host}:${check.port}. Verify the fingerprint:\n\n'
                  '${check.fingerprint}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(check.changed ? 'Trust new key' : 'Trust'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _open(SshConnection c, _OpenMode mode) async {
    if (_connectingId != null) return;
    setState(() => _connectingId = c.id);
    final SSHClient client;
    try {
      client = await widget.ssh.connect(c, confirmHostKey: _confirmHostKey);
    } catch (e) {
      if (mounted) {
        setState(() => _connectingId = null);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
      return;
    }
    if (!mounted) {
      client.close();
      return;
    }
    setState(() => _connectingId = null);

    final effective = mode == _OpenMode.auto
        ? (c.autoAttachTmux ? _OpenMode.tmux : _OpenMode.shell)
        : mode;

    final Widget screen;
    if (effective == _OpenMode.shell) {
      screen = TerminalScreen(client: client, connection: c, ownsClient: true);
    } else if (mode == _OpenMode.auto && c.tmuxSession != null) {
      // Auto-attach straight into the default session.
      screen = TerminalScreen(
        client: client,
        connection: c,
        tmuxSession: c.tmuxSession,
        ownsClient: true,
      );
    } else {
      screen = TmuxSessionsScreen(client: client, connection: c);
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SshMagic')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Connection'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _connections.isEmpty
              ? const _EmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: _connections.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final c = _connections[i];
                    final connecting = _connectingId == c.id;
                    return ListTile(
                      leading: CircleAvatar(
                        child: Icon(c.autoAttachTmux ? Icons.view_quilt : Icons.terminal),
                      ),
                      title: Text(c.name),
                      subtitle: Text(
                        c.tmuxSession == null ? c.address : '${c.address} · tmux: ${c.tmuxSession}',
                      ),
                      onTap: () => _open(c, _OpenMode.auto),
                      trailing: connecting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : PopupMenuButton<String>(
                              onSelected: (v) {
                                switch (v) {
                                  case 'shell':
                                    _open(c, _OpenMode.shell);
                                  case 'tmux':
                                    _open(c, _OpenMode.tmux);
                                  case 'edit':
                                    _edit(c);
                                  case 'delete':
                                    _delete(c);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'shell', child: Text('Open shell')),
                                PopupMenuItem(value: 'tmux', child: Text('tmux sessions')),
                                PopupMenuItem(value: 'edit', child: Text('Edit')),
                                PopupMenuItem(value: 'delete', child: Text('Delete')),
                              ],
                            ),
                    );
                  },
                ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.terminal, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('No connections yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Add a server to save its host, user and credentials. '
              'Turn on "Open tmux on connect" to jump straight into your tmux session.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
