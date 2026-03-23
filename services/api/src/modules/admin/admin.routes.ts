import type { FastifyPluginAsync } from 'fastify';

import { adminService } from './admin.service.js';

export const adminRoutes: FastifyPluginAsync = async (app) => {
  app.get('/overview', async () => {
    return adminService.getOverview();
  });

  app.get('/audit-logs', async () => {
    return {
      items: adminService.getAuditLogs(),
    };
  });

  app.post('/invitations', async () => {
    return adminService.issueInvitation();
  });
};
