import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/domain/auth_state.dart';
import '../../features/settings/application/settings_controller.dart';
import 'secure_store.dart';

final _appLockPinHashProvider = FutureProvider<String?>((ref) {
  return ref.watch(secureStoreProvider).read(AppLockController.appPinHashKey);
});

final _appLockRuntimeProvider = StateProvider<AppLockRuntimeState>((ref) {
  return const AppLockRuntimeState();
});

final appLockControllerProvider = Provider<AppLockController>((ref) {
  return AppLockController(ref);
});

final biometricAvailabilityProvider = FutureProvider<bool>((ref) {
  return ref.read(appLockControllerProvider).isBiometricAvailable();
});

final appLockStateProvider = Provider<AppLockState>((ref) {
  final authStage = ref.watch(
    authControllerProvider.select((state) => state.stage),
  );
  final settings = ref.watch(settingsControllerProvider);
  final preferences = settings.valueOrNull?.preferences;
  final pinHashAsync = ref.watch(_appLockPinHashProvider);
  final pinHash = pinHashAsync.valueOrNull;
  final runtime = ref.watch(_appLockRuntimeProvider);
  final signedIn = authStage == AuthStage.signedIn;
  final pinPolicyLoading =
      signedIn &&
      runtime.locked &&
      (preferences?.pinLockEnabled ?? false) &&
      pinHashAsync.isLoading;
  final policyLoading =
      signedIn && runtime.locked && (settings.isLoading || pinPolicyLoading);
  final canUseBiometrics = signedIn && (preferences?.biometricEnabled ?? false);
  final canUsePin =
      signedIn && (preferences?.pinLockEnabled ?? false) && pinHash != null;
  final protectionEnabled = policyLoading || canUseBiometrics || canUsePin;

  return AppLockState(
    locked: protectionEnabled && runtime.locked,
    unlockInFlight: runtime.unlockInFlight,
    canUseBiometrics: canUseBiometrics,
    canUsePin: canUsePin,
    policyLoading: policyLoading,
    errorMessage: runtime.errorMessage,
  );
});

class AppLockController {
  AppLockController(this._ref);

  static const appPinHashKey = 'labguard.security.app_pin_hash';
  static final RegExp _pinPattern = RegExp(r'^\d{4}$');

  final Ref _ref;
  final LocalAuthentication _localAuthentication = LocalAuthentication();

  void lock() {
    final current = _ref.read(_appLockRuntimeProvider);
    _ref.read(_appLockRuntimeProvider.notifier).state = current.copyWith(
      locked: true,
      unlockInFlight: false,
      clearError: true,
    );
  }

  void clearLock() {
    final current = _ref.read(_appLockRuntimeProvider);
    _ref.read(_appLockRuntimeProvider.notifier).state = current.copyWith(
      locked: false,
      unlockInFlight: false,
      clearError: true,
    );
  }

  Future<void> configurePin(String pin) async {
    final normalized = pin.trim();
    if (!_pinPattern.hasMatch(normalized)) {
      throw ArgumentError('App PINs must be exactly four digits.');
    }
    await _ref
        .read(secureStoreProvider)
        .write(key: appPinHashKey, value: _hashPin(normalized));
    _ref.invalidate(_appLockPinHashProvider);
    clearLock();
  }

  Future<void> clearPin() async {
    await _ref.read(secureStoreProvider).delete(appPinHashKey);
    _ref.invalidate(_appLockPinHashProvider);
  }

  Future<bool> unlock({String? pin}) async {
    final state = _ref.read(appLockStateProvider);
    if (!state.locked) {
      return true;
    }

    _setRuntime(unlockInFlight: true, clearError: true);

    try {
      if (state.canUseBiometrics) {
        final authenticated = await authenticateBiometric(
          localizedReason: 'Unlock LabGuard',
        );
        if (authenticated) {
          clearLock();
          return true;
        }
      }

      if (state.canUsePin) {
        if (pin == null || pin.trim().isEmpty) {
          _setRuntime(
            unlockInFlight: false,
            errorMessage: 'Enter your app PIN to resume LabGuard.',
          );
          return false;
        }

        final pinValid = await verifyPin(pin);
        if (pinValid) {
          clearLock();
          return true;
        }

        _setRuntime(
          unlockInFlight: false,
          errorMessage: 'The app PIN is incorrect.',
        );
        return false;
      }

      if (state.canUseBiometrics) {
        _setRuntime(
          unlockInFlight: false,
          errorMessage: 'Biometric verification did not complete.',
        );
        return false;
      }

      clearLock();
      return true;
    } finally {
      final current = _ref.read(_appLockRuntimeProvider);
      _ref.read(_appLockRuntimeProvider.notifier).state = current.copyWith(
        unlockInFlight: false,
      );
    }
  }

  void clearError() {
    _setRuntime(clearError: true);
  }

  Future<bool> isBiometricAvailable() async {
    try {
      final canCheckBiometrics = await _localAuthentication.canCheckBiometrics;
      final isDeviceSupported = await _localAuthentication.isDeviceSupported();
      return canCheckBiometrics && isDeviceSupported;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> authenticateBiometric({
    String localizedReason = 'Approve this LabGuard action',
  }) async {
    try {
      final available = await isBiometricAvailable();
      if (!available) {
        return false;
      }

      return await _localAuthentication.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          sensitiveTransaction: true,
        ),
      );
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> verifyPin(String pin) async {
    final normalizedPin = pin.trim();
    if (!_pinPattern.hasMatch(normalizedPin)) {
      return false;
    }

    final expectedHash = await _ref.read(_appLockPinHashProvider.future);
    return expectedHash != null && expectedHash == _hashPin(normalizedPin);
  }

  void _setRuntime({
    bool? locked,
    bool? unlockInFlight,
    String? errorMessage,
    bool clearError = false,
  }) {
    final current = _ref.read(_appLockRuntimeProvider);
    _ref.read(_appLockRuntimeProvider.notifier).state = current.copyWith(
      locked: locked,
      unlockInFlight: unlockInFlight,
      errorMessage: errorMessage,
      clearError: clearError,
    );
  }

  String _hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }
}

class AppLockState {
  const AppLockState({
    required this.locked,
    required this.unlockInFlight,
    required this.canUseBiometrics,
    required this.canUsePin,
    required this.policyLoading,
    this.errorMessage,
  });

  final bool locked;
  final bool unlockInFlight;
  final bool canUseBiometrics;
  final bool canUsePin;
  final bool policyLoading;
  final String? errorMessage;

  bool get requiresUnlock =>
      locked && (policyLoading || canUseBiometrics || canUsePin);
}

class AppLockRuntimeState {
  const AppLockRuntimeState({
    this.locked = false,
    this.unlockInFlight = false,
    this.errorMessage,
  });

  final bool locked;
  final bool unlockInFlight;
  final String? errorMessage;

  AppLockRuntimeState copyWith({
    bool? locked,
    bool? unlockInFlight,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AppLockRuntimeState(
      locked: locked ?? this.locked,
      unlockInFlight: unlockInFlight ?? this.unlockInFlight,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
