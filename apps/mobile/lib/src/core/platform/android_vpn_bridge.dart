import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/vpn/domain/vpn_overview.dart';

final androidVpnBridgeProvider = Provider<AndroidVpnBridge>((ref) {
  return const AndroidVpnBridge();
});

class AndroidVpnBridge {
  const AndroidVpnBridge();

  static const MethodChannel _channel = MethodChannel(
    'com.emilolabs.labguard/vpn',
  );

  Future<VpnPlatformCapabilities> getPlatformCapabilities() async {
    final values = await _channel.invokeMapMethod<String, dynamic>(
      'getPlatformCapabilities',
    );

    return VpnPlatformCapabilities.fromJson(values ?? const {});
  }

  Future<VpnNativeStatus> getStatus() async {
    final values = await _channel.invokeMapMethod<String, dynamic>('getStatus');

    return VpnNativeStatus.fromJson(values ?? const {});
  }

  Future<VpnPlatformCapabilities> prepareVpn() async {
    final values = await _channel.invokeMapMethod<String, dynamic>(
      'prepareVpn',
    );
    return VpnPlatformCapabilities.fromJson(values ?? const {});
  }

  Future<VpnNativeStatus> installProfile({
    required String deviceId,
    required String tunnelName,
    required String serverId,
    required String serverName,
    required String locationLabel,
    required String endpoint,
    required String exitIpAddress,
    required List<String> dnsServers,
    required int revision,
    required String config,
  }) async {
    final values = await _channel
        .invokeMapMethod<String, dynamic>('installProfile', {
          'deviceId': deviceId,
          'tunnelName': tunnelName,
          'serverId': serverId,
          'serverName': serverName,
          'locationLabel': locationLabel,
          'endpoint': endpoint,
          'exitIpAddress': exitIpAddress,
          'dnsServers': dnsServers,
          'revision': revision,
          'config': config,
        });

    return VpnNativeStatus.fromJson(values ?? const {});
  }

  Future<VpnNativeStatus> connect() async {
    final values = await _channel.invokeMapMethod<String, dynamic>('connect');

    return VpnNativeStatus.fromJson(values ?? const {});
  }

  Future<VpnNativeStatus> disconnect() async {
    final values = await _channel.invokeMapMethod<String, dynamic>(
      'disconnect',
    );

    return VpnNativeStatus.fromJson(values ?? const {});
  }

  Future<VpnNativeStatus> clearProfile() async {
    final values = await _channel.invokeMapMethod<String, dynamic>(
      'clearProfile',
    );

    return VpnNativeStatus.fromJson(values ?? const {});
  }

  Future<void> openVpnSettings() async {
    try {
      await _channel.invokeMethod<void>('openVpnSettings');
    } on MissingPluginException {
      // Android VPN settings handoff is unavailable in tests and future non-Android builds.
    }
  }
}
