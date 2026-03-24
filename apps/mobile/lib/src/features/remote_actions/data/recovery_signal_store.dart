import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/secure_store.dart';

final recoverySignalInvalidationProvider = StateProvider<int>((ref) => 0);

final recoverySignalStoreProvider = Provider<RecoverySignalStore>((ref) {
  return RecoverySignalStore(secureStore: ref.watch(secureStoreProvider));
});

final recoverySignalProvider = FutureProvider<RecoverySignal?>((ref) async {
  ref.watch(recoverySignalInvalidationProvider);
  return ref.watch(recoverySignalStoreProvider).read();
});

class RecoverySignalStore {
  RecoverySignalStore({required SecureStore secureStore})
    : _secureStore = secureStore;

  final SecureStore _secureStore;

  static const signalKey = 'labguard.device.recovery_signal';

  Future<RecoverySignal?> read() async {
    final raw = await _secureStore.read(signalKey);

    if (raw == null || raw.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    return RecoverySignal.fromJson(decoded);
  }

  Future<void> write(RecoverySignal signal) {
    return _secureStore.write(
      key: signalKey,
      value: jsonEncode(signal.toJson()),
    );
  }

  Future<void> clear() {
    return _secureStore.delete(signalKey);
  }
}

class RecoverySignal {
  const RecoverySignal({
    required this.message,
    required this.receivedAt,
    required this.alarmRequested,
  });

  factory RecoverySignal.fromJson(Map<String, dynamic> json) {
    return RecoverySignal(
      message:
          json['message'] as String? ??
          'LabGuard recovery mode is active on this device.',
      receivedAt:
          DateTime.tryParse(json['receivedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      alarmRequested: json['alarmRequested'] as bool? ?? false,
    );
  }

  final String message;
  final DateTime receivedAt;
  final bool alarmRequested;

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'receivedAt': receivedAt.toIso8601String(),
      'alarmRequested': alarmRequested,
    };
  }
}
