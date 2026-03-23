import { getAdminOverview } from '../../common/mock/control-plane-data.js';

export class AdminService {
  getOverview() {
    return getAdminOverview();
  }

  getAuditLogs() {
    return [
      {
        id: 'audit-01',
        action: 'DEVICE_MARKED_LOST',
        targetType: 'DEVICE',
        targetId: 'galaxy-s24',
        outcome: 'SUCCESS',
        createdAt: new Date().toISOString(),
      },
      {
        id: 'audit-02',
        action: 'VPN_PROFILE_ROTATED',
        targetType: 'DEVICE',
        targetId: 'pixel-9-pro',
        outcome: 'SUCCESS',
        createdAt: new Date(Date.now() - 1000 * 60 * 24).toISOString(),
      },
    ];
  }

  issueInvitation() {
    return {
      invitationId: 'inv-01',
      status: 'PENDING',
      deliveryMode: 'MANUAL_CODE',
    };
  }
}

export const adminService = new AdminService();
