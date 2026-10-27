enum AuthMethod { password, privateKey }

/// A saved SSH connection profile.
///
/// Only non-secret fields live here. Passwords, private keys and key
/// passphrases are kept in the platform keychain/keystore by
/// [ConnectionStore] and are attached at connect time as [ConnectionSecrets].
class SshConnection {
  SshConnection({
    required this.id,
    required this.name,
    required this.host,
    this.port = 22,
    required this.username,
    this.authMethod = AuthMethod.password,
    this.tmuxSession,
    this.autoAttachTmux = false,
  });

  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final AuthMethod authMethod;

  /// Default tmux session name to attach to (or create) for this connection.
  final String? tmuxSession;

  /// When true, connecting opens the tmux session list instead of a plain shell.
  final bool autoAttachTmux;

  String get address => port == 22 ? '$username@$host' : '$username@$host:$port';

  SshConnection copyWith({
    String? name,
    String? host,
    int? port,
    String? username,
    AuthMethod? authMethod,
    String? tmuxSession,
    bool clearTmuxSession = false,
    bool? autoAttachTmux,
  }) {
    return SshConnection(
      id: id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      authMethod: authMethod ?? this.authMethod,
      tmuxSession: clearTmuxSession ? null : (tmuxSession ?? this.tmuxSession),
      autoAttachTmux: autoAttachTmux ?? this.autoAttachTmux,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'username': username,
        'authMethod': authMethod.name,
        if (tmuxSession != null) 'tmuxSession': tmuxSession,
        'autoAttachTmux': autoAttachTmux,
      };

  factory SshConnection.fromJson(Map<String, dynamic> json) {
    return SshConnection(
      id: json['id'] as String,
      name: json['name'] as String,
      host: json['host'] as String,
      port: (json['port'] as num?)?.toInt() ?? 22,
      username: json['username'] as String,
      authMethod: AuthMethod.values.firstWhere(
        (m) => m.name == json['authMethod'],
        orElse: () => AuthMethod.password,
      ),
      tmuxSession: json['tmuxSession'] as String?,
      autoAttachTmux: json['autoAttachTmux'] as bool? ?? false,
    );
  }
}

class ConnectionSecrets {
  const ConnectionSecrets({this.password, this.privateKey, this.passphrase});

  final String? password;

  /// PEM-encoded private key (OpenSSH or PKCS#1/PKCS#8).
  final String? privateKey;
  final String? passphrase;
}
