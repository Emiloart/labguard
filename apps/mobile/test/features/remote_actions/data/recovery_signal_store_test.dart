import 'package:flutter_test/flutter_test.dart';

import 'package:labguard/src/core/security/secure_store.dart';
import 'package:labguard/src/features/remote_actions/data/recovery_signal_store.dart';

void main() {
  test('persists and clears recovery signals', () async {
    final store = RecoverySignalStore(secureStore: _FakeSecureStore());
    final signal = RecoverySignal(
      message: 'LabGuard recovery mode is active.',
      receivedAt: DateTime.parse('2026-03-24T10:30:00.000Z'),
      alarmRequested: true,
    );

    await store.write(signal);
    final restored = await store.read();
    await store.clear();

    expect(restored, isNotNull);
    expect(restored!.message, 'LabGuard recovery mode is active.');
    expect(restored.alarmRequested, isTrue);
    expect(await store.read(), isNull);
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
