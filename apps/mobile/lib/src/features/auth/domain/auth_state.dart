enum AuthStage { booting, onboarding, signedOut, signedIn }

class AuthSessionState {
  const AuthSessionState({
    required this.stage,
    this.biometricEnabled = false,
    this.pinLockEnabled = false,
  });

  const AuthSessionState.booting()
    : stage = AuthStage.booting,
      biometricEnabled = false,
      pinLockEnabled = false;

  final AuthStage stage;
  final bool biometricEnabled;
  final bool pinLockEnabled;

  AuthSessionState copyWith({
    AuthStage? stage,
    bool? biometricEnabled,
    bool? pinLockEnabled,
  }) {
    return AuthSessionState(
      stage: stage ?? this.stage,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      pinLockEnabled: pinLockEnabled ?? this.pinLockEnabled,
    );
  }
}
