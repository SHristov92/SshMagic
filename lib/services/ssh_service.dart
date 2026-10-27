import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../models/connection.dart';
import 'connection_store.dart';

/// Details about a server host key that the user must accept.
class HostKeyCheck {
  const HostKeyCheck({
    required this.host,
    required this.port,
    required this.type,
    required this.fingerprint,
    this.previousFingerprint,
  });

  final String host;
  final int port;
  final String type;
  final String fingerprint;

  /// Set when the server presents a different key than the one trusted before.
  final String? previousFingerprint;

  bool get changed => previousFingerprint != null;
}

typedef HostKeyPrompt = Future<bool> Function(HostKeyCheck check);

class SshConnectException implements Exception {
  SshConnectException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Opens authenticated SSH connections for saved profiles, with
/// trust-on-first-use host key verification.
class SshService {
  SshService(this._store);

  final ConnectionStore _store;

  Future<SSHClient> connect(
    SshConnection connection, {
    required HostKeyPrompt confirmHostKey,
  }) async {
    final secrets = await _store.loadSecrets(connection.id);

    List<SSHKeyPair>? identities;
    if (connection.authMethod == AuthMethod.privateKey) {
      final pem = secrets.privateKey ?? '';
      if (pem.trim().isEmpty) {
        throw SshConnectException('No private key saved for this connection.');
      }
      try {
        final passphrase = (secrets.passphrase ?? '').isEmpty ? null : secrets.passphrase;
        identities = SSHKeyPair.fromPem(pem, passphrase);
      } catch (e) {
        throw SshConnectException('Could not read the private key: $e');
      }
    }

    final SSHSocket socket;
    try {
      socket = await SSHSocket.connect(
        connection.host,
        connection.port,
        timeout: const Duration(seconds: 15),
      );
    } catch (e) {
      throw SshConnectException('Could not reach ${connection.host}:${connection.port} ($e)');
    }

    final password = connection.authMethod == AuthMethod.password ? secrets.password : null;
    final client = SSHClient(
      socket,
      username: connection.username,
      identities: identities,
      keepAliveInterval: const Duration(seconds: 20),
      onPasswordRequest: () => password,
      onUserInfoRequest: (request) =>
          password == null ? null : request.prompts.map((_) => password).toList(),
      onVerifyHostKey: (type, fingerprint) =>
          _verifyHostKey(connection, type, fingerprint, confirmHostKey),
    );

    try {
      await client.authenticated;
    } catch (e) {
      client.close();
      throw SshConnectException('Authentication failed: $e');
    }
    return client;
  }

  Future<bool> _verifyHostKey(
    SshConnection connection,
    String type,
    Uint8List fingerprintBytes,
    HostKeyPrompt confirm,
  ) async {
    final fingerprint = '$type MD5:${formatFingerprint(fingerprintBytes)}';
    final known = await _store.knownHostKey(connection.host, connection.port);
    if (known == fingerprint) return true;

    final accepted = await confirm(HostKeyCheck(
      host: connection.host,
      port: connection.port,
      type: type,
      fingerprint: fingerprint,
      previousFingerprint: known,
    ));
    if (accepted) {
      await _store.trustHostKey(connection.host, connection.port, fingerprint);
    }
    return accepted;
  }

  static String formatFingerprint(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':');
}
