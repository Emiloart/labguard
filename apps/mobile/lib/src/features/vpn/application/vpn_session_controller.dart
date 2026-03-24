import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/android_vpn_bridge.dart';
import '../../../core/security/secure_store.dart';
import '../../auth/application/auth_controller.dart';
import '../../dashboard/application/dashboard_controller.dart';
import '../../devices/application/device_registry_provider.dart';
import '../domain/vpn_overview.dart';
import 'vpn_preferences_controller.dart';

final vpnSessionControllerProvider =
    AsyncNotifierProvider<VpnSessionController, VpnControlState>(
      VpnSessionController.new,
    );

class VpnSessionController extends AsyncNotifier<VpnControlState> {
  Timer? _poller;

  @override
  Future<VpnControlState> build() async {
    ref.watch(
      authControllerProvider.select((state) => state.session?.device.id),
    );
    ref.onDispose(_stopPolling);
    final controlState = await _loadState(reconcileNativeProfile: true);
    _configurePolling(controlState);
    return controlState;
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => _loadState(reconcileNativeProfile: true),
    );
    _configurePolling(state.valueOrNull);
  }

  Future<void> prepareAndroidVpn() async {
    await AsyncValue.guard(() async {
      await ref.read(androidVpnBridgeProvider).prepareVpn();
      return _loadState(reconcileNativeProfile: false);
    }).then((value) {
      state = value;
      _configurePolling(state.valueOrNull);
    });
  }

  Future<void> installLatestProfile() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final deviceId = _currentDeviceId();
      final profile = await ref
          .read(vpnRepositoryProvider)
          .fetchProfile(deviceId);
      await _persistProfile(profile);
      await _installProfileOnBridge(profile);
      return _loadState(
        reconcileNativeProfile: false,
        profileOverride: profile,
      );
    });
    _configurePolling(state.valueOrNull);
    _invalidateCrossFeatureState();
  }

  Future<void> connect() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final deviceId = _currentDeviceId();
      final bridge = ref.read(androidVpnBridgeProvider);

      await _ensureInstalledProfile(deviceId);
      final capabilities = await bridge.prepareVpn();

      if (!capabilities.permissionGranted) {
        return _loadState(reconcileNativeProfile: false);
      }

      final nativeStatus = await bridge.connect();
      await ref
          .read(vpnRepositoryProvider)
          .connectSession(
            deviceId: deviceId,
            serverId: nativeStatus.serverId,
            currentIp: nativeStatus.currentIp,
          );
      await ref
          .read(vpnRepositoryProvider)
          .recordHeartbeat(deviceId: deviceId, status: nativeStatus);

      return _loadState(reconcileNativeProfile: false);
    });
    _configurePolling(state.valueOrNull);
    _invalidateCrossFeatureState();
  }

  Future<void> disconnect() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final deviceId = _currentDeviceId();
      final nativeStatus = await ref
          .read(androidVpnBridgeProvider)
          .disconnect();

      await ref
          .read(vpnRepositoryProvider)
          .disconnectSession(
            deviceId: deviceId,
            reason: nativeStatus.lastError,
          );

      return _loadState(reconcileNativeProfile: false);
    });
    _configurePolling(state.valueOrNull);
    _invalidateCrossFeatureState();
  }

  Future<void> rotateProfile() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final deviceId = _currentDeviceId();
      final profile = await ref
          .read(vpnRepositoryProvider)
          .rotateProfile(deviceId);
      await _persistProfile(profile);
      await _installProfileOnBridge(profile);
      await ref
          .read(vpnRepositoryProvider)
          .disconnectSession(
            deviceId: deviceId,
            reason:
                'WireGuard credentials rotated. Reconnect required to resume traffic.',
          );

      return _loadState(
        reconcileNativeProfile: false,
        profileOverride: profile,
      );
    });
    _configurePolling(state.valueOrNull);
    _invalidateCrossFeatureState();
  }

  Future<void> revokeProfile() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final deviceId = _currentDeviceId();
      final profile = await ref
          .read(vpnRepositoryProvider)
          .revokeProfile(deviceId);
      await _deleteStoredProfile(deviceId);
      await ref.read(androidVpnBridgeProvider).clearProfile();
      await ref
          .read(vpnRepositoryProvider)
          .disconnectSession(
            deviceId: deviceId,
            reason: 'VPN access revoked for this device.',
          );

      return _loadState(
        reconcileNativeProfile: false,
        profileOverride: profile,
      );
    });
    _configurePolling(state.valueOrNull);
    _invalidateCrossFeatureState();
  }

  Future<void> syncTunnelState() async {
    final current = state.valueOrNull;

    if (current == null) {
      await refresh();
      return;
    }

    state = await AsyncValue.guard(() async {
      final deviceId = _currentDeviceId();
      final nativeStatus = await ref.read(androidVpnBridgeProvider).getStatus();
      await ref
          .read(vpnRepositoryProvider)
          .recordHeartbeat(deviceId: deviceId, status: nativeStatus);

      return _loadState(
        reconcileNativeProfile: false,
        nativeStatusOverride: nativeStatus,
      );
    });
    _configurePolling(state.valueOrNull);
    _invalidateCrossFeatureState();
  }

  Future<VpnControlState> _loadState({
    required bool reconcileNativeProfile,
    VpnProfileBundle? profileOverride,
    VpnNativeStatus? nativeStatusOverride,
  }) async {
    final deviceId = _currentDeviceId();
    final bridge = ref.read(androidVpnBridgeProvider);
    final repository = ref.read(vpnRepositoryProvider);
    final capabilities = await bridge.getPlatformCapabilities();
    var nativeStatus = nativeStatusOverride ?? await bridge.getStatus();

    VpnProfileBundle? profile = profileOverride;
    profile ??= await _loadProfileFromRepository(deviceId);
    profile ??= await _readStoredProfile(deviceId);

    if (reconcileNativeProfile && profile != null && profile.hasConfig) {
      final shouldInstall =
          !nativeStatus.profileInstalled ||
          nativeStatus.profileRevision != profile.revision;

      if (shouldInstall) {
        nativeStatus = await _installProfileOnBridge(profile);
      }
    }

    final remoteSession = await repository.fetchSession(deviceId);

    return VpnControlState(
      profile: profile,
      remoteSession: remoteSession,
      nativeStatus: nativeStatus,
      capabilities: capabilities,
    );
  }

  Future<VpnProfileBundle?> _loadProfileFromRepository(String deviceId) async {
    try {
      final profile = await ref
          .read(vpnRepositoryProvider)
          .fetchProfile(deviceId);
      await _persistProfile(profile);
      return profile;
    } catch (_) {
      return null;
    }
  }

  Future<void> _ensureInstalledProfile(String deviceId) async {
    final current = state.valueOrNull;
    final profile = current?.profile ?? await _readStoredProfile(deviceId);

    if (profile != null &&
        profile.hasConfig &&
        current?.nativeStatus.profileInstalled == true) {
      return;
    }

    final freshProfile = profile?.hasConfig == true
        ? profile!
        : await ref.read(vpnRepositoryProvider).fetchProfile(deviceId);
    await _persistProfile(freshProfile);
    await _installProfileOnBridge(freshProfile);
  }

  Future<VpnNativeStatus> _installProfileOnBridge(
    VpnProfileBundle profile,
  ) async {
    if (!profile.hasConfig) {
      throw StateError(
        'The current VPN profile is missing WireGuard config data.',
      );
    }

    return ref
        .read(androidVpnBridgeProvider)
        .installProfile(
          tunnelName: profile.tunnelName,
          serverId: profile.serverId,
          revision: profile.revision,
          config: profile.config!,
        );
  }

  Future<void> _persistProfile(VpnProfileBundle profile) async {
    final deviceId = profile.deviceId;

    if (!profile.hasConfig) {
      await _deleteStoredProfile(deviceId);
      return;
    }

    await ref
        .read(secureStoreProvider)
        .write(
          key: _profileStorageKey(deviceId),
          value: jsonEncode(profile.toStoredJson()),
        );
  }

  Future<VpnProfileBundle?> _readStoredProfile(String deviceId) async {
    final raw = await ref
        .read(secureStoreProvider)
        .read(_profileStorageKey(deviceId));

    if (raw == null || raw.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    return VpnProfileBundle.fromJson(decoded);
  }

  Future<void> _deleteStoredProfile(String deviceId) {
    return ref.read(secureStoreProvider).delete(_profileStorageKey(deviceId));
  }

  void _invalidateCrossFeatureState() {
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(deviceRegistryProvider);
    ref.invalidate(vpnOverviewProvider);
  }

  void _configurePolling(VpnControlState? controlState) {
    final connectionState = controlState?.nativeStatus.tunnelState;
    final shouldPoll =
        connectionState == VpnConnectionState.connected ||
        connectionState == VpnConnectionState.connecting;

    if (!shouldPoll) {
      _stopPolling();
      return;
    }

    _poller ??= Timer.periodic(const Duration(seconds: 12), (_) {
      unawaited(syncTunnelState());
    });
  }

  void _stopPolling() {
    _poller?.cancel();
    _poller = null;
  }

  String _currentDeviceId() {
    final deviceId = ref.read(authControllerProvider).session?.device.id;

    if (deviceId == null || deviceId.isEmpty) {
      throw StateError(
        'VPN controls are unavailable without an active session.',
      );
    }

    return deviceId;
  }

  String _profileStorageKey(String deviceId) =>
      'labguard.vpn.profile.$deviceId';
}
