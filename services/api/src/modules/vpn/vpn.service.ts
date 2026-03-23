import {
  getVpnProfileSummary,
  getVpnServers,
} from '../../common/mock/control-plane-data.js';

export class VpnService {
  listServers() {
    return getVpnServers();
  }

  getProfile(deviceId: string) {
    return getVpnProfileSummary(deviceId);
  }

  rotateProfile(deviceId: string) {
    return {
      deviceId,
      rotatedAt: new Date().toISOString(),
    };
  }

  revokeProfile(deviceId: string) {
    return {
      deviceId,
      revokedAt: new Date().toISOString(),
    };
  }

  recordHeartbeat() {
    return {
      accepted: true,
      syncedAt: new Date().toISOString(),
    };
  }
}

export const vpnService = new VpnService();
