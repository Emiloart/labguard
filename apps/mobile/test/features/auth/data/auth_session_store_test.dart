import 'package:flutter_test/flutter_test.dart';

import 'package:labguard/src/core/security/secure_store.dart';
import 'package:labguard/src/features/auth/data/auth_session_store.dart';
import 'package:labguard/src/features/auth/domain/auth_session.dart';
import 'package:labguard/src/features/devices/domain/device_record.dart';

void main() {
  test('persists and restores the auth session payload', () async {
    final store = AuthSessionStore(secureStore: _FakeSecureStore());
    const session = AuthSession(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresInSeconds: 900,
      viewer: AuthViewer(
        id: 'viewer-01',
        email: 'owner@emilolabs.com',
        displayName: 'Emilo Owner',
        role: 'OWNER',
      ),
      account: AuthAccount(
        id: 'acct-01',
        name: 'Emilo Labs',
        brandAttribution: 'Built by Emilo Labs',
      ),
      device: AuthDevice(
        id: 'device-01',
        name: 'Primary Pixel',
        trustState: DeviceTrustState.trusted,
      ),
    );

    await store.writeSession(session);
    final restored = await store.readSession();

    expect(restored, isNotNull);
    expect(restored!.accessToken, 'access-token');
    expect(restored.refreshToken, 'refresh-token');
    expect(restored.viewer.displayName, 'Emilo Owner');
    expect(restored.account.brandAttribution, 'Built by Emilo Labs');
    expect(restored.device.trustState, DeviceTrustState.trusted);
  });

  test('tracks onboarding completion and session clearing', () async {
    final store = AuthSessionStore(secureStore: _FakeSecureStore());
    const session = AuthSession(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresInSeconds: 900,
      viewer: AuthViewer(
        id: 'viewer-01',
        email: 'owner@emilolabs.com',
        displayName: 'Emilo Owner',
        role: 'OWNER',
      ),
      account: AuthAccount(
        id: 'acct-01',
        name: 'Emilo Labs',
        brandAttribution: 'Built by Emilo Labs',
      ),
      device: AuthDevice(
        id: 'device-01',
        name: 'Primary Pixel',
        trustState: DeviceTrustState.trusted,
      ),
    );

    expect(await store.isOnboardingComplete(), isFalse);

    await store.completeOnboarding();
    await store.writeSession(session);
    await store.clearSession();

    expect(await store.isOnboardingComplete(), isTrue);
    expect(await store.readSession(), isNull);
  });
}

class _FakeSecureStore implements SecureStore {
  final Map<String, String> _storage = <String, String>{};

  @override
  Future<void> delete(String key) async {
    _storage.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _storage.clear();
  }

  @override
  Future<String?> read(String key) async => _storage[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _storage[key] = value;
  }
}
