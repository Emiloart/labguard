export const userRoles = ['OWNER', 'MEMBER'] as const;
export const deviceTrustStates = [
  'TRUSTED',
  'PENDING_APPROVAL',
  'SUSPENDED',
  'REVOKED',
] as const;
export const deviceConnectivityStates = [
  'CONNECTED',
  'DISCONNECTED',
  'DEGRADED',
  'UNKNOWN',
] as const;
export const lostModeStates = ['OFF', 'ACTIVE', 'RECOVERED'] as const;
export const remoteCommandTypes = [
  'SIGN_OUT',
  'REVOKE_VPN',
  'ROTATE_SESSION',
  'WIPE_APP_DATA',
  'RING_ALARM',
  'SHOW_RECOVERY_MESSAGE',
  'MARK_RECOVERED',
  'DISABLE_DEVICE',
] as const;
export const securityEventSeverities = ['INFO', 'WARNING', 'CRITICAL'] as const;

export type UserRole = (typeof userRoles)[number];
export type DeviceTrustState = (typeof deviceTrustStates)[number];
export type DeviceConnectivityState = (typeof deviceConnectivityStates)[number];
export type LostModeState = (typeof lostModeStates)[number];
export type RemoteCommandType = (typeof remoteCommandTypes)[number];
export type SecurityEventSeverity = (typeof securityEventSeverities)[number];
