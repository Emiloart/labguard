import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/network/labguard_api_client.dart';
import '../../dashboard/application/dashboard_controller.dart';
import '../../devices/application/device_registry_provider.dart';
import '../../events/application/security_events_provider.dart';
import '../domain/find_device_snapshot.dart';

final findDeviceRepositoryProvider = Provider<FindDeviceRepository>((ref) {
  return FindDeviceRepository(client: ref.watch(labGuardApiClientProvider));
});

final findDeviceSnapshotProvider =
    FutureProvider.family<FindDeviceSnapshot, String>((ref, deviceId) async {
      return ref.watch(findDeviceRepositoryProvider).fetchSnapshot(deviceId);
    });

final findDeviceControllerProvider = Provider<FindDeviceController>((ref) {
  return FindDeviceController(ref);
});

class FindDeviceRepository {
  FindDeviceRepository({required Dio client}) : _client = client;

  final Dio _client;

  Future<FindDeviceSnapshot> fetchSnapshot(String deviceId) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/v1/devices/$deviceId/locations',
      );

      return FindDeviceSnapshot.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw ApiException(
        error.message ?? 'Unable to load the find-device snapshot.',
      );
    }
  }

  Future<FindDeviceSnapshot> requestFreshLocation(String deviceId) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/v1/devices/$deviceId/location',
      );
      final payload =
          response.data?['location'] as Map<String, dynamic>? ?? const {};

      return FindDeviceSnapshot.fromJson(payload);
    } on DioException catch (error) {
      throw ApiException(
        error.message ?? 'Unable to request a fresh location sample.',
      );
    }
  }
}

class FindDeviceController {
  FindDeviceController(this._ref);

  final Ref _ref;

  Future<FindDeviceSnapshot> requestFreshLocation(String deviceId) async {
    final snapshot = await _ref
        .read(findDeviceRepositoryProvider)
        .requestFreshLocation(deviceId);
    _invalidate(deviceId);
    return snapshot;
  }

  void _invalidate(String deviceId) {
    _ref.invalidate(findDeviceSnapshotProvider(deviceId));
    _ref.invalidate(deviceDetailProvider(deviceId));
    _ref.invalidate(deviceByIdProvider(deviceId));
    _ref.invalidate(deviceRegistryProvider);
    _ref.invalidate(securityEventsProvider);
    _ref.invalidate(dashboardSummaryProvider);
  }
}
