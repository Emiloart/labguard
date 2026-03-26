import type { FastifyPluginAsync } from 'fastify';

import { requireActor } from '../../common/auth/request-auth.js';
import {
  type PreferencesPatch,
  preferencesService,
} from './preferences.service.js';

export const preferencesRoutes: FastifyPluginAsync = async (app) => {
  app.get('/me', async (request) => {
    return preferencesService.getPreferences(requireActor(request));
  });

  app.patch('/me', async (request) => {
    const body = (request.body ?? {}) as Record<string, unknown>;
    const telemetryLevel =
      typeof body['telemetryLevel'] == 'string'
        ? body['telemetryLevel']
        : undefined;
    const locationPermissionStatus =
      typeof body['locationPermissionStatus'] == 'string'
        ? body['locationPermissionStatus']
        : undefined;
    const patch: PreferencesPatch = {};

    if (typeof body['biometricEnabled'] == 'boolean') {
      patch['biometricEnabled'] = body['biometricEnabled'];
    }

    if (typeof body['pinLockEnabled'] == 'boolean') {
      patch['pinLockEnabled'] = body['pinLockEnabled'];
    }

    if (typeof body['autoConnectEnabled'] == 'boolean') {
      patch['autoConnectEnabled'] = body['autoConnectEnabled'];
    }

    if (typeof body['killSwitchEnabled'] == 'boolean') {
      patch['killSwitchEnabled'] = body['killSwitchEnabled'];
    }

    if (typeof body['notificationsEnabled'] == 'boolean') {
      patch['notificationsEnabled'] = body['notificationsEnabled'];
    }

    if (
      telemetryLevel == 'minimal' ||
      telemetryLevel == 'elevated_lost_mode_only'
    ) {
      patch['telemetryLevel'] = telemetryLevel;
    }

    if (
      locationPermissionStatus == 'not_requested' ||
      locationPermissionStatus == 'granted_when_in_use'
    ) {
      patch['locationPermissionStatus'] = locationPermissionStatus;
    }

    if (typeof body['batteryOptimizationAcknowledged'] == 'boolean') {
      patch['batteryOptimizationAcknowledged'] =
        body['batteryOptimizationAcknowledged'];
    }

    if (typeof body['appPin'] == 'string' || body['appPin'] == null) {
      patch['appPin'] = body['appPin'] as string | null;
    }

    return preferencesService.updatePreferences(requireActor(request), patch);
  });

  app.post('/me/verify-pin', async (request) => {
    const body = (request.body ?? {}) as Record<string, unknown>;
    return preferencesService.verifyAppPin(
      requireActor(request),
      typeof body['pin'] == 'string' ? body['pin'] : undefined,
    );
  });
};
