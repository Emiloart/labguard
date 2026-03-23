import type { FastifyPluginAsync } from 'fastify';

import { securityEventsService } from './security-events.service.js';

export const securityEventsRoutes: FastifyPluginAsync = async (app) => {
  app.get('/', async () => {
    return {
      items: securityEventsService.listEvents(),
    };
  });

  app.post('/:eventId/read', async (request) => {
    const params = request.params as { eventId: string };
    return securityEventsService.markRead(params.eventId);
  });
};
