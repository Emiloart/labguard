import {
  getVpnProfileSummary,
  getVpnSessionSnapshot,
  getVpnServers,
  recordVpnHeartbeat,
  recordVpnSessionConnect,
  recordVpnSessionDisconnect,
  revokeVpnProfile,
  rotateVpnProfile,
} from '../../common/mock/control-plane-data.js';

export class VpnService {
  listServers() {
    return getVpnServers();
  }

  getProfile(deviceId: string) {
    return getVpnProfileSummary(deviceId);
  }

  getSession(deviceId: string) {
    return getVpnSessionSnapshot(deviceId);
  }

  rotateProfile(deviceId: string) {
    return rotateVpnProfile(deviceId);
  }

  revokeProfile(deviceId: string) {
    return revokeVpnProfile(deviceId);
  }

  connectSession(payload: {
    deviceId?: string;
    serverId?: string;
    currentIp?: string;
  }) {
    return recordVpnSessionConnect(payload);
  }

  disconnectSession(payload: { deviceId?: string; reason?: string }) {
    return recordVpnSessionDisconnect(payload);
  }

  recordHeartbeat(payload: {
    deviceId?: string;
    serverId?: string;
    tunnelState?: string;
    currentIp?: string;
    bytesReceived?: number;
    bytesSent?: number;
    lastHandshakeAt?: string;
    lastError?: string;
  }) {
    return recordVpnHeartbeat(payload);
  }
}

export const vpnService = new VpnService();
