import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/secure_store.dart';
import '../domain/auth_session.dart';

final authSessionInvalidationProvider = StateProvider<int>((ref) => 0);

final authSessionStoreProvider = Provider<AuthSessionStore>((ref) {
  return AuthSessionStore(secureStore: ref.watch(secureStoreProvider));
});

class AuthSessionStore {
  AuthSessionStore({required SecureStore secureStore})
    : _secureStore = secureStore;

  final SecureStore _secureStore;

  static const onboardingKey = 'labguard.app.onboarding_complete';
  static const sessionKey = 'labguard.auth.session';
  static const _boolTrue = 'true';

  Future<bool> isOnboardingComplete() async {
    return await _secureStore.read(onboardingKey) == _boolTrue;
  }

  Future<void> completeOnboarding() {
    return _secureStore.write(key: onboardingKey, value: _boolTrue);
  }

  Future<AuthSession?> readSession() async {
    final rawSession = await _secureStore.read(sessionKey);

    if (rawSession == null || rawSession.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(rawSession);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    return AuthSession.fromStoredJson(decoded);
  }

  Future<void> writeSession(AuthSession session) {
    return _secureStore.write(
      key: sessionKey,
      value: jsonEncode(session.toJson()),
    );
  }

  Future<void> clearSession() {
    return _secureStore.delete(sessionKey);
  }
}
