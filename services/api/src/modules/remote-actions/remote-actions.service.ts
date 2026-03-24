import {
  listRemoteCommands,
  queueRemoteCommand,
  reportRemoteCommandResult,
} from '../../common/mock/control-plane-data.js';

export class RemoteActionsService {
  queueCommand(
    deviceId: string,
    payload: Partial<{
      commandType:
        | 'SIGN_OUT'
        | 'REVOKE_VPN'
        | 'ROTATE_SESSION'
        | 'WIPE_APP_DATA'
        | 'RING_ALARM'
        | 'SHOW_RECOVERY_MESSAGE'
        | 'MARK_RECOVERED'
        | 'DISABLE_DEVICE_ACCESS';
      message: string;
    }>,
  ) {
    return queueRemoteCommand({
      deviceId,
      commandType: payload.commandType ?? 'RING_ALARM',
      ...(payload.message == null ? {} : { message: payload.message }),
    });
  }

  listCommands(deviceId: string) {
    return listRemoteCommands(deviceId);
  }

  reportResult(
    commandId: string,
    payload: Partial<{ status: 'SUCCEEDED' | 'FAILED'; resultMessage: string }>,
  ) {
    return reportRemoteCommandResult(commandId, payload);
  }
}

export const remoteActionsService = new RemoteActionsService();
