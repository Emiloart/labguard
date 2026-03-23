import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final secureStoreProvider = Provider<SecureStore>((ref) {
  return const FlutterSecureStoreAdapter();
});

abstract interface class SecureStore {
  Future<void> write({required String key, required String value});

  Future<String?> read(String key);

  Future<void> delete(String key);
}

class FlutterSecureStoreAdapter implements SecureStore {
  const FlutterSecureStoreAdapter();

  static const _storage = FlutterSecureStorage();

  @override
  Future<void> delete(String key) {
    return _storage.delete(key: key);
  }

  @override
  Future<String?> read(String key) {
    return _storage.read(key: key);
  }

  @override
  Future<void> write({required String key, required String value}) {
    return _storage.write(key: key, value: value);
  }
}
