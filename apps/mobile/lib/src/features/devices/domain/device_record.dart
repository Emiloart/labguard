enum DeviceTrustState { trusted, pendingApproval, suspended, revoked }

enum DeviceConnectivityStatus { connected, disconnected, degraded }

class DeviceRecord {
  const DeviceRecord({
    required this.id,
    required this.name,
    required this.model,
    required this.platform,
    required this.appVersion,
    required this.lastActiveAt,
    required this.vpnStatus,
    required this.batteryLevel,
    required this.lastKnownIp,
    required this.lastKnownNetwork,
    required this.lastKnownLocation,
    required this.locationCapturedAt,
    required this.trustState,
    required this.isLost,
    required this.isPrimary,
  });

  final String id;
  final String name;
  final String model;
  final String platform;
  final String appVersion;
  final DateTime lastActiveAt;
  final DeviceConnectivityStatus vpnStatus;
  final int batteryLevel;
  final String lastKnownIp;
  final String lastKnownNetwork;
  final String lastKnownLocation;
  final DateTime locationCapturedAt;
  final DeviceTrustState trustState;
  final bool isLost;
  final bool isPrimary;

  factory DeviceRecord.fromJson(Map<String, dynamic> json) {
    return DeviceRecord(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown device',
      model: json['model'] as String? ?? 'Unknown model',
      platform: json['platform'] as String? ?? 'Android',
      appVersion: json['appVersion'] as String? ?? '0.0.0',
      lastActiveAt:
          DateTime.tryParse(json['lastActiveAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      vpnStatus: deviceConnectivityStatusFromWire(
        json['vpnStatus'] as String? ?? 'UNKNOWN',
      ),
      batteryLevel: json['batteryLevel'] as int? ?? 0,
      lastKnownIp: json['lastKnownIp'] as String? ?? 'Unavailable',
      lastKnownNetwork: json['lastKnownNetwork'] as String? ?? 'Unavailable',
      lastKnownLocation:
          json['lastKnownLocation'] as String? ?? 'Location unavailable',
      locationCapturedAt:
          DateTime.tryParse(json['locationCapturedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      trustState: deviceTrustStateFromWire(
        json['trustState'] as String? ?? 'PENDING_APPROVAL',
      ),
      isLost: json['isLost'] as bool? ?? false,
      isPrimary: json['isPrimary'] as bool? ?? false,
    );
  }
}

class DeviceDetailRecord extends DeviceRecord {
  const DeviceDetailRecord({
    required super.id,
    required super.name,
    required super.model,
    required super.platform,
    required super.appVersion,
    required super.lastActiveAt,
    required super.vpnStatus,
    required super.batteryLevel,
    required super.lastKnownIp,
    required super.lastKnownNetwork,
    required super.lastKnownLocation,
    required super.locationCapturedAt,
    required super.trustState,
    required super.isLost,
    required super.isPrimary,
    required this.lostModeStatus,
    required this.remoteActionsAvailable,
    required this.securityHistory,
  });

  factory DeviceDetailRecord.fromJson(Map<String, dynamic> json) {
    final base = DeviceRecord.fromJson(json);
    final rawActions =
        json['remoteActionsAvailable'] as List<dynamic>? ?? const [];
    final rawHistory = json['securityHistory'] as List<dynamic>? ?? const [];

    return DeviceDetailRecord(
      id: base.id,
      name: base.name,
      model: base.model,
      platform: base.platform,
      appVersion: base.appVersion,
      lastActiveAt: base.lastActiveAt,
      vpnStatus: base.vpnStatus,
      batteryLevel: base.batteryLevel,
      lastKnownIp: base.lastKnownIp,
      lastKnownNetwork: base.lastKnownNetwork,
      lastKnownLocation: base.lastKnownLocation,
      locationCapturedAt: base.locationCapturedAt,
      trustState: base.trustState,
      isLost: base.isLost,
      isPrimary: base.isPrimary,
      lostModeStatus: json['lostModeStatus'] as String? ?? 'OFF',
      remoteActionsAvailable: rawActions.whereType<String>().toList(
        growable: false,
      ),
      securityHistory: rawHistory
          .whereType<Map<String, dynamic>>()
          .map(DeviceSecurityHistoryEntry.fromJson)
          .toList(growable: false),
    );
  }

  final String lostModeStatus;
  final List<String> remoteActionsAvailable;
  final List<DeviceSecurityHistoryEntry> securityHistory;
}

class DeviceSecurityHistoryEntry {
  const DeviceSecurityHistoryEntry({
    required this.id,
    required this.title,
    required this.detail,
    required this.occurredAt,
  });

  factory DeviceSecurityHistoryEntry.fromJson(Map<String, dynamic> json) {
    return DeviceSecurityHistoryEntry(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Security event',
      detail: json['detail'] as String? ?? 'No additional detail available.',
      occurredAt:
          DateTime.tryParse(json['occurredAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String id;
  final String title;
  final String detail;
  final DateTime occurredAt;
}

DeviceTrustState deviceTrustStateFromWire(String value) {
  switch (value) {
    case 'TRUSTED':
      return DeviceTrustState.trusted;
    case 'SUSPENDED':
      return DeviceTrustState.suspended;
    case 'REVOKED':
      return DeviceTrustState.revoked;
    case 'PENDING_APPROVAL':
    default:
      return DeviceTrustState.pendingApproval;
  }
}

DeviceConnectivityStatus deviceConnectivityStatusFromWire(String value) {
  switch (value) {
    case 'CONNECTED':
      return DeviceConnectivityStatus.connected;
    case 'DEGRADED':
      return DeviceConnectivityStatus.degraded;
    case 'DISCONNECTED':
    case 'UNKNOWN':
    default:
      return DeviceConnectivityStatus.disconnected;
  }
}
