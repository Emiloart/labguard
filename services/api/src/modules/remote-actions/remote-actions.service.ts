export class RemoteActionsService {
  queueCommand(deviceId: string) {
    return {
      commandId: 'cmd-01',
      deviceId,
      status: 'QUEUED',
      commandType: 'RING_ALARM',
      queuedAt: new Date().toISOString(),
    };
  }

  listCommands(deviceId: string) {
    return [
      {
        commandId: 'cmd-01',
        deviceId,
        status: 'SUCCEEDED',
        commandType: 'SHOW_RECOVERY_MESSAGE',
        completedAt: new Date(Date.now() - 1000 * 60 * 6).toISOString(),
      },
      {
        commandId: 'cmd-02',
        deviceId,
        status: 'QUEUED',
        commandType: 'RING_ALARM',
        queuedAt: new Date().toISOString(),
      },
    ];
  }

  reportResult(commandId: string) {
    return {
      commandId,
      accepted: true,
      recordedAt: new Date().toISOString(),
    };
  }
}

export const remoteActionsService = new RemoteActionsService();
