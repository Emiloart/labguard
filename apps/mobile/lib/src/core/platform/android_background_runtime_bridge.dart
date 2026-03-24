import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final androidBackgroundRuntimeBridgeProvider =
    Provider<AndroidBackgroundRuntimeBridge>((ref) {
      return const AndroidBackgroundRuntimeBridge();
    });

class AndroidBackgroundRuntimeBridge {
  const AndroidBackgroundRuntimeBridge();

  static const MethodChannel _channel = MethodChannel(
    'com.emilolabs.labguard/runtime',
  );

  Future<void> configureBackgroundSync({
    required bool enabled,
    required String apiBaseUrl,
  }) async {
    try {
      await _channel.invokeMethod<void>('configureBackgroundSync', {
        'enabled': enabled,
        'apiBaseUrl': apiBaseUrl,
      });
    } on MissingPluginException {
      // Android-specific bridge unavailable in tests or future non-Android builds.
    }
  }

  Future<void> triggerBackgroundSync({required String apiBaseUrl}) async {
    try {
      await _channel.invokeMethod<void>('triggerBackgroundSync', {
        'apiBaseUrl': apiBaseUrl,
      });
    } on MissingPluginException {
      // Android-specific bridge unavailable in tests or future non-Android builds.
    }
  }

  Future<void> syncRuntimePreferences({
    required bool notificationsEnabled,
  }) async {
    try {
      await _channel.invokeMethod<void>('syncRuntimePreferences', {
        'notificationsEnabled': notificationsEnabled,
      });
    } on MissingPluginException {
      // Android-specific bridge unavailable in tests or future non-Android builds.
    }
  }
}
