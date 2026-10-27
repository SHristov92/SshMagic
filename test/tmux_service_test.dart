import 'package:flutter_test/flutter_test.dart';
import 'package:sshmagic/services/tmux_service.dart';

void main() {
  group('TmuxService.parseListSessions', () {
    test('parses tab separated list-sessions output', () {
      const output = 'main\t3\t1\t1700000000\n'
          'work stuff\t1\t0\t1700000600\n';
      final sessions = TmuxService.parseListSessions(output);

      expect(sessions, hasLength(2));
      expect(sessions[0].name, 'main');
      expect(sessions[0].windows, 3);
      expect(sessions[0].attached, isTrue);
      expect(sessions[0].created, DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000));
      expect(sessions[1].name, 'work stuff');
      expect(sessions[1].attached, isFalse);
    });

    test('returns empty list for empty output', () {
      expect(TmuxService.parseListSessions(''), isEmpty);
      expect(TmuxService.parseListSessions('\n\n'), isEmpty);
    });

    test('skips malformed lines', () {
      expect(TmuxService.parseListSessions('no server running\n'), isEmpty);
    });
  });

  test('shellQuote escapes single quotes', () {
    expect(TmuxService.shellQuote('abc'), "'abc'");
    expect(TmuxService.shellQuote("it's"), r"'it'\''s'");
  });

  test('sanitizeSessionName replaces characters tmux rejects', () {
    expect(TmuxService.sanitizeSessionName('  my.project:dev  '), 'my-project-dev');
    expect(TmuxService.sanitizeSessionName('a b'), 'a-b');
  });

  test('attachCommand creates or attaches to the named session', () {
    expect(
      TmuxService.attachCommand("o'neil"),
      endsWith(r"exec tmux new-session -A -s 'o'\''neil'"),
    );
  });
}
