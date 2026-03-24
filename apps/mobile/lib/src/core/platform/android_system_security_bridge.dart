import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final androidSystemSecurityBridgeProvider =
    Provider<AndroidSystemSecurityBridge>((ref) {
      return const AndroidSystemSecurityBridge();
    });

class AndroidSystemSecurityBridge {
  const AndroidSystemSecurityBridge();

  static const MethodChannel _channel = MethodChannel(
    'com.emilolabs.labguard/system',
  );

  Future<DeviceSecurityPosture> getSecurityPosture() async {
    return _requestPosture('getSecurityPosture');
  }

  Future<DeviceSecurityPosture> requestNotificationPermission() async {
    return _requestPosture('requestNotificationPermission');
  }

  Future<DeviceSecurityPosture> requestLocationPermission() async {
    return _requestPosture('requestLocationPermission');
  }

  Future<DeviceSecurityPosture> _requestPosture(String method) async {
    try {
      final values = await _channel.invokeMapMethod<String, dynamic>(method);
      return DeviceSecurityPosture.fromJson(values ?? const {});
    } on MissingPluginException {
      return const DeviceSecurityPosture.unsupported();
    }
  }

  Future<void> openNotificationSettings() async {
    await _invoke('openNotificationSettings');
  }

  Future<void> openBatteryOptimizationSettings() async {
    await _invoke('openBatteryOptimizationSettings');
  }

  Future<void> openApplicationSettings() async {
    await _invoke('openApplicationSettings');
  }

  Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // Android-only bridge is unavailable in tests and future iOS builds.
    }
  }
}

class DeviceSecurityPosture {
  const DeviceSecurityPosture({
    required this.sdkInt,
    required this.notificationsEnabled,
    required this.postNotificationsRuntimePermissionRequired,
    required this.locationPermissionStatus,
    required this.batteryOptimizationIgnored,
    required this.supported,
  });

  const DeviceSecurityPosture.unsupported()
    : sdkInt = 0,
      notificationsEnabled = true,
      postNotificationsRuntimePermissionRequired = false,
      locationPermissionStatus = 'unsupported',
      batteryOptimizationIgnored = true,
      supported = false;

  factory DeviceSecurityPosture.fromJson(Map<String, dynamic> json) {
    return DeviceSecurityPosture(
      sdkInt: json['sdkInt'] as int? ?? 0,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      postNotificationsRuntimePermissionRequired:
          json['postNotificationsRuntimePermissionRequired'] as bool? ?? false,
      locationPermissionStatus:
          json['locationPermissionStatus'] as String? ?? 'unsupported',
      batteryOptimizationIgnored:
          json['batteryOptimizationIgnored'] as bool? ?? true,
      supported: json['supported'] as bool? ?? json.isNotEmpty,
    );
  }

  final int sdkInt;
  final bool notificationsEnabled;
  final bool postNotificationsRuntimePermissionRequired;
  final String locationPermissionStatus;
  final bool batteryOptimizationIgnored;
  final bool supported;
}
