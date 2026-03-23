import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/network/labguard_api_client.dart';
import '../../../core/security/secure_store.dart';
import '../domain/auth_session.dart';
import '../domain/auth_state.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    client: ref.watch(labGuardApiClientProvider),
    secureStore: ref.watch(secureStoreProvider),
  );
});

class AuthRepository {
  AuthRepository({required Dio client, required SecureStore secureStore})
    : _client = client,
      _secureStore = secureStore;

  final Dio _client;
  final SecureStore _secureStore;

  static const _onboardingKey = 'labguard.app.onboarding_complete';
  static const _sessionKey = 'labguard.auth.session';

  Future<AuthBootstrapResult> bootstrap() async {
    final onboardingComplete =
        await _secureStore.read(_onboardingKey) == boolTrue;

    if (!onboardingComplete) {
      return const AuthBootstrapResult(stage: AuthStage.onboarding);
    }

    final session = await _readStoredSession();

    if (session == null || !session.isPersistable) {
      return const AuthBootstrapResult(stage: AuthStage.signedOut);
    }

    return AuthBootstrapResult(stage: AuthStage.signedIn, session: session);
  }

  Future<void> completeOnboarding() {
    return _secureStore.write(key: _onboardingKey, value: boolTrue);
  }

  Future<AuthSession> login({
    required String identity,
    String? inviteCode,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/v1/auth/login',
        data: {
          'identity': identity,
          if (inviteCode != null && inviteCode.isNotEmpty)
            'inviteCode': inviteCode,
        },
      );

      final payload = response.data;

      if (payload == null) {
        throw const ApiException(
          'The server returned an empty login response.',
        );
      }

      final session = AuthSession.fromEnvelope(payload);
      await _persistSession(session);
      await completeOnboarding();

      return session;
    } on DioException catch (error) {
      throw ApiException(
        error.message ?? 'Unable to sign in to LabGuard right now.',
      );
    }
  }

  Future<AuthSession> restoreTrustedSession() async {
    final storedSession = await _readStoredSession();

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

      await _persistSession(refreshedSession);
      return refreshedSession;
    } on DioException {
      return storedSession;
    }
  }

  Future<void> logout() async {
    try {
      await _client.post<void>('/v1/auth/logout');
    } on DioException {
      // Local session clearing still takes priority.
    } finally {
      await _secureStore.delete(_sessionKey);
    }
  }

  Future<AuthSession?> _readStoredSession() async {
    final rawSession = await _secureStore.read(_sessionKey);

    if (rawSession == null || rawSession.isEmpty) {
      return null;
    }

    final payload = jsonDecode(rawSession) as Map<String, dynamic>;
    return AuthSession.fromStoredJson(payload);
  }

  Future<void> _persistSession(AuthSession session) {
    return _secureStore.write(
      key: _sessionKey,
      value: jsonEncode(session.toJson()),
    );
  }
}

class AuthBootstrapResult {
  const AuthBootstrapResult({required this.stage, this.session});

  final AuthStage stage;
  final AuthSession? session;
}

const boolTrue = 'true';
