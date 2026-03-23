import { getDashboardSummary } from '../../common/mock/control-plane-data.js';

export class DashboardService {
  getSummary() {
    return getDashboardSummary();
  }
}

export const dashboardService = new DashboardService();
