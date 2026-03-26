import type { LabGuardActor } from '../../common/auth/auth-types.js';
import {
  getAdminOverview,
  issueInvitation,
  listAuditLogs,
} from '../../common/control-plane/control-plane-service.js';

export class AdminService {
  getOverview(actor: LabGuardActor) {
    return getAdminOverview(actor);
  }

  getAuditLogs(actor: LabGuardActor) {
    return listAuditLogs(actor);
  }

  issueInvitation(actor: LabGuardActor) {
    return issueInvitation(actor);
  }
}

export const adminService = new AdminService();
