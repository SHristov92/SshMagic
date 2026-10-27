import 'package:flutter/material.dart';

import 'screens/connections_screen.dart';
import 'services/connection_store.dart';
import 'services/ssh_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final store = ConnectionStore();
  runApp(SshMagicApp(store: store, ssh: SshService(store)));
}

class SshMagicApp extends StatelessWidget {
  const SshMagicApp({super.key, required this.store, required this.ssh});

  final ConnectionStore store;
  final SshService ssh;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2E7D6B);
    return MaterialApp(
      title: 'SshMagic',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: seed,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      home: ConnectionsScreen(store: store, ssh: ssh),
    );
  }
}
