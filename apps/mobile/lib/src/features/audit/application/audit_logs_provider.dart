import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/network/labguard_api_client.dart';
import '../domain/audit_log_record.dart';

final auditLogsRepositoryProvider = Provider<AuditLogsRepository>((ref) {
  return AuditLogsRepository(client: ref.watch(labGuardApiClientProvider));
});

final auditLogsProvider = FutureProvider<List<AuditLogRecord>>((ref) async {
  return ref.watch(auditLogsRepositoryProvider).fetchAuditLogs();
});

class AuditLogsRepository {
  AuditLogsRepository({required Dio client}) : _client = client;

  final Dio _client;

  Future<List<AuditLogRecord>> fetchAuditLogs() async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/v1/admin/audit-logs',
      );
      final items = response.data?['items'] as List<dynamic>? ?? const [];

      return items
          .whereType<Map<String, dynamic>>()
          .map(AuditLogRecord.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw ApiException(
        error.message ?? 'Unable to load the audit log trail.',
      );
    }
  }
}
