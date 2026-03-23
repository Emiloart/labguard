import 'auth_session.dart';

enum AuthStage { booting, onboarding, signedOut, signedIn }

class AuthSessionState {
  const AuthSessionState({
    required this.stage,
    this.session,
    this.isBusy = false,
    this.errorMessage,
  });

  const AuthSessionState.booting()
    : stage = AuthStage.booting,
      session = null,
      isBusy = false,
      errorMessage = null;

  final AuthStage stage;
  final AuthSession? session;
  final bool isBusy;
  final String? errorMessage;

  AuthSessionState copyWith({
    AuthStage? stage,
    AuthSession? session,
    bool clearSession = false,
    bool? isBusy,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthSessionState(
      stage: stage ?? this.stage,
      session: clearSession ? null : session ?? this.session,
      isBusy: isBusy ?? this.isBusy,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
