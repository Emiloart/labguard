import type { FastifyPluginAsync } from 'fastify';

import { requireActor } from '../../common/auth/request-auth.js';
import { dashboardService } from './dashboard.service.js';

export const dashboardRoutes: FastifyPluginAsync = async (app) => {
  app.get('/summary', async (request) => {
    return dashboardService.getSummary(requireActor(request));
  });
};
