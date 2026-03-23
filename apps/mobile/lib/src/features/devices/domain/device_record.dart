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
}
