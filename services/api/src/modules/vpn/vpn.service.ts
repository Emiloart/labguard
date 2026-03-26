import type { LabGuardActor } from '../../common/auth/auth-types.js';
import {
  connectVpnSession,
  getVpnProfile,
  getVpnSession,
  listVpnServers,
  recordVpnHeartbeat,
  revokeVpnProfile,
  rotateVpnProfile,
  disconnectVpnSession,
} from '../../common/control-plane/control-plane-service.js';

export class VpnService {
  listServers(actor: LabGuardActor) {
    return listVpnServers(actor);
  }

  getProfile(actor: LabGuardActor, deviceId: string) {
    return getVpnProfile(actor, deviceId);
  }

  getSession(actor: LabGuardActor, deviceId: string) {
    return getVpnSession(actor, deviceId);
  }

  rotateProfile(actor: LabGuardActor, deviceId: string) {
    return rotateVpnProfile(actor, deviceId);
  }

  revokeProfile(actor: LabGuardActor, deviceId: string) {
    return revokeVpnProfile(actor, deviceId);
  }

  connectSession(payload: {
    actor: LabGuardActor;
    deviceId?: string;
    serverId?: string;
    currentIp?: string;
  }) {
    return connectVpnSession(payload.actor, payload);
  }

  disconnectSession(payload: {
    actor: LabGuardActor;
    deviceId?: string;
    reason?: string;
  }) {
    return disconnectVpnSession(payload.actor, payload);
  }

  recordHeartbeat(payload: {
    actor: LabGuardActor;
    deviceId?: string;
    serverId?: string;
    tunnelState?: string;
    currentIp?: string;
    bytesReceived?: number;
    bytesSent?: number;
    lastHandshakeAt?: string;
    lastError?: string;
  }) {
    return recordVpnHeartbeat(payload.actor, payload);
  }
}

export const vpnService = new VpnService();
