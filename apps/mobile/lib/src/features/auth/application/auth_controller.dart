import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_state.dart';

final authControllerProvider =
    NotifierProvider<AuthController, AuthSessionState>(AuthController.new);

class AuthController extends Notifier<AuthSessionState> {
  bool _bootstrapStarted = false;

  @override
  AuthSessionState build() {
    if (!_bootstrapStarted) {
      _bootstrapStarted = true;
      Future<void>.microtask(_bootstrap);
    }

    return const AuthSessionState.booting();
  }

  Future<void> _bootstrap() async {
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    state = state.copyWith(stage: AuthStage.onboarding);
  }

  void completeOnboarding() {
    state = state.copyWith(stage: AuthStage.signedOut);
  }

  void signInPlaceholder() {
    state = state.copyWith(stage: AuthStage.signedIn);
  }

  void signOut() {
    state = state.copyWith(stage: AuthStage.signedOut);
  }

  void setBiometric(bool enabled) {
    state = state.copyWith(biometricEnabled: enabled);
  }

  void setPinLock(bool enabled) {
    state = state.copyWith(pinLockEnabled: enabled);
  }
}
