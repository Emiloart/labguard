import type { LabGuardActor } from '../../common/auth/auth-types.js';
import {
  listRemoteCommands,
  queueRemoteCommand,
  type QueueRemoteCommandInput,
  retryRemoteCommand,
  reportRemoteCommandResult,
  type RemoteCommandResultInput,
} from '../../common/control-plane/control-plane-service.js';

export class RemoteActionsService {
  queueCommand(
    actor: LabGuardActor,
    deviceId: string,
    payload: Partial<QueueRemoteCommandInput>,
  ) {
    return queueRemoteCommand(actor, deviceId, {
      commandType: payload.commandType ?? 'RING_ALARM',
      ...(payload.message == null ? {} : { message: payload.message }),
    });
  }

  listCommands(actor: LabGuardActor, deviceId: string) {
    return listRemoteCommands(actor, deviceId);
  }

  reportResult(
    actor: LabGuardActor,
    commandId: string,
    payload: Partial<RemoteCommandResultInput>,
  ) {
    return reportRemoteCommandResult(actor, commandId, {
      status: payload.status ?? 'SUCCEEDED',
      ...(payload.resultMessage == null
        ? {}
        : { resultMessage: payload.resultMessage }),
      ...(payload.failureCode == null ? {} : { failureCode: payload.failureCode }),
    });
  }

  retryCommand(actor: LabGuardActor, commandId: string) {
    return retryRemoteCommand(actor, commandId);
  }
}

export const remoteActionsService = new RemoteActionsService();
