import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';

import '../models/connection.dart';
import '../services/tmux_service.dart';
import '../widgets/message_view.dart';
import 'terminal_screen.dart';

/// Lists tmux sessions on the remote host and lets the user attach, create,
/// rename or end them. Owns [client] and closes it when popped.
class TmuxSessionsScreen extends StatefulWidget {
  const TmuxSessionsScreen({super.key, required this.client, required this.connection});

  final SSHClient client;
  final SshConnection connection;

  @override
  State<TmuxSessionsScreen> createState() => _TmuxSessionsScreenState();
}

class _TmuxSessionsScreenState extends State<TmuxSessionsScreen> {
  late final TmuxService _tmux = TmuxService(widget.client);
  List<TmuxSession> _sessions = [];
  bool _loading = true;
  bool _installed = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    widget.client.close();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final installed = await _tmux.isInstalled();
      final sessions = installed ? await _tmux.listSessions() : <TmuxSession>[];
      if (!mounted) return;
      setState(() {
        _installed = installed;
        _sessions = sessions;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _attach(String name) async {
    await _push(TerminalScreen(
      client: widget.client,
      connection: widget.connection,
      tmuxSession: name,
      ownsClient: false,
    ));
    if (mounted) _refresh();
  }

  Future<void> _push(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  Future<String?> _askName({required String title, String initial = ''}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Session name'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('OK')),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _create() async {
    final raw = await _askName(
      title: 'New tmux session',
      initial: widget.connection.tmuxSession ?? '',
    );
    final name = TmuxService.sanitizeSessionName(raw ?? '');
    if (name.isNotEmpty) await _attach(name);
  }

  Future<void> _rename(TmuxSession s) async {
    final raw = await _askName(title: 'Rename session', initial: s.name);
    final name = TmuxService.sanitizeSessionName(raw ?? '');
    if (name.isEmpty || name == s.name) return;
    await _tmux.renameSession(s.name, name);
    _refresh();
  }

  Future<void> _end(TmuxSession s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('End "${s.name}"?'),
        content: Text('All ${s.windows} window(s) and the programs in them will be closed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('End session')),
        ],
      ),
    );
    if (ok != true) return;
    await _tmux.killSession(s.name);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('tmux · ${widget.connection.name}'),
        actions: [
          IconButton(
            tooltip: 'Plain shell',
            icon: const Icon(Icons.terminal),
            onPressed: () => _push(TerminalScreen(
              client: widget.client,
              connection: widget.connection,
              ownsClient: false,
            )),
          ),
          IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      floatingActionButton: _installed
          ? FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: const Text('Session'),
            )
          : null,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return MessageView(icon: Icons.error_outline, title: 'Could not list sessions', body: _error!);
    }
    if (!_installed) {
      return const MessageView(
        icon: Icons.extension_off,
        title: 'tmux is not installed',
        body: 'Install it on the server (e.g. "sudo apt install tmux" or "brew install tmux") '
            'and refresh. You can still open a plain shell from the toolbar.',
      );
    }
    if (_sessions.isEmpty) {
      return const MessageView(
        icon: Icons.view_quilt_outlined,
        title: 'No tmux sessions running',
        body: 'Create one with the + button. It keeps running on the server after you disconnect.',
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: _sessions.length,
        itemBuilder: (context, i) {
          final s = _sessions[i];
          final created = s.created;
          return ListTile(
            leading: Icon(s.attached ? Icons.link : Icons.view_quilt),
            title: Text(s.name),
            subtitle: Text([
              '${s.windows} window${s.windows == 1 ? '' : 's'}',
              if (s.attached) 'attached (${s.attachedClients})',
              if (created != null) 'since ${_formatDate(created)}',
            ].join(' · ')),
            onTap: () => _attach(s.name),
            trailing: PopupMenuButton<String>(
              onSelected: (v) => v == 'rename' ? _rename(s) : _end(s),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(value: 'end', child: Text('End session')),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
}
