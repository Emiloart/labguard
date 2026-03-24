import { randomBytes } from 'node:crypto';

type UserRole = 'OWNER' | 'MEMBER';
type DeviceTrustState =
  | 'TRUSTED'
  | 'PENDING_APPROVAL'
  | 'SUSPENDED'
  | 'REVOKED';
type DeviceConnectivityState =
  | 'CONNECTED'
  | 'DISCONNECTED'
  | 'DEGRADED'
  | 'UNKNOWN';
type SecurityEventSeverity = 'INFO' | 'WARNING' | 'CRITICAL';
type VpnProfileStatus = 'ACTIVE' | 'REVOKED';
type VpnTunnelState =
  | 'DISCONNECTED'
  | 'CONNECTING'
  | 'CONNECTED'
  | 'ERROR'
  | 'AUTH_REQUIRED'
  | 'PROFILE_MISSING';

type ViewerProfile = {
  id: string;
  email: string;
  displayName: string;
  role: UserRole;
};

type AccountProfile = {
  id: string;
  name: string;
  brandAttribution: string;
};

type SessionDevice = {
  id: string;
  name: string;
  trustState: DeviceTrustState;
};

type DeviceSeed = {
  id: string;
  name: string;
  model: string;
  platform: string;
  appVersion: string;
  trustState: DeviceTrustState;
  batteryLevel: number;
  isLost: boolean;
  isPrimary: boolean;
  lastActiveAt: string;
  lastKnownIp: string;
  lastKnownNetwork: string;
  lastKnownLocation: string;
  locationCapturedAt: string;
};

type DeviceRecord = DeviceSeed & {
  vpnStatus: DeviceConnectivityState;
};

type SecurityPreferenceState = {
  biometricEnabled: boolean;
  pinLockEnabled: boolean;
  autoConnectEnabled: boolean;
  killSwitchEnabled: boolean;
  notificationsEnabled: boolean;
  telemetryLevel: 'minimal' | 'elevated_lost_mode_only';
  locationPermissionStatus: 'not_requested' | 'granted_when_in_use';
  batteryOptimizationAcknowledged: boolean;
};

type SecurityEventRecord = {
  id: string;
  type: string;
  severity: SecurityEventSeverity;
  title: string;
  summary: string;
  unread: boolean;
  occurredAt: string;
  deviceName?: string;
};

type VpnServerRecord = {
  id: string;
  name: string;
  regionCode: string;
  endpoint: string;
  hostAddress: string;
  status: 'ACTIVE' | 'MAINTENANCE';
  isPrimary: boolean;
  dnsServers: string[];
};

type VpnProfileRecord = {
  deviceId: string;
  profileStatus: VpnProfileStatus;
  revision: number;
  tunnelName: string;
  serverId: string;
  dnsServers: string[];
  issuedAt: string;
  rotatedAt: string;
  config: string | null;
  note: string;
};

type VpnRuntimeState = {
  tunnelState: VpnTunnelState;
  currentIp: string;
  dnsMode: string;
  connectedAt: string | null;
  lastHeartbeatAt: string | null;
  lastHandshakeAt: string | null;
  bytesReceived: number;
  bytesSent: number;
  lastError: string | null;
  serverId: string;
};

type VpnSessionPatch = {
  deviceId?: string;
  serverId?: string;
  tunnelState?: string;
  currentIp?: string;
  bytesReceived?: number;
  bytesSent?: number;
  lastHandshakeAt?: string;
  lastError?: string;
};

const sessionTokens = {
  accessToken: 'labguard-phase-2-access-token',
  refreshToken: 'labguard-phase-2-refresh-token',
  expiresInSeconds: 900,
};

const viewer: ViewerProfile = {
  id: 'user-owner-01',
  email: 'owner@emilolabs.com',
  displayName: 'Emilo Owner',
  role: 'OWNER',
};

const account: AccountProfile = {
  id: 'acct-emilo-labs',
  name: 'Emilo Labs',
  brandAttribution: 'Built by Emilo Labs',
};

let preferences: SecurityPreferenceState = {
  biometricEnabled: true,
  pinLockEnabled: false,
  autoConnectEnabled: true,
  killSwitchEnabled: true,
  notificationsEnabled: true,
  telemetryLevel: 'elevated_lost_mode_only',
  locationPermissionStatus: 'granted_when_in_use',
  batteryOptimizationAcknowledged: false,
};

const vpnServers: VpnServerRecord[] = [
  {
    id: 'wg-01',
    name: 'Casablanca Primary',
    regionCode: 'ma-cas',
    endpoint: '162.55.11.18:51820',
    hostAddress: '162.55.11.18',
    status: 'ACTIVE',
    isPrimary: true,
    dnsServers: ['10.66.0.1', '1.1.1.1'],
  },
];

const deviceSeeds: DeviceSeed[] = [
  {
    id: 'pixel-9-pro',
    name: 'Primary Pixel',
    model: 'Google Pixel 9 Pro',
    platform: 'Android 15',
    appVersion: '0.1.0',
    trustState: 'TRUSTED',
    batteryLevel: 82,
    isLost: false,
    isPrimary: true,
    lastActiveAt: isoAgo({ minutes: 3 }),
    lastKnownIp: '185.233.44.12',
    lastKnownNetwork: 'Emilo Labs Secure Wi-Fi',
    lastKnownLocation: 'Casablanca, MA',
    locationCapturedAt: isoAgo({ minutes: 4 }),
  },
  {
    id: 'galaxy-s24',
    name: 'Travel Device',
    model: 'Samsung Galaxy S24',
    platform: 'Android 14',
    appVersion: '0.1.0',
    trustState: 'TRUSTED',
    batteryLevel: 46,
    isLost: true,
    isPrimary: false,
    lastActiveAt: isoAgo({ minutes: 27 }),
    lastKnownIp: '102.64.220.9',
    lastKnownNetwork: 'LTE',
    lastKnownLocation: 'Rabat, MA',
    locationCapturedAt: isoAgo({ minutes: 18 }),
  },
  {
    id: 'owner-tablet',
    name: 'Owner Tablet',
    model: 'Lenovo Tab P12',
    platform: 'Android 14',
    appVersion: '0.1.0',
    trustState: 'PENDING_APPROVAL',
    batteryLevel: 64,
    isLost: false,
    isPrimary: false,
    lastActiveAt: isoAgo({ hours: 4 }),
    lastKnownIp: '41.248.2.22',
    lastKnownNetwork: 'Home Fiber',
    lastKnownLocation: 'Last update withheld',
    locationCapturedAt: isoAgo({ hours: 5 }),
  },
];

const securityEvents: SecurityEventRecord[] = [
  {
    id: 'evt-01',
    type: 'DEVICE_MARKED_LOST',
    severity: 'CRITICAL',
    title: 'Travel Device remains in lost mode',
    summary:
      'Elevated location updates are still active while the device is online.',
    unread: true,
    occurredAt: isoAgo({ minutes: 21 }),
    deviceName: 'Travel Device',
  },
  {
    id: 'evt-02',
    type: 'VPN_RECONNECTED',
    severity: 'INFO',
    title: 'Primary Pixel tunnel recovered',
    summary:
      'WireGuard re-established after a network transition without manual action.',
    unread: true,
    occurredAt: isoAgo({ minutes: 9 }),
    deviceName: 'Primary Pixel',
  },
  {
    id: 'evt-03',
    type: 'DEVICE_PENDING_APPROVAL',
    severity: 'WARNING',
    title: 'Owner Tablet is awaiting approval',
    summary:
      'The device is registered but cannot receive an active VPN profile yet.',
    unread: false,
    occurredAt: isoAgo({ hours: 4 }),
    deviceName: 'Owner Tablet',
  },
];

const vpnProfiles = new Map<string, VpnProfileRecord>();
const vpnRuntimeByDevice = new Map<string, VpnRuntimeState>([
  [
    'pixel-9-pro',
    {
      tunnelState: 'CONNECTED',
      currentIp: '185.233.44.12',
      dnsMode: 'Private DNS via tunnel',
      connectedAt: isoAgo({ hours: 3, minutes: 14 }),
      lastHeartbeatAt: isoAgo({ minutes: 1 }),
      lastHandshakeAt: isoAgo({ minutes: 1 }),
      bytesReceived: 25_124_122,
      bytesSent: 9_423_311,
      lastError: null,
      serverId: 'wg-01',
    },
  ],
  [
    'galaxy-s24',
    {
      tunnelState: 'ERROR',
      currentIp: 'Unavailable',
      dnsMode: 'Tunnel unavailable',
      connectedAt: null,
      lastHeartbeatAt: isoAgo({ minutes: 27 }),
      lastHandshakeAt: isoAgo({ minutes: 31 }),
      bytesReceived: 0,
      bytesSent: 0,
      lastError: 'Awaiting recovery while the device remains in lost mode.',
      serverId: 'wg-01',
    },
  ],
  [
    'owner-tablet',
    {
      tunnelState: 'PROFILE_MISSING',
      currentIp: 'Unavailable',
      dnsMode: 'No profile assigned',
      connectedAt: null,
      lastHeartbeatAt: isoAgo({ hours: 4 }),
      lastHandshakeAt: null,
      bytesReceived: 0,
      bytesSent: 0,
      lastError: 'Device approval required before issuing a tunnel profile.',
      serverId: 'wg-01',
    },
  ],
]);

initializeVpnProfiles();

function initializeVpnProfiles() {
  for (const device of deviceSeeds) {
    if (device.trustState != 'TRUSTED') {
      continue;
    }

    vpnProfiles.set(device.id, issueVpnProfile(device.id, 'wg-01', 1));
  }
}

function isoAgo({
  minutes = 0,
  hours = 0,
  seconds = 0,
}: {
  minutes?: number;
  hours?: number;
  seconds?: number;
}) {
  return new Date(
    Date.now() -
      minutes * 60 * 1000 -
      hours * 60 * 60 * 1000 -
      seconds * 1000,
  ).toISOString();
}

function nowIso() {
  return new Date().toISOString();
}

function currentSessionDevice(): SessionDevice {
  const device =
    buildDevices().find((entry) => entry.isPrimary) ?? buildDevices()[0]!;
  return {
    id: device.id,
    name: device.name,
    trustState: device.trustState,
  };
}

function findServer(serverId: string) {
  return vpnServers.find((server) => server.id == serverId) ?? vpnServers[0]!;
}

function profileAddressForDevice(deviceId: string) {
  switch (deviceId) {
    case 'galaxy-s24':
      return '10.66.0.3/32';
    case 'owner-tablet':
      return '10.66.0.4/32';
    default:
      return '10.66.0.2/32';
  }
}

function issueVpnProfile(
  deviceId: string,
  serverId: string,
  revision: number,
): VpnProfileRecord {
  const server = findServer(serverId);
  const issuedAt = nowIso();
  const privateKey = randomBytes(32).toString('base64');
  const publicKey = randomBytes(32).toString('base64');

  return {
    deviceId,
    profileStatus: 'ACTIVE',
    revision,
    tunnelName: deviceId.replace(/[^a-zA-Z0-9]/g, '').slice(0, 12) || 'labguard',
    serverId,
    dnsServers: server.dnsServers,
    issuedAt,
    rotatedAt: issuedAt,
    config: [
      '[Interface]',
      `PrivateKey = ${privateKey}`,
      `Address = ${profileAddressForDevice(deviceId)}`,
      `DNS = ${server.dnsServers.join(', ')}`,
      'MTU = 1280',
      '',
      '[Peer]',
      `PublicKey = ${publicKey}`,
      'AllowedIPs = 0.0.0.0/0, ::/0',
      `Endpoint = ${server.endpoint}`,
      'PersistentKeepalive = 25',
      '',
    ].join('\n'),
    note:
      'Development profile for the LabGuard Android VPN core. Replace with live provisioned credentials before release.',
  };
}

function ensureVpnProfile(deviceId: string) {
  const existing = vpnProfiles.get(deviceId);

  if (existing) {
    return existing;
  }

  const created = issueVpnProfile(deviceId, 'wg-01', 1);
  vpnProfiles.set(deviceId, created);
  return created;
}

function ensureVpnRuntime(deviceId: string) {
  const existing = vpnRuntimeByDevice.get(deviceId);

  if (existing) {
    return existing;
  }

  const created: VpnRuntimeState = {
    tunnelState: 'DISCONNECTED',
    currentIp: 'Unavailable',
    dnsMode: 'Private DNS via tunnel',
    connectedAt: null,
    lastHeartbeatAt: null,
    lastHandshakeAt: null,
    bytesReceived: 0,
    bytesSent: 0,
    lastError: null,
    serverId: 'wg-01',
  };
  vpnRuntimeByDevice.set(deviceId, created);
  return created;
}

function connectivityStateForRuntime(
  state: VpnTunnelState,
): DeviceConnectivityState {
  switch (state) {
    case 'CONNECTED':
      return 'CONNECTED';
    case 'CONNECTING':
    case 'ERROR':
    case 'AUTH_REQUIRED':
      return 'DEGRADED';
    case 'PROFILE_MISSING':
    case 'DISCONNECTED':
      return 'DISCONNECTED';
  }
}

function buildDevices(): DeviceRecord[] {
  return deviceSeeds.map((device) => {
    const runtime = vpnRuntimeByDevice.get(device.id);

    return {
      ...device,
      vpnStatus: runtime
        ? connectivityStateForRuntime(runtime.tunnelState)
        : 'UNKNOWN',
      lastActiveAt: runtime?.lastHeartbeatAt ?? device.lastActiveAt,
      lastKnownIp:
        runtime?.currentIp && runtime.currentIp != 'Unavailable'
          ? runtime.currentIp
          : device.lastKnownIp,
    };
  });
}

function profileEnvelope(deviceId: string) {
  const profile = ensureVpnProfile(deviceId);
  const server = findServer(profile.serverId);

  return {
    deviceId: profile.deviceId,
    profileStatus: profile.profileStatus,
    revision: profile.revision,
    tunnelName: profile.tunnelName,
    serverId: profile.serverId,
    serverName: server.name,
    endpoint: server.endpoint,
    dnsServers: profile.dnsServers,
    issuedAt: profile.issuedAt,
    rotatedAt: profile.rotatedAt,
    config: profile.config,
    note: profile.note,
  };
}

function sessionEnvelope(deviceId: string) {
  const runtime = ensureVpnRuntime(deviceId);
  const profile = vpnProfiles.get(deviceId) ?? null;
  const server = findServer(runtime.serverId);
  const sessionDurationSeconds = runtime.connectedAt
    ? Math.max(
        0,
        Math.floor(
          (Date.now() - new Date(runtime.connectedAt).getTime()) / 1000,
        ),
      )
    : 0;

  return {
    deviceId,
    tunnelState: runtime.tunnelState,
    connected: runtime.tunnelState == 'CONNECTED',
    profileInstalled: profile?.profileStatus == 'ACTIVE' && profile.config != null,
    profileRevision: profile?.revision ?? 0,
    serverId: runtime.serverId,
    serverName: server.name,
    endpoint: server.endpoint,
    currentIp: runtime.currentIp,
    dnsMode: runtime.dnsMode,
    connectedAt: runtime.connectedAt,
    lastHeartbeatAt: runtime.lastHeartbeatAt,
    lastHandshakeAt: runtime.lastHandshakeAt,
    bytesReceived: runtime.bytesReceived,
    bytesSent: runtime.bytesSent,
    sessionDurationSeconds,
    lastError: runtime.lastError,
  };
}

export function getAuthSessionEnvelope() {
  return {
    ...sessionTokens,
    session: {
      viewer,
      account,
      device: currentSessionDevice(),
    },
  };
}

export function getSessionSnapshot() {
  return {
    session: {
      viewer,
      account,
      device: currentSessionDevice(),
    },
  };
}

export function getDashboardSummary() {
  const devices = buildDevices();
  const events = securityEvents;
  const sessionDevice = currentSessionDevice();
  const vpnSession = sessionEnvelope(sessionDevice.id);

  return {
    viewer: {
      displayName: viewer.displayName,
      role: viewer.role,
      accountName: account.name,
    },
    vpn: {
      connected: vpnSession.connected,
      serverName: `${vpnSession.serverName} • ${vpnSession.serverId}`,
      currentIp: vpnSession.currentIp,
      sessionDurationSeconds: vpnSession.sessionDurationSeconds,
      dnsMode: vpnSession.dnsMode,
    },
    security: {
      trustedDevicesCount: devices.filter(
        (device) => device.trustState == 'TRUSTED',
      ).length,
      lostDevicesCount: devices.filter((device) => device.isLost).length,
      unreadAlertsCount: events.filter((event) => event.unread).length,
      criticalAlertsCount: events.filter(
        (event) => event.severity == 'CRITICAL' && event.unread,
      ).length,
    },
    quickActions: [
      {
        id: 'devices',
        label: 'Devices',
        route: '/devices',
      },
      {
        id: 'events',
        label: 'Events',
        route: '/events',
      },
      {
        id: 'settings',
        label: 'Settings',
        route: '/settings',
      },
    ],
  };
}

export function listDevices() {
  return buildDevices();
}

export function getDeviceById(deviceId: string) {
  return buildDevices().find((device) => device.id == deviceId) ?? null;
}

export function listSecurityEvents() {
  return securityEvents;
}

export function getPreferences() {
  return {
    preferences,
    profile: {
      viewer,
      account,
    },
  };
}

export function updatePreferences(patch: Partial<SecurityPreferenceState>) {
  preferences = {
    ...preferences,
    ...patch,
  };

  return getPreferences();
}

export function getAdminOverview() {
  const devices = buildDevices();
  const events = securityEvents;

  return {
    totalUsers: 2,
    totalDevices: devices.length,
    devicesInLostMode: devices.filter((device) => device.isLost).length,
    pendingApprovals: devices.filter(
      (device) => device.trustState == 'PENDING_APPROVAL',
    ).length,
    activeVpnServers: vpnServers.filter((server) => server.status == 'ACTIVE')
      .length,
    queuedRemoteCommands: 2,
    unreadSecurityEvents: events.filter((event) => event.unread).length,
  };
}

export function getVpnServers() {
  return vpnServers.map(({ hostAddress, dnsServers, ...server }) => ({
    ...server,
    dnsServers,
  }));
}

export function getVpnProfileSummary(deviceId: string) {
  return profileEnvelope(deviceId);
}

export function rotateVpnProfile(deviceId: string) {
  const current = ensureVpnProfile(deviceId);
  const rotated = issueVpnProfile(deviceId, current.serverId, current.revision + 1);
  vpnProfiles.set(deviceId, rotated);

  const runtime = ensureVpnRuntime(deviceId);
  vpnRuntimeByDevice.set(deviceId, {
    ...runtime,
    tunnelState: 'DISCONNECTED',
    connectedAt: null,
    lastHeartbeatAt: nowIso(),
    lastHandshakeAt: null,
    lastError: 'Profile rotated. Reconnect with the freshly issued configuration.',
    bytesReceived: 0,
    bytesSent: 0,
  });

  return {
    deviceId,
    rotatedAt: rotated.rotatedAt,
    profile: profileEnvelope(deviceId),
  };
}

export function revokeVpnProfile(deviceId: string) {
  const current = ensureVpnProfile(deviceId);
  const revokedAt = nowIso();
  vpnProfiles.set(deviceId, {
    ...current,
    profileStatus: 'REVOKED',
    rotatedAt: revokedAt,
    config: null,
    note:
      'VPN access was revoked by the control plane. Issue a fresh profile before attempting another connection.',
  });

  const runtime = ensureVpnRuntime(deviceId);
  vpnRuntimeByDevice.set(deviceId, {
    ...runtime,
    tunnelState: 'PROFILE_MISSING',
    connectedAt: null,
    lastHeartbeatAt: revokedAt,
    lastHandshakeAt: null,
    bytesReceived: 0,
    bytesSent: 0,
    currentIp: 'Unavailable',
    dnsMode: 'Profile revoked',
    lastError: 'VPN access revoked for this device.',
  });

  return {
    deviceId,
    revokedAt,
    profile: profileEnvelope(deviceId),
  };
}

export function getVpnSessionSnapshot(deviceId: string) {
  return sessionEnvelope(deviceId);
}

export function recordVpnSessionConnect({
  deviceId,
  serverId,
  currentIp,
}: {
  deviceId?: string;
  serverId?: string;
  currentIp?: string;
}) {
  const targetDeviceId = deviceId ?? currentSessionDevice().id;
  const runtime = ensureVpnRuntime(targetDeviceId);
  const nextHeartbeatAt = nowIso();
  const nextServerId = serverId ?? runtime.serverId;

  vpnRuntimeByDevice.set(targetDeviceId, {
    ...runtime,
    tunnelState: 'CONNECTED',
    serverId: nextServerId,
    currentIp: currentIp ?? '185.233.44.12',
    dnsMode: 'Private DNS via tunnel',
    connectedAt: runtime.connectedAt ?? nextHeartbeatAt,
    lastHeartbeatAt: nextHeartbeatAt,
    lastHandshakeAt: nextHeartbeatAt,
    lastError: null,
  });

  return sessionEnvelope(targetDeviceId);
}

export function recordVpnSessionDisconnect({
  deviceId,
  reason,
}: {
  deviceId?: string;
  reason?: string;
}) {
  const targetDeviceId = deviceId ?? currentSessionDevice().id;
  const runtime = ensureVpnRuntime(targetDeviceId);
  const disconnectedAt = nowIso();

  vpnRuntimeByDevice.set(targetDeviceId, {
    ...runtime,
    tunnelState: 'DISCONNECTED',
    connectedAt: null,
    lastHeartbeatAt: disconnectedAt,
    currentIp: 'Unavailable',
    dnsMode: 'Tunnel down',
    lastError: reason ?? null,
  });

  return sessionEnvelope(targetDeviceId);
}

export function recordVpnHeartbeat(patch: VpnSessionPatch) {
  const targetDeviceId = patch.deviceId ?? currentSessionDevice().id;
  const runtime = ensureVpnRuntime(targetDeviceId);
  const acceptedState: VpnTunnelState =
    patch.tunnelState == 'CONNECTING' ||
    patch.tunnelState == 'CONNECTED' ||
    patch.tunnelState == 'ERROR' ||
    patch.tunnelState == 'AUTH_REQUIRED' ||
    patch.tunnelState == 'PROFILE_MISSING'
      ? patch.tunnelState
      : runtime.tunnelState;

  vpnRuntimeByDevice.set(targetDeviceId, {
    ...runtime,
    tunnelState: acceptedState,
    serverId: patch.serverId ?? runtime.serverId,
    currentIp: patch.currentIp ?? runtime.currentIp,
    lastHeartbeatAt: nowIso(),
    lastHandshakeAt: patch.lastHandshakeAt ?? runtime.lastHandshakeAt,
    bytesReceived:
      typeof patch.bytesReceived == 'number'
        ? patch.bytesReceived
        : runtime.bytesReceived,
    bytesSent:
      typeof patch.bytesSent == 'number' ? patch.bytesSent : runtime.bytesSent,
    lastError:
      typeof patch.lastError == 'string' ? patch.lastError : runtime.lastError,
  });

  return {
    accepted: true,
    syncedAt: nowIso(),
    session: sessionEnvelope(targetDeviceId),
  };
}
