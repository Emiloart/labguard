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
