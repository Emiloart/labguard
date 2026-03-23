import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/network/labguard_api_client.dart';
import '../../dashboard/application/dashboard_controller.dart';
import '../domain/vpn_overview.dart';

final vpnOverviewProvider = FutureProvider<VpnOverview>((ref) async {
  final summary = await ref.watch(dashboardSummaryProvider.future);
  return summary.vpnOverview;
});

final vpnRepositoryProvider = Provider<VpnRepository>((ref) {
  return VpnRepository(client: ref.watch(labGuardApiClientProvider));
});

final vpnServersProvider = FutureProvider<List<VpnServerRecord>>((ref) async {
  return ref.watch(vpnRepositoryProvider).fetchServers();
});

class VpnRepository {
  VpnRepository({required Dio client}) : _client = client;

  final Dio _client;

  Future<List<VpnServerRecord>> fetchServers() async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/v1/vpn/servers',
      );
      final items = response.data?['items'] as List<dynamic>? ?? const [];

      return items
          .whereType<Map<String, dynamic>>()
          .map(VpnServerRecord.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw ApiException(
        error.message ?? 'Unable to load the LabGuard server registry.',
      );
    }
  }
}
