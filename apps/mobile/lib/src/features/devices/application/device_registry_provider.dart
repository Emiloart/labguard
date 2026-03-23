import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/device_record.dart';

final deviceRegistryProvider = Provider<List<DeviceRecord>>((ref) {
  final now = DateTime.now();

  return [
    DeviceRecord(
      id: 'pixel-9-pro',
      name: 'Primary Pixel',
      model: 'Google Pixel 9 Pro',
      platform: 'Android 15',
      appVersion: '0.1.0',
      lastActiveAt: now.subtract(const Duration(minutes: 3)),
      vpnStatus: DeviceConnectivityStatus.connected,
      batteryLevel: 82,
      lastKnownIp: '41.214.91.17',
      lastKnownNetwork: 'Emilo Labs Secure Wi-Fi',
      lastKnownLocation: 'Casablanca, MA',
      locationCapturedAt: now.subtract(const Duration(minutes: 4)),
      trustState: DeviceTrustState.trusted,
      isLost: false,
      isPrimary: true,
    ),
    DeviceRecord(
      id: 'galaxy-s24',
      name: 'Travel Device',
      model: 'Samsung Galaxy S24',
      platform: 'Android 14',
      appVersion: '0.1.0',
      lastActiveAt: now.subtract(const Duration(minutes: 27)),
      vpnStatus: DeviceConnectivityStatus.degraded,
      batteryLevel: 46,
      lastKnownIp: '102.64.220.9',
      lastKnownNetwork: 'LTE',
      lastKnownLocation: 'Rabat, MA',
      locationCapturedAt: now.subtract(const Duration(minutes: 18)),
      trustState: DeviceTrustState.trusted,
      isLost: true,
      isPrimary: false,
    ),
    DeviceRecord(
      id: 'owner-tablet',
      name: 'Owner Tablet',
      model: 'Lenovo Tab P12',
      platform: 'Android 14',
      appVersion: '0.1.0',
      lastActiveAt: now.subtract(const Duration(hours: 4)),
      vpnStatus: DeviceConnectivityStatus.disconnected,
      batteryLevel: 64,
      lastKnownIp: '41.248.2.22',
      lastKnownNetwork: 'Home Fiber',
      lastKnownLocation: 'Last update withheld',
      locationCapturedAt: now.subtract(const Duration(hours: 5)),
      trustState: DeviceTrustState.pendingApproval,
      isLost: false,
      isPrimary: false,
    ),
  ];
});

final deviceByIdProvider = Provider.family<DeviceRecord?, String>((
  ref,
  deviceId,
) {
  for (final device in ref.watch(deviceRegistryProvider)) {
    if (device.id == deviceId) {
      return device;
    }
  }

  return null;
});
