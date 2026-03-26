import type { LabGuardActor } from '../../common/auth/auth-types.js';
import {
  getDeviceDetail,
  getDeviceLocationSnapshot,
  type DevicePatchInput,
  listDevices,
  markLostMode,
  markRecovered,
  type LocationPatchInput,
  recordDeviceLocation,
  registerDevice,
  revokeDevice,
  rotateDeviceCredentials,
  suspendDevice,
  updateDevice,
  type DeviceRegistrationInput,
} from '../../common/control-plane/control-plane-service.js';

export class DevicesService {
  listDevices(actor: LabGuardActor) {
    return listDevices(actor);
  }

  getDevice(actor: LabGuardActor, deviceId: string) {
    return getDeviceDetail(actor, deviceId);
  }

  getDeviceLocations(actor: LabGuardActor, deviceId: string) {
    return getDeviceLocationSnapshot(actor, deviceId);
  }

  registerDevice(actor: LabGuardActor, device: Partial<DeviceRegistrationInput>) {
    return registerDevice(actor, device);
  }

  updateDevice(
    actor: LabGuardActor,
    deviceId: string,
    patch: DevicePatchInput,
  ) {
    return updateDevice(actor, deviceId, patch);
  }

  markLostMode(actor: LabGuardActor, deviceId: string) {
    return markLostMode(actor, deviceId);
  }

  markRecovered(actor: LabGuardActor, deviceId: string) {
    return markRecovered(actor, deviceId);
  }

  revoke(actor: LabGuardActor, deviceId: string) {
    return revokeDevice(actor, deviceId);
  }

  suspend(actor: LabGuardActor, deviceId: string) {
    return suspendDevice(actor, deviceId);
  }

  rotateCredentials(actor: LabGuardActor, deviceId: string) {
    return rotateDeviceCredentials(actor, deviceId);
  }

  recordLocation(
    actor: LabGuardActor,
    deviceId: string,
    patch: LocationPatchInput,
  ) {
    return recordDeviceLocation(actor, deviceId, patch);
  }
}

export const devicesService = new DevicesService();
