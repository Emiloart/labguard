class FindDeviceSnapshot {
  const FindDeviceSnapshot({
    required this.deviceId,
    required this.lostModeStatus,
    required this.liveTrackingEnabled,
    required this.updateMode,
    required this.updateFrequencyLabel,
    required this.currentLocation,
    required this.items,
  });

  factory FindDeviceSnapshot.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];

    return FindDeviceSnapshot(
      deviceId: json['deviceId'] as String? ?? '',
      lostModeStatus: json['lostModeStatus'] as String? ?? 'OFF',
      liveTrackingEnabled: json['liveTrackingEnabled'] as bool? ?? false,
      updateMode: json['updateMode'] as String? ?? 'minimal_background',
      updateFrequencyLabel:
          json['updateFrequencyLabel'] as String? ??
          'Only on explicit security events',
      currentLocation: json['currentLocation'] is Map<String, dynamic>
          ? FindDeviceLocationRecord.fromJson(
              json['currentLocation'] as Map<String, dynamic>,
            )
          : null,
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(FindDeviceLocationRecord.fromJson)
          .toList(growable: false),
    );
  }

  final String deviceId;
  final String lostModeStatus;
  final bool liveTrackingEnabled;
  final String updateMode;
  final String updateFrequencyLabel;
  final FindDeviceLocationRecord? currentLocation;
  final List<FindDeviceLocationRecord> items;
}

class FindDeviceLocationRecord {
  const FindDeviceLocationRecord({
    required this.id,
    required this.deviceId,
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAt,
    required this.source,
    this.lastKnownNetwork,
    this.lastKnownIp,
  });

  factory FindDeviceLocationRecord.fromJson(Map<String, dynamic> json) {
    return FindDeviceLocationRecord(
      id: json['id'] as String? ?? '',
      deviceId: json['deviceId'] as String? ?? '',
      label: json['label'] as String? ?? 'Unknown location',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble() ?? 0,
      capturedAt:
          DateTime.tryParse(json['capturedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      source: json['source'] as String? ?? 'BACKGROUND',
      lastKnownNetwork: json['lastKnownNetwork'] as String?,
      lastKnownIp: json['lastKnownIp'] as String?,
    );
  }

  final String id;
  final String deviceId;
  final String label;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime capturedAt;
  final String source;
  final String? lastKnownNetwork;
  final String? lastKnownIp;
}
