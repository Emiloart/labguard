import type { LabGuardActor } from '../../common/auth/auth-types.js';
import { getDashboardSummary } from '../../common/control-plane/control-plane-service.js';

export class DashboardService {
  getSummary(actor: LabGuardActor) {
    return getDashboardSummary(actor);
  }
}

export const dashboardService = new DashboardService();
