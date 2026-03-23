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
