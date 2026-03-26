import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/network/labguard_api_client.dart';
import '../domain/auth_session.dart';
import '../domain/auth_state.dart';
import 'auth_session_store.dart';
import 'device_identity_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    client: ref.watch(labGuardApiClientProvider),
    sessionStore: ref.watch(authSessionStoreProvider),
    deviceIdentityRepository: ref.watch(deviceIdentityRepositoryProvider),
  );
});

class AuthRepository {
  AuthRepository({
    required Dio client,
    required AuthSessionStore sessionStore,
    required DeviceIdentityRepository deviceIdentityRepository,
  }) : _client = client,
       _sessionStore = sessionStore,
       _deviceIdentityRepository = deviceIdentityRepository;

  final Dio _client;
  final AuthSessionStore _sessionStore;
  final DeviceIdentityRepository _deviceIdentityRepository;

  Future<AuthBootstrapResult> bootstrap() async {
    final onboardingComplete = await _sessionStore.isOnboardingComplete();

    if (!onboardingComplete) {
      return const AuthBootstrapResult(stage: AuthStage.onboarding);
    }

    final session = await _sessionStore.readSession();

    if (session == null || !session.isPersistable) {
      return const AuthBootstrapResult(stage: AuthStage.signedOut);
    }

    return AuthBootstrapResult(stage: AuthStage.signedIn, session: session);
  }

  Future<void> completeOnboarding() {
    return _sessionStore.completeOnboarding();
  }

  Future<AuthSession> login({
    required String identity,
    String? inviteCode,
  }) async {
    final device = await _deviceIdentityRepository.readCurrentDevice();

    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/v1/auth/login',
        data: {
          'identity': identity,
          if (inviteCode != null && inviteCode.isNotEmpty)
            'inviteCode': inviteCode,
          'device': device.toJson(),
        },
        options: Options(extra: const {'skipAuth': true}),
      );

      final payload = response.data;

      if (payload == null) {
        throw const ApiException(
          'The server returned an empty login response.',
        );
      }

      final session = AuthSession.fromEnvelope(payload);
      await _sessionStore.writeSession(session);
      await completeOnboarding();

      return session;
    } on DioException catch (error) {
      throw ApiException(
        error.message ?? 'Unable to sign in to LabGuard right now.',
      );
    }
  }

  Future<AuthSession> restoreTrustedSession() async {
    final storedSession = await _sessionStore.readSession();

    if (storedSession == null || !storedSession.isPersistable) {
      throw const ApiException('No trusted session is stored on this device.');
    }

    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/v1/auth/session',
      );
      final payload =
          response.data?['session'] as Map<String, dynamic>? ?? const {};

      final refreshedSession = storedSession.copyWith(
        viewer: AuthViewer.fromJson(
          payload['viewer'] as Map<String, dynamic>? ?? const {},
        ),
        account: AuthAccount.fromJson(
          payload['account'] as Map<String, dynamic>? ?? const {},
        ),
        device: AuthDevice.fromJson(
          payload['device'] as Map<String, dynamic>? ?? const {},
        ),
      );

      await _sessionStore.writeSession(refreshedSession);
      return refreshedSession;
    } on DioException {
      return storedSession;
    }
  }

  Future<void> logout() async {
    final storedSession = await _sessionStore.readSession();

    try {
      await _client.post<void>(
        '/v1/auth/logout',
        options: Options(
          extra: const {'skipAuth': true, 'skipRetry': true},
          headers: {
            if (storedSession != null && storedSession.accessToken.isNotEmpty)
              'Authorization': 'Bearer ${storedSession.accessToken}',
          },
        ),
      );
    } on DioException {
      // Local session clearing still takes priority.
    } finally {
      await _sessionStore.clearSession();
    }
  }
}

class AuthBootstrapResult {
  const AuthBootstrapResult({required this.stage, this.session});

  final AuthStage stage;
  final AuthSession? session;
}
