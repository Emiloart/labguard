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

  app.get('/sessions/:deviceId', async (request) => {
    const params = request.params as { deviceId: string };
    return vpnService.getSession(params.deviceId);
  });

  app.post('/profiles/:deviceId/rotate', async (request) => {
    const params = request.params as { deviceId: string };
    return vpnService.rotateProfile(params.deviceId);
  });

  app.post('/profiles/:deviceId/revoke', async (request) => {
    const params = request.params as { deviceId: string };
    return vpnService.revokeProfile(params.deviceId);
  });

  app.post('/sessions/connect', async (request) => {
    const body = (request.body ?? {}) as Record<string, unknown>;
    const payload = {
      ...(typeof body['deviceId'] == 'string'
        ? { deviceId: body['deviceId'] }
        : {}),
      ...(typeof body['serverId'] == 'string'
        ? { serverId: body['serverId'] }
        : {}),
      ...(typeof body['currentIp'] == 'string'
        ? { currentIp: body['currentIp'] }
        : {}),
    };

    return vpnService.connectSession(payload);
  });

  app.post('/sessions/disconnect', async (request) => {
    const body = (request.body ?? {}) as Record<string, unknown>;
    const payload = {
      ...(typeof body['deviceId'] == 'string'
        ? { deviceId: body['deviceId'] }
        : {}),
      ...(typeof body['reason'] == 'string' ? { reason: body['reason'] } : {}),
    };

    return vpnService.disconnectSession(payload);
  });

  app.post('/sessions/heartbeat', async (request) => {
    const body = (request.body ?? {}) as Record<string, unknown>;
    const payload = {
      ...(typeof body['deviceId'] == 'string'
        ? { deviceId: body['deviceId'] }
        : {}),
      ...(typeof body['serverId'] == 'string'
        ? { serverId: body['serverId'] }
        : {}),
      ...(typeof body['tunnelState'] == 'string'
        ? { tunnelState: body['tunnelState'] }
        : {}),
      ...(typeof body['currentIp'] == 'string'
        ? { currentIp: body['currentIp'] }
        : {}),
      ...(typeof body['bytesReceived'] == 'number'
        ? { bytesReceived: body['bytesReceived'] }
        : {}),
      ...(typeof body['bytesSent'] == 'number'
        ? { bytesSent: body['bytesSent'] }
        : {}),
      ...(typeof body['lastHandshakeAt'] == 'string'
        ? { lastHandshakeAt: body['lastHandshakeAt'] }
        : {}),
      ...(typeof body['lastError'] == 'string'
        ? { lastError: body['lastError'] }
        : {}),
    };

    return vpnService.recordHeartbeat(payload);
  });
};
