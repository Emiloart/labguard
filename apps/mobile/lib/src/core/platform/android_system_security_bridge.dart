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

  Future<AndroidDeviceIdentity?> getDeviceIdentity() async {
    try {
      final values = await _channel.invokeMapMethod<String, dynamic>(
        'getDeviceIdentity',
      );

      if (values == null || values.isEmpty) {
        return null;
      }

      return AndroidDeviceIdentity.fromJson(values);
    } on MissingPluginException {
      return null;
    }
  }

  Future<AndroidLocationSample?> captureLocationSample() async {
    try {
      final values = await _channel.invokeMapMethod<String, dynamic>(
        'captureLocationSample',
      );

      if (values == null || values.isEmpty) {
        return null;
      }

      return AndroidLocationSample.fromJson(values);
    } on MissingPluginException {
      return null;
    }
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

class AndroidDeviceIdentity {
  const AndroidDeviceIdentity({
    required this.name,
    required this.model,
    required this.platform,
    required this.osVersion,
  });

  factory AndroidDeviceIdentity.fromJson(Map<String, dynamic> json) {
    return AndroidDeviceIdentity(
      name: json['name'] as String? ?? 'Android device',
      model: json['model'] as String? ?? 'Android device',
      platform: json['platform'] as String? ?? 'Android',
      osVersion: json['osVersion'] as String? ?? 'Unknown',
    );
  }

  final String name;
  final String model;
  final String platform;
  final String osVersion;
}

class AndroidLocationSample {
  const AndroidLocationSample({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAt,
    required this.label,
    required this.networkLabel,
    required this.provider,
  });

  factory AndroidLocationSample.fromJson(Map<String, dynamic> json) {
    return AndroidLocationSample(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble() ?? 0,
      capturedAt:
          DateTime.tryParse(json['capturedAt'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      label: json['label'] as String? ?? 'Unknown location',
      networkLabel: json['networkLabel'] as String? ?? 'Unknown network',
      provider: json['provider'] as String? ?? 'android',
    );
  }

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime capturedAt;
  final String label;
  final String networkLabel;
  final String provider;

  Map<String, dynamic> toApiJson({required String source}) {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracyMeters': accuracyMeters,
      'lastKnownLocation': label,
      'lastKnownNetwork': networkLabel,
      'source': source,
    };
  }
}
