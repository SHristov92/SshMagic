import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/connection.dart';

/// Persists connection profiles, their secrets and trusted host keys.
///
/// Profiles go to shared preferences; secrets go to the iOS Keychain /
/// Android Keystore via flutter_secure_storage.
class ConnectionStore {
  ConnectionStore({FlutterSecureStorage? secureStorage})
      : _secure = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
            );

  static const _connectionsKey = 'connections.v1';
  static const _hostKeysKey = 'known_hosts.v1';

  final FlutterSecureStorage _secure;

  Future<List<SshConnection>> loadConnections() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_connectionsKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => SshConnection.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> _saveConnections(List<SshConnection> connections) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _connectionsKey,
      jsonEncode(connections.map((c) => c.toJson()).toList()),
    );
  }

  Future<void> upsert(SshConnection connection, ConnectionSecrets secrets) async {
    final all = await loadConnections();
    final index = all.indexWhere((c) => c.id == connection.id);
    if (index >= 0) {
      all[index] = connection;
    } else {
      all.add(connection);
    }
    await _saveConnections(all);
    await _writeSecret(connection.id, 'password', secrets.password);
    await _writeSecret(connection.id, 'privateKey', secrets.privateKey);
    await _writeSecret(connection.id, 'passphrase', secrets.passphrase);
  }

  Future<void> delete(String id) async {
    final all = await loadConnections();
    all.removeWhere((c) => c.id == id);
    await _saveConnections(all);
    for (final field in const ['password', 'privateKey', 'passphrase']) {
      await _secure.delete(key: _secretKey(id, field));
    }
  }

  Future<ConnectionSecrets> loadSecrets(String id) async {
    return ConnectionSecrets(
      password: await _secure.read(key: _secretKey(id, 'password')),
      privateKey: await _secure.read(key: _secretKey(id, 'privateKey')),
      passphrase: await _secure.read(key: _secretKey(id, 'passphrase')),
    );
  }

  Future<void> _writeSecret(String id, String field, String? value) async {
    final key = _secretKey(id, field);
    if (value == null || value.isEmpty) {
      await _secure.delete(key: key);
    } else {
      await _secure.write(key: key, value: value);
    }
  }

  String _secretKey(String id, String field) => 'conn.$id.$field';

  /// Returns the trusted host key fingerprint for `host:port`, if any.
  Future<String?> knownHostKey(String host, int port) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_hostKeysKey);
    if (raw == null) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map['$host:$port'] as String?;
  }

  Future<void> trustHostKey(String host, int port, String fingerprint) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_hostKeysKey);
    final map = raw == null ? <String, dynamic>{} : jsonDecode(raw) as Map<String, dynamic>;
    map['$host:$port'] = fingerprint;
    await prefs.setString(_hostKeysKey, jsonEncode(map));
  }
}
