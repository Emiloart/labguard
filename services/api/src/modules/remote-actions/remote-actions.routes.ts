import type { FastifyPluginAsync } from 'fastify';

import { remoteActionsService } from './remote-actions.service.js';

export const remoteActionsRoutes: FastifyPluginAsync = async (app) => {
  app.post('/:deviceId', async (request) => {
    const params = request.params as { deviceId: string };
    return remoteActionsService.queueCommand(params.deviceId);
  });

  app.get('/:deviceId', async (request) => {
    const params = request.params as { deviceId: string };
    return {
      items: remoteActionsService.listCommands(params.deviceId),
    };
  });

  app.post('/:commandId/result', async (request) => {
    const params = request.params as { commandId: string };
    return remoteActionsService.reportResult(params.commandId);
  });
};
