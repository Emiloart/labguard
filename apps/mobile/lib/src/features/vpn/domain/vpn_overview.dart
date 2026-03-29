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
    required this.locationLabel,
    required this.hostname,
    required this.endpoint,
    required this.port,
    required this.status,
    required this.isPrimary,
    required this.selectable,
    required this.availabilityState,
    required this.availabilityMessage,
    required this.exitIpAddress,
    required this.dnsServers,
  });

  factory VpnServerRecord.fromJson(Map<String, dynamic> json) {
    final rawDnsServers = json['dnsServers'] as List<dynamic>? ?? const [];

    return VpnServerRecord(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unassigned',
      regionCode: json['regionCode'] as String? ?? '',
      locationLabel: json['locationLabel'] as String? ?? 'Unknown region',
      hostname: json['hostname'] as String? ?? '',
      endpoint: json['endpoint'] as String? ?? '',
      port: json['port'] as int? ?? 0,
      status: json['status'] as String? ?? 'UNKNOWN',
      isPrimary: json['isPrimary'] as bool? ?? false,
      selectable: json['selectable'] as bool? ?? false,
      availabilityState:
          json['availabilityState'] as String? ?? 'not_configured',
      availabilityMessage:
          json['availabilityMessage'] as String? ??
          'This region is not ready yet.',
      exitIpAddress: json['exitIpAddress'] as String? ?? '',
      dnsServers: rawDnsServers.whereType<String>().toList(growable: false),
    );
  }

  final String id;
  final String name;
  final String regionCode;
  final String locationLabel;
  final String hostname;
  final String endpoint;
  final int port;
  final String status;
  final bool isPrimary;
  final bool selectable;
  final String availabilityState;
  final String availabilityMessage;
  final String exitIpAddress;
  final List<String> dnsServers;

  String get displayLabel => name;
}

class VpnProfileBundle {
  const VpnProfileBundle({
    required this.deviceId,
    required this.profileStatus,
    required this.revision,
    required this.tunnelName,
    required this.serverId,
    required this.serverName,
    required this.locationLabel,
    required this.endpoint,
    required this.exitIpAddress,
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
      locationLabel: json['locationLabel'] as String? ?? 'Unknown region',
      endpoint: json['endpoint'] as String? ?? '',
      exitIpAddress: json['exitIpAddress'] as String? ?? '',
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
  final String locationLabel;
  final String endpoint;
  final String exitIpAddress;
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
      'locationLabel': locationLabel,
      'endpoint': endpoint,
      'exitIpAddress': exitIpAddress,
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
    required this.locationLabel,
    required this.endpoint,
    required this.exitIpAddress,
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
      locationLabel: json['locationLabel'] as String? ?? 'Unknown region',
      endpoint: json['endpoint'] as String? ?? '',
      exitIpAddress: json['exitIpAddress'] as String? ?? '',
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
  final String locationLabel;
  final String endpoint;
  final String exitIpAddress;
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

  VpnConnectionState get effectiveTunnelState {
    if (remoteSession.connectionState == VpnConnectionState.error) {
      return VpnConnectionState.error;
    }
    if (nativeStatus.tunnelState == VpnConnectionState.authRequired) {
      return VpnConnectionState.authRequired;
    }
    if (!nativeStatus.profileInstalled) {
      return VpnConnectionState.profileMissing;
    }
    if (nativeStatus.tunnelState == VpnConnectionState.connected &&
        remoteSession.connectionState == VpnConnectionState.connected) {
      return VpnConnectionState.connected;
    }
    if (nativeStatus.tunnelState == VpnConnectionState.connected &&
        remoteSession.connectionState != VpnConnectionState.connected) {
      return VpnConnectionState.connecting;
    }
    if (nativeStatus.tunnelState == VpnConnectionState.connecting) {
      return VpnConnectionState.connecting;
    }
    if (nativeStatus.tunnelState == VpnConnectionState.error) {
      return VpnConnectionState.error;
    }
    return remoteSession.connectionState;
  }

  String get activeServerName => profile?.serverName ?? remoteSession.serverName;

  String get activeLocationLabel =>
      profile?.locationLabel ?? remoteSession.locationLabel;

  String get activeEndpoint => profile?.endpoint ?? remoteSession.endpoint;

  String get activeExitIpAddress =>
      profile?.exitIpAddress ?? remoteSession.exitIpAddress;

  String get displayCurrentIp =>
      remoteSession.currentIp != 'Unavailable'
          ? remoteSession.currentIp
          : nativeStatus.currentIp;

  String? get effectiveError => remoteSession.lastError ?? nativeStatus.lastError;
}

bool shouldAttemptAutoConnect({
  required VpnNativeStatus status,
  required bool autoConnectEnabled,
}) {
  if (!autoConnectEnabled || !status.desiredConnected) {
    return false;
  }

  if (!status.permissionGranted || !status.profileInstalled) {
    return false;
  }

  return status.tunnelState == VpnConnectionState.disconnected ||
      status.tunnelState == VpnConnectionState.error;
}

class VpnPlatformCapabilities {
  const VpnPlatformCapabilities({
    required this.platform,
    required this.vpnServicePrepared,
    required this.wireGuardBackendIntegrated,
    required this.supportsAlwaysOnSystemSettings,
    required this.killSwitchManagedBySystem,
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
      supportsAlwaysOnSystemSettings:
          json['supportsAlwaysOnSystemSettings'] as bool? ?? false,
      killSwitchManagedBySystem:
          json['killSwitchManagedBySystem'] as bool? ?? false,
      permissionGranted: json['permissionGranted'] as bool? ?? false,
      packageName: json['packageName'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
    );
  }

  final String platform;
  final bool vpnServicePrepared;
  final bool wireGuardBackendIntegrated;
  final bool supportsAlwaysOnSystemSettings;
  final bool killSwitchManagedBySystem;
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
    required this.desiredConnected,
    required this.killSwitchRequested,
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
      desiredConnected: json['desiredConnected'] as bool? ?? false,
      killSwitchRequested: json['killSwitchRequested'] as bool? ?? false,
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
  final bool desiredConnected;
  final bool killSwitchRequested;
  final String currentIp;
  final int bytesReceived;
  final int bytesSent;
  final DateTime? connectedAt;
  final DateTime? lastHandshakeAt;
  final String? lastError;
  final String backendVersion;
}
