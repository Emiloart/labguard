import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/network/labguard_api_client.dart';
import '../../dashboard/application/dashboard_controller.dart';
import '../../events/application/security_events_provider.dart';
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

final deviceDetailProvider = FutureProvider.family<DeviceDetailRecord, String>((
  ref,
  deviceId,
) async {
  return ref.watch(devicesRepositoryProvider).fetchDeviceDetail(deviceId);
});

final deviceActionsControllerProvider = Provider<DeviceActionsController>((
  ref,
) {
  return DeviceActionsController(ref);
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
    final detail = await fetchDeviceDetail(deviceId);
    return detail;
  }

  Future<DeviceDetailRecord> fetchDeviceDetail(String deviceId) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/v1/devices/$deviceId',
      );
      final payload = response.data;

      if (payload == null) {
        throw const ApiException('The requested device could not be loaded.');
      }

      return DeviceDetailRecord.fromJson(payload);
    } on DioException catch (error) {
      throw ApiException(error.message ?? 'Unable to load the device detail.');
    }
  }

  Future<DeviceDetailRecord> updateDevice({
    required String deviceId,
    String? name,
    bool? isPrimary,
  }) async {
    try {
      final response = await _client.patch<Map<String, dynamic>>(
        '/v1/devices/$deviceId',
        data: {
          ...?(name == null ? null : {'name': name}),
          ...?(isPrimary == null ? null : {'isPrimary': isPrimary}),
        },
      );

      return DeviceDetailRecord.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw ApiException(
        error.message ?? 'Unable to update the device metadata.',
      );
    }
  }

  Future<DeviceDetailRecord> markLostMode(String deviceId) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/v1/devices/$deviceId/lost-mode',
      );
      final payload =
          response.data?['device'] as Map<String, dynamic>? ?? const {};
      return DeviceDetailRecord.fromJson(payload);
    } on DioException catch (error) {
      throw ApiException(error.message ?? 'Unable to enable lost mode.');
    }
  }

  Future<DeviceDetailRecord> markRecovered(String deviceId) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/v1/devices/$deviceId/recovered',
      );
      final payload =
          response.data?['device'] as Map<String, dynamic>? ?? const {};
      return DeviceDetailRecord.fromJson(payload);
    } on DioException catch (error) {
      throw ApiException(error.message ?? 'Unable to clear lost mode.');
    }
  }

  Future<DeviceDetailRecord> suspendDevice(String deviceId) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/v1/devices/$deviceId/suspend',
      );
      final payload =
          response.data?['device'] as Map<String, dynamic>? ?? const {};
      return DeviceDetailRecord.fromJson(payload);
    } on DioException catch (error) {
      throw ApiException(error.message ?? 'Unable to suspend the device.');
    }
  }

  Future<DeviceDetailRecord> revokeDevice(String deviceId) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/v1/devices/$deviceId/revoke',
      );
      final payload =
          response.data?['device'] as Map<String, dynamic>? ?? const {};
      return DeviceDetailRecord.fromJson(payload);
    } on DioException catch (error) {
      throw ApiException(error.message ?? 'Unable to revoke the device.');
    }
  }

  Future<DeviceDetailRecord> rotateCredentials(String deviceId) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/v1/devices/$deviceId/rotate-credentials',
      );
      final payload =
          response.data?['device'] as Map<String, dynamic>? ?? const {};
      return DeviceDetailRecord.fromJson(payload);
    } on DioException catch (error) {
      throw ApiException(
        error.message ?? 'Unable to rotate the device credentials.',
      );
    }
  }
}

class DeviceActionsController {
  DeviceActionsController(this._ref);

  final Ref _ref;

  Future<DeviceDetailRecord> renameDevice(String deviceId, String name) async {
    final detail = await _ref
        .read(devicesRepositoryProvider)
        .updateDevice(deviceId: deviceId, name: name);
    _invalidateDeviceState(deviceId);
    return detail;
  }

  Future<DeviceDetailRecord> markLostMode(String deviceId) async {
    final detail = await _ref
        .read(devicesRepositoryProvider)
        .markLostMode(deviceId);
    _invalidateDeviceState(deviceId);
    return detail;
  }

  Future<DeviceDetailRecord> markRecovered(String deviceId) async {
    final detail = await _ref
        .read(devicesRepositoryProvider)
        .markRecovered(deviceId);
    _invalidateDeviceState(deviceId);
    return detail;
  }

  Future<DeviceDetailRecord> suspendDevice(String deviceId) async {
    final detail = await _ref
        .read(devicesRepositoryProvider)
        .suspendDevice(deviceId);
    _invalidateDeviceState(deviceId);
    return detail;
  }

  Future<DeviceDetailRecord> revokeDevice(String deviceId) async {
    final detail = await _ref
        .read(devicesRepositoryProvider)
        .revokeDevice(deviceId);
    _invalidateDeviceState(deviceId);
    return detail;
  }

  Future<DeviceDetailRecord> rotateCredentials(String deviceId) async {
    final detail = await _ref
        .read(devicesRepositoryProvider)
        .rotateCredentials(deviceId);
    _invalidateDeviceState(deviceId);
    return detail;
  }

  void _invalidateDeviceState(String deviceId) {
    _ref.invalidate(deviceRegistryProvider);
    _ref.invalidate(deviceByIdProvider(deviceId));
    _ref.invalidate(deviceDetailProvider(deviceId));
    _ref.invalidate(dashboardSummaryProvider);
    _ref.invalidate(securityEventsProvider);
  }
}
