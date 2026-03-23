class SettingsBundle {
  const SettingsBundle({required this.preferences, required this.profile});

  factory SettingsBundle.fromJson(Map<String, dynamic> json) {
    return SettingsBundle(
      preferences: SecurityPreferences.fromJson(
        json['preferences'] as Map<String, dynamic>? ?? const {},
      ),
      profile: SettingsProfile.fromJson(
        json['profile'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  final SecurityPreferences preferences;
  final SettingsProfile profile;

  SettingsBundle copyWith({
    SecurityPreferences? preferences,
    SettingsProfile? profile,
  }) {
    return SettingsBundle(
      preferences: preferences ?? this.preferences,
      profile: profile ?? this.profile,
    );
  }
}

class SecurityPreferences {
  const SecurityPreferences({
    required this.biometricEnabled,
    required this.pinLockEnabled,
    required this.autoConnectEnabled,
    required this.killSwitchEnabled,
    required this.notificationsEnabled,
    required this.telemetryLevel,
    required this.locationPermissionStatus,
    required this.batteryOptimizationAcknowledged,
  });

  factory SecurityPreferences.fromJson(Map<String, dynamic> json) {
    return SecurityPreferences(
      biometricEnabled: json['biometricEnabled'] as bool? ?? false,
      pinLockEnabled: json['pinLockEnabled'] as bool? ?? false,
      autoConnectEnabled: json['autoConnectEnabled'] as bool? ?? true,
      killSwitchEnabled: json['killSwitchEnabled'] as bool? ?? true,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      telemetryLevel:
          json['telemetryLevel'] as String? ?? 'elevated_lost_mode_only',
      locationPermissionStatus:
          json['locationPermissionStatus'] as String? ?? 'not_requested',
      batteryOptimizationAcknowledged:
          json['batteryOptimizationAcknowledged'] as bool? ?? false,
    );
  }

  final bool biometricEnabled;
  final bool pinLockEnabled;
  final bool autoConnectEnabled;
  final bool killSwitchEnabled;
  final bool notificationsEnabled;
  final String telemetryLevel;
  final String locationPermissionStatus;
  final bool batteryOptimizationAcknowledged;

  SecurityPreferences copyWith({
    bool? biometricEnabled,
    bool? pinLockEnabled,
    bool? autoConnectEnabled,
    bool? killSwitchEnabled,
    bool? notificationsEnabled,
    String? telemetryLevel,
    String? locationPermissionStatus,
    bool? batteryOptimizationAcknowledged,
  }) {
    return SecurityPreferences(
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      pinLockEnabled: pinLockEnabled ?? this.pinLockEnabled,
      autoConnectEnabled: autoConnectEnabled ?? this.autoConnectEnabled,
      killSwitchEnabled: killSwitchEnabled ?? this.killSwitchEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      telemetryLevel: telemetryLevel ?? this.telemetryLevel,
      locationPermissionStatus:
          locationPermissionStatus ?? this.locationPermissionStatus,
      batteryOptimizationAcknowledged:
          batteryOptimizationAcknowledged ??
          this.batteryOptimizationAcknowledged,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'biometricEnabled': biometricEnabled,
      'pinLockEnabled': pinLockEnabled,
      'autoConnectEnabled': autoConnectEnabled,
      'killSwitchEnabled': killSwitchEnabled,
      'notificationsEnabled': notificationsEnabled,
      'telemetryLevel': telemetryLevel,
      'locationPermissionStatus': locationPermissionStatus,
      'batteryOptimizationAcknowledged': batteryOptimizationAcknowledged,
    };
  }
}

class SettingsProfile {
  const SettingsProfile({
    required this.viewerDisplayName,
    required this.viewerEmail,
    required this.accountName,
    required this.brandAttribution,
  });

  factory SettingsProfile.fromJson(Map<String, dynamic> json) {
    final viewer = json['viewer'] as Map<String, dynamic>? ?? const {};
    final account = json['account'] as Map<String, dynamic>? ?? const {};

    return SettingsProfile(
      viewerDisplayName: viewer['displayName'] as String? ?? 'LabGuard User',
      viewerEmail: viewer['email'] as String? ?? 'owner@emilolabs.com',
      accountName: account['name'] as String? ?? 'Emilo Labs',
      brandAttribution:
          account['brandAttribution'] as String? ?? 'Built by Emilo Labs',
    );
  }

  final String viewerDisplayName;
  final String viewerEmail;
  final String accountName;
  final String brandAttribution;
}
