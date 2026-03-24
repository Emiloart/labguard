import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/android_vpn_bridge.dart';
import '../../dashboard/application/dashboard_controller.dart';
import '../../devices/application/device_registry_provider.dart';
import '../../events/application/security_events_provider.dart';
import '../../remote_actions/data/recovery_signal_store.dart';
import '../../settings/application/settings_controller.dart';
import '../../vpn/application/vpn_preferences_controller.dart';
import '../data/auth_repository.dart';
import '../data/auth_session_store.dart';
import '../domain/auth_state.dart';

final authControllerProvider =
    NotifierProvider<AuthController, AuthSessionState>(AuthController.new);

class AuthController extends Notifier<AuthSessionState> {
  bool _bootstrapStarted = false;
  int _lastInvalidationVersion = 0;

  @override
  AuthSessionState build() {
    final invalidationVersion = ref.watch(authSessionInvalidationProvider);

    if (_lastInvalidationVersion != invalidationVersion) {
      _lastInvalidationVersion = invalidationVersion;
      if (invalidationVersion > 0) {
        Future<void>.microtask(_handleExternalSessionInvalidation);
      }
    }

    if (!_bootstrapStarted) {
      _bootstrapStarted = true;
      Future<void>.microtask(_bootstrap);
    }

    return const AuthSessionState.booting();
  }

  Future<void> _bootstrap() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final result = await ref.read(authRepositoryProvider).bootstrap();
    state = state.copyWith(
      stage: result.stage,
      session: result.session,
      clearSession: result.session == null,
      clearError: true,
    );
  }

  Future<void> completeOnboarding() async {
    await ref.read(authRepositoryProvider).completeOnboarding();
    state = state.copyWith(stage: AuthStage.signedOut, clearError: true);
  }

  Future<void> signIn({required String identity, String? inviteCode}) async {
    state = state.copyWith(isBusy: true, clearError: true);

    try {
      final session = await ref
          .read(authRepositoryProvider)
          .login(identity: identity, inviteCode: inviteCode);
      _invalidateAppData();
      state = state.copyWith(
        stage: AuthStage.signedIn,
        session: session,
        isBusy: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        stage: AuthStage.signedOut,
        isBusy: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> restoreTrustedSession() async {
    state = state.copyWith(isBusy: true, clearError: true);

    try {
      final session = await ref
          .read(authRepositoryProvider)
          .restoreTrustedSession();
      _invalidateAppData();
      state = state.copyWith(
        stage: AuthStage.signedIn,
        session: session,
        isBusy: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        stage: AuthStage.signedOut,
        isBusy: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isBusy: true, clearError: true);
    await ref.read(authRepositoryProvider).logout();
    await _clearLocalProtectedMaterial();
    _invalidateAppData();
    state = state.copyWith(
      stage: AuthStage.signedOut,
      clearSession: true,
      isBusy: false,
      clearError: true,
    );
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<void> revalidateStoredSession() async {
    final result = await ref.read(authRepositoryProvider).bootstrap();
    final previousSession = state.session;
    final currentAccessToken = state.session?.accessToken;
    final nextAccessToken = result.session?.accessToken;
    final previousDeviceId = previousSession?.device.id;
    final nextDeviceId = result.session?.device.id;
    final sessionChanged =
        currentAccessToken != nextAccessToken ||
        previousDeviceId != nextDeviceId;
    final shouldClearLocalProtectedMaterial =
        previousDeviceId != null &&
        previousDeviceId.isNotEmpty &&
        previousDeviceId != nextDeviceId;

    if (state.stage == result.stage && !sessionChanged) {
      return;
    }

    if (shouldClearLocalProtectedMaterial) {
      await _clearLocalProtectedMaterial();
    }

    _invalidateAppData();
    state = state.copyWith(
      stage: result.stage,
      session: result.session,
      clearSession: result.session == null,
      isBusy: false,
      clearError: true,
    );
  }

  Future<void> _handleExternalSessionInvalidation() async {
    await revalidateStoredSession();
  }

  Future<void> _clearLocalProtectedMaterial() async {
    try {
      await ref.read(androidVpnBridgeProvider).clearProfile();
    } on MissingPluginException {
      // Android VPN bridge is unavailable in tests and future non-Android builds.
    }

    await ref.read(recoverySignalStoreProvider).clear();
    ref.read(recoverySignalInvalidationProvider.notifier).state++;
  }

  void _invalidateAppData() {
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(deviceRegistryProvider);
    ref.invalidate(securityEventsProvider);
    ref.invalidate(settingsControllerProvider);
    ref.invalidate(vpnOverviewProvider);
    ref.invalidate(vpnServersProvider);
  }
}
