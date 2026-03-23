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
type LostModeState = 'OFF' | 'ACTIVE' | 'RECOVERED';
type SecurityEventSeverity = 'INFO' | 'WARNING' | 'CRITICAL';

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

type DeviceRecord = {
  id: string;
  name: string;
  model: string;
  platform: string;
  appVersion: string;
  trustState: DeviceTrustState;
  vpnStatus: DeviceConnectivityState;
  batteryLevel: number;
  isLost: boolean;
  isPrimary: boolean;
  lastActiveAt: string;
  lastKnownIp: string;
  lastKnownNetwork: string;
  lastKnownLocation: string;
  locationCapturedAt: string;
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

function isoAgo({
  minutes = 0,
  hours = 0,
}: {
  minutes?: number;
  hours?: number;
}) {
  return new Date(
    Date.now() - minutes * 60 * 1000 - hours * 60 * 60 * 1000,
  ).toISOString();
}

function buildDevices(): DeviceRecord[] {
  return [
    {
      id: 'pixel-9-pro',
      name: 'Primary Pixel',
      model: 'Google Pixel 9 Pro',
      platform: 'Android 15',
      appVersion: '0.1.0',
      trustState: 'TRUSTED',
      vpnStatus: 'CONNECTED',
      batteryLevel: 82,
      isLost: false,
      isPrimary: true,
      lastActiveAt: isoAgo({ minutes: 3 }),
      lastKnownIp: '41.214.91.17',
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
      vpnStatus: 'DEGRADED',
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
      vpnStatus: 'DISCONNECTED',
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
}

function buildSecurityEvents(): SecurityEventRecord[] {
  return [
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
  const events = buildSecurityEvents();

  return {
    viewer: {
      displayName: viewer.displayName,
      role: viewer.role,
      accountName: account.name,
    },
    vpn: {
      connected: true,
      serverName: 'Casablanca Primary • wg-01',
      currentIp: '185.233.44.12',
      sessionDurationSeconds: 3 * 60 * 60 + 14 * 60,
      dnsMode: 'Private DNS via tunnel',
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
  return buildSecurityEvents();
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

export function updatePreferences(
  patch: Partial<SecurityPreferenceState>,
) {
  preferences = {
    ...preferences,
    ...patch,
  };

  return getPreferences();
}

export function getAdminOverview() {
  const devices = buildDevices();
  const events = buildSecurityEvents();

  return {
    totalUsers: 2,
    totalDevices: devices.length,
    devicesInLostMode: devices.filter((device) => device.isLost).length,
    pendingApprovals: devices.filter(
      (device) => device.trustState == 'PENDING_APPROVAL',
    ).length,
    activeVpnServers: 1,
    queuedRemoteCommands: 2,
    unreadSecurityEvents: events.filter((event) => event.unread).length,
  };
}

export function getVpnServers() {
  return [
    {
      id: 'wg-01',
      name: 'Casablanca Primary',
      regionCode: 'ma-cas',
      endpoint: 'vpn.labguard.internal:51820',
      status: 'ACTIVE',
      isPrimary: true,
    },
  ];
}

export function getVpnProfileSummary(deviceId: string) {
  return {
    deviceId,
    profileStatus: 'ACTIVE',
    serverId: 'wg-01',
    dnsServers: ['10.0.0.2', '1.1.1.1'],
    note: 'Phase 2 still returns metadata only. Secure profile delivery lands with the Android VPN core in Phase 3.',
  };
}
