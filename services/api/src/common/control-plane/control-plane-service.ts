import {
  Prisma,
  PrismaClient,
  type AuditOutcome,
  type DeviceConnectivityStatus,
  type SecurityEventSeverity,
  type SecurityEventType,
  type DeviceTrustState,
  type RemoteCommandStatus,
  type RemoteCommandType,
  type UserRole,
  type VpnProfileStatus,
} from '@prisma/client';
import { createCipheriv, createDecipheriv, createHash, randomBytes } from 'node:crypto';

import type { LabGuardActor } from '../auth/auth-types.js';
import { prisma } from '../db/prisma.js';
import { env } from '../../config/env.js';

const ACCESS_TOKEN_TTL_SECONDS = 15 * 60;
const SESSION_TTL_DAYS = 30;
const DEFAULT_BRAND_ATTRIBUTION = 'Built by Emilo Labs';
const DEFAULT_INVITE_CODE = 'EMILO-TRUST-01';
const DEMO_DEVICE_CLIENT_IDS = [
  'seed-primary-pixel',
  'seed-galaxy-s24',
  'seed-owner-tablet',
] as const;

type ConfiguredVpnServer = {
  name: string;
  regionCode: 'uk-lon' | 'us-sfo';
  locationLabel: string;
  hostname: string;
  endpoint: string;
  port: number;
  publicKey: string;
  exitIpAddress: string;
  dnsServers: string[];
  priority: number;
  isPrimary: boolean;
};

const SERVER_TEMPLATES = [
  {
    name: 'UK — London',
    regionCode: 'uk-lon' as const,
    locationLabel: 'London, United Kingdom',
    endpoint: env.VPN_SERVER_LONDON_ENDPOINT,
    publicKey: env.VPN_SERVER_LONDON_PUBLIC_KEY,
    exitIpAddress: env.VPN_SERVER_LONDON_EXIT_IP,
    dnsServers: env.VPN_SERVER_LONDON_DNS,
    priority: 1,
  },
  {
    name: 'US — San Francisco',
    regionCode: 'us-sfo' as const,
    locationLabel: 'San Francisco, United States',
    endpoint: env.VPN_SERVER_SF_ENDPOINT,
    publicKey: env.VPN_SERVER_SF_PUBLIC_KEY,
    exitIpAddress: env.VPN_SERVER_SF_EXIT_IP,
    dnsServers: env.VPN_SERVER_SF_DNS,
    priority: 2,
  },
] as const;

type DbClient = PrismaClient | Prisma.TransactionClient;

export type DeviceRegistrationInput = {
  clientId: string;
  name: string;
  model: string;
  platform: string;
  osVersion?: string | undefined;
  appVersion: string;
};

export type LoginInput = {
  identity?: string | undefined;
  inviteCode?: string | undefined;
  device?: Partial<DeviceRegistrationInput> | undefined;
  ipAddress?: string | undefined;
  userAgent?: string | undefined;
};

export type AcceptInvitationInput = LoginInput;

export type DevicePatchInput = Partial<{
  name: string;
  isPrimary: boolean;
}>;

export type LocationPatchInput = Partial<{
  lastKnownLocation: string;
  lastKnownNetwork: string;
  lastKnownIp: string;
  latitude: number;
  longitude: number;
  accuracyMeters: number;
  source: string;
}>;

export type PreferencesPatchInput = Partial<{
  biometricEnabled: boolean;
  pinLockEnabled: boolean;
  autoConnectEnabled: boolean;
  killSwitchEnabled: boolean;
  notificationsEnabled: boolean;
  telemetryLevel: string;
  locationPermissionStatus: string;
  batteryOptimizationAcknowledged: boolean;
  appPin: string | null;
}>;

export type QueueRemoteCommandInput = {
  commandType: RemoteCommandType;
  message?: string;
};

export type RemoteCommandResultInput = {
  status: 'DELIVERED' | 'SUCCEEDED' | 'FAILED';
  resultMessage?: string;
  failureCode?: string;
};

type SessionEnvelope = {
  accessToken: string;
  refreshToken: string;
  expiresInSeconds: number;
  session: {
    viewer: {
      id: string;
      email: string;
      displayName: string;
      role: UserRole;
    };
    account: {
      id: string;
      name: string;
      brandAttribution: string;
    };
    device: {
      id: string;
      name: string;
      trustState: DeviceTrustState;
    };
  };
};

export async function ensureSeedData() {
  const account = await ensureAccountSeed(prisma);
  const owner = await ensureOwnerSeed(prisma, account.id);
  await ensurePreferenceSeed(prisma, owner.id);
  const provisionedServers = await ensureServerSeeds(prisma, account.id);
  await cleanupLegacyDemoData(prisma, account.id);
  await reconcileProvisionedVpnState(
    prisma,
    account.id,
    provisionedServers.map((server) => server.id),
  );
  await ensureInvitationSeed(prisma, account.id, owner.id);
}

export async function authenticateAccessToken(
  accessToken?: string,
): Promise<LabGuardActor | null> {
  if (accessToken == null || accessToken.trim().length == 0) {
    return null;
  }

  const session = await prisma.session.findFirst({
    where: {
      accessTokenHash: hashSecret(accessToken),
      status: 'ACTIVE',
      accessTokenExpiresAt: { gt: new Date() },
      expiresAt: { gt: new Date() },
    },
    include: {
      user: true,
      device: true,
    },
  });

  if (session == null) {
    return null;
  }

  await prisma.session.update({
    where: { id: session.id },
    data: { lastUsedAt: new Date() },
  });

  return {
    sessionId: session.id,
    accountId: session.device.accountId,
    userId: session.userId,
    deviceId: session.deviceId,
    role: session.user.role,
    displayName: session.user.displayName,
    email: session.user.email,
    deviceName: session.device.name,
  };
}

export async function acceptInvitation(input: AcceptInvitationInput) {
  const normalizedIdentity = normalizeIdentity(input.identity);
  const inviteCode = normalizeInviteCode(input.inviteCode);

  if (inviteCode == null) {
    throw badRequest('A valid invite code is required.');
  }

  return prisma.$transaction(async (tx) => {
    const invitation = await tx.invitation.findFirst({
      where: {
        codeHash: hashInviteCode(inviteCode),
        status: 'PENDING',
        expiresAt: { gt: new Date() },
      },
      include: {
        account: true,
      },
    });

    if (invitation == null) {
      throw unauthorized('Invitation code is invalid or expired.');
    }

    const email = normalizedIdentity ?? invitation.email;
    if (email == null) {
      throw badRequest('Invitation acceptance requires an identity.');
    }

    const user = await ensureMemberFromInvitation(tx, invitation, email);
    const device = await ensureDeviceForUser(tx, {
      accountId: invitation.accountId,
      userId: user.id,
      userRole: user.role,
      device: sanitizeDeviceRegistrationInput(input.device, email),
      trustState: 'TRUSTED',
    });

    await tx.invitation.update({
      where: { id: invitation.id },
      data: {
        status: 'ACCEPTED',
        acceptedAt: new Date(),
      },
    });

    const envelope = await createSessionEnvelope(tx, {
      user,
      device,
      ...optionalStringProperty('ipAddress', input.ipAddress),
      ...optionalStringProperty('userAgent', input.userAgent),
    });

    await emitAuditLog(tx, {
      accountId: invitation.accountId,
      actorUserId: user.id,
      deviceId: device.id,
      action: 'INVITATION_ACCEPTED',
      targetType: 'AUTH',
      targetId: invitation.id,
      outcome: 'SUCCESS',
      summary: 'A trusted invitation was accepted and a session was issued.',
      ...optionalStringProperty('ipAddress', input.ipAddress),
      ...optionalStringProperty('userAgent', input.userAgent),
    });

    await emitSecurityEvent(tx, {
      accountId: invitation.accountId,
      userId: user.id,
      deviceId: device.id,
      type: 'DEVICE_REGISTERED',
      severity: 'INFO',
      title: `${device.name} enrolled`,
      summary: 'An invited trusted device joined the LabGuard account.',
    });

    return {
      invitationAccepted: true,
      deviceApprovalRequired: device.trustState != 'TRUSTED',
      ...envelope,
    };
  });
}

export async function login(input: LoginInput) {
  const normalizedIdentity = normalizeIdentity(input.identity);

  if (normalizedIdentity == null) {
    throw badRequest('An identity is required to sign in.');
  }

  return prisma.$transaction(async (tx) => {
    const owner = await ensureOwnerSeed(tx, (await ensureAccountSeed(tx)).id);
    let user =
      normalizedIdentity == owner.email
        ? owner
        : await tx.user.findUnique({
            where: { email: normalizedIdentity },
          });

    if (user == null) {
      const inviteCode = normalizeInviteCode(input.inviteCode);
      if (inviteCode == null) {
        throw unauthorized('This identity is not yet trusted. Use an invitation code.');
      }

      const invitation = await tx.invitation.findFirst({
        where: {
          codeHash: hashInviteCode(inviteCode),
          status: 'PENDING',
          expiresAt: { gt: new Date() },
        },
      });

      if (invitation == null) {
        throw unauthorized('Invitation code is invalid or expired.');
      }

      user = await ensureMemberFromInvitation(tx, invitation, normalizedIdentity);

      await tx.invitation.update({
        where: { id: invitation.id },
        data: {
          status: 'ACCEPTED',
          acceptedAt: new Date(),
        },
      });
    }

    const device = await ensureDeviceForUser(tx, {
      accountId: user.accountId,
      userId: user.id,
      userRole: user.role,
      device: sanitizeDeviceRegistrationInput(input.device, normalizedIdentity),
      trustState: 'TRUSTED',
    });

    const envelope = await createSessionEnvelope(tx, {
      user,
      device,
      ...optionalStringProperty('ipAddress', input.ipAddress),
      ...optionalStringProperty('userAgent', input.userAgent),
    });

    await emitAuditLog(tx, {
      accountId: user.accountId,
      actorUserId: user.id,
      deviceId: device.id,
      action: 'LOGIN_SUCCEEDED',
      targetType: 'AUTH',
      targetId: user.id,
      outcome: 'SUCCESS',
      summary: `A trusted LabGuard session was issued for ${device.name}.`,
      ...optionalStringProperty('ipAddress', input.ipAddress),
      ...optionalStringProperty('userAgent', input.userAgent),
    });

    await emitSecurityEvent(tx, {
      accountId: user.accountId,
      userId: user.id,
      deviceId: device.id,
      type: 'DEVICE_REGISTERED',
      severity: 'INFO',
      title: `${device.name} authenticated`,
      summary: 'A trusted device authenticated with the LabGuard control plane.',
    });

    return envelope;
  });
}

export async function refresh(refreshToken?: string) {
  if (refreshToken == null || refreshToken.trim().length == 0) {
    throw unauthorized('Refresh token is invalid or expired.');
  }

  return prisma.$transaction(async (tx) => {
    const session = await tx.session.findFirst({
      where: {
        refreshTokenHash: hashSecret(refreshToken),
        status: 'ACTIVE',
        expiresAt: { gt: new Date() },
      },
      include: {
        user: true,
        device: true,
      },
    });

    if (session == null) {
      throw unauthorized('Refresh token is invalid or expired.');
    }

    const nextTokens = generateSessionTokens();

    await tx.session.update({
      where: { id: session.id },
      data: {
        accessTokenHash: hashSecret(nextTokens.accessToken),
        refreshTokenHash: hashSecret(nextTokens.refreshToken),
        accessTokenExpiresAt: nextTokens.accessTokenExpiresAt,
        expiresAt: nextTokens.sessionExpiresAt,
        lastUsedAt: new Date(),
      },
    });

    await emitAuditLog(tx, {
      accountId: session.device.accountId,
      actorUserId: session.userId,
      deviceId: session.deviceId,
      action: 'SESSION_REFRESHED',
      targetType: 'AUTH',
      targetId: session.id,
      outcome: 'SUCCESS',
      summary: 'LabGuard access and refresh tokens were rotated.',
    });

    return buildSessionEnvelope({
      accessToken: nextTokens.accessToken,
      refreshToken: nextTokens.refreshToken,
      user: session.user,
      account: await tx.account.findUniqueOrThrow({ where: { id: session.device.accountId } }),
      device: session.device,
    });
  });
}

export async function logout(actor: LabGuardActor) {
  await prisma.session.updateMany({
    where: {
      id: actor.sessionId,
      status: 'ACTIVE',
    },
    data: {
      status: 'REVOKED',
      revokedAt: new Date(),
    },
  });

  await emitAuditLog(prisma, {
    accountId: actor.accountId,
    actorUserId: actor.userId,
    deviceId: actor.deviceId,
    action: 'LOGOUT_COMPLETED',
    targetType: 'AUTH',
    targetId: actor.sessionId,
    outcome: 'SUCCESS',
    summary: 'The active LabGuard session was revoked.',
  });

  return { revoked: true };
}

export async function getSessionSnapshot(actor: LabGuardActor) {
  const [user, account, device] = await Promise.all([
    prisma.user.findUniqueOrThrow({ where: { id: actor.userId } }),
    prisma.account.findUniqueOrThrow({ where: { id: actor.accountId } }),
    prisma.device.findUniqueOrThrow({ where: { id: actor.deviceId } }),
  ]);

  return {
    session: {
      viewer: serializeViewer(user),
      account: serializeAccount(account),
      device: serializeSessionDevice(device),
    },
  };
}

export async function getDashboardSummary(actor: LabGuardActor) {
  const [user, account, devices, securityEvents, vpnSession, activeProfile] = await Promise.all([
    prisma.user.findUniqueOrThrow({ where: { id: actor.userId } }),
    prisma.account.findUniqueOrThrow({ where: { id: actor.accountId } }),
    prisma.device.findMany({
      where: { accountId: actor.accountId },
    }),
    prisma.securityEvent.findMany({
      where: { accountId: actor.accountId },
    }),
    getOrCreateDeviceSession(prisma, actor.deviceId),
    prisma.vpnProfile.findFirst({
      where: {
        deviceId: actor.deviceId,
        status: 'ACTIVE',
      },
      include: { vpnServer: true },
      orderBy: { revision: 'desc' },
    }),
  ]);

  const server =
    (vpnSession.serverId == null
      ? null
      : await prisma.vpnServer.findUnique({ where: { id: vpnSession.serverId } })) ??
    activeProfile?.vpnServer ??
    null;
  const selectableServer =
    server != null && isSelectableServerRecord(server) ? server : null;
  const connected = vpnSession.status == 'CONNECTED' && selectableServer != null;

  return {
    viewer: {
      displayName: user.displayName,
      role: user.role,
      accountName: account.name,
    },
    vpn: {
      connected,
      serverName: selectableServer?.name ?? 'VPN not provisioned',
      currentIp: connected ? (vpnSession.publicIp ?? 'Unavailable') : 'Unavailable',
      sessionDurationSeconds: vpnSession.connectedAt == null
        ? 0
        : connected
          ? Math.max(0, Math.floor((Date.now() - vpnSession.connectedAt.getTime()) / 1000))
          : 0,
      dnsMode: connected ? 'Private DNS via tunnel' : 'No live region provisioned',
    },
    security: {
      trustedDevicesCount: devices.filter((device) => device.trustState == 'TRUSTED').length,
      lostDevicesCount: devices.filter((device) => device.lostModeStatus == 'ACTIVE').length,
      unreadAlertsCount: securityEvents.filter((event) => event.unread).length,
      criticalAlertsCount: securityEvents.filter(
        (event) => event.unread && event.severity == 'CRITICAL',
      ).length,
    },
    quickActions: [
      { id: 'devices', label: 'Devices', route: '/devices' },
      { id: 'events', label: 'Events', route: '/events' },
      { id: 'settings', label: 'Settings', route: '/settings' },
    ],
  };
}

export async function listDevices(actor: LabGuardActor) {
  const devices = await prisma.device.findMany({
    where: { accountId: actor.accountId },
    include: {
      sessions: {
        orderBy: { updatedAt: 'desc' },
        take: 1,
      },
      locations: {
        orderBy: { capturedAt: 'desc' },
        take: 1,
      },
    },
    orderBy: [
      { isPrimary: 'desc' },
      { createdAt: 'asc' },
    ],
  });

  return devices.map((device) => serializeDeviceRecord(device));
}

export async function registerDevice(
  actor: LabGuardActor,
  deviceInput?: Partial<DeviceRegistrationInput>,
) {
  const device = await ensureDeviceForUser(prisma, {
    accountId: actor.accountId,
    userId: actor.userId,
    userRole: actor.role,
    device: sanitizeDeviceRegistrationInput(deviceInput, actor.email),
    trustState: actor.role == 'OWNER' ? 'TRUSTED' : 'PENDING_APPROVAL',
  });

  return {
    deviceId: device.id,
    approvalState: device.trustState,
    vpnProfileIssued: device.trustState == 'TRUSTED',
  };
}

export async function getDeviceDetail(actor: LabGuardActor, deviceId: string) {
  const device = await requireAccountDevice(prisma, actor.accountId, deviceId);
  return serializeDeviceDetail(prisma, device);
}

export async function getDeviceLocationSnapshot(
  actor: LabGuardActor,
  deviceId: string,
) {
  await requireAccountDevice(prisma, actor.accountId, deviceId);
  return buildLocationSnapshot(prisma, deviceId);
}

export async function updateDevice(
  actor: LabGuardActor,
  deviceId: string,
  patch: DevicePatchInput,
) {
  await requireAccountDevice(prisma, actor.accountId, deviceId);

  if (patch.isPrimary === true) {
    await prisma.device.updateMany({
      where: { accountId: actor.accountId },
      data: { isPrimary: false },
    });
  }

  await prisma.device.update({
    where: { id: deviceId },
    data: {
      ...(typeof patch.name == 'string' && patch.name.trim().length > 0
        ? { name: patch.name.trim() }
        : {}),
      ...(patch.isPrimary === undefined ? {} : { isPrimary: patch.isPrimary }),
    },
  });

  await emitSecurityEvent(prisma, {
    accountId: actor.accountId,
    userId: actor.userId,
    deviceId,
    type: 'DEVICE_REGISTERED',
    severity: 'INFO',
    title: 'Device metadata updated',
    summary: 'Device label or primary ownership metadata changed.',
  });
  await emitAuditLog(prisma, {
    accountId: actor.accountId,
    actorUserId: actor.userId,
    deviceId,
    action: 'DEVICE_METADATA_UPDATED',
    targetType: 'DEVICE',
    targetId: deviceId,
    outcome: 'SUCCESS',
    summary: 'Device label or primary ownership metadata changed.',
  });

  return getDeviceDetail(actor, deviceId);
}

export async function markLostMode(actor: LabGuardActor, deviceId: string) {
  const device = await requireAccountDevice(prisma, actor.accountId, deviceId);

  await prisma.device.update({
    where: { id: deviceId },
    data: {
      lostModeStatus: 'ACTIVE',
      operationalStatus: 'LOST',
      telemetryElevated: true,
      updatedAt: new Date(),
    },
  });

  await emitSecurityEvent(prisma, {
    accountId: actor.accountId,
    userId: actor.userId,
    deviceId,
    type: 'DEVICE_MARKED_LOST',
    severity: 'CRITICAL',
    title: `${device.name} marked as lost`,
    summary: 'Lost mode is active and elevated recovery telemetry is enabled.',
  });
  await emitAuditLog(prisma, {
    accountId: actor.accountId,
    actorUserId: actor.userId,
    deviceId,
    action: 'DEVICE_MARKED_LOST',
    targetType: 'DEVICE',
    targetId: deviceId,
    outcome: 'SUCCESS',
    summary: 'Lost mode was enabled for the device.',
  });

  return {
    deviceId,
    lostModeStatus: 'ACTIVE',
    telemetryElevated: true,
    device: await getDeviceDetail(actor, deviceId),
  };
}

export async function markRecovered(actor: LabGuardActor, deviceId: string) {
  const device = await requireAccountDevice(prisma, actor.accountId, deviceId);

  await prisma.device.update({
    where: { id: deviceId },
    data: {
      lostModeStatus: 'RECOVERED',
      operationalStatus: 'ACTIVE',
      telemetryElevated: false,
    },
  });

  await emitSecurityEvent(prisma, {
    accountId: actor.accountId,
    userId: actor.userId,
    deviceId,
    type: 'DEVICE_LOCATION_UPDATED',
    severity: 'INFO',
    title: `${device.name} marked recovered`,
    summary: 'Lost mode was cleared and elevated telemetry was disabled.',
  });
  await emitAuditLog(prisma, {
    accountId: actor.accountId,
    actorUserId: actor.userId,
    deviceId,
    action: 'DEVICE_MARKED_RECOVERED',
    targetType: 'DEVICE',
    targetId: deviceId,
    outcome: 'SUCCESS',
    summary: 'Lost mode was cleared for the device.',
  });

  return {
    deviceId,
    lostModeStatus: 'RECOVERED',
    telemetryElevated: false,
    device: await getDeviceDetail(actor, deviceId),
  };
}

export async function revokeDevice(actor: LabGuardActor, deviceId: string) {
  await requireAccountDevice(prisma, actor.accountId, deviceId);

  await prisma.$transaction(async (tx) => {
    await tx.device.update({
      where: { id: deviceId },
      data: {
        trustState: 'REVOKED',
        connectivityStatus: 'DISCONNECTED',
        operationalStatus: 'DISABLED',
      },
    });

    await revokeActiveVpnProfileInternal(tx, deviceId, actor);
    await tx.session.updateMany({
      where: { deviceId, status: 'ACTIVE' },
      data: {
        status: 'REVOKED',
        revokedAt: new Date(),
      },
    });

    await emitSecurityEvent(tx, {
      accountId: actor.accountId,
      userId: actor.userId,
      deviceId,
      type: 'DEVICE_REVOKED',
      severity: 'CRITICAL',
      title: 'Device access revoked',
      summary: 'The device can no longer authenticate or obtain VPN access.',
    });
    await emitAuditLog(tx, {
      accountId: actor.accountId,
      actorUserId: actor.userId,
      deviceId,
      action: 'DEVICE_REVOKED',
      targetType: 'DEVICE',
      targetId: deviceId,
      outcome: 'SUCCESS',
      summary: 'Device trust and VPN access were revoked.',
    });
  });

  return {
    deviceId,
    trustState: 'REVOKED',
    vpnAccessActive: false,
    device: await getDeviceDetail(actor, deviceId),
  };
}

export async function suspendDevice(actor: LabGuardActor, deviceId: string) {
  await requireAccountDevice(prisma, actor.accountId, deviceId);

  await prisma.device.update({
    where: { id: deviceId },
    data: {
      trustState: 'SUSPENDED',
      connectivityStatus: 'DISCONNECTED',
    },
  });

  await emitSecurityEvent(prisma, {
    accountId: actor.accountId,
    userId: actor.userId,
    deviceId,
    type: 'DEVICE_REVOKED',
    severity: 'WARNING',
    title: 'Device suspended',
    summary: 'Device access is paused until it is reapproved.',
  });
  await emitAuditLog(prisma, {
    accountId: actor.accountId,
    actorUserId: actor.userId,
    deviceId,
    action: 'DEVICE_SUSPENDED',
    targetType: 'DEVICE',
    targetId: deviceId,
    outcome: 'SUCCESS',
    summary: 'Device access was suspended pending reapproval.',
  });

  return {
    deviceId,
    trustState: 'SUSPENDED',
    device: await getDeviceDetail(actor, deviceId),
  };
}

export async function rotateDeviceCredentials(actor: LabGuardActor, deviceId: string) {
  await requireAccountDevice(prisma, actor.accountId, deviceId);

  const profile = await rotateVpnProfile(actor, deviceId);

  await emitSecurityEvent(prisma, {
    accountId: actor.accountId,
    userId: actor.userId,
    deviceId,
    type: 'KEY_ROTATED',
    severity: 'WARNING',
    title: 'Device credentials rotated',
    summary: 'The device must fetch the latest secure configuration.',
  });
  await emitAuditLog(prisma, {
    accountId: actor.accountId,
    actorUserId: actor.userId,
    deviceId,
    action: 'DEVICE_CREDENTIALS_ROTATED',
    targetType: 'DEVICE',
    targetId: deviceId,
    outcome: 'SUCCESS',
    summary: 'Device credentials and VPN profile were rotated.',
  });

  return {
    deviceId,
    rotatedAt: profile.rotatedAt,
    profile: profile.profile,
    device: await getDeviceDetail(actor, deviceId),
  };
}

export async function recordDeviceLocation(
  actor: LabGuardActor,
  deviceId: string,
  patch: LocationPatchInput,
) {
  await requireAccountDevice(prisma, actor.accountId, deviceId);

  const device = await prisma.device.findUniqueOrThrow({ where: { id: deviceId } });
  const latest = await prisma.deviceLocation.findFirst({
    where: { deviceId },
    orderBy: { capturedAt: 'desc' },
  });
  const latitude = typeof patch.latitude == 'number'
    ? patch.latitude
    : latest == null
      ? 33.5731
      : Number(latest.latitude);
  const longitude = typeof patch.longitude == 'number'
    ? patch.longitude
    : latest == null
      ? -7.5898
      : Number(latest.longitude);
  const accuracyMeters = typeof patch.accuracyMeters == 'number'
    ? patch.accuracyMeters
    : latest?.accuracyMeters ?? (device.lostModeStatus == 'ACTIVE' ? 16 : 42);
  const label = patch.lastKnownLocation?.trim().length
    ? patch.lastKnownLocation.trim()
    : formatLocationLabel(latitude, longitude);
  const capturedAt = new Date();

  await prisma.deviceLocation.create({
    data: {
      deviceId,
      latitude: new Prisma.Decimal(latitude.toFixed(6)),
      longitude: new Prisma.Decimal(longitude.toFixed(6)),
      accuracyMeters: Math.round(accuracyMeters),
      capturedAt,
      networkType: patch.lastKnownNetwork ?? device.lastKnownNetwork ?? 'Unknown network',
      ipAddress: patch.lastKnownIp ?? device.lastKnownIp ?? 'Unavailable',
      source: patch.source ?? (device.lostModeStatus == 'ACTIVE' ? 'LOST_MODE' : 'MANUAL_REFRESH'),
      lostModeSnapshot: device.lostModeStatus == 'ACTIVE',
    },
  });

  await prisma.device.update({
    where: { id: deviceId },
    data: {
      lastKnownLocation: label,
      lastKnownNetwork: patch.lastKnownNetwork ?? device.lastKnownNetwork,
      lastKnownIp: patch.lastKnownIp ?? device.lastKnownIp,
      lastSeenAt: capturedAt,
    },
  });

  await emitSecurityEvent(prisma, {
    accountId: actor.accountId,
    userId: actor.userId,
    deviceId,
    type: 'DEVICE_LOCATION_UPDATED',
    severity: device.lostModeStatus == 'ACTIVE' ? 'WARNING' : 'INFO',
    title: 'Device location refreshed',
    summary: 'A fresh location sample was recorded for this device.',
  });
  await emitAuditLog(prisma, {
    accountId: actor.accountId,
    actorUserId: actor.userId,
    deviceId,
    action: 'DEVICE_LOCATION_REFRESHED',
    targetType: 'LOCATION',
    targetId: deviceId,
    outcome: 'SUCCESS',
    summary: 'A fresh location sample was recorded for the device.',
  });

  return {
    deviceId,
    accepted: true,
    recordedAt: capturedAt.toISOString(),
    location: await buildLocationSnapshot(prisma, deviceId),
    device: await getDeviceDetail(actor, deviceId),
  };
}

export async function getPreferences(actor: LabGuardActor) {
  const [preference, user, account] = await Promise.all([
    ensurePreferenceSeed(prisma, actor.userId),
    prisma.user.findUniqueOrThrow({ where: { id: actor.userId } }),
    prisma.account.findUniqueOrThrow({ where: { id: actor.accountId } }),
  ]);

  return {
    preferences: serializePreferences(preference),
    profile: {
      viewer: serializeViewer(user),
      account: serializeAccount(account),
    },
  };
}

export async function updatePreferences(
  actor: LabGuardActor,
  patch: PreferencesPatchInput,
) {
  const preference = await ensurePreferenceSeed(prisma, actor.userId);
  const nextPinHash = patch.appPin === undefined
    ? undefined
    : patch.appPin == null || patch.appPin.trim().length == 0
      ? null
      : hashAppPin(patch.appPin);

  await prisma.userPreference.update({
    where: { userId: actor.userId },
    data: {
      ...(patch.biometricEnabled === undefined ? {} : { biometricEnabled: patch.biometricEnabled }),
      ...(patch.pinLockEnabled === undefined ? {} : { pinLockEnabled: patch.pinLockEnabled }),
      ...(patch.autoConnectEnabled === undefined ? {} : { autoConnectEnabled: patch.autoConnectEnabled }),
      ...(patch.killSwitchEnabled === undefined ? {} : { killSwitchEnabled: patch.killSwitchEnabled }),
      ...(patch.notificationsEnabled === undefined ? {} : { notificationsEnabled: patch.notificationsEnabled }),
      ...(patch.telemetryLevel == null ? {} : { telemetryLevel: patch.telemetryLevel }),
      ...(patch.locationPermissionStatus == null ? {} : { locationPermissionStatus: patch.locationPermissionStatus }),
      ...(patch.batteryOptimizationAcknowledged === undefined
        ? {}
        : { batteryOptimizationAcknowledged: patch.batteryOptimizationAcknowledged }),
      ...optionalNullableStringProperty('appPinHash', nextPinHash),
      notificationSettings: preference.notificationSettings ?? Prisma.JsonNull,
      trustedWifiPolicies: preference.trustedWifiPolicies ?? Prisma.JsonNull,
    },
  });

  await emitAuditLog(prisma, {
    accountId: actor.accountId,
    actorUserId: actor.userId,
    deviceId: actor.deviceId,
    action: 'SETTINGS_UPDATED',
    targetType: 'AUTH',
    targetId: actor.userId,
    outcome: 'SUCCESS',
    summary: 'Security preferences were updated.',
  });

  return getPreferences(actor);
}

export async function verifyAppPin(actor: LabGuardActor, pin?: string) {
  if (pin == null || pin.trim().length == 0) {
    throw badRequest('A valid app PIN is required.');
  }

  const preference = await ensurePreferenceSeed(prisma, actor.userId);
  const verified =
    preference.appPinHash != null && timingSafeEqual(preference.appPinHash, hashAppPin(pin));

  return { verified };
}

export async function listVpnServers(actor: LabGuardActor) {
  const servers = await prisma.vpnServer.findMany({
    where: {
      accountId: actor.accountId,
      status: 'ACTIVE',
    },
    orderBy: [{ isPrimary: 'desc' }, { priority: 'asc' }],
  });

  return servers
    .map((server) => serializeVpnServerRecord(server))
    .filter((server): server is NonNullable<typeof server> => server != null);
}

export async function getVpnProfile(actor: LabGuardActor, deviceId: string) {
  const device = await requireAccountDevice(prisma, actor.accountId, deviceId);
  const profile = await ensureActiveVpnProfile(prisma, device);
  return profile == null ? emptyVpnProfile(device.id) : serializeVpnProfile(profile);
}

export async function selectVpnServer(
  actor: LabGuardActor,
  payload: { deviceId: string; serverId: string },
) {
  const device = await requireAccountDevice(prisma, actor.accountId, payload.deviceId);
  const server = await requireSelectableVpnServer(prisma, actor.accountId, payload.serverId);

  const result = await prisma.$transaction(async (tx) => {
    const active = await tx.vpnProfile.findFirst({
      where: {
        deviceId: device.id,
        status: 'ACTIVE',
      },
      include: { vpnServer: true },
      orderBy: { revision: 'desc' },
    });

    if (active?.vpnServerId == server.id) {
      return active;
    }

    if (active != null) {
      await tx.vpnProfile.update({
        where: { id: active.id },
        data: {
          status: 'ROTATED',
          rotatedAt: new Date(),
        },
      });
    }

    const created = await createVpnProfile(tx, device, server, (active?.revision ?? 0) + 1);
    const session = await getOrCreateDeviceSession(tx, device.id);

    await tx.deviceSession.update({
      where: { id: session.id },
      data: {
        serverId: server.id,
        status: 'DISCONNECTED',
        publicIp: 'Unavailable',
        connectedAt: null,
        disconnectedAt: new Date(),
        lastHeartbeatAt: new Date(),
        lastHandshakeAt: null,
        lastError: `A new profile is ready for ${server.name}. Reconnect to switch the tunnel.`,
      },
    });
    await tx.device.update({
      where: { id: device.id },
      data: {
        connectivityStatus: 'DISCONNECTED',
        lastSeenAt: new Date(),
      },
    });

    await emitSecurityEvent(tx, {
      accountId: actor.accountId,
      userId: actor.userId,
      deviceId: device.id,
      type: 'KEY_ROTATED',
      severity: 'INFO',
      title: `VPN server switched to ${server.name}`,
      summary: `A server-specific WireGuard profile was issued for ${server.name}.`,
    });
    await emitAuditLog(tx, {
      accountId: actor.accountId,
      actorUserId: actor.userId,
      deviceId: device.id,
      action: 'VPN_SERVER_SELECTED',
      targetType: 'VPN_SERVER',
      targetId: server.id,
      outcome: 'SUCCESS',
      summary: `The device selected ${server.name} as its VPN exit region.`,
    });

    return created;
  });

  return {
    deviceId: device.id,
    switchedAt: new Date().toISOString(),
    profile: serializeVpnProfile(result),
  };
}

export async function rotateVpnProfile(actor: LabGuardActor, deviceId: string) {
  const device = await requireAccountDevice(prisma, actor.accountId, deviceId);

  const result = await prisma.$transaction(async (tx) => {
    const active = await tx.vpnProfile.findFirst({
      where: { deviceId, status: 'ACTIVE' },
      orderBy: { revision: 'desc' },
      include: { vpnServer: true },
    });

    if (active != null) {
      await tx.vpnProfile.update({
        where: { id: active.id },
        data: {
          status: 'ROTATED',
          rotatedAt: new Date(),
        },
      });
    }

    const server =
      active?.vpnServer != null && isSelectableServerRecord(active.vpnServer)
        ? active.vpnServer
        : await resolvePrimaryServer(tx, device.accountId);
    const created = await createVpnProfile(tx, device, server, (active?.revision ?? 0) + 1);

    await emitSecurityEvent(tx, {
      accountId: actor.accountId,
      userId: actor.userId,
      deviceId,
      type: 'KEY_ROTATED',
      severity: 'WARNING',
      title: 'VPN credentials rotated',
      summary: 'A fresh WireGuard profile was issued for this device.',
    });
    await emitAuditLog(tx, {
      accountId: actor.accountId,
      actorUserId: actor.userId,
      deviceId,
      action: 'VPN_PROFILE_ROTATED',
      targetType: 'VPN_PROFILE',
      targetId: deviceId,
      outcome: 'SUCCESS',
      summary: 'A fresh WireGuard profile revision was issued.',
    });

    return created;
  });

  return {
    deviceId,
    rotatedAt: result.rotatedAt?.toISOString() ?? result.issuedAt.toISOString(),
    profile: serializeVpnProfile(result),
  };
}

export async function revokeVpnProfile(actor: LabGuardActor, deviceId: string) {
  await requireAccountDevice(prisma, actor.accountId, deviceId);
  await revokeActiveVpnProfileInternal(prisma, deviceId, actor);
  const profile = await prisma.vpnProfile.findFirst({
    where: { deviceId },
    orderBy: { revision: 'desc' },
    include: { vpnServer: true },
  });

  return {
    deviceId,
    revokedAt: new Date().toISOString(),
    profile: profile == null ? emptyVpnProfile(deviceId) : serializeVpnProfile(profile),
  };
}

export async function getVpnSession(actor: LabGuardActor, deviceId: string) {
  await requireAccountDevice(prisma, actor.accountId, deviceId);
  const session = await getOrCreateDeviceSession(prisma, deviceId);
  return serializeVpnSession(prisma, session);
}

export async function connectVpnSession(
  actor: LabGuardActor,
  payload: {
    deviceId?: string;
    serverId?: string;
    currentIp?: string;
    observedIp?: string;
    lastHandshakeAt?: string;
    lastError?: string;
  },
) {
  const deviceId = payload.deviceId ?? actor.deviceId;
  await requireAccountDevice(prisma, actor.accountId, deviceId);
  const session = await getOrCreateDeviceSession(prisma, deviceId);
  const server =
    payload.serverId == null
      ? await resolvePrimaryServer(prisma, actor.accountId)
      : await requireSelectableVpnServer(prisma, actor.accountId, payload.serverId);
  const observedIp = normalizeObservedIp(payload.observedIp);
  const verification = verifyObservedExitIp(server, observedIp);
  const nextStatus = verification.verified ? 'CONNECTED' : 'DEGRADED';
  const connectedAt =
    nextStatus == 'CONNECTED' ? (session.connectedAt ?? new Date()) : session.connectedAt;
  const lastHandshakeAt = parseIsoDate(payload.lastHandshakeAt);

  await prisma.deviceSession.update({
    where: { id: session.id },
    data: {
      status: nextStatus,
      serverId: server.id,
      publicIp: observedIp ?? payload.currentIp ?? 'Unavailable',
      connectedAt,
      disconnectedAt: null,
      lastHeartbeatAt: new Date(),
      lastHandshakeAt,
      lastError: verification.errorMessage ?? payload.lastError ?? null,
    },
  });
  await prisma.device.update({
    where: { id: deviceId },
    data: {
      connectivityStatus: nextStatus,
      lastSeenAt: new Date(),
      ...optionalStringProperty('lastKnownIp', observedIp ?? payload.currentIp),
    },
  });

  const refreshed = await getOrCreateDeviceSession(prisma, deviceId);
  return serializeVpnSession(prisma, {
    ...refreshed,
    serverId: server.id,
  });
}

export async function disconnectVpnSession(
  actor: LabGuardActor,
  payload: { deviceId?: string; reason?: string },
) {
  const deviceId = payload.deviceId ?? actor.deviceId;
  await requireAccountDevice(prisma, actor.accountId, deviceId);
  const session = await getOrCreateDeviceSession(prisma, deviceId);

  await prisma.deviceSession.update({
    where: { id: session.id },
    data: {
      status: 'DISCONNECTED',
      disconnectedAt: new Date(),
      lastHeartbeatAt: new Date(),
      lastHandshakeAt: null,
      lastError: payload.reason ?? null,
      publicIp: 'Unavailable',
      serverId: null,
    },
  });
  await prisma.device.update({
    where: { id: deviceId },
    data: {
      connectivityStatus: 'DISCONNECTED',
      lastSeenAt: new Date(),
    },
  });

  const refreshed = await getOrCreateDeviceSession(prisma, deviceId);
  return {
    ...(await serializeVpnSession(prisma, refreshed)),
    lastError: payload.reason ?? null,
  };
}

export async function recordVpnHeartbeat(
  actor: LabGuardActor,
  payload: {
    deviceId?: string;
    serverId?: string;
    tunnelState?: string;
    currentIp?: string;
    observedIp?: string;
    bytesReceived?: number;
    bytesSent?: number;
    lastHandshakeAt?: string;
    lastError?: string;
  },
) {
  const deviceId = payload.deviceId ?? actor.deviceId;
  await requireAccountDevice(prisma, actor.accountId, deviceId);
  const session = await getOrCreateDeviceSession(prisma, deviceId);
  const server =
    payload.serverId == null
      ? (session.serverId == null
          ? null
          : await prisma.vpnServer.findFirst({
              where: {
                id: session.serverId,
                accountId: actor.accountId,
              },
            }))
      : await prisma.vpnServer.findFirst({
          where: {
            id: payload.serverId,
            accountId: actor.accountId,
          },
        });
  const observedIp = normalizeObservedIp(payload.observedIp);
  const verification = verifyObservedExitIp(server, observedIp);
  const nextStatus = resolveHeartbeatStatus({
    ...(payload.tunnelState == null ? {} : { tunnelState: payload.tunnelState }),
    verifiedExit: verification.verified,
  });
  const lastHandshakeAt = parseIsoDate(payload.lastHandshakeAt);

  await prisma.deviceSession.update({
    where: { id: session.id },
    data: {
      status: nextStatus,
      ...(server == null ? {} : { serverId: server.id }),
      publicIp: observedIp ?? payload.currentIp ?? session.publicIp,
      bytesIn: BigInt(Math.max(0, payload.bytesReceived ?? Number(session.bytesIn ?? 0n))),
      bytesOut: BigInt(Math.max(0, payload.bytesSent ?? Number(session.bytesOut ?? 0n))),
      lastHeartbeatAt: new Date(),
      lastHandshakeAt,
      lastError: verification.errorMessage ?? payload.lastError ?? null,
      connectedAt:
        nextStatus == 'CONNECTED'
          ? session.connectedAt ?? new Date()
          : nextStatus == 'DEGRADED'
            ? session.connectedAt
            : null,
    },
  });
  await prisma.device.update({
    where: { id: deviceId },
    data: {
      connectivityStatus: nextStatus,
      lastSeenAt: new Date(),
      ...optionalStringProperty('lastKnownIp', observedIp ?? payload.currentIp),
    },
  });

  return {
    accepted: true,
    syncedAt: new Date().toISOString(),
    session: await getVpnSession(actor, deviceId),
  };
}

export async function listRemoteCommands(actor: LabGuardActor, deviceId: string) {
  await requireAccountDevice(prisma, actor.accountId, deviceId);
  const commands = await prisma.remoteCommand.findMany({
    where: { deviceId },
    include: {
      results: {
        orderBy: { executedAt: 'desc' },
      },
    },
    orderBy: [{ completedAt: 'desc' }, { requestedAt: 'desc' }],
  });

  return commands.map(serializeRemoteCommand);
}

export async function queueRemoteCommand(
  actor: LabGuardActor,
  deviceId: string,
  payload: QueueRemoteCommandInput,
) {
  await requireAccountDevice(prisma, actor.accountId, deviceId);
  const command = await prisma.remoteCommand.create({
    data: {
      deviceId,
      initiatedByUserId: actor.userId,
      type: payload.commandType,
      status: 'QUEUED',
      expiresAt: new Date(Date.now() + 10 * 60_000),
      payload:
        payload.message == null
          ? Prisma.JsonNull
          : ({ message: payload.message } satisfies Prisma.JsonObject),
    },
    include: {
      results: true,
    },
  });

  await emitSecurityEvent(prisma, {
    accountId: actor.accountId,
    userId: actor.userId,
    deviceId,
    type: 'COMMAND_EXECUTED',
    severity: payload.commandType == 'DISABLE_DEVICE_ACCESS' ? 'WARNING' : 'INFO',
    title: `${payload.commandType.replaceAll('_', ' ')} queued`,
    summary:
      payload.message == null
        ? 'A remote action was queued for device delivery.'
        : `A remote action was queued with operator message: ${payload.message}`,
  });
  await emitAuditLog(prisma, {
    accountId: actor.accountId,
    actorUserId: actor.userId,
    deviceId,
    action: 'REMOTE_COMMAND_QUEUED',
    targetType: 'REMOTE_COMMAND',
    targetId: command.id,
    outcome: 'SUCCESS',
    summary: `${payload.commandType} was queued for device delivery.`,
  });

  return serializeRemoteCommand(command);
}

export async function reportRemoteCommandResult(
  actor: LabGuardActor,
  commandId: string,
  payload: RemoteCommandResultInput,
) {
  return prisma.$transaction(async (tx) => {
    const command = await tx.remoteCommand.findFirst({
      where: {
        id: commandId,
        device: { accountId: actor.accountId },
      },
      include: {
        device: true,
        results: {
          orderBy: { executedAt: 'desc' },
        },
      },
    });

    if (command == null) {
      throw notFound('Remote command not found.');
    }

    const nextStatus: RemoteCommandStatus =
      payload.status == 'DELIVERED'
        ? 'DELIVERED'
        : payload.status == 'FAILED'
          ? 'FAILED'
          : 'SUCCEEDED';
    const deliveredAt =
      nextStatus == 'DELIVERED' ? new Date() : command.deliveredAt ?? new Date();
    const completedAt = nextStatus == 'DELIVERED' ? null : new Date();

    await tx.remoteCommand.update({
      where: { id: command.id },
      data: {
        status: nextStatus,
        deliveredAt,
        completedAt,
      },
    });

    await tx.remoteCommandResult.create({
      data: {
        remoteCommandId: command.id,
        status:
          nextStatus == 'DELIVERED'
            ? 'ACKNOWLEDGED'
            : nextStatus == 'FAILED'
              ? 'FAILED'
              : 'SUCCEEDED',
        ...optionalNullableStringProperty('errorCode', payload.failureCode ?? null),
        ...optionalNullableStringProperty('errorMessage', payload.resultMessage ?? null),
        metadata:
          payload.resultMessage == null && payload.failureCode == null
            ? Prisma.JsonNull
            : ({
                resultMessage: payload.resultMessage,
                failureCode: payload.failureCode,
              } satisfies Prisma.JsonObject),
      },
    });

    if (nextStatus == 'SUCCEEDED') {
      await applySuccessfulRemoteCommand(tx, command, actor);
    }

    await emitAuditLog(tx, {
      accountId: actor.accountId,
      actorUserId: actor.userId,
      deviceId: command.deviceId,
      action: `REMOTE_COMMAND_${nextStatus}`,
      targetType: 'REMOTE_COMMAND',
      targetId: command.id,
      outcome: nextStatus == 'FAILED' ? 'FAILURE' : 'SUCCESS',
      summary: payload.resultMessage ?? `${command.type} reported ${nextStatus}.`,
    });

    const refreshed = await tx.remoteCommand.findUniqueOrThrow({
      where: { id: command.id },
      include: {
        results: {
          orderBy: { executedAt: 'desc' },
        },
      },
    });

    return serializeRemoteCommand(refreshed);
  });
}

export async function retryRemoteCommand(actor: LabGuardActor, commandId: string) {
  const command = await prisma.remoteCommand.findFirst({
    where: {
      id: commandId,
      device: { accountId: actor.accountId },
    },
    include: { results: true },
  });

  if (command == null) {
    throw notFound('Remote command not found.');
  }

  await prisma.remoteCommand.update({
    where: { id: command.id },
    data: {
      status: 'QUEUED',
      requestedAt: new Date(),
      expiresAt: new Date(Date.now() + 10 * 60_000),
      deliveredAt: null,
      completedAt: null,
      acknowledgedAt: null,
    },
  });

  await emitAuditLog(prisma, {
    accountId: actor.accountId,
    actorUserId: actor.userId,
    deviceId: command.deviceId,
    action: 'REMOTE_COMMAND_RETRIED',
    targetType: 'REMOTE_COMMAND',
    targetId: command.id,
    outcome: 'SUCCESS',
    summary: `${command.type} was requeued for another delivery attempt.`,
  });

  const refreshed = await prisma.remoteCommand.findUniqueOrThrow({
    where: { id: command.id },
    include: {
      results: {
        orderBy: { executedAt: 'desc' },
      },
    },
  });

  return serializeRemoteCommand(refreshed);
}

export async function listSecurityEvents(actor: LabGuardActor) {
  const events = await prisma.securityEvent.findMany({
    where: { accountId: actor.accountId },
    include: { device: true },
    orderBy: { occurredAt: 'desc' },
  });

  return events.map((event) => ({
    id: event.id,
    title: event.title,
    summary: event.summary,
    severity: event.severity,
    occurredAt: event.occurredAt.toISOString(),
    unread: event.unread,
    ...(event.device?.name == null ? {} : { deviceName: event.device.name }),
  }));
}

export async function markSecurityEventRead(actor: LabGuardActor, eventId: string) {
  const event = await prisma.securityEvent.findFirst({
    where: { id: eventId, accountId: actor.accountId },
  });

  if (event == null) {
    throw notFound('Security event not found.');
  }

  await prisma.securityEvent.update({
    where: { id: eventId },
    data: {
      unread: false,
      readAt: new Date(),
    },
  });

  return { markedRead: true, eventId };
}

export async function getAdminOverview(actor: LabGuardActor) {
  requireOwner(actor);

  const [totalUsers, devices, activeVpnServers, queuedRemoteCommands, unreadSecurityEvents] =
    await Promise.all([
      prisma.user.count({ where: { accountId: actor.accountId } }),
      prisma.device.findMany({ where: { accountId: actor.accountId } }),
      prisma.vpnServer.count({
        where: {
          accountId: actor.accountId,
          status: 'ACTIVE',
        },
      }),
      prisma.remoteCommand.count({
        where: {
          device: { accountId: actor.accountId },
          status: 'QUEUED',
        },
      }),
      prisma.securityEvent.count({
        where: {
          accountId: actor.accountId,
          unread: true,
        },
      }),
    ]);

  return {
    totalUsers,
    totalDevices: devices.length,
    devicesInLostMode: devices.filter((device) => device.lostModeStatus == 'ACTIVE').length,
    pendingApprovals: devices.filter((device) => device.trustState == 'PENDING_APPROVAL').length,
    activeVpnServers,
    queuedRemoteCommands,
    unreadSecurityEvents,
  };
}

export async function listAuditLogs(actor: LabGuardActor) {
  requireOwner(actor);

  const auditLogs = await prisma.auditLog.findMany({
    where: { accountId: actor.accountId },
    include: { actorUser: true },
    orderBy: { createdAt: 'desc' },
    take: 200,
  });

  return auditLogs.map((entry) => ({
    id: entry.id,
    action: entry.action,
    targetType: entry.targetType,
    targetId: entry.targetId ?? '',
    outcome: entry.outcome,
    summary: entry.summary,
    actorLabel: entry.actorUser?.displayName ?? 'LabGuard',
    createdAt: entry.createdAt.toISOString(),
  }));
}

export async function issueInvitation(actor: LabGuardActor) {
  requireOwner(actor);

  const inviteCode = `LAB-${randomBytes(4).toString('hex').toUpperCase()}`;
  const invitation = await prisma.invitation.create({
    data: {
      accountId: actor.accountId,
      invitedByUserId: actor.userId,
      codeHash: hashInviteCode(inviteCode),
      status: 'PENDING',
      expiresAt: new Date(Date.now() + 14 * 24 * 60 * 60_000),
    },
  });

  await emitAuditLog(prisma, {
    accountId: actor.accountId,
    actorUserId: actor.userId,
    deviceId: actor.deviceId,
    action: 'INVITATION_ISSUED',
    targetType: 'AUTH',
    targetId: invitation.id,
    outcome: 'SUCCESS',
    summary: 'A new trusted invitation code was issued.',
  });

  return {
    invitationId: invitation.id,
    status: invitation.status,
    deliveryMode: 'MANUAL_CODE',
    inviteCode,
  };
}

async function ensureAccountSeed(db: DbClient) {
  const existing = await db.account.findFirst({
    where: { name: 'Emilo Labs' },
  });

  if (existing != null) {
    return existing;
  }

  return db.account.create({
    data: { name: 'Emilo Labs' },
  });
}

async function ensureOwnerSeed(db: DbClient, accountId: string) {
  const existing = await db.user.findUnique({
    where: { email: 'owner@emilolabs.com' },
  });

  if (existing != null) {
    return existing;
  }

  return db.user.create({
    data: {
      accountId,
      email: 'owner@emilolabs.com',
      displayName: 'Emilo Owner',
      role: 'OWNER',
    },
  });
}

async function ensurePreferenceSeed(db: DbClient, userId: string) {
  return db.userPreference.upsert({
    where: { userId },
    update: {},
    create: {
      userId,
      biometricEnabled: true,
      pinLockEnabled: false,
      autoConnectEnabled: true,
      killSwitchEnabled: true,
      notificationsEnabled: true,
      telemetryLevel: 'elevated_lost_mode_only',
      locationPermissionStatus: 'granted_when_in_use',
      batteryOptimizationAcknowledged: false,
    },
  });
}

async function ensureServerSeeds(db: DbClient, accountId: string) {
  const configuredServers = configuredVpnServers();

  if (configuredServers.length == 0) {
    await db.vpnServer.updateMany({
      where: {
        accountId,
        status: 'ACTIVE',
      },
      data: {
        status: 'DISABLED',
        isPrimary: false,
      },
    });

    return [];
  }

  await Promise.all(
    configuredServers.map((server) =>
      db.vpnServer.upsert({
        where: {
          accountId_name: {
            accountId,
            name: server.name,
          },
        },
        update: {
          endpoint: server.endpoint,
          hostname: server.hostname,
          regionCode: server.regionCode,
          publicKey: server.publicKey,
          isPrimary: server.isPrimary,
          status: 'ACTIVE',
          priority: server.priority,
          port: server.port,
        },
        create: {
          accountId,
          name: server.name,
          regionCode: server.regionCode,
          hostname: server.hostname,
          endpoint: server.endpoint,
          port: server.port,
          publicKey: server.publicKey,
          isPrimary: server.isPrimary,
          status: 'ACTIVE',
          priority: server.priority,
        },
      }),
    ),
  );

  await db.vpnServer.updateMany({
    where: {
      accountId,
      name: {
        notIn: configuredServers.map((server) => server.name),
      },
    },
    data: {
      status: 'DISABLED',
      isPrimary: false,
    },
  });

  return db.vpnServer.findMany({
    where: {
      accountId,
      status: 'ACTIVE',
    },
    orderBy: [{ isPrimary: 'desc' }, { priority: 'asc' }],
  });
}

async function ensureInvitationSeed(db: DbClient, accountId: string, ownerUserId: string) {
  const existing = await db.invitation.findFirst({
    where: {
      accountId,
      status: 'PENDING',
      codeHash: hashInviteCode(DEFAULT_INVITE_CODE),
    },
  });

  if (existing != null) {
    return existing;
  }

  return db.invitation.create({
    data: {
      accountId,
      invitedByUserId: ownerUserId,
      codeHash: hashInviteCode(DEFAULT_INVITE_CODE),
      status: 'PENDING',
      expiresAt: new Date(Date.now() + 14 * 24 * 60 * 60_000),
    },
  });
}

async function cleanupLegacyDemoData(db: DbClient, accountId: string) {
  const demoDevices = await db.device.findMany({
    where: {
      accountId,
      clientId: {
        in: [...DEMO_DEVICE_CLIENT_IDS],
      },
    },
    select: { id: true },
  });

  if (demoDevices.length == 0) {
    return;
  }

  const demoDeviceIds = demoDevices.map((device) => device.id);

  await db.auditLog.deleteMany({
    where: {
      accountId,
      deviceId: {
        in: demoDeviceIds,
      },
    },
  });
  await db.securityEvent.deleteMany({
    where: {
      accountId,
      deviceId: {
        in: demoDeviceIds,
      },
    },
  });
  await db.device.deleteMany({
    where: {
      id: {
        in: demoDeviceIds,
      },
    },
  });
}

async function reconcileProvisionedVpnState(
  db: DbClient,
  accountId: string,
  selectableServerIds: string[],
) {
  const accountDevices = await db.device.findMany({
    where: { accountId },
    select: { id: true },
  });

  if (accountDevices.length == 0) {
    return;
  }

  const deviceIds = accountDevices.map((device) => device.id);
  const now = new Date();

  if (selectableServerIds.length == 0) {
    await db.vpnProfile.updateMany({
      where: {
        deviceId: {
          in: deviceIds,
        },
        status: 'ACTIVE',
      },
      data: {
        status: 'REVOKED',
        revokedAt: now,
        rotatedAt: now,
      },
    });
    await db.deviceSession.updateMany({
      where: {
        deviceId: {
          in: deviceIds,
        },
      },
      data: {
        serverId: null,
        status: 'DISCONNECTED',
        publicIp: null,
        connectedAt: null,
        disconnectedAt: now,
        bytesIn: BigInt(0),
        bytesOut: BigInt(0),
        lastError: 'No production-ready VPN region is configured for this account.',
      },
    });
    return;
  }

  await db.vpnProfile.updateMany({
    where: {
      deviceId: {
        in: deviceIds,
      },
      status: 'ACTIVE',
      NOT: {
        vpnServerId: {
          in: selectableServerIds,
        },
      },
    },
    data: {
      status: 'REVOKED',
      revokedAt: now,
      rotatedAt: now,
    },
  });
  await db.deviceSession.updateMany({
    where: {
      deviceId: {
        in: deviceIds,
      },
      serverId: {
        not: null,
      },
      NOT: {
        serverId: {
          in: selectableServerIds,
        },
      },
    },
    data: {
      serverId: null,
      status: 'DISCONNECTED',
      publicIp: null,
      connectedAt: null,
      disconnectedAt: now,
      bytesIn: BigInt(0),
      bytesOut: BigInt(0),
      lastError:
        'The active VPN region is no longer available. Refresh the device profile before reconnecting.',
    },
  });
}

async function ensureMemberFromInvitation(
  db: DbClient,
  invitation: { accountId: string; id: string },
  email: string,
) {
  const existing = await db.user.findUnique({
    where: { email },
  });

  if (existing != null) {
    return existing;
  }

  const member = await db.user.create({
    data: {
      accountId: invitation.accountId,
      email,
      displayName: displayNameFromIdentity(email),
      role: 'MEMBER',
    },
  });
  await ensurePreferenceSeed(db, member.id);
  return member;
}

async function ensureDeviceForUser(
  db: DbClient,
  input: {
    accountId: string;
    userId: string;
    userRole: UserRole;
    device: DeviceRegistrationInput;
    trustState: DeviceTrustState;
  },
) {
  const existing = await db.device.findUnique({
    where: { clientId: input.device.clientId },
  });

  if (existing != null) {
    return db.device.update({
      where: { id: existing.id },
      data: {
        accountId: input.accountId,
        userId: input.userId,
        name: input.device.name,
        model: input.device.model,
        platform: input.device.platform,
        ...optionalNullableStringProperty('osVersion', input.device.osVersion ?? null),
        appVersion: input.device.appVersion,
        trustState: input.trustState,
        lastSeenAt: new Date(),
        isPrimary:
          input.userRole == 'OWNER'
            ? existing.isPrimary || !(await hasPrimaryDevice(db, input.accountId))
            : existing.isPrimary,
      },
    });
  }

  const isPrimary = input.userRole == 'OWNER' && !(await hasPrimaryDevice(db, input.accountId));

  return db.device.create({
    data: {
      accountId: input.accountId,
      userId: input.userId,
      clientId: input.device.clientId,
      name: input.device.name,
      model: input.device.model,
      platform: input.device.platform,
      osVersion: input.device.osVersion ?? null,
      appVersion: input.device.appVersion,
      trustState: input.trustState,
      isPrimary,
      batteryLevel: 100,
      lastSeenAt: new Date(),
      lastKnownIp: 'Unavailable',
      lastKnownNetwork: 'Unavailable',
      lastKnownLocation: 'Location unavailable',
    },
  });
}

async function hasPrimaryDevice(db: DbClient, accountId: string) {
  const primary = await db.device.findFirst({
    where: { accountId, isPrimary: true },
    select: { id: true },
  });
  return primary != null;
}

async function createSessionEnvelope(
  db: DbClient,
  input: {
    user: { id: string; accountId: string; email: string; displayName: string; role: UserRole };
    device: { id: string; name: string; trustState: DeviceTrustState };
    ipAddress?: string | undefined;
    userAgent?: string | undefined;
  },
) {
  const tokens = generateSessionTokens();

  await db.session.create({
    data: {
      userId: input.user.id,
      deviceId: input.device.id,
      accessTokenHash: hashSecret(tokens.accessToken),
      refreshTokenHash: hashSecret(tokens.refreshToken),
      accessTokenExpiresAt: tokens.accessTokenExpiresAt,
      expiresAt: tokens.sessionExpiresAt,
      status: 'ACTIVE',
      ...optionalNullableStringProperty('ipAddress', input.ipAddress ?? null),
      ...optionalNullableStringProperty('userAgent', input.userAgent ?? null),
    },
  });

  const account = await db.account.findUniqueOrThrow({
    where: { id: input.user.accountId },
  });

  return buildSessionEnvelope({
    accessToken: tokens.accessToken,
    refreshToken: tokens.refreshToken,
    user: input.user,
    account,
    device: input.device,
  });
}

function buildSessionEnvelope(input: {
  accessToken: string;
  refreshToken: string;
  user: { id: string; email: string; displayName: string; role: UserRole };
  account: { id: string; name: string };
  device: { id: string; name: string; trustState: DeviceTrustState };
}): SessionEnvelope {
  return {
    accessToken: input.accessToken,
    refreshToken: input.refreshToken,
    expiresInSeconds: ACCESS_TOKEN_TTL_SECONDS,
    session: {
      viewer: serializeViewer(input.user),
      account: serializeAccount(input.account),
      device: serializeSessionDevice(input.device),
    },
  };
}

async function requireAccountDevice(db: DbClient, accountId: string, deviceId: string) {
  const device = await db.device.findFirst({
    where: { id: deviceId, accountId },
  });

  if (device == null) {
    throw notFound('Device not found.');
  }

  return device;
}

async function ensureActiveVpnProfile(
  db: DbClient,
  device: {
    id: string;
    accountId: string;
    trustState: DeviceTrustState;
    clientId: string;
  },
) {
  if (device.trustState != 'TRUSTED') {
    throw forbidden('The device must be trusted before VPN access can be issued.');
  }

  const existing = await db.vpnProfile.findFirst({
    where: { deviceId: device.id, status: 'ACTIVE' },
    orderBy: { revision: 'desc' },
    include: { vpnServer: true },
  });

  if (existing != null && isSelectableServerRecord(existing.vpnServer)) {
    return existing;
  }

  if (existing != null) {
    await db.vpnProfile.update({
      where: { id: existing.id },
      data: {
        status: 'REVOKED',
        rotatedAt: new Date(),
      },
    });
  }

  const server = await db.vpnServer.findFirst({
    where: { accountId: device.accountId, status: 'ACTIVE' },
    orderBy: [{ isPrimary: 'desc' }, { priority: 'asc' }],
  });
  if (server == null || !isSelectableServerRecord(server)) {
    return null;
  }

  return createVpnProfile(db, device, server, 1);
}

async function resolvePrimaryServer(db: DbClient, accountId: string) {
  const server = await db.vpnServer.findFirst({
    where: { accountId, status: 'ACTIVE' },
    orderBy: [{ isPrimary: 'desc' }, { priority: 'asc' }],
  });

  if (server == null || !isSelectableServerRecord(server)) {
    throw badRequest(
      'No production-ready VPN server is configured for this account.',
    );
  }

  return server;
}

async function requireSelectableVpnServer(
  db: DbClient,
  accountId: string,
  serverId: string,
) {
  const server = await db.vpnServer.findFirst({
    where: {
      id: serverId,
      accountId,
      status: 'ACTIVE',
    },
  });

  if (server == null || !isSelectableServerRecord(server)) {
    throw badRequest('The selected VPN region is not configured for use.');
  }

  return server;
}

async function createVpnProfile(
  db: DbClient,
  device: { id: string; clientId: string },
  server: {
    id: string;
    publicKey: string;
    endpoint: string;
    name?: string;
    regionCode?: string;
  },
  revision: number,
) {
  const configuredServer = resolveConfiguredServerForRecord(server);
  if (configuredServer == null) {
    throw badRequest(
      'The selected VPN server is missing its live endpoint configuration.',
    );
  }

  const privateKey = randomWireGuardKey();
  const publicKey = randomWireGuardKey();
  const presharedKey = randomWireGuardKey();
  const assignedAddress = await nextAssignedAddress(db);

  return db.vpnProfile.create({
    data: {
      deviceId: device.id,
      vpnServerId: server.id,
      revision,
      publicKey,
      privateKeyEncrypted: encryptSecret(privateKey),
      presharedKeyEncrypted: encryptSecret(presharedKey),
      assignedAddress,
      dnsServers: configuredServer.dnsServers,
      status: 'ACTIVE',
      issuedAt: new Date(),
      rotatedAt: revision > 1 ? new Date() : null,
    },
    include: { vpnServer: true },
  });
}

async function nextAssignedAddress(db: DbClient) {
  const profiles = await db.vpnProfile.findMany({
    select: { assignedAddress: true },
  });
  const used = new Set(
    profiles
      .map((profile) => Number(profile.assignedAddress.split('.')[3]?.split('/')[0] ?? '0'))
      .filter((value) => Number.isFinite(value) && value > 1),
  );

  let candidate = 2;
  while (used.has(candidate)) {
    candidate += 1;
  }

  return `10.66.0.${candidate}/32`;
}

async function revokeActiveVpnProfileInternal(
  db: DbClient,
  deviceId: string,
  actor: LabGuardActor,
) {
  const profile = await db.vpnProfile.findFirst({
    where: { deviceId, status: 'ACTIVE' },
    orderBy: { revision: 'desc' },
  });

  if (profile != null) {
    await db.vpnProfile.update({
      where: { id: profile.id },
      data: {
        status: 'REVOKED',
        revokedAt: new Date(),
      },
    });
  }

  await emitSecurityEvent(db, {
    accountId: actor.accountId,
    userId: actor.userId,
    deviceId,
    type: 'KEY_ROTATED',
    severity: 'CRITICAL',
    title: 'VPN access revoked',
    summary: 'The active tunnel profile for this device was revoked.',
  });
  await emitAuditLog(db, {
    accountId: actor.accountId,
    actorUserId: actor.userId,
    deviceId,
    action: 'VPN_PROFILE_REVOKED',
    targetType: 'VPN_PROFILE',
    targetId: deviceId,
    outcome: 'SUCCESS',
    summary: 'VPN access was revoked for the device.',
  });
}

async function getOrCreateDeviceSession(db: DbClient, deviceId: string) {
  const existing = await db.deviceSession.findFirst({
    where: { deviceId },
    orderBy: { updatedAt: 'desc' },
  });

  if (existing != null) {
    return existing;
  }

  return db.deviceSession.create({
    data: {
      deviceId,
      serverId: null,
      status: 'DISCONNECTED',
      publicIp: 'Unavailable',
      lastHeartbeatAt: new Date(),
      lastHandshakeAt: null,
      lastError: null,
      bytesIn: BigInt(0),
      bytesOut: BigInt(0),
    },
  });
}

async function buildLocationSnapshot(db: DbClient, deviceId: string) {
  const [device, locations] = await Promise.all([
    db.device.findUniqueOrThrow({ where: { id: deviceId } }),
    db.deviceLocation.findMany({
      where: { deviceId },
      orderBy: { capturedAt: 'desc' },
      take: 12,
    }),
  ]);

  const currentLocation = locations[0] == null ? null : serializeLocationRecord(locations[0], device);

  return {
    deviceId,
    lostModeStatus: device.lostModeStatus,
    liveTrackingEnabled: device.lostModeStatus == 'ACTIVE',
    updateMode: device.lostModeStatus == 'ACTIVE' ? 'elevated_lost_mode' : 'minimal_background',
    updateFrequencyLabel:
      device.lostModeStatus == 'ACTIVE'
        ? 'Every few minutes while online'
        : 'Only on explicit security events',
    currentLocation,
    items: locations.map((location) => serializeLocationRecord(location, device)),
  };
}

async function serializeDeviceDetail(
  db: DbClient,
  device: Awaited<ReturnType<typeof requireAccountDevice>>,
) {
  const [deviceRecord, securityEvents, remoteCommands] = await Promise.all([
    prisma.device.findUniqueOrThrow({
      where: { id: device.id },
      include: {
        sessions: {
          orderBy: { updatedAt: 'desc' },
          take: 1,
        },
        locations: {
          orderBy: { capturedAt: 'desc' },
          take: 1,
        },
      },
    }),
    db.securityEvent.findMany({
      where: { deviceId: device.id },
      orderBy: { occurredAt: 'desc' },
      take: 24,
    }),
    db.remoteCommand.findMany({
      where: { deviceId: device.id },
      include: {
        results: {
          orderBy: { executedAt: 'desc' },
        },
      },
      orderBy: [{ completedAt: 'desc' }, { requestedAt: 'desc' }],
      take: 24,
    }),
  ]);

  return {
    ...serializeDeviceRecord(deviceRecord),
    lostModeStatus: deviceRecord.lostModeStatus,
    remoteActionsAvailable: remoteActionsAvailable(deviceRecord.trustState, deviceRecord.lostModeStatus),
    securityHistory: [
      ...securityEvents.map((event) => ({
        id: event.id,
        title: event.title,
        detail: event.summary,
        occurredAt: event.occurredAt.toISOString(),
      })),
      ...remoteCommands.map((command) => ({
        id: command.id,
        title: `${command.type.replaceAll('_', ' ')} • ${command.status}`,
        detail:
          latestCommandResultMessage(command) ??
          extractCommandMessage(command.payload) ??
          'Remote action queued through the LabGuard control plane.',
        occurredAt: (command.completedAt ?? command.requestedAt).toISOString(),
      })),
    ].sort((left, right) => right.occurredAt.localeCompare(left.occurredAt)),
  };
}

function serializeDeviceRecord(device: {
  id: string;
  name: string;
  model: string;
  platform: string;
  appVersion: string;
  trustState: DeviceTrustState;
  lostModeStatus: string;
  isPrimary: boolean;
  batteryLevel: number | null;
  lastKnownIp: string | null;
  lastKnownNetwork: string | null;
  lastKnownLocation: string | null;
  lastSeenAt: Date | null;
  sessions?: Array<{
    status: DeviceConnectivityStatus;
    lastHeartbeatAt: Date | null;
  }>;
  locations?: Array<{
    capturedAt: Date;
  }>;
}) {
  const latestSession = device.sessions?.[0];
  const latestLocation = device.locations?.[0];
  return {
    id: device.id,
    name: device.name,
    model: device.model,
    platform: device.platform,
    appVersion: device.appVersion,
    trustState: device.trustState,
    vpnStatus: latestSession?.status ?? 'DISCONNECTED',
    batteryLevel: device.batteryLevel ?? 0,
    isLost: device.lostModeStatus == 'ACTIVE',
    isPrimary: device.isPrimary,
    lastActiveAt: (latestSession?.lastHeartbeatAt ?? device.lastSeenAt ?? new Date(0)).toISOString(),
    lastKnownIp: device.lastKnownIp ?? 'Unavailable',
    lastKnownNetwork: device.lastKnownNetwork ?? 'Unavailable',
    lastKnownLocation: device.lastKnownLocation ?? 'Location unavailable',
    locationCapturedAt: (latestLocation?.capturedAt ?? device.lastSeenAt ?? new Date(0)).toISOString(),
  };
}

function serializePreferences(preference: {
  biometricEnabled: boolean;
  pinLockEnabled: boolean;
  autoConnectEnabled: boolean;
  killSwitchEnabled: boolean;
  notificationsEnabled: boolean;
  telemetryLevel: string;
  locationPermissionStatus: string;
  batteryOptimizationAcknowledged: boolean;
}) {
  return {
    biometricEnabled: preference.biometricEnabled,
    pinLockEnabled: preference.pinLockEnabled,
    autoConnectEnabled: preference.autoConnectEnabled,
    killSwitchEnabled: preference.killSwitchEnabled,
    notificationsEnabled: preference.notificationsEnabled,
    telemetryLevel: preference.telemetryLevel,
    locationPermissionStatus: preference.locationPermissionStatus,
    batteryOptimizationAcknowledged: preference.batteryOptimizationAcknowledged,
  };
}

function serializeViewer(user: { id: string; email: string; displayName: string; role: UserRole }) {
  return {
    id: user.id,
    email: user.email,
    displayName: user.displayName,
    role: user.role,
  };
}

function serializeAccount(account: { id: string; name: string }) {
  return {
    id: account.id,
    name: account.name,
    brandAttribution: DEFAULT_BRAND_ATTRIBUTION,
  };
}

function serializeSessionDevice(device: {
  id: string;
  name: string;
  trustState: DeviceTrustState;
}) {
  return {
    id: device.id,
    name: device.name,
    trustState: device.trustState,
  };
}

function serializeVpnProfile(
  profile: {
    deviceId: string;
    status: VpnProfileStatus;
    revision: number;
    issuedAt: Date;
    rotatedAt: Date | null;
    assignedAddress: string;
    dnsServers: string[];
    privateKeyEncrypted: string;
    vpnServer: {
      id: string;
      name: string;
      regionCode?: string;
      hostname?: string;
      port?: number;
      endpoint: string;
      publicKey: string;
    };
  },
) {
  const server = resolveConfiguredServerForRecord(profile.vpnServer);
  if (server == null) {
    return {
      ...emptyVpnProfile(profile.deviceId),
      revision: profile.revision,
      issuedAt: profile.issuedAt.toISOString(),
      rotatedAt: profile.rotatedAt?.toISOString() ?? profile.issuedAt.toISOString(),
      note: 'No production-ready VPN region is configured for this device.',
    };
  }

  const tunnelName = tunnelNameForDevice(profile.deviceId);
  return {
    deviceId: profile.deviceId,
    profileStatus: profile.status,
    revision: profile.revision,
    tunnelName,
    serverId: profile.vpnServer.id,
    serverName: profile.vpnServer.name,
    locationLabel: server?.locationLabel ?? profile.vpnServer.name,
    endpoint: profile.vpnServer.endpoint,
    exitIpAddress: server?.exitIpAddress ?? '',
    dnsServers: profile.dnsServers,
    issuedAt: profile.issuedAt.toISOString(),
    rotatedAt: profile.rotatedAt?.toISOString() ?? profile.issuedAt.toISOString(),
    config:
      profile.status == 'REVOKED'
        ? null
        : buildWireGuardConfig({
            privateKey: decryptSecret(profile.privateKeyEncrypted),
            assignedAddress: profile.assignedAddress,
            dnsServers: profile.dnsServers,
            serverPublicKey: profile.vpnServer.publicKey,
            endpoint: profile.vpnServer.endpoint,
          }),
    note:
      profile.status == 'REVOKED'
        ? 'VPN access was revoked for this device.'
        : 'Active WireGuard profile issued by the LabGuard control plane.',
  };
}

function emptyVpnProfile(deviceId: string) {
  return {
    deviceId,
    profileStatus: 'REVOKED',
    revision: 0,
    tunnelName: tunnelNameForDevice(deviceId),
    serverId: '',
    serverName: 'VPN not provisioned',
    locationLabel: 'Provisioning required',
    endpoint: '',
    exitIpAddress: '',
    dnsServers: [],
    issuedAt: new Date(0).toISOString(),
    rotatedAt: new Date(0).toISOString(),
    config: null,
    note: 'No production-ready VPN region is configured for this device.',
  };
}

async function serializeVpnSession(
  db: DbClient,
  session: {
    deviceId: string;
    status: DeviceConnectivityStatus;
    publicIp: string | null;
    connectedAt: Date | null;
    lastHeartbeatAt: Date | null;
    lastHandshakeAt?: Date | null;
    lastError?: string | null;
    bytesIn: bigint | null;
    bytesOut: bigint | null;
    disconnectedAt: Date | null;
    serverId?: string | null;
  },
) {
  const [device, activeProfile] = await Promise.all([
    db.device.findUniqueOrThrow({ where: { id: session.deviceId } }),
    db.vpnProfile.findFirst({
      where: {
        deviceId: session.deviceId,
        status: 'ACTIVE',
      },
      include: { vpnServer: true },
      orderBy: { revision: 'desc' },
    }),
  ]);
  const activeSelectableProfile =
    activeProfile != null && isSelectableServerRecord(activeProfile.vpnServer)
      ? activeProfile
      : null;
  const sessionServer =
    session.serverId == null
      ? null
      : await db.vpnServer.findUnique({ where: { id: session.serverId } });
  const server =
    (sessionServer != null && isSelectableServerRecord(sessionServer)
      ? sessionServer
      : null) ??
    activeSelectableProfile?.vpnServer ??
    null;
  const configuredServer = server == null ? null : resolveConfiguredServerForRecord(server);

  if (server == null || configuredServer == null) {
    return {
      deviceId: session.deviceId,
      tunnelState: 'DISCONNECTED',
      connected: false,
      profileInstalled: false,
      profileRevision: 0,
      serverId: '',
      serverName: 'VPN not provisioned',
      locationLabel: 'Provisioning required',
      endpoint: '',
      exitIpAddress: '',
      currentIp: 'Unavailable',
      dnsMode: 'No live region provisioned',
      connectedAt: null,
      lastHeartbeatAt: session.lastHeartbeatAt?.toISOString() ?? null,
      lastHandshakeAt: session.lastHandshakeAt?.toISOString() ?? null,
      bytesReceived: Number(session.bytesIn ?? 0n),
      bytesSent: Number(session.bytesOut ?? 0n),
      sessionDurationSeconds: 0,
      lastError:
        session.lastError ?? 'No production-ready VPN region is configured for this account.',
    };
  }

  return {
    deviceId: session.deviceId,
    tunnelState: connectivityStatusToTunnelState(session.status),
    connected: session.status == 'CONNECTED',
    profileInstalled: activeProfile != null,
    profileRevision: activeProfile?.revision ?? 0,
    serverId: server?.id ?? '',
    serverName: server?.name ?? 'Unassigned',
    locationLabel: configuredServer?.locationLabel ?? server?.name ?? 'Unassigned',
    endpoint: server?.endpoint ?? '',
    exitIpAddress: configuredServer?.exitIpAddress ?? '',
    currentIp: session.publicIp ?? 'Unavailable',
    dnsMode: session.status == 'CONNECTED' ? 'Private DNS via tunnel' : 'Tunnel down',
    connectedAt: session.connectedAt?.toISOString() ?? null,
    lastHeartbeatAt: session.lastHeartbeatAt?.toISOString() ?? null,
    lastHandshakeAt: session.lastHandshakeAt?.toISOString() ?? null,
    bytesReceived: Number(session.bytesIn ?? 0n),
    bytesSent: Number(session.bytesOut ?? 0n),
    sessionDurationSeconds:
      session.connectedAt == null
        ? 0
        : Math.max(0, Math.floor((Date.now() - session.connectedAt.getTime()) / 1000)),
    lastError: session.lastError ?? null,
  };
}

function serializeRemoteCommand(command: {
  id: string;
  deviceId: string;
  type: RemoteCommandType;
  status: RemoteCommandStatus;
  requestedAt: Date;
  expiresAt: Date | null;
  deliveredAt: Date | null;
  completedAt: Date | null;
  payload: Prisma.JsonValue | null;
  results: Array<{
    errorCode: string | null;
    errorMessage: string | null;
    executedAt: Date;
  }>;
}) {
  const latestResult = command.results[0];
  return {
    commandId: command.id,
    deviceId: command.deviceId,
    commandType: command.type,
    status: command.status,
    queuedAt: command.requestedAt.toISOString(),
    deliveredAt: command.deliveredAt?.toISOString(),
    completedAt: command.completedAt?.toISOString(),
    expiresAt: command.expiresAt?.toISOString() ?? new Date(Date.now() + 10 * 60_000).toISOString(),
    attemptCount: Math.max(1, command.results.length + (command.status == 'QUEUED' ? 1 : 0)),
    message: extractCommandMessage(command.payload),
    resultMessage: latestResult?.errorMessage ?? undefined,
    failureCode: latestResult?.errorCode ?? undefined,
  };
}

function serializeLocationRecord(
  location: {
    id: string;
    deviceId: string;
    latitude: Prisma.Decimal;
    longitude: Prisma.Decimal;
    accuracyMeters: number | null;
    capturedAt: Date;
    source: string;
    networkType: string | null;
    ipAddress: string | null;
  },
  device: {
    lastKnownNetwork: string | null;
    lastKnownIp: string | null;
    lastKnownLocation: string | null;
  },
) {
  const latitude = Number(location.latitude);
  const longitude = Number(location.longitude);
  return {
    id: location.id,
    deviceId: location.deviceId,
    label: device.lastKnownLocation ?? formatLocationLabel(latitude, longitude),
    latitude,
    longitude,
    accuracyMeters: location.accuracyMeters ?? 0,
    capturedAt: location.capturedAt.toISOString(),
    source: location.source,
    lastKnownNetwork: location.networkType ?? device.lastKnownNetwork ?? 'Unavailable',
    lastKnownIp: location.ipAddress ?? device.lastKnownIp ?? 'Unavailable',
  };
}

function remoteActionsAvailable(trustState: DeviceTrustState, lostModeStatus: string) {
  if (trustState == 'REVOKED') {
    return ['MARK_RECOVERED'];
  }

  return [
    'SIGN_OUT',
    'REVOKE_VPN',
    'ROTATE_SESSION',
    'WIPE_APP_DATA',
    'RING_ALARM',
    'SHOW_RECOVERY_MESSAGE',
    ...(lostModeStatus == 'ACTIVE' ? (['MARK_RECOVERED'] as const) : []),
    'DISABLE_DEVICE_ACCESS',
  ];
}

async function applySuccessfulRemoteCommand(
  db: DbClient,
  command: {
    id: string;
    type: RemoteCommandType;
    deviceId: string;
    device: { accountId: string; name: string };
  },
  actor: LabGuardActor,
) {
  switch (command.type) {
    case 'REVOKE_VPN':
      await revokeActiveVpnProfileInternal(db, command.deviceId, actor);
      break;
    case 'MARK_RECOVERED':
      await db.device.update({
        where: { id: command.deviceId },
        data: {
          lostModeStatus: 'RECOVERED',
          operationalStatus: 'ACTIVE',
          telemetryElevated: false,
        },
      });
      break;
    case 'DISABLE_DEVICE_ACCESS':
      await db.device.update({
        where: { id: command.deviceId },
        data: {
          trustState: 'SUSPENDED',
          operationalStatus: 'DISABLED',
          connectivityStatus: 'DISCONNECTED',
        },
      });
      await db.session.updateMany({
        where: { deviceId: command.deviceId, status: 'ACTIVE' },
        data: {
          status: 'REVOKED',
          revokedAt: new Date(),
        },
      });
      break;
    case 'SIGN_OUT':
    case 'ROTATE_SESSION':
    case 'WIPE_APP_DATA':
      await db.session.updateMany({
        where: { deviceId: command.deviceId, status: 'ACTIVE' },
        data: {
          status: 'REVOKED',
          revokedAt: new Date(),
        },
      });
      break;
    case 'RING_ALARM':
    case 'SHOW_RECOVERY_MESSAGE':
      break;
  }
}

async function emitSecurityEvent(
  db: DbClient,
  input: {
    accountId: string;
    userId?: string | null;
    deviceId?: string | null;
    type: SecurityEventType;
    severity: SecurityEventSeverity;
    title: string;
    summary: string;
  },
) {
  await db.securityEvent.create({
    data: {
      accountId: input.accountId,
      userId: input.userId ?? null,
      deviceId: input.deviceId ?? null,
      type: input.type,
      severity: input.severity,
      title: input.title,
      summary: input.summary,
    },
  });
}

async function emitAuditLog(
  db: DbClient,
  input: {
    accountId: string;
    actorUserId?: string | null;
    deviceId?: string | null;
    action: string;
    targetType: string;
    targetId?: string | null;
    outcome: AuditOutcome;
    summary: string;
    ipAddress?: string | undefined;
    userAgent?: string | undefined;
  },
) {
  await db.auditLog.create({
    data: {
      accountId: input.accountId,
      actorUserId: input.actorUserId ?? null,
      deviceId: input.deviceId ?? null,
      action: input.action,
      targetType: input.targetType,
      targetId: input.targetId ?? null,
      summary: input.summary,
      outcome: input.outcome,
      ...optionalNullableStringProperty('ipAddress', input.ipAddress ?? null),
      ...optionalNullableStringProperty('userAgent', input.userAgent ?? null),
      metadata: Prisma.JsonNull,
    },
  });
}

function sanitizeDeviceRegistrationInput(
  device: Partial<DeviceRegistrationInput> | undefined,
  identity: string,
): DeviceRegistrationInput {
  return {
    clientId:
      device?.clientId?.trim().length
        ? device.clientId.trim()
        : `client-${hashSecret(identity).slice(0, 16)}`,
    name:
      device?.name?.trim().length
        ? device.name.trim()
        : `${displayNameFromIdentity(identity)} device`,
    model: device?.model?.trim().length ? device.model.trim() : 'Android device',
    platform: device?.platform?.trim().length ? device.platform.trim() : 'Android',
    appVersion: device?.appVersion?.trim().length ? device.appVersion.trim() : '1.0.0',
    ...(device?.osVersion?.trim().length
      ? { osVersion: device.osVersion.trim() }
      : {}),
  };
}

function optionalStringProperty<Key extends string>(key: Key, value: string | undefined) {
  return value === undefined ? {} : ({ [key]: value } as Record<Key, string>);
}

function optionalNullableStringProperty<Key extends string>(
  key: Key,
  value: string | null | undefined,
) {
  return value === undefined
    ? {}
    : ({ [key]: value } as Record<Key, string | null>);
}

function normalizeIdentity(identity?: string) {
  const normalized = identity?.trim().toLowerCase();
  return normalized == null || normalized.length == 0 ? null : normalized;
}

function normalizeInviteCode(inviteCode?: string) {
  const normalized = inviteCode?.trim().toUpperCase();
  return normalized == null || normalized.length == 0 ? null : normalized;
}

function displayNameFromIdentity(identity: string) {
  const localPart = identity.split('@')[0] ?? identity;
  return localPart
    .split(/[._-]+/)
    .filter((value) => value.length > 0)
    .map((value) => value[0]!.toUpperCase() + value.slice(1))
    .join(' ');
}

function hashSecret(value: string) {
  return createHash('sha256')
    .update(env.JWT_REFRESH_SECRET)
    .update(':')
    .update(value)
    .digest('hex');
}

function hashInviteCode(value: string) {
  return createHash('sha256')
    .update(env.JWT_ACCESS_SECRET)
    .update(':invite:')
    .update(value)
    .digest('hex');
}

function hashAppPin(value: string) {
  return createHash('sha256')
    .update(env.JWT_ACCESS_SECRET)
    .update(':pin:')
    .update(value)
    .digest('hex');
}

function timingSafeEqual(left: string, right: string) {
  return left.length == right.length && left == right;
}

function encryptSecret(value: string) {
  const key = createHash('sha256').update(env.JWT_REFRESH_SECRET).digest();
  const iv = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', key, iv);
  const encrypted = Buffer.concat([cipher.update(value, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return Buffer.concat([iv, tag, encrypted]).toString('base64');
}

function decryptSecret(value: string) {
  const payload = Buffer.from(value, 'base64');
  const iv = payload.subarray(0, 12);
  const tag = payload.subarray(12, 28);
  const encrypted = payload.subarray(28);
  const key = createHash('sha256').update(env.JWT_REFRESH_SECRET).digest();
  const decipher = createDecipheriv('aes-256-gcm', key, iv);
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(encrypted), decipher.final()]).toString('utf8');
}

function generateSessionTokens() {
  return {
    accessToken: randomBytes(24).toString('base64url'),
    refreshToken: randomBytes(32).toString('base64url'),
    accessTokenExpiresAt: new Date(Date.now() + ACCESS_TOKEN_TTL_SECONDS * 1000),
    sessionExpiresAt: new Date(Date.now() + SESSION_TTL_DAYS * 24 * 60 * 60_000),
  };
}

function randomWireGuardKey() {
  return randomBytes(32).toString('base64');
}

function configuredVpnServers(): ConfiguredVpnServer[] {
  const configuredCandidates = SERVER_TEMPLATES.map(
    (template): ConfiguredVpnServer | null => {
      const endpoint = template.endpoint.trim();
      const publicKey = template.publicKey.trim();
      const exitIpAddress = normalizeObservedIp(template.exitIpAddress);

      if (endpoint.length == 0 || publicKey.length == 0 || exitIpAddress == null) {
        return null;
      }

      const endpointParts = parseEndpoint(endpoint);
      if (endpointParts == null) {
        return null;
      }

      return {
        name: template.name,
        regionCode: template.regionCode,
        locationLabel: template.locationLabel,
        hostname: endpointParts.hostname,
        endpoint,
        port: endpointParts.port,
        publicKey,
        exitIpAddress,
        dnsServers: parseDnsServers(template.dnsServers),
        priority: template.priority,
        isPrimary: false,
      };
    },
  );
  const configured = configuredCandidates.filter(
    (server): server is ConfiguredVpnServer => server != null,
  );

  if (configured.length == 0) {
    return [];
  }

  const preferredPrimary = env.VPN_SERVER_DEFAULT_REGION;
  return configured.map((server, index) => ({
    ...server,
    isPrimary:
      configured.some((candidate) => candidate.regionCode == preferredPrimary)
        ? server.regionCode == preferredPrimary
        : index == 0,
  }));
}

function resolveConfiguredServerForRecord(server: {
  name?: string | null;
  regionCode?: string | null;
  endpoint?: string | null;
  publicKey?: string | null;
}) {
  return configuredVpnServers().find(
    (candidate) =>
      candidate.regionCode == server.regionCode ||
      candidate.name == server.name ||
      candidate.endpoint == server.endpoint,
  );
}

function isSelectableServerRecord(server: {
  name?: string | null;
  regionCode?: string | null;
  endpoint?: string | null;
  publicKey?: string | null;
}) {
  return resolveConfiguredServerForRecord(server) != null;
}

function serializeVpnServerRecord(server: {
  id: string;
  name: string;
  regionCode: string;
  hostname: string;
  endpoint: string;
  port: number;
  status: string;
  isPrimary: boolean;
  publicKey: string;
}) {
  const configured = resolveConfiguredServerForRecord(server);
  if (configured == null) {
    return null;
  }

  return {
    id: server.id,
    name: server.name,
    regionCode: server.regionCode,
    locationLabel: configured.locationLabel,
    hostname: server.hostname,
    endpoint: server.endpoint,
    port: server.port,
    status: server.status,
    isPrimary: server.isPrimary,
    selectable: true,
    exitIpAddress: configured.exitIpAddress,
    dnsServers: configured.dnsServers,
  };
}

function parseEndpoint(endpoint: string) {
  const [hostname, portValue] = endpoint.split(':');
  if (hostname == null || hostname.trim().length == 0 || portValue == null) {
    return null;
  }

  const port = Number(portValue);
  if (!Number.isInteger(port) || port <= 0) {
    return null;
  }

  return {
    hostname: hostname.trim(),
    port,
  };
}

function parseDnsServers(rawValue: string) {
  const servers = rawValue
    .split(',')
    .map((value) => value.trim())
    .filter((value) => value.length > 0);

  return servers.length == 0 ? ['1.1.1.1', '1.0.0.1'] : servers;
}

function normalizeObservedIp(value?: string | null) {
  const normalized = value?.trim();
  if (normalized == null || normalized.length == 0) {
    return null;
  }

  return normalized.startsWith('::ffff:') ? normalized.slice(7) : normalized;
}

function parseIsoDate(value?: string | null) {
  if (value == null || value.trim().length == 0) {
    return null;
  }

  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function verifyObservedExitIp(
  server:
    | {
        name?: string | null;
        regionCode?: string | null;
        endpoint?: string | null;
        publicKey?: string | null;
      }
    | null,
  observedIp: string | null,
) {
  const configured = server == null ? null : resolveConfiguredServerForRecord(server);
  if (configured == null) {
    return {
      verified: false,
      errorMessage: 'The selected VPN region is not fully configured.',
    };
  }

  if (observedIp == null) {
    return {
      verified: false,
      errorMessage: 'Unable to verify the tunnel exit IP.',
    };
  }

  if (observedIp != configured.exitIpAddress) {
    return {
      verified: false,
      errorMessage:
        `Traffic is exiting from ${observedIp} instead of ${configured.locationLabel}.`,
    };
  }

  return {
    verified: true,
    errorMessage: null,
  };
}

function buildWireGuardConfig(input: {
  privateKey: string;
  assignedAddress: string;
  dnsServers: string[];
  serverPublicKey: string;
  endpoint: string;
}) {
  return [
    '[Interface]',
    `PrivateKey = ${input.privateKey}`,
    `Address = ${input.assignedAddress}`,
    `DNS = ${input.dnsServers.join(', ')}`,
    'MTU = 1280',
    '',
    '[Peer]',
    `PublicKey = ${input.serverPublicKey}`,
    'AllowedIPs = 0.0.0.0/0, ::/0',
    `Endpoint = ${input.endpoint}`,
    'PersistentKeepalive = 25',
    '',
  ].join('\n');
}

function tunnelNameForDevice(value: string) {
  const sanitized = value.replace(/[^a-zA-Z0-9_=+.-]/g, '').slice(0, 15);
  return sanitized.length == 0 ? 'labguard' : sanitized;
}

function formatLocationLabel(latitude: number, longitude: number) {
  return `${latitude.toFixed(4)}, ${longitude.toFixed(4)}`;
}

function extractCommandMessage(payload: Prisma.JsonValue | null) {
  if (payload == null || typeof payload != 'object' || Array.isArray(payload)) {
    return undefined;
  }

  return typeof payload['message'] == 'string' ? payload['message'] : undefined;
}

function latestCommandResultMessage(command: {
  results: Array<{ errorMessage: string | null }>;
}) {
  return command.results[0]?.errorMessage ?? undefined;
}

function tunnelStateToConnectivityStatus(tunnelState?: string): DeviceConnectivityStatus {
  switch (tunnelState) {
    case 'CONNECTED':
      return 'CONNECTED';
    case 'ERROR':
    case 'CONNECTING':
    case 'AUTH_REQUIRED':
      return 'DEGRADED';
    case 'PROFILE_MISSING':
    case 'DISCONNECTED':
    default:
      return 'DISCONNECTED';
  }
}

function resolveHeartbeatStatus(input: {
  tunnelState?: string;
  verifiedExit: boolean;
}): DeviceConnectivityStatus {
  const baseStatus = tunnelStateToConnectivityStatus(input.tunnelState);
  if (input.tunnelState == 'CONNECTED' && !input.verifiedExit) {
    return 'DEGRADED';
  }

  return baseStatus;
}

function connectivityStatusToTunnelState(status: DeviceConnectivityStatus) {
  switch (status) {
    case 'CONNECTED':
      return 'CONNECTED';
    case 'DEGRADED':
      return 'ERROR';
    case 'UNKNOWN':
    case 'DISCONNECTED':
    default:
      return 'DISCONNECTED';
  }
}

function requireOwner(actor: LabGuardActor) {
  if (actor.role != 'OWNER') {
    throw forbidden('Owner access is required for this operation.');
  }
}

function badRequest(message: string) {
  return Object.assign(new Error(message), { statusCode: 400 });
}

function unauthorized(message: string) {
  return Object.assign(new Error(message), { statusCode: 401 });
}

function forbidden(message: string) {
  return Object.assign(new Error(message), { statusCode: 403 });
}

function notFound(message: string) {
  return Object.assign(new Error(message), { statusCode: 404 });
}
