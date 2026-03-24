import {
  getDeviceDetail,
  getDeviceLocationSnapshot,
  listDevices,
  markDeviceLostMode,
  markDeviceRecovered,
  recordDeviceLocation,
  revokeDeviceAccess,
  rotateDeviceCredentials,
  suspendDevice,
  updateDeviceMetadata,
} from '../../common/mock/control-plane-data.js';

export class DevicesService {
  listDevices() {
    return listDevices();
  }

  getDevice(deviceId: string) {
    return getDeviceDetail(deviceId);
  }

  getDeviceLocations(deviceId: string) {
    return getDeviceLocationSnapshot(deviceId);
  }

  registerDevice() {
    return {
      deviceId: 'pending-device-id',
      approvalState: 'PENDING_APPROVAL',
      vpnProfileIssued: false,
    };
  }

  updateDevice(
    deviceId: string,
    patch: Partial<{ name: string; isPrimary: boolean }>,
  ) {
    return updateDeviceMetadata(deviceId, patch);
  }

  markLostMode(deviceId: string) {
    return markDeviceLostMode(deviceId);
  }

  markRecovered(deviceId: string) {
    return markDeviceRecovered(deviceId);
  }

  revoke(deviceId: string) {
    return revokeDeviceAccess(deviceId);
  }

  suspend(deviceId: string) {
    return suspendDevice(deviceId);
  }

  rotateCredentials(deviceId: string) {
    return rotateDeviceCredentials(deviceId);
  }

  recordLocation(
    deviceId: string,
    patch: Partial<{
      lastKnownLocation: string;
      lastKnownNetwork: string;
      lastKnownIp: string;
      latitude: number;
      longitude: number;
      accuracyMeters: number;
    }>,
  ) {
    return recordDeviceLocation(deviceId, patch);
  }
}

export const devicesService = new DevicesService();
