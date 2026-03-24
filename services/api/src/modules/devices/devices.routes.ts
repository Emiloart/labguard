import type { FastifyPluginAsync } from 'fastify';

import { devicesService } from './devices.service.js';

export const devicesRoutes: FastifyPluginAsync = async (app) => {
  app.get('/', async () => {
    return {
      items: devicesService.listDevices(),
    };
  });

  app.post('/register', async () => {
    return devicesService.registerDevice();
  });

  app.get('/:deviceId', async (request, reply) => {
    const params = request.params as { deviceId: string };
    const device = devicesService.getDevice(params.deviceId);

    if (!device) {
      return reply.code(404).send({
        error: 'Not Found',
        message: 'Device not found.',
        requestId: request.id,
      });
    }

    return device;
  });

  app.patch('/:deviceId', async (request) => {
    const params = request.params as { deviceId: string };
    const body = (request.body ?? {}) as Record<string, unknown>;

    return devicesService.updateDevice(params.deviceId, {
      ...(typeof body['name'] == 'string' ? { name: body['name'] } : {}),
      ...(typeof body['isPrimary'] == 'boolean'
        ? { isPrimary: body['isPrimary'] }
        : {}),
    });
  });

  app.post('/:deviceId/revoke', async (request) => {
    const params = request.params as { deviceId: string };
    return devicesService.revoke(params.deviceId);
  });

  app.post('/:deviceId/suspend', async (request) => {
    const params = request.params as { deviceId: string };
    return devicesService.suspend(params.deviceId);
  });

  app.post('/:deviceId/rotate-credentials', async (request) => {
    const params = request.params as { deviceId: string };
    return devicesService.rotateCredentials(params.deviceId);
  });

  app.post('/:deviceId/lost-mode', async (request) => {
    const params = request.params as { deviceId: string };
    return devicesService.markLostMode(params.deviceId);
  });

  app.post('/:deviceId/recovered', async (request) => {
    const params = request.params as { deviceId: string };
    return devicesService.markRecovered(params.deviceId);
  });

  app.post('/:deviceId/location', async (request) => {
    const params = request.params as { deviceId: string };
    const body = (request.body ?? {}) as Record<string, unknown>;

    return devicesService.recordLocation(params.deviceId, {
      ...(typeof body['lastKnownLocation'] == 'string'
        ? { lastKnownLocation: body['lastKnownLocation'] }
        : {}),
      ...(typeof body['lastKnownNetwork'] == 'string'
        ? { lastKnownNetwork: body['lastKnownNetwork'] }
        : {}),
      ...(typeof body['lastKnownIp'] == 'string'
        ? { lastKnownIp: body['lastKnownIp'] }
        : {}),
    });
  });
};
