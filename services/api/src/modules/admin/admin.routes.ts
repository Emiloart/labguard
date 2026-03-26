import type { FastifyPluginAsync } from 'fastify';

import { requireActor } from '../../common/auth/request-auth.js';
import { adminService } from './admin.service.js';

export const adminRoutes: FastifyPluginAsync = async (app) => {
  app.get('/overview', async (request) => {
    return adminService.getOverview(requireActor(request));
  });

  app.get('/audit-logs', async (request) => {
    return {
      items: await adminService.getAuditLogs(requireActor(request)),
    };
  });

  app.post('/invitations', async (request) => {
    return adminService.issueInvitation(requireActor(request));
  });
};
