import type { FastifyPluginAsync } from 'fastify';

import { dashboardService } from './dashboard.service.js';

export const dashboardRoutes: FastifyPluginAsync = async (app) => {
  app.get('/summary', async () => {
    return dashboardService.getSummary();
  });
};
