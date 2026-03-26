import type { FastifyPluginAsync } from 'fastify';

import { requireActor } from '../../common/auth/request-auth.js';
import { devicesService } from './devices.service.js';

export const devicesRoutes: FastifyPluginAsync = async (app) => {
  app.get('/', async (request) => {
    return {
      items: await devicesService.listDevices(requireActor(request)),
    };
  });

  app.post('/register', async (request) => {
    const body = (request.body ?? {}) as Record<string, unknown>;

    return devicesService.registerDevice(requireActor(request), {
      ...(typeof body['clientId'] == 'string' ? { clientId: body['clientId'] } : {}),
      ...(typeof body['name'] == 'string' ? { name: body['name'] } : {}),
      ...(typeof body['model'] == 'string' ? { model: body['model'] } : {}),
      ...(typeof body['platform'] == 'string' ? { platform: body['platform'] } : {}),
      ...(typeof body['osVersion'] == 'string' ? { osVersion: body['osVersion'] } : {}),
      ...(typeof body['appVersion'] == 'string' ? { appVersion: body['appVersion'] } : {}),
    });
  });

  app.get('/:deviceId', async (request) => {
    const params = request.params as { deviceId: string };
    return devicesService.getDevice(requireActor(request), params.deviceId);
  });

  app.get('/:deviceId/locations', async (request) => {
    const params = request.params as { deviceId: string };
    return devicesService.getDeviceLocations(requireActor(request), params.deviceId);
  });

  app.patch('/:deviceId', async (request) => {
    const params = request.params as { deviceId: string };
    const body = (request.body ?? {}) as Record<string, unknown>;

    return devicesService.updateDevice(requireActor(request), params.deviceId, {
      ...(typeof body['name'] == 'string' ? { name: body['name'] } : {}),
      ...(typeof body['isPrimary'] == 'boolean'
        ? { isPrimary: body['isPrimary'] }
        : {}),
    });
  });

  app.post('/:deviceId/revoke', async (request) => {
    const params = request.params as { deviceId: string };
    return devicesService.revoke(requireActor(request), params.deviceId);
  });

  app.post('/:deviceId/suspend', async (request) => {
    const params = request.params as { deviceId: string };
    return devicesService.suspend(requireActor(request), params.deviceId);
  });

  app.post('/:deviceId/rotate-credentials', async (request) => {
    const params = request.params as { deviceId: string };
    return devicesService.rotateCredentials(requireActor(request), params.deviceId);
  });

  app.post('/:deviceId/lost-mode', async (request) => {
    const params = request.params as { deviceId: string };
    return devicesService.markLostMode(requireActor(request), params.deviceId);
  });

  app.post('/:deviceId/recovered', async (request) => {
    const params = request.params as { deviceId: string };
    return devicesService.markRecovered(requireActor(request), params.deviceId);
  });

  app.post('/:deviceId/location', async (request) => {
    const params = request.params as { deviceId: string };
    const body = (request.body ?? {}) as Record<string, unknown>;

    return devicesService.recordLocation(requireActor(request), params.deviceId, {
      ...(typeof body['lastKnownLocation'] == 'string'
        ? { lastKnownLocation: body['lastKnownLocation'] }
        : {}),
      ...(typeof body['lastKnownNetwork'] == 'string'
        ? { lastKnownNetwork: body['lastKnownNetwork'] }
        : {}),
      ...(typeof body['lastKnownIp'] == 'string'
        ? { lastKnownIp: body['lastKnownIp'] }
        : {}),
      ...(typeof body['latitude'] == 'number' ? { latitude: body['latitude'] } : {}),
      ...(typeof body['longitude'] == 'number'
        ? { longitude: body['longitude'] }
        : {}),
      ...(typeof body['accuracyMeters'] == 'number'
        ? { accuracyMeters: body['accuracyMeters'] }
        : {}),
      ...(typeof body['source'] == 'string' ? { source: body['source'] } : {}),
    });
  });
};
