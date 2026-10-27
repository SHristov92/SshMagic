import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/connection.dart';
import '../services/connection_store.dart';
import '../services/tmux_service.dart';

/// Create or edit a saved connection.
class ConnectionEditScreen extends StatefulWidget {
  const ConnectionEditScreen({super.key, required this.store, this.existing});

  final ConnectionStore store;
  final SshConnection? existing;

  @override
  State<ConnectionEditScreen> createState() => _ConnectionEditScreenState();
}

class _ConnectionEditScreenState extends State<ConnectionEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _username;
  late final TextEditingController _tmuxSession;
  final _password = TextEditingController();
  final _privateKey = TextEditingController();
  final _passphrase = TextEditingController();

  late AuthMethod _authMethod;
  late bool _autoAttachTmux;
  bool _obscurePassword = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    _name = TextEditingController(text: c?.name ?? '');
    _host = TextEditingController(text: c?.host ?? '');
    _port = TextEditingController(text: '${c?.port ?? 22}');
    _username = TextEditingController(text: c?.username ?? '');
    _tmuxSession = TextEditingController(text: c?.tmuxSession ?? '');
    _authMethod = c?.authMethod ?? AuthMethod.password;
    _autoAttachTmux = c?.autoAttachTmux ?? false;
    if (c != null) _loadSecrets(c.id);
  }

  Future<void> _loadSecrets(String id) async {
    final s = await widget.store.loadSecrets(id);
    if (!mounted) return;
    setState(() {
      _password.text = s.password ?? '';
      _privateKey.text = s.privateKey ?? '';
      _passphrase.text = s.passphrase ?? '';
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _host, _port, _username, _tmuxSession, _password, _privateKey, _passphrase]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final tmux = TmuxService.sanitizeSessionName(_tmuxSession.text);
    final host = _host.text.trim();
    final connection = SshConnection(
      id: widget.existing?.id ?? const Uuid().v4(),
      name: _name.text.trim().isEmpty ? host : _name.text.trim(),
      host: host,
      port: int.parse(_port.text.trim()),
      username: _username.text.trim(),
      authMethod: _authMethod,
      tmuxSession: tmux.isEmpty ? null : tmux,
      autoAttachTmux: _autoAttachTmux,
    );
    final usesKey = _authMethod == AuthMethod.privateKey;
    await widget.store.upsert(
      connection,
      ConnectionSecrets(
        password: usesKey ? null : _password.text,
        privateKey: usesKey ? _privateKey.text.trim() : null,
        passphrase: usesKey ? _passphrase.text : null,
      ),
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New connection' : 'Edit connection'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Home server'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _host,
                    decoration: const InputDecoration(labelText: 'Host'),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    validator: _required,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _port,
                    decoration: const InputDecoration(labelText: 'Port'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final p = int.tryParse(v?.trim() ?? '');
                      return (p == null || p < 1 || p > 65535) ? '1-65535' : null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _username,
              decoration: const InputDecoration(labelText: 'Username'),
              autocorrect: false,
              validator: _required,
            ),
            const SizedBox(height: 20),
            SegmentedButton<AuthMethod>(
              segments: const [
                ButtonSegment(value: AuthMethod.password, label: Text('Password'), icon: Icon(Icons.password)),
                ButtonSegment(value: AuthMethod.privateKey, label: Text('Private key'), icon: Icon(Icons.key)),
              ],
              selected: {_authMethod},
              onSelectionChanged: (s) => setState(() => _authMethod = s.first),
            ),
            const SizedBox(height: 12),
            if (_authMethod == AuthMethod.password)
              TextFormField(
                controller: _password,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText: 'Stored in the device keychain',
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              )
            else ...[
              TextFormField(
                controller: _privateKey,
                minLines: 4,
                maxLines: 8,
                autocorrect: false,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: const InputDecoration(
                  labelText: 'Private key (PEM)',
                  hintText: '-----BEGIN OPENSSH PRIVATE KEY-----',
                  border: OutlineInputBorder(),
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passphrase,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Key passphrase (optional)'),
              ),
            ],
            const SizedBox(height: 24),
            Text('tmux', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _tmuxSession,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Default session name (optional)',
                hintText: 'e.g. main',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Open tmux on connect'),
              subtitle: const Text(
                'Attaches to the default session (creating it if needed), '
                'or shows the session list when no default is set.',
              ),
              value: _autoAttachTmux,
              onChanged: (v) => setState(() => _autoAttachTmux = v),
            ),
          ],
        ),
      ),
    );
  }
}
