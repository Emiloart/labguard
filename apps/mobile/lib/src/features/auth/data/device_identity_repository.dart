import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_environment.dart';
import '../../../core/platform/android_system_security_bridge.dart';
import '../../../core/security/secure_store.dart';

final deviceIdentityRepositoryProvider = Provider<DeviceIdentityRepository>((
  ref,
) {
  return DeviceIdentityRepository(
    secureStore: ref.watch(secureStoreProvider),
    systemBridge: ref.watch(androidSystemSecurityBridgeProvider),
  );
});

class DeviceIdentityRepository {
  DeviceIdentityRepository({
    required SecureStore secureStore,
    required AndroidSystemSecurityBridge systemBridge,
  }) : _secureStore = secureStore,
       _systemBridge = systemBridge;

  final SecureStore _secureStore;
  final AndroidSystemSecurityBridge _systemBridge;

  static const _clientIdKey = 'labguard.device.client_id';

  Future<DeviceIdentityPayload> readCurrentDevice() async {
    final clientId = await _readOrCreateClientId();
    final identity = await _systemBridge.getDeviceIdentity();
    final fallbackName = Platform.isAndroid
        ? 'Android device'
        : 'Trusted device';
    final fallbackModel = Platform.isAndroid
        ? 'Android device'
        : Platform.operatingSystem;

    return DeviceIdentityPayload(
      clientId: clientId,
      name: identity?.name ?? fallbackName,
      model: identity?.model ?? fallbackModel,
      platform: identity?.platform ?? _platformLabel(),
      osVersion: identity?.osVersion ?? Platform.operatingSystemVersion,
      appVersion: AppEnvironment.appVersion,
    );
  }

  Future<String> _readOrCreateClientId() async {
    final existing = await _secureStore.read(_clientIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final created = 'client-${_randomHex(16)}';
    await _secureStore.write(key: _clientIdKey, value: created);
    return created;
  }

  String _platformLabel() {
    if (Platform.isAndroid) {
      return 'Android';
    }
    if (Platform.isIOS) {
      return 'iOS';
    }
    return Platform.operatingSystem;
  }

  String _randomHex(int length) {
    const alphabet = '0123456789abcdef';
    final random = Random.secure();
    final buffer = StringBuffer();

    for (var index = 0; index < length; index++) {
      buffer.write(alphabet[random.nextInt(alphabet.length)]);
    }

    return buffer.toString();
  }
}

class DeviceIdentityPayload {
  const DeviceIdentityPayload({
    required this.clientId,
    required this.name,
    required this.model,
    required this.platform,
    required this.osVersion,
    required this.appVersion,
  });

  final String clientId;
  final String name;
  final String model;
  final String platform;
  final String osVersion;
  final String appVersion;

  Map<String, dynamic> toJson() {
    return {
      'clientId': clientId,
      'name': name,
      'model': model,
      'platform': platform,
      'osVersion': osVersion,
      'appVersion': appVersion,
    };
  }
}
