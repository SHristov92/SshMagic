import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';

class TmuxSession {
  const TmuxSession({
    required this.name,
    required this.windows,
    required this.attachedClients,
    this.created,
  });

  final String name;
  final int windows;
  final int attachedClients;
  final DateTime? created;

  bool get attached => attachedClients > 0;
}

/// Runs tmux commands on a remote host over an existing SSH connection.
class TmuxService {
  TmuxService(this._client);

  final SSHClient _client;

  /// Non-interactive SSH commands often get a minimal PATH, so include the
  /// usual places tmux is installed (Homebrew on macOS, /usr/local on BSDs).
  static const _pathPrefix = r'PATH="$PATH:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"; ';

  static const _listFormat =
      '#{session_name}\t#{session_windows}\t#{session_attached}\t#{session_created}';

  Future<String> _run(String command) async {
    final out = await _client.run('$_pathPrefix$command', stderr: false);
    return utf8.decode(out, allowMalformed: true);
  }

  Future<bool> isInstalled() async {
    final out = await _run('command -v tmux >/dev/null 2>&1 && echo yes || echo no');
    return out.trim() == 'yes';
  }

  Future<List<TmuxSession>> listSessions() async {
    // `list-sessions` exits non-zero when no server is running; treat as empty.
    final out = await _run("tmux list-sessions -F '$_listFormat' 2>/dev/null || true");
    return parseListSessions(out);
  }

  Future<void> killSession(String name) => _run('tmux kill-session -t ${shellQuote('=$name')}');

  Future<void> renameSession(String from, String to) =>
      _run('tmux rename-session -t ${shellQuote('=$from')} ${shellQuote(to)}');

  /// Command that attaches to [name], creating the session if it does not exist.
  static String attachCommand(String name) =>
      '${_pathPrefix}exec tmux new-session -A -s ${shellQuote(name)}';

  static List<TmuxSession> parseListSessions(String output) {
    final sessions = <TmuxSession>[];
    for (final line in const LineSplitter().convert(output)) {
      if (line.trim().isEmpty) continue;
      final parts = line.split('\t');
      if (parts.length < 4) continue;
      final createdSeconds = int.tryParse(parts[3]);
      sessions.add(TmuxSession(
        name: parts[0],
        windows: int.tryParse(parts[1]) ?? 0,
        attachedClients: int.tryParse(parts[2]) ?? 0,
        created: createdSeconds == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(createdSeconds * 1000),
      ));
    }
    return sessions;
  }

  /// tmux forbids '.' and ':' in session names; replace them and whitespace.
  static String sanitizeSessionName(String name) =>
      name.trim().replaceAll(RegExp(r'[.:\s]+'), '-');

  static String shellQuote(String value) => "'${value.replaceAll("'", r"'\''")}'";
}
