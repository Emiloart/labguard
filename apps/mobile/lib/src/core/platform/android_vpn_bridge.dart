import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final androidVpnBridgeProvider = Provider<AndroidVpnBridge>((ref) {
  return const AndroidVpnBridge();
});

class AndroidVpnBridge {
  const AndroidVpnBridge();

  static const MethodChannel _channel = MethodChannel(
    'com.emilolabs.labguard/vpn',
  );

  Future<Map<String, dynamic>> getPlatformCapabilities() async {
    final values = await _channel.invokeMapMethod<String, dynamic>(
      'getPlatformCapabilities',
    );

    return values ?? const {};
  }

  Future<Map<String, dynamic>> prepareVpn() async {
    final values = await _channel.invokeMapMethod<String, dynamic>(
      'prepareVpn',
    );
    return values ?? const {};
  }
}
