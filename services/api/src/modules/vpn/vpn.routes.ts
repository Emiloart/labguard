import type { FastifyPluginAsync } from 'fastify';

import { vpnService } from './vpn.service.js';

export const vpnRoutes: FastifyPluginAsync = async (app) => {
  app.get('/servers', async () => {
    return {
      items: vpnService.listServers(),
    };
  });

  app.get('/profiles/:deviceId', async (request) => {
    const params = request.params as { deviceId: string };
    return vpnService.getProfile(params.deviceId);
  });

  app.post('/profiles/:deviceId/rotate', async (request) => {
    const params = request.params as { deviceId: string };
    return vpnService.rotateProfile(params.deviceId);
  });

  app.post('/profiles/:deviceId/revoke', async (request) => {
    const params = request.params as { deviceId: string };
    return vpnService.revokeProfile(params.deviceId);
  });

  app.post('/sessions/heartbeat', async () => {
    return vpnService.recordHeartbeat();
  });
};
