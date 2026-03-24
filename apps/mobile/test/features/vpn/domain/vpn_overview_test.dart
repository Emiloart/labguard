import 'package:flutter_test/flutter_test.dart';
import 'package:labguard/src/features/vpn/domain/vpn_overview.dart';

void main() {
  group('Vpn domain policy', () {
    test('parses native status with reconnect and kill-switch fields', () {
      final status = VpnNativeStatus.fromJson(const {
        'permissionGranted': true,
        'profileInstalled': true,
        'tunnelState': 'DISCONNECTED',
        'tunnelName': 'labguard',
        'serverId': 'wg-01',
        'profileRevision': 4,
        'desiredConnected': true,
        'killSwitchRequested': true,
        'currentIp': 'Unavailable',
        'bytesReceived': 0,
        'bytesSent': 0,
        'backendVersion': '1.0',
      });

      expect(status.permissionGranted, isTrue);
      expect(status.profileInstalled, isTrue);
      expect(status.desiredConnected, isTrue);
      expect(status.killSwitchRequested, isTrue);
      expect(status.tunnelState, VpnConnectionState.disconnected);
    });

    test('parses platform capabilities with system kill-switch support', () {
      final capabilities = VpnPlatformCapabilities.fromJson(const {
        'platform': 'android',
        'vpnServicePrepared': true,
        'wireGuardBackendIntegrated': true,
        'supportsAlwaysOnSystemSettings': true,
        'killSwitchManagedBySystem': true,
        'permissionGranted': true,
        'packageName': 'com.emilolabs.labguard',
        'notes': 'test',
      });

      expect(capabilities.supportsAlwaysOnSystemSettings, isTrue);
      expect(capabilities.killSwitchManagedBySystem, isTrue);
    });

    test(
      'auto-connect helper only reconnects when policy and runtime permit',
      () {
        const status = VpnNativeStatus(
          permissionGranted: true,
          profileInstalled: true,
          tunnelState: VpnConnectionState.error,
          tunnelName: 'labguard',
          serverId: 'wg-01',
          profileRevision: 2,
          desiredConnected: true,
          killSwitchRequested: true,
          currentIp: 'Unavailable',
          bytesReceived: 0,
          bytesSent: 0,
          connectedAt: null,
          lastHandshakeAt: null,
          lastError: 'network lost',
          backendVersion: '1.0',
        );

        expect(
          shouldAttemptAutoConnect(status: status, autoConnectEnabled: true),
          isTrue,
        );

        expect(
          shouldAttemptAutoConnect(status: status, autoConnectEnabled: false),
          isFalse,
        );
      },
    );

    test(
      'auto-connect helper respects manual disconnect intent and live state',
      () {
        const disconnectedByChoice = VpnNativeStatus(
          permissionGranted: true,
          profileInstalled: true,
          tunnelState: VpnConnectionState.disconnected,
          tunnelName: 'labguard',
          serverId: 'wg-01',
          profileRevision: 2,
          desiredConnected: false,
          killSwitchRequested: true,
          currentIp: 'Unavailable',
          bytesReceived: 0,
          bytesSent: 0,
          connectedAt: null,
          lastHandshakeAt: null,
          lastError: null,
          backendVersion: '1.0',
        );

        const alreadyConnected = VpnNativeStatus(
          permissionGranted: true,
          profileInstalled: true,
          tunnelState: VpnConnectionState.connected,
          tunnelName: 'labguard',
          serverId: 'wg-01',
          profileRevision: 2,
          desiredConnected: true,
          killSwitchRequested: true,
          currentIp: '10.0.0.2',
          bytesReceived: 256,
          bytesSent: 128,
          connectedAt: null,
          lastHandshakeAt: null,
          lastError: null,
          backendVersion: '1.0',
        );

        expect(
          shouldAttemptAutoConnect(
            status: disconnectedByChoice,
            autoConnectEnabled: true,
          ),
          isFalse,
        );

        expect(
          shouldAttemptAutoConnect(
            status: alreadyConnected,
            autoConnectEnabled: true,
          ),
          isFalse,
        );
      },
    );
  });
}
