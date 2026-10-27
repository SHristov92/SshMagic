import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import '../models/connection.dart';
import '../services/tmux_service.dart';
import '../widgets/extra_keys_bar.dart';

/// Interactive terminal over an SSH PTY. When [tmuxSession] is set the PTY
/// runs `tmux new-session -A -s <name>` (attach, or create if missing);
/// otherwise it opens the user's login shell.
class TerminalScreen extends StatefulWidget {
  const TerminalScreen({
    super.key,
    required this.client,
    required this.connection,
    this.tmuxSession,
    required this.ownsClient,
  });

  final SSHClient client;
  final SshConnection connection;
  final String? tmuxSession;

  /// Close the SSH connection when this screen goes away.
  final bool ownsClient;

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final _terminal = Terminal(maxLines: 10000);
  final _terminalController = TerminalController();
  SSHSession? _session;
  final _subscriptions = <StreamSubscription<String>>[];
  bool _ctrlArmed = false;
  bool _closed = false;
  double _fontSize = 13;

  bool get _isTmux => widget.tmuxSession != null;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    _terminal.write(_isTmux
        ? 'Attaching to tmux session "${widget.tmuxSession}"...\r\n'
        : 'Connected to ${widget.connection.address}\r\n');

    final pty = SSHPtyConfig(
      width: _terminal.viewWidth,
      height: _terminal.viewHeight,
    );
    final SSHSession session;
    try {
      session = _isTmux
          ? await widget.client.execute(TmuxService.attachCommand(widget.tmuxSession!), pty: pty)
          : await widget.client.shell(pty: pty);
    } catch (e) {
      _terminal.write('\r\nFailed to open session: $e\r\n');
      return;
    }
    if (!mounted) {
      session.close();
      return;
    }
    _session = session;

    _terminal.onOutput = _handleOutput;
    _terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      session.resizeTerminal(width, height, pixelWidth, pixelHeight);
    };
    // The view may have been laid out before the session existed.
    session.resizeTerminal(_terminal.viewWidth, _terminal.viewHeight);

    _subscriptions.add(session.stdout
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(_terminal.write));
    _subscriptions.add(session.stderr
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(_terminal.write));

    session.done.then((_) => _onSessionDone(), onError: (_) => _onSessionDone());
  }

  void _onSessionDone() {
    if (!mounted || _closed) return;
    _closed = true;
    if (_isTmux) {
      // Detached or the session ended: go back to the session list / home.
      Navigator.of(context).maybePop();
    } else {
      _terminal.write('\r\n[connection closed]\r\n');
      setState(() {});
    }
  }

  void _handleOutput(String data) {
    if (_ctrlArmed && data.length == 1) {
      final code = data.toUpperCase().codeUnitAt(0);
      setState(() => _ctrlArmed = false);
      if (code >= 0x40 && code <= 0x5f) {
        _send(String.fromCharCode(code - 0x40));
        return;
      }
    }
    _send(data);
  }

  void _send(String data) {
    _session?.write(Uint8List.fromList(utf8.encode(data)));
  }

  void _zoom(double delta) {
    setState(() => _fontSize = (_fontSize + delta).clamp(8, 28));
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _session?.close();
    if (widget.ownsClient) widget.client.close();
    _terminalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isTmux ? 'tmux: ${widget.tmuxSession}' : widget.connection.name;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(tooltip: 'Smaller text', icon: const Icon(Icons.text_decrease), onPressed: () => _zoom(-1)),
          IconButton(tooltip: 'Larger text', icon: const Icon(Icons.text_increase), onPressed: () => _zoom(1)),
          if (_isTmux)
            IconButton(
              tooltip: 'Detach',
              icon: const Icon(Icons.logout),
              onPressed: () => _send('\x02d'),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: TerminalView(
                _terminal,
                controller: _terminalController,
                autofocus: true,
                backgroundOpacity: 1,
                textStyle: TerminalStyle(fontSize: _fontSize),
                keyboardType: TextInputType.visiblePassword,
              ),
            ),
            if (_isTmux) TmuxKeysBar(onSendText: _send),
            ExtraKeysBar(
              terminal: _terminal,
              ctrlActive: _ctrlArmed,
              onCtrlToggle: () => setState(() => _ctrlArmed = !_ctrlArmed),
              onSendText: _send,
            ),
          ],
        ),
      ),
    );
  }
}
