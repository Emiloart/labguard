import type { FastifyPluginAsync } from 'fastify';

import { requireActor } from '../../common/auth/request-auth.js';
import { vpnService } from './vpn.service.js';

export const vpnRoutes: FastifyPluginAsync = async (app) => {
  app.get('/servers', async (request) => {
    return {
      items: await vpnService.listServers(requireActor(request)),
    };
  });

  app.get('/profiles/:deviceId', async (request) => {
    const params = request.params as { deviceId: string };
    return vpnService.getProfile(requireActor(request), params.deviceId);
  });

  app.post('/profiles/:deviceId/select-server', async (request) => {
    const params = request.params as { deviceId: string };
    const body = (request.body ?? {}) as Record<string, unknown>;
    const serverId = typeof body['serverId'] == 'string' ? body['serverId'] : '';

    return vpnService.selectServer(requireActor(request), {
      deviceId: params.deviceId,
      serverId,
    });
  });

  app.get('/sessions/:deviceId', async (request) => {
    const params = request.params as { deviceId: string };
    return vpnService.getSession(requireActor(request), params.deviceId);
  });

  app.post('/profiles/:deviceId/rotate', async (request) => {
    const params = request.params as { deviceId: string };
    return vpnService.rotateProfile(requireActor(request), params.deviceId);
  });

  app.post('/profiles/:deviceId/revoke', async (request) => {
    const params = request.params as { deviceId: string };
    return vpnService.revokeProfile(requireActor(request), params.deviceId);
  });

  app.post('/sessions/connect', async (request) => {
    const body = (request.body ?? {}) as Record<string, unknown>;
    const payload = {
      actor: requireActor(request),
      ...(typeof body['deviceId'] == 'string'
        ? { deviceId: body['deviceId'] }
        : {}),
      ...(typeof body['serverId'] == 'string'
        ? { serverId: body['serverId'] }
        : {}),
      ...(typeof body['currentIp'] == 'string'
        ? { currentIp: body['currentIp'] }
        : {}),
      observedIp: request.ip,
      ...(typeof body['lastHandshakeAt'] == 'string'
        ? { lastHandshakeAt: body['lastHandshakeAt'] }
        : {}),
      ...(typeof body['lastError'] == 'string'
        ? { lastError: body['lastError'] }
        : {}),
    };

    return vpnService.connectSession(payload);
  });

  app.post('/sessions/disconnect', async (request) => {
    const body = (request.body ?? {}) as Record<string, unknown>;
    const payload = {
      actor: requireActor(request),
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
      actor: requireActor(request),
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
      observedIp: request.ip,
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
