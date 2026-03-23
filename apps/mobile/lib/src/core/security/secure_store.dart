import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
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
  static final Map<String, String> _fallbackStore = <String, String>{};

  @override
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } on MissingPluginException {
      _fallbackStore.remove(key);
    }
  }

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } on MissingPluginException {
      return _fallbackStore[key];
    }
  }

  @override
  Future<void> write({required String key, required String value}) async {
    try {
      await _storage.write(key: key, value: value);
    } on MissingPluginException {
      _fallbackStore[key] = value;
    }
  }
}
