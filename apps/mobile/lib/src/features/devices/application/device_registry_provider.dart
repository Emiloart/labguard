import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/network/labguard_api_client.dart';
import '../domain/device_record.dart';

final devicesRepositoryProvider = Provider<DevicesRepository>((ref) {
  return DevicesRepository(client: ref.watch(labGuardApiClientProvider));
});

final deviceRegistryProvider = FutureProvider<List<DeviceRecord>>((ref) async {
  return ref.watch(devicesRepositoryProvider).fetchDevices();
});

final deviceByIdProvider = FutureProvider.family<DeviceRecord, String>((
  ref,
  deviceId,
) async {
  return ref.watch(devicesRepositoryProvider).fetchDevice(deviceId);
});

class DevicesRepository {
  DevicesRepository({required Dio client}) : _client = client;

  final Dio _client;

  Future<List<DeviceRecord>> fetchDevices() async {
    try {
      final response = await _client.get<Map<String, dynamic>>('/v1/devices');
      final items = response.data?['items'] as List<dynamic>? ?? const [];

      return items
          .whereType<Map<String, dynamic>>()
          .map(DeviceRecord.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw ApiException(
        error.message ?? 'Unable to load the device registry.',
      );
    }
  }

  Future<DeviceRecord> fetchDevice(String deviceId) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/v1/devices/$deviceId',
      );
      final payload = response.data;

      if (payload == null) {
        throw const ApiException('The requested device could not be loaded.');
      }

      return DeviceRecord.fromJson(payload);
    } on DioException catch (error) {
      throw ApiException(error.message ?? 'Unable to load the device detail.');
    }
  }
}
