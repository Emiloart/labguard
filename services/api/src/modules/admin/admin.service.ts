import {
  getAdminOverview,
  listAuditLogs,
  recordAuditLogEntry,
} from '../../common/mock/control-plane-data.js';

export class AdminService {
  getOverview() {
    return getAdminOverview();
  }

  getAuditLogs() {
    return listAuditLogs();
  }

  issueInvitation() {
    recordAuditLogEntry({
      action: 'INVITATION_ISSUED',
      targetType: 'AUTH',
      targetId: 'invitation-manual-code',
      summary: 'A new trusted invitation code was issued.',
    });
    return {
      invitationId: 'inv-01',
      status: 'PENDING',
      deliveryMode: 'MANUAL_CODE',
    };
  }
}

export const adminService = new AdminService();
