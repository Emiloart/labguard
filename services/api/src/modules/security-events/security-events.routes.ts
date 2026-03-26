import type { FastifyPluginAsync } from 'fastify';

import { requireActor } from '../../common/auth/request-auth.js';
import { securityEventsService } from './security-events.service.js';

export const securityEventsRoutes: FastifyPluginAsync = async (app) => {
  app.get('/', async (request) => {
    return {
      items: await securityEventsService.listEvents(requireActor(request)),
    };
  });

  app.post('/:eventId/read', async (request) => {
    const params = request.params as { eventId: string };
    return securityEventsService.markRead(requireActor(request), params.eventId);
  });
};
