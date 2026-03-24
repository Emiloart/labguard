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

class VpnServerRecord {
  const VpnServerRecord({
    required this.id,
    required this.name,
    required this.regionCode,
    required this.endpoint,
    required this.status,
    required this.isPrimary,
    required this.dnsServers,
  });

  factory VpnServerRecord.fromJson(Map<String, dynamic> json) {
    final rawDnsServers = json['dnsServers'] as List<dynamic>? ?? const [];

    return VpnServerRecord(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unassigned',
      regionCode: json['regionCode'] as String? ?? '',
      endpoint: json['endpoint'] as String? ?? '',
      status: json['status'] as String? ?? 'UNKNOWN',
      isPrimary: json['isPrimary'] as bool? ?? false,
      dnsServers: rawDnsServers.whereType<String>().toList(growable: false),
    );
  }

  final String id;
  final String name;
  final String regionCode;
  final String endpoint;
  final String status;
  final bool isPrimary;
  final List<String> dnsServers;

  String get displayLabel => isPrimary ? '$name • $id' : '$name • $regionCode';
}

class VpnProfileBundle {
  const VpnProfileBundle({
    required this.deviceId,
    required this.profileStatus,
    required this.revision,
    required this.tunnelName,
    required this.serverId,
    required this.serverName,
    required this.endpoint,
    required this.dnsServers,
    required this.issuedAt,
    required this.rotatedAt,
    required this.config,
    required this.note,
  });

  factory VpnProfileBundle.fromJson(Map<String, dynamic> json) {
    final rawDnsServers = json['dnsServers'] as List<dynamic>? ?? const [];

    return VpnProfileBundle(
      deviceId: json['deviceId'] as String? ?? '',
      profileStatus: json['profileStatus'] as String? ?? 'UNKNOWN',
      revision: json['revision'] as int? ?? 0,
      tunnelName: json['tunnelName'] as String? ?? 'labguard',
      serverId: json['serverId'] as String? ?? '',
      serverName: json['serverName'] as String? ?? 'Unassigned',
      endpoint: json['endpoint'] as String? ?? '',
      dnsServers: rawDnsServers.whereType<String>().toList(growable: false),
      issuedAt: DateTime.tryParse(json['issuedAt'] as String? ?? ''),
      rotatedAt: DateTime.tryParse(json['rotatedAt'] as String? ?? ''),
      config: json['config'] as String?,
      note: json['note'] as String? ?? '',
    );
  }

  final String deviceId;
  final String profileStatus;
  final int revision;
  final String tunnelName;
  final String serverId;
  final String serverName;
  final String endpoint;
  final List<String> dnsServers;
  final DateTime? issuedAt;
  final DateTime? rotatedAt;
  final String? config;
  final String note;

  bool get isActive => profileStatus == 'ACTIVE';
  bool get hasConfig => (config ?? '').isNotEmpty;

  Map<String, dynamic> toStoredJson() {
    return {
      'deviceId': deviceId,
      'profileStatus': profileStatus,
      'revision': revision,
      'tunnelName': tunnelName,
      'serverId': serverId,
      'serverName': serverName,
      'endpoint': endpoint,
      'dnsServers': dnsServers,
      'issuedAt': issuedAt?.toIso8601String(),
      'rotatedAt': rotatedAt?.toIso8601String(),
      'config': config,
      'note': note,
    };
  }
}

enum VpnConnectionState {
  disconnected,
  connecting,
  connected,
  error,
  authRequired,
  profileMissing,
}

VpnConnectionState vpnConnectionStateFromWire(String value) {
  switch (value) {
    case 'CONNECTED':
      return VpnConnectionState.connected;
    case 'CONNECTING':
      return VpnConnectionState.connecting;
    case 'ERROR':
      return VpnConnectionState.error;
    case 'AUTH_REQUIRED':
      return VpnConnectionState.authRequired;
    case 'PROFILE_MISSING':
      return VpnConnectionState.profileMissing;
    default:
      return VpnConnectionState.disconnected;
  }
}

class VpnSessionSnapshot {
  const VpnSessionSnapshot({
    required this.deviceId,
    required this.connectionState,
    required this.connected,
    required this.profileInstalled,
    required this.profileRevision,
    required this.serverId,
    required this.serverName,
    required this.endpoint,
    required this.currentIp,
    required this.dnsMode,
    required this.connectedAt,
    required this.lastHeartbeatAt,
    required this.lastHandshakeAt,
    required this.bytesReceived,
    required this.bytesSent,
    required this.sessionDuration,
    required this.lastError,
  });

  factory VpnSessionSnapshot.fromJson(Map<String, dynamic> json) {
    return VpnSessionSnapshot(
      deviceId: json['deviceId'] as String? ?? '',
      connectionState: vpnConnectionStateFromWire(
        json['tunnelState'] as String? ?? 'DISCONNECTED',
      ),
      connected: json['connected'] as bool? ?? false,
      profileInstalled: json['profileInstalled'] as bool? ?? false,
      profileRevision: json['profileRevision'] as int? ?? 0,
      serverId: json['serverId'] as String? ?? '',
      serverName: json['serverName'] as String? ?? 'Unassigned',
      endpoint: json['endpoint'] as String? ?? '',
      currentIp: json['currentIp'] as String? ?? 'Unavailable',
      dnsMode: json['dnsMode'] as String? ?? 'Default',
      connectedAt: DateTime.tryParse(json['connectedAt'] as String? ?? ''),
      lastHeartbeatAt: DateTime.tryParse(
        json['lastHeartbeatAt'] as String? ?? '',
      ),
      lastHandshakeAt: DateTime.tryParse(
        json['lastHandshakeAt'] as String? ?? '',
      ),
      bytesReceived: (json['bytesReceived'] as num?)?.toInt() ?? 0,
      bytesSent: (json['bytesSent'] as num?)?.toInt() ?? 0,
      sessionDuration: Duration(
        seconds: json['sessionDurationSeconds'] as int? ?? 0,
      ),
      lastError: json['lastError'] as String?,
    );
  }

  final String deviceId;
  final VpnConnectionState connectionState;
  final bool connected;
  final bool profileInstalled;
  final int profileRevision;
  final String serverId;
  final String serverName;
  final String endpoint;
  final String currentIp;
  final String dnsMode;
  final DateTime? connectedAt;
  final DateTime? lastHeartbeatAt;
  final DateTime? lastHandshakeAt;
  final int bytesReceived;
  final int bytesSent;
  final Duration sessionDuration;
  final String? lastError;

  String get sessionLabel {
    final hours = sessionDuration.inHours.toString().padLeft(2, '0');
    final minutes = (sessionDuration.inMinutes % 60).toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  String get trafficLabel =>
      '${_formatBytes(bytesReceived)} down • ${_formatBytes(bytesSent)} up';

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }

    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    return '$bytes B';
  }
}

class VpnControlState {
  const VpnControlState({
    required this.profile,
    required this.remoteSession,
    required this.nativeStatus,
    required this.capabilities,
  });

  final VpnProfileBundle? profile;
  final VpnSessionSnapshot remoteSession;
  final VpnNativeStatus nativeStatus;
  final VpnPlatformCapabilities capabilities;

  bool get hasUsableProfile =>
      (profile?.isActive ?? false) &&
      (profile?.hasConfig ?? false) &&
      nativeStatus.profileInstalled;
}

class VpnPlatformCapabilities {
  const VpnPlatformCapabilities({
    required this.platform,
    required this.vpnServicePrepared,
    required this.wireGuardBackendIntegrated,
    required this.permissionGranted,
    required this.packageName,
    required this.notes,
  });

  factory VpnPlatformCapabilities.fromJson(Map<String, dynamic> json) {
    return VpnPlatformCapabilities(
      platform: json['platform'] as String? ?? 'unknown',
      vpnServicePrepared: json['vpnServicePrepared'] as bool? ?? false,
      wireGuardBackendIntegrated:
          json['wireGuardBackendIntegrated'] as bool? ?? false,
      permissionGranted: json['permissionGranted'] as bool? ?? false,
      packageName: json['packageName'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
    );
  }

  final String platform;
  final bool vpnServicePrepared;
  final bool wireGuardBackendIntegrated;
  final bool permissionGranted;
  final String packageName;
  final String notes;
}

class VpnNativeStatus {
  const VpnNativeStatus({
    required this.permissionGranted,
    required this.profileInstalled,
    required this.tunnelState,
    required this.tunnelName,
    required this.serverId,
    required this.profileRevision,
    required this.currentIp,
    required this.bytesReceived,
    required this.bytesSent,
    required this.connectedAt,
    required this.lastHandshakeAt,
    required this.lastError,
    required this.backendVersion,
  });

  factory VpnNativeStatus.fromJson(Map<String, dynamic> json) {
    return VpnNativeStatus(
      permissionGranted: json['permissionGranted'] as bool? ?? false,
      profileInstalled: json['profileInstalled'] as bool? ?? false,
      tunnelState: vpnConnectionStateFromWire(
        json['tunnelState'] as String? ?? 'DISCONNECTED',
      ),
      tunnelName: json['tunnelName'] as String? ?? 'labguard',
      serverId: json['serverId'] as String? ?? '',
      profileRevision: json['profileRevision'] as int? ?? 0,
      currentIp: json['currentIp'] as String? ?? 'Unavailable',
      bytesReceived: (json['bytesReceived'] as num?)?.toInt() ?? 0,
      bytesSent: (json['bytesSent'] as num?)?.toInt() ?? 0,
      connectedAt: DateTime.tryParse(json['connectedAt'] as String? ?? ''),
      lastHandshakeAt: DateTime.tryParse(
        json['lastHandshakeAt'] as String? ?? '',
      ),
      lastError: json['lastError'] as String?,
      backendVersion: json['backendVersion'] as String? ?? 'Unavailable',
    );
  }

  final bool permissionGranted;
  final bool profileInstalled;
  final VpnConnectionState tunnelState;
  final String tunnelName;
  final String serverId;
  final int profileRevision;
  final String currentIp;
  final int bytesReceived;
  final int bytesSent;
  final DateTime? connectedAt;
  final DateTime? lastHandshakeAt;
  final String? lastError;
  final String backendVersion;
}
