import type { FastifyPluginAsync } from 'fastify';

import { remoteActionsService } from './remote-actions.service.js';

export const remoteActionsRoutes: FastifyPluginAsync = async (app) => {
  app.post('/:deviceId', async (request) => {
    const params = request.params as { deviceId: string };
    const body = (request.body ?? {}) as Record<string, unknown>;
    const rawCommandType = body['commandType'];
    const commandType:
      | 'SIGN_OUT'
      | 'REVOKE_VPN'
      | 'ROTATE_SESSION'
      | 'WIPE_APP_DATA'
      | 'RING_ALARM'
      | 'SHOW_RECOVERY_MESSAGE'
      | 'MARK_RECOVERED'
      | 'DISABLE_DEVICE_ACCESS'
      | undefined =
      rawCommandType == 'SIGN_OUT' ||
      rawCommandType == 'REVOKE_VPN' ||
      rawCommandType == 'ROTATE_SESSION' ||
      rawCommandType == 'WIPE_APP_DATA' ||
      rawCommandType == 'RING_ALARM' ||
      rawCommandType == 'SHOW_RECOVERY_MESSAGE' ||
      rawCommandType == 'MARK_RECOVERED' ||
      rawCommandType == 'DISABLE_DEVICE_ACCESS'
        ? (rawCommandType as
            | 'SIGN_OUT'
            | 'REVOKE_VPN'
            | 'ROTATE_SESSION'
            | 'WIPE_APP_DATA'
            | 'RING_ALARM'
            | 'SHOW_RECOVERY_MESSAGE'
            | 'MARK_RECOVERED'
            | 'DISABLE_DEVICE_ACCESS')
        : undefined;

    const payload = {
      ...(commandType == null ? {} : { commandType }),
      ...(typeof body['message'] == 'string'
        ? { message: body['message'] }
        : {}),
    };

    return remoteActionsService.queueCommand(params.deviceId, payload);
  });

  app.get('/:deviceId', async (request) => {
    const params = request.params as { deviceId: string };
    return {
      items: remoteActionsService.listCommands(params.deviceId),
    };
  });

  app.post('/:commandId/result', async (request) => {
    const params = request.params as { commandId: string };
    const body = (request.body ?? {}) as Record<string, unknown>;
    const rawStatus = body['status'];
    const status: 'SUCCEEDED' | 'FAILED' | undefined =
      rawStatus == 'SUCCEEDED' || rawStatus == 'FAILED'
        ? (rawStatus as 'SUCCEEDED' | 'FAILED')
        : undefined;

    const payload = {
      ...(status == null ? {} : { status }),
      ...(typeof body['resultMessage'] == 'string'
        ? { resultMessage: body['resultMessage'] }
        : {}),
    };

    return remoteActionsService.reportResult(params.commandId, payload);
  });
};
