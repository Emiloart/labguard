class AboutRuntimeStatus {
  const AboutRuntimeStatus({
    required this.status,
    required this.service,
    required this.brandAttribution,
    required this.timestamp,
    required this.stage,
    required this.summary,
    required this.seededBootstrapActive,
    required this.vpnRegions,
  });

  factory AboutRuntimeStatus.fromJson(Map<String, dynamic> json) {
    final readiness = json['readiness'] as Map<String, dynamic>? ?? const {};
    final rawRegions = readiness['vpnRegions'] as List<dynamic>? ?? const [];

    return AboutRuntimeStatus(
      status: json['status'] as String? ?? 'unknown',
      service: json['service'] as String? ?? 'labguard-api',
      brandAttribution:
          json['brandAttribution'] as String? ?? 'Built by Emilo Labs',
      timestamp: json['timestamp'] as String? ?? '',
      stage: readiness['stage'] as String? ?? 'operator_preview',
      summary: readiness['summary'] as String? ?? 'Status unavailable.',
      seededBootstrapActive:
          readiness['seededBootstrapActive'] as bool? ?? true,
      vpnRegions: rawRegions
          .whereType<Map<String, dynamic>>()
          .map(AboutRuntimeRegion.fromJson)
          .toList(growable: false),
    );
  }

  final String status;
  final String service;
  final String brandAttribution;
  final String timestamp;
  final String stage;
  final String summary;
  final bool seededBootstrapActive;
  final List<AboutRuntimeRegion> vpnRegions;

  bool get reachable => status == 'ok';
}

class AboutRuntimeRegion {
  const AboutRuntimeRegion({
    required this.regionCode,
    required this.name,
    required this.locationLabel,
    required this.ready,
    required this.availabilityState,
    required this.availabilityMessage,
  });

  factory AboutRuntimeRegion.fromJson(Map<String, dynamic> json) {
    return AboutRuntimeRegion(
      regionCode: json['regionCode'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown region',
      locationLabel: json['locationLabel'] as String? ?? 'Unknown location',
      ready: json['ready'] as bool? ?? false,
      availabilityState: json['availabilityState'] as String? ?? 'unknown',
      availabilityMessage:
          json['availabilityMessage'] as String? ?? 'Status unavailable.',
    );
  }

  final String regionCode;
  final String name;
  final String locationLabel;
  final bool ready;
  final String availabilityState;
  final String availabilityMessage;
}
