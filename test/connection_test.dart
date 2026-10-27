import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshmagic/main.dart';
import 'package:sshmagic/models/connection.dart';
import 'package:sshmagic/services/connection_store.dart';
import 'package:sshmagic/services/ssh_service.dart';

void main() {
  test('SshConnection round-trips through JSON', () {
    final c = SshConnection(
      id: '1',
      name: 'Home',
      host: 'example.com',
      port: 2222,
      username: 'spas',
      authMethod: AuthMethod.privateKey,
      tmuxSession: 'main',
      autoAttachTmux: true,
    );
    final back = SshConnection.fromJson(c.toJson());

    expect(back.id, '1');
    expect(back.host, 'example.com');
    expect(back.port, 2222);
    expect(back.authMethod, AuthMethod.privateKey);
    expect(back.tmuxSession, 'main');
    expect(back.autoAttachTmux, isTrue);
    expect(back.address, 'spas@example.com:2222');
  });

  test('fromJson applies defaults for missing optional fields', () {
    final c = SshConnection.fromJson({
      'id': '2',
      'name': 'Box',
      'host': 'box',
      'username': 'root',
    });
    expect(c.port, 22);
    expect(c.authMethod, AuthMethod.password);
    expect(c.tmuxSession, isNull);
    expect(c.address, 'root@box');
  });

  test('formatFingerprint renders colon separated hex', () {
    expect(SshService.formatFingerprint([0x0a, 0xff, 0x01]), '0a:ff:01');
  });

  testWidgets('home screen shows empty state', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = ConnectionStore();
    await tester.pumpWidget(SshMagicApp(store: store, ssh: SshService(store)));
    await tester.pumpAndSettle();

    expect(find.text('No connections yet'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
