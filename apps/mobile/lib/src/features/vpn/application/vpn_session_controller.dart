import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/android_background_runtime_bridge.dart';
import '../../../core/platform/android_vpn_bridge.dart';
import '../../../core/security/secure_store.dart';
import '../../auth/application/auth_controller.dart';
import '../../dashboard/application/dashboard_controller.dart';
import '../../devices/application/device_registry_provider.dart';
import '../../settings/application/settings_controller.dart';
import '../domain/vpn_overview.dart';
import 'vpn_preferences_controller.dart';

final vpnSessionControllerProvider =
    AsyncNotifierProvider<VpnSessionController, VpnControlState>(
      VpnSessionController.new,
    );

class VpnSessionController extends AsyncNotifier<VpnControlState> {
  Timer? _poller;
  bool _autoConnectInFlight = false;
  DateTime? _lastHeartbeatSentAt;
  String? _lastHeartbeatSignature;
  String? _lastBroadcastSignature;

  @override
  Future<VpnControlState> build() async {
    ref.watch(
      authControllerProvider.select((state) => state.session?.device.id),
    );
    ref.watch(
      settingsControllerProvider.select(
        (value) => value.valueOrNull?.preferences.autoConnectEnabled,
      ),
    );
    ref.onDispose(_stopPolling);
    var controlState = await _loadState(reconcileNativeProfile: true);
    controlState = await _autoConnectIfRequired(controlState);
    _configurePolling(controlState);
    return controlState;
  }

  Future<void> refresh() async {
    final previous = state.valueOrNull;
    state = await AsyncValue.guard(() async {
      final controlState = await _loadState(reconcileNativeProfile: true);
      return _autoConnectIfRequired(controlState);
    });
    _commitState(previous: previous);
  }

  Future<void> prepareAndroidVpn() async {
    _beginLoading();
    final previous = state.valueOrNull;
    await AsyncValue.guard(() async {
      await ref.read(androidVpnBridgeProvider).prepareVpn();
      final controlState = await _loadState(reconcileNativeProfile: false);
      return _autoConnectIfRequired(controlState);
    }).then((value) {
      state = value;
      _commitState(previous: previous);
    });
  }

  Future<void> installLatestProfile() async {
    _beginLoading();
    final previous = state.valueOrNull;
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
    state = await AsyncValue.guard(() async {
      final current = state.valueOrNull;
      if (current == null) {
        return _loadState(reconcileNativeProfile: true);
      }
      return _autoConnectIfRequired(current);
    });
    _commitState(previous: previous, invalidateCrossFeatures: true);
  }

  Future<void> connect() async {
    _beginLoading();
    final previous = state.valueOrNull;
    state = await AsyncValue.guard(() async {
      final deviceId = _currentDeviceId();
      final bridge = ref.read(androidVpnBridgeProvider);

      await _ensureInstalledProfile(deviceId);
      await ref
          .read(androidBackgroundRuntimeBridgeProvider)
          .setVpnConnectionIntent(desiredConnected: true);
      final capabilities = await bridge.prepareVpn();

      if (!capabilities.permissionGranted) {
        return _loadState(reconcileNativeProfile: false);
      }

      final nativeStatus = await bridge.connect();
      final remoteSession = await ref
          .read(vpnRepositoryProvider)
          .connectSession(
            deviceId: deviceId,
            serverId: nativeStatus.serverId,
            currentIp: _usableCurrentIp(nativeStatus.currentIp),
            lastHandshakeAt: nativeStatus.lastHandshakeAt,
            lastError: nativeStatus.lastError,
          );
      _rememberHeartbeat(nativeStatus);

      return _loadState(
        reconcileNativeProfile: false,
        nativeStatusOverride: nativeStatus,
        remoteSessionOverride: remoteSession,
      );
    });
    _commitState(previous: previous, invalidateCrossFeatures: true);
  }

  Future<void> disconnect() async {
    _beginLoading();
    final previous = state.valueOrNull;
    state = await AsyncValue.guard(() async {
      final deviceId = _currentDeviceId();
      await ref
          .read(androidBackgroundRuntimeBridgeProvider)
          .setVpnConnectionIntent(desiredConnected: false);
      final nativeStatus = await ref
          .read(androidVpnBridgeProvider)
          .disconnect();

      final remoteSession = await ref
          .read(vpnRepositoryProvider)
          .disconnectSession(
            deviceId: deviceId,
            reason: nativeStatus.lastError,
          );
      _rememberHeartbeat(nativeStatus);

      return _loadState(
        reconcileNativeProfile: false,
        nativeStatusOverride: nativeStatus,
        remoteSessionOverride: remoteSession,
      );
    });
    _commitState(previous: previous, invalidateCrossFeatures: true);
  }

  Future<void> switchServer(String serverId) async {
    _beginLoading();
    final previous = state.valueOrNull;
    state = await AsyncValue.guard(() async {
      final deviceId = _currentDeviceId();
      final current =
          previous ?? await _loadState(reconcileNativeProfile: true);
      final shouldReconnect =
          current.effectiveTunnelState == VpnConnectionState.connected ||
          current.effectiveTunnelState == VpnConnectionState.connecting ||
          current.nativeStatus.desiredConnected;
      final repository = ref.read(vpnRepositoryProvider);
      final bridge = ref.read(androidVpnBridgeProvider);
      final profile = await repository.selectServer(
        deviceId: deviceId,
        serverId: serverId,
      );

      await _persistProfile(profile);
      await _installProfileOnBridge(profile);
      await ref
          .read(androidBackgroundRuntimeBridgeProvider)
          .setVpnConnectionIntent(desiredConnected: shouldReconnect);

      if (!shouldReconnect) {
        return _loadState(
          reconcileNativeProfile: false,
          profileOverride: profile,
        );
      }

      final capabilities = await bridge.prepareVpn();
      if (!capabilities.permissionGranted) {
        return _loadState(
          reconcileNativeProfile: false,
          profileOverride: profile,
        );
      }

      final nativeStatus = await bridge.connect();
      final remoteSession = await repository.connectSession(
        deviceId: deviceId,
        serverId: nativeStatus.serverId,
        currentIp: _usableCurrentIp(nativeStatus.currentIp),
        lastHandshakeAt: nativeStatus.lastHandshakeAt,
        lastError: nativeStatus.lastError,
      );
      _rememberHeartbeat(nativeStatus);

      return _loadState(
        reconcileNativeProfile: false,
        profileOverride: profile,
        nativeStatusOverride: nativeStatus,
        remoteSessionOverride: remoteSession,
      );
    });
    _commitState(previous: previous, invalidateCrossFeatures: true);
  }

  Future<void> rotateProfile() async {
    _beginLoading();
    final previous = state.valueOrNull;
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
    state = await AsyncValue.guard(() async {
      final current = state.valueOrNull;
      if (current == null) {
        return _loadState(reconcileNativeProfile: true);
      }
      return _autoConnectIfRequired(current);
    });
    _commitState(previous: previous, invalidateCrossFeatures: true);
  }

  Future<void> revokeProfile() async {
    _beginLoading();
    final previous = state.valueOrNull;
    state = await AsyncValue.guard(() async {
      final deviceId = _currentDeviceId();
      await ref
          .read(androidBackgroundRuntimeBridgeProvider)
          .setVpnConnectionIntent(desiredConnected: false);
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
    _commitState(previous: previous, invalidateCrossFeatures: true);
  }

  Future<void> syncTunnelState() async {
    final current = state.valueOrNull;

    if (current == null) {
      await refresh();
      return;
    }

    final previous = current;
    state = await AsyncValue.guard(() async {
      final deviceId = _currentDeviceId();
      final nativeStatus = await ref.read(androidVpnBridgeProvider).getStatus();
      final repository = ref.read(vpnRepositoryProvider);
      final shouldSendHeartbeat = _shouldSendHeartbeat(nativeStatus);
      final remoteSession = shouldSendHeartbeat
          ? await repository.recordHeartbeat(
              deviceId: deviceId,
              status: nativeStatus,
            )
          : current.remoteSession;
      if (shouldSendHeartbeat) {
        _rememberHeartbeat(nativeStatus);
      }

      final controlState = await _loadState(
        reconcileNativeProfile: false,
        nativeStatusOverride: nativeStatus,
        remoteSessionOverride: remoteSession,
      );
      return _autoConnectIfRequired(controlState);
    });
    _commitState(previous: previous, invalidateCrossFeatures: true);
  }

  Future<VpnControlState> _autoConnectIfRequired(
    VpnControlState controlState,
  ) async {
    if (_autoConnectInFlight) {
      return controlState;
    }

    final settings = await ref.read(settingsControllerProvider.future);
    final shouldConnect = shouldAttemptAutoConnect(
      status: controlState.nativeStatus,
      autoConnectEnabled: settings.preferences.autoConnectEnabled,
    );

    if (!shouldConnect) {
      return controlState;
    }

    _autoConnectInFlight = true;

    try {
      final deviceId = _currentDeviceId();
      final nativeStatus = await ref.read(androidVpnBridgeProvider).connect();
      final remoteSession = await ref
          .read(vpnRepositoryProvider)
          .connectSession(
            deviceId: deviceId,
            serverId: nativeStatus.serverId,
            currentIp: _usableCurrentIp(nativeStatus.currentIp),
            lastHandshakeAt: nativeStatus.lastHandshakeAt,
            lastError: nativeStatus.lastError,
          );
      _rememberHeartbeat(nativeStatus);

      return _loadState(
        reconcileNativeProfile: false,
        nativeStatusOverride: nativeStatus,
        remoteSessionOverride: remoteSession,
        profileOverride: controlState.profile,
      );
    } catch (_) {
      return _loadState(
        reconcileNativeProfile: false,
        profileOverride: controlState.profile,
      );
    } finally {
      _autoConnectInFlight = false;
    }
  }

  Future<VpnControlState> _loadState({
    required bool reconcileNativeProfile,
    VpnProfileBundle? profileOverride,
    VpnNativeStatus? nativeStatusOverride,
    VpnSessionSnapshot? remoteSessionOverride,
  }) async {
    final deviceId = _currentDeviceId();
    final bridge = ref.read(androidVpnBridgeProvider);
    final repository = ref.read(vpnRepositoryProvider);
    final capabilities = await bridge.getPlatformCapabilities();
    var nativeStatus = nativeStatusOverride ?? await bridge.getStatus();

    VpnProfileBundle? profile = profileOverride;
    profile ??= await _loadProfileFromRepository(deviceId);
    profile ??= await _readStoredProfile(deviceId);

    if (reconcileNativeProfile) {
      if (profile == null || !profile.hasConfig) {
        if (nativeStatus.profileInstalled) {
          nativeStatus = await bridge.clearProfile();
        }
      } else {
        final shouldInstall =
            !nativeStatus.profileInstalled ||
            nativeStatus.profileRevision != profile.revision;

        if (shouldInstall) {
          nativeStatus = await _installProfileOnBridge(profile);
        }
      }
    }

    final remoteSession =
        remoteSessionOverride ?? await repository.fetchSession(deviceId);

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
    if (!freshProfile.hasConfig) {
      throw StateError(
        'No production-ready VPN region is available for this device.',
      );
    }
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
          deviceId: profile.deviceId,
          tunnelName: profile.tunnelName,
          serverId: profile.serverId,
          serverName: profile.serverName,
          locationLabel: profile.locationLabel,
          endpoint: profile.endpoint,
          exitIpAddress: profile.exitIpAddress,
          dnsServers: profile.dnsServers,
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

  void _commitState({
    required VpnControlState? previous,
    bool invalidateCrossFeatures = false,
  }) {
    final current = state.valueOrNull;
    _configurePolling(current);

    if (!invalidateCrossFeatures || current == null) {
      return;
    }

    final nextSignature = _broadcastSignature(current);
    if (_lastBroadcastSignature == nextSignature &&
        previous != null &&
        _broadcastSignature(previous) == nextSignature) {
      return;
    }

    _lastBroadcastSignature = nextSignature;
    _invalidateCrossFeatureState();
  }

  void _beginLoading() {
    state = const AsyncLoading<VpnControlState>().copyWithPrevious(state);
  }

  void _configurePolling(VpnControlState? controlState) {
    final connectionState = controlState?.effectiveTunnelState;
    final shouldPoll =
        connectionState == VpnConnectionState.connected ||
        connectionState == VpnConnectionState.connecting;

    if (!shouldPoll) {
      _stopPolling();
      return;
    }

    _poller ??= Timer.periodic(const Duration(seconds: 45), (_) {
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

  bool _shouldSendHeartbeat(VpnNativeStatus status) {
    final now = DateTime.now();
    final signature = _heartbeatSignature(status);

    if (_lastHeartbeatSentAt == null || _lastHeartbeatSignature != signature) {
      return true;
    }

    return now.difference(_lastHeartbeatSentAt!) >= const Duration(minutes: 1);
  }

  void _rememberHeartbeat(VpnNativeStatus status) {
    _lastHeartbeatSentAt = DateTime.now();
    _lastHeartbeatSignature = _heartbeatSignature(status);
  }

  String _heartbeatSignature(VpnNativeStatus status) {
    return [
      status.tunnelState.name,
      status.serverId,
      status.currentIp,
      status.lastHandshakeAt?.millisecondsSinceEpoch ?? 0,
      status.lastError ?? '',
      status.connectedAt?.millisecondsSinceEpoch ?? 0,
    ].join('|');
  }

  String _broadcastSignature(VpnControlState controlState) {
    return [
      controlState.effectiveTunnelState.name,
      controlState.profile?.serverId ?? '',
      controlState.remoteSession.serverId,
      controlState.displayCurrentIp,
      controlState.remoteSession.profileRevision,
      controlState.effectiveError ?? '',
    ].join('|');
  }

  String? _usableCurrentIp(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized == 'Unavailable') {
      return null;
    }

    return normalized;
  }
}
