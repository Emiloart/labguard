import {
  getDeviceById,
  listDevices,
} from '../../common/mock/control-plane-data.js';

export class DevicesService {
  listDevices() {
    return listDevices();
  }

  getDevice(deviceId: string) {
    const device = getDeviceById(deviceId);

    if (!device) {
      return null;
    }

    return {
      ...device,
      lostModeStatus: device.isLost ? 'ACTIVE' : 'OFF',
      remoteActionsAvailable: [
        'SIGN_OUT',
        'REVOKE_VPN',
        'ROTATE_SESSION',
        'RING_ALARM',
        'SHOW_RECOVERY_MESSAGE',
      ],
      securityHistory: [
        {
          id: 'history-01',
          title: 'VPN profile rotated',
          occurredAt: device.locationCapturedAt,
        },
        {
          id: 'history-02',
          title: device.isLost
              ? 'Lost mode enabled'
              : 'Device registered and trusted',
          occurredAt: device.lastActiveAt,
        },
      ],
    };
  }

  registerDevice() {
    return {
      deviceId: 'pending-device-id',
      approvalState: 'PENDING_APPROVAL',
      vpnProfileIssued: false,
    };
  }

  updateDevice(deviceId: string) {
    return {
      deviceId,
      updated: true,
    };
  }

  markLostMode(deviceId: string) {
    return {
      deviceId,
      lostModeStatus: 'ACTIVE',
      telemetryElevated: true,
    };
  }

  markRecovered(deviceId: string) {
    return {
      deviceId,
      lostModeStatus: 'RECOVERED',
      telemetryElevated: false,
    };
  }

  revoke(deviceId: string) {
    return {
      deviceId,
      trustState: 'REVOKED',
      vpnAccessActive: false,
    };
  }

  suspend(deviceId: string) {
    return {
      deviceId,
      trustState: 'SUSPENDED',
    };
  }

  rotateCredentials(deviceId: string) {
    return {
      deviceId,
      rotatedAt: new Date().toISOString(),
    };
  }

  recordLocation(deviceId: string) {
    return {
      deviceId,
      accepted: true,
      recordedAt: new Date().toISOString(),
    };
  }
}

export const devicesService = new DevicesService();
