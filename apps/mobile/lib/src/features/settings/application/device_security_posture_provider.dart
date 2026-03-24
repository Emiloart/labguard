import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/android_system_security_bridge.dart';

final deviceSecurityPostureRepositoryProvider =
    Provider<DeviceSecurityPostureRepository>((ref) {
      return DeviceSecurityPostureRepository(
        bridge: ref.watch(androidSystemSecurityBridgeProvider),
      );
    });

final deviceSecurityPostureProvider = FutureProvider<DeviceSecurityPosture>((
  ref,
) async {
  return ref
      .watch(deviceSecurityPostureRepositoryProvider)
      .getSecurityPosture();
});

final deviceSecurityPostureControllerProvider =
    Provider<DeviceSecurityPostureController>((ref) {
      return DeviceSecurityPostureController(ref);
    });

class DeviceSecurityPostureRepository {
  DeviceSecurityPostureRepository({required AndroidSystemSecurityBridge bridge})
    : _bridge = bridge;

  final AndroidSystemSecurityBridge _bridge;

  Future<DeviceSecurityPosture> getSecurityPosture() {
    return _bridge.getSecurityPosture();
  }

  Future<DeviceSecurityPosture> requestNotificationPermission() {
    return _bridge.requestNotificationPermission();
  }

  Future<DeviceSecurityPosture> requestLocationPermission() {
    return _bridge.requestLocationPermission();
  }

  Future<void> openNotificationSettings() {
    return _bridge.openNotificationSettings();
  }

  Future<void> openBatteryOptimizationSettings() {
    return _bridge.openBatteryOptimizationSettings();
  }

  Future<void> openApplicationSettings() {
    return _bridge.openApplicationSettings();
  }
}

class DeviceSecurityPostureController {
  DeviceSecurityPostureController(this._ref);

  final Ref _ref;

  Future<void> openNotificationSettings() async {
    await _ref
        .read(deviceSecurityPostureRepositoryProvider)
        .openNotificationSettings();
  }

  Future<DeviceSecurityPosture> requestNotificationPermission() async {
    final posture = await _ref
        .read(deviceSecurityPostureRepositoryProvider)
        .requestNotificationPermission();
    refresh();
    return posture;
  }

  Future<DeviceSecurityPosture> requestLocationPermission() async {
    final posture = await _ref
        .read(deviceSecurityPostureRepositoryProvider)
        .requestLocationPermission();
    refresh();
    return posture;
  }

  Future<void> openBatteryOptimizationSettings() async {
    await _ref
        .read(deviceSecurityPostureRepositoryProvider)
        .openBatteryOptimizationSettings();
  }

  Future<void> openApplicationSettings() async {
    await _ref
        .read(deviceSecurityPostureRepositoryProvider)
        .openApplicationSettings();
  }

  void refresh() {
    _ref.invalidate(deviceSecurityPostureProvider);
  }
}
