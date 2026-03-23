import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/network/labguard_api_client.dart';
import '../domain/dashboard_summary.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(client: ref.watch(labGuardApiClientProvider));
});

class DashboardRepository {
  DashboardRepository({required Dio client}) : _client = client;

  final Dio _client;

  Future<DashboardSummary> fetchSummary() async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/v1/dashboard/summary',
      );

      final payload = response.data;

      if (payload == null) {
        throw const ApiException('The LabGuard dashboard summary was empty.');
      }

      return DashboardSummary.fromJson(payload);
    } on DioException catch (error) {
      throw ApiException(
        error.message ?? 'Unable to load the LabGuard dashboard.',
      );
    }
  }
}
