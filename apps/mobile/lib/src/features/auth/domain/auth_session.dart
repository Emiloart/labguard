import '../../devices/domain/device_record.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresInSeconds,
    required this.viewer,
    required this.account,
    required this.device,
  });

  factory AuthSession.fromEnvelope(Map<String, dynamic> json) {
    final session = json['session'] as Map<String, dynamic>? ?? const {};

    return AuthSession(
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      expiresInSeconds: json['expiresInSeconds'] as int? ?? 0,
      viewer: AuthViewer.fromJson(
        session['viewer'] as Map<String, dynamic>? ?? const {},
      ),
      account: AuthAccount.fromJson(
        session['account'] as Map<String, dynamic>? ?? const {},
      ),
      device: AuthDevice.fromJson(
        session['device'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  factory AuthSession.fromStoredJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      expiresInSeconds: json['expiresInSeconds'] as int? ?? 0,
      viewer: AuthViewer.fromJson(
        json['viewer'] as Map<String, dynamic>? ?? const {},
      ),
      account: AuthAccount.fromJson(
        json['account'] as Map<String, dynamic>? ?? const {},
      ),
      device: AuthDevice.fromJson(
        json['device'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  final String accessToken;
  final String refreshToken;
  final int expiresInSeconds;
  final AuthViewer viewer;
  final AuthAccount account;
  final AuthDevice device;

  bool get isPersistable => accessToken.isNotEmpty && refreshToken.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresInSeconds': expiresInSeconds,
      'viewer': viewer.toJson(),
      'account': account.toJson(),
      'device': device.toJson(),
    };
  }

  AuthSession copyWith({
    String? accessToken,
    String? refreshToken,
    int? expiresInSeconds,
    AuthViewer? viewer,
    AuthAccount? account,
    AuthDevice? device,
  }) {
    return AuthSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresInSeconds: expiresInSeconds ?? this.expiresInSeconds,
      viewer: viewer ?? this.viewer,
      account: account ?? this.account,
      device: device ?? this.device,
    );
  }
}

class AuthViewer {
  const AuthViewer({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
  });

  factory AuthViewer.fromJson(Map<String, dynamic> json) {
    return AuthViewer(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'LabGuard User',
      role: json['role'] as String? ?? 'MEMBER',
    );
  }

  final String id;
  final String email;
  final String displayName;
  final String role;

  Map<String, dynamic> toJson() {
    return {'id': id, 'email': email, 'displayName': displayName, 'role': role};
  }
}

class AuthAccount {
  const AuthAccount({
    required this.id,
    required this.name,
    required this.brandAttribution,
  });

  factory AuthAccount.fromJson(Map<String, dynamic> json) {
    return AuthAccount(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Emilo Labs',
      brandAttribution:
          json['brandAttribution'] as String? ?? 'Built by Emilo Labs',
    );
  }

  final String id;
  final String name;
  final String brandAttribution;

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'brandAttribution': brandAttribution};
  }
}

class AuthDevice {
  const AuthDevice({
    required this.id,
    required this.name,
    required this.trustState,
  });

  factory AuthDevice.fromJson(Map<String, dynamic> json) {
    return AuthDevice(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown device',
      trustState: deviceTrustStateFromWire(
        json['trustState'] as String? ?? 'PENDING_APPROVAL',
      ),
    );
  }

  final String id;
  final String name;
  final DeviceTrustState trustState;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'trustState': trustState.name.toUpperCase(),
    };
  }
}
