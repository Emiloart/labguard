import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/network/labguard_api_client.dart';
import '../domain/security_event_record.dart';

final securityEventsRepositoryProvider = Provider<SecurityEventsRepository>((
  ref,
) {
  return SecurityEventsRepository(client: ref.watch(labGuardApiClientProvider));
});

final securityEventsProvider = FutureProvider<List<SecurityEventRecord>>((
  ref,
) async {
  return ref.watch(securityEventsRepositoryProvider).fetchEvents();
});

final securityEventsControllerProvider = Provider<SecurityEventsController>((
  ref,
) {
  return SecurityEventsController(ref);
});

class SecurityEventsRepository {
  SecurityEventsRepository({required Dio client}) : _client = client;

  final Dio _client;

  Future<List<SecurityEventRecord>> fetchEvents() async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/v1/security-events',
      );
      final items = response.data?['items'] as List<dynamic>? ?? const [];

      return items
          .whereType<Map<String, dynamic>>()
          .map(SecurityEventRecord.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw ApiException(
        error.message ?? 'Unable to load LabGuard security events.',
      );
    }
  }

  Future<void> markRead(String eventId) async {
    try {
      await _client.post<Map<String, dynamic>>(
        '/v1/security-events/$eventId/read',
      );
    } on DioException catch (error) {
      throw ApiException(
        error.message ?? 'Unable to mark the security event as read.',
      );
    }
  }
}

class SecurityEventsController {
  SecurityEventsController(this._ref);

  final Ref _ref;

  Future<void> markRead(String eventId) async {
    await _ref.read(securityEventsRepositoryProvider).markRead(eventId);
    _ref.invalidate(securityEventsProvider);
  }
}
