import 'package:flutter_test/flutter_test.dart';
import 'package:labguard/src/core/platform/android_system_security_bridge.dart';

void main() {
  group('DeviceSecurityPosture', () {
    test('parses a supported Android posture payload', () {
      final posture = DeviceSecurityPosture.fromJson(const {
        'supported': true,
        'sdkInt': 35,
        'notificationsEnabled': false,
        'postNotificationsRuntimePermissionRequired': true,
        'locationPermissionStatus': 'granted_approximate',
        'batteryOptimizationIgnored': false,
      });

      expect(posture.supported, isTrue);
      expect(posture.sdkInt, 35);
      expect(posture.notificationsEnabled, isFalse);
      expect(posture.postNotificationsRuntimePermissionRequired, isTrue);
      expect(posture.locationPermissionStatus, 'granted_approximate');
      expect(posture.batteryOptimizationIgnored, isFalse);
    });

    test('treats an empty payload as unsupported', () {
      final posture = DeviceSecurityPosture.fromJson(const {});

      expect(posture.supported, isFalse);
      expect(posture.sdkInt, 0);
      expect(posture.locationPermissionStatus, 'unsupported');
    });
  });
}
