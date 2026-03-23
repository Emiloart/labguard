class VpnOverview {
  const VpnOverview({
    required this.connected,
    required this.serverName,
    required this.currentIp,
    required this.sessionDuration,
    required this.dnsMode,
  });

  final bool connected;
  final String serverName;
  final String currentIp;
  final Duration sessionDuration;
  final String dnsMode;

  String get sessionLabel {
    final hours = sessionDuration.inHours.toString().padLeft(2, '0');
    final minutes = (sessionDuration.inMinutes % 60).toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  factory VpnOverview.fromJson(Map<String, dynamic> json) {
    return VpnOverview(
      connected: json['connected'] as bool? ?? false,
      serverName: json['serverName'] as String? ?? 'Unassigned',
      currentIp: json['currentIp'] as String? ?? 'Unavailable',
      sessionDuration: Duration(
        seconds: json['sessionDurationSeconds'] as int? ?? 0,
      ),
      dnsMode: json['dnsMode'] as String? ?? 'Default',
    );
  }
}

class VpnPolicySettings {
  const VpnPolicySettings({
    required this.killSwitchEnabled,
    required this.autoConnectEnabled,
    required this.reconnectOnNetworkChange,
    required this.customDnsEnabled,
  });

  final bool killSwitchEnabled;
  final bool autoConnectEnabled;
  final bool reconnectOnNetworkChange;
  final bool customDnsEnabled;

  VpnPolicySettings copyWith({
    bool? killSwitchEnabled,
    bool? autoConnectEnabled,
    bool? reconnectOnNetworkChange,
    bool? customDnsEnabled,
  }) {
    return VpnPolicySettings(
      killSwitchEnabled: killSwitchEnabled ?? this.killSwitchEnabled,
      autoConnectEnabled: autoConnectEnabled ?? this.autoConnectEnabled,
      reconnectOnNetworkChange:
          reconnectOnNetworkChange ?? this.reconnectOnNetworkChange,
      customDnsEnabled: customDnsEnabled ?? this.customDnsEnabled,
    );
  }
}

class VpnServerRecord {
  const VpnServerRecord({
    required this.id,
    required this.name,
    required this.regionCode,
    required this.endpoint,
    required this.status,
    required this.isPrimary,
  });

  factory VpnServerRecord.fromJson(Map<String, dynamic> json) {
    return VpnServerRecord(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unassigned',
      regionCode: json['regionCode'] as String? ?? '',
      endpoint: json['endpoint'] as String? ?? '',
      status: json['status'] as String? ?? 'UNKNOWN',
      isPrimary: json['isPrimary'] as bool? ?? false,
    );
  }

  final String id;
  final String name;
  final String regionCode;
  final String endpoint;
  final String status;
  final bool isPrimary;

  String get displayLabel => isPrimary ? '$name • $id' : '$name • $regionCode';
}
