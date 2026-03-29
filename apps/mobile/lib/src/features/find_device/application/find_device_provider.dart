import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/network/labguard_api_client.dart';
import '../../../core/platform/android_system_security_bridge.dart';
import '../../auth/application/auth_controller.dart';
import '../../dashboard/application/dashboard_controller.dart';
import '../../devices/application/device_registry_provider.dart';
import '../../events/application/security_events_provider.dart';
import '../domain/find_device_snapshot.dart';

final findDeviceRepositoryProvider = Provider<FindDeviceRepository>((ref) {
  return FindDeviceRepository(
    client: ref.watch(labGuardApiClientProvider),
    systemBridge: ref.watch(androidSystemSecurityBridgeProvider),
  );
});

final findDeviceSnapshotProvider =
    FutureProvider.family<FindDeviceSnapshot, String>((ref, deviceId) async {
      return ref.watch(findDeviceRepositoryProvider).fetchSnapshot(deviceId);
    });

final findDeviceControllerProvider = Provider<FindDeviceController>((ref) {
  return FindDeviceController(ref);
});

class FindDeviceRepository {
  FindDeviceRepository({
    required Dio client,
    required AndroidSystemSecurityBridge systemBridge,
  }) : _client = client,
       _systemBridge = systemBridge;

  final Dio _client;
  final AndroidSystemSecurityBridge _systemBridge;

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
    final sample = await _readLocationSample(
      source: 'MANUAL_REFRESH',
      failureMessage:
          'Location permission is required before LabGuard can refresh the device location.',
    );

    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/v1/devices/$deviceId/location',
        data: sample,
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

  Future<void> syncLostModeLocation(String deviceId) async {
    final sample = await _readLocationSample(
      source: 'LOST_MODE',
      failureMessage: null,
    );

    if (sample == null) {
      return;
    }

    try {
      await _client.post<Map<String, dynamic>>(
        '/v1/devices/$deviceId/location',
        data: sample,
      );
    } on DioException catch (error) {
      throw ApiException(
        error.message ?? 'Unable to sync the lost-mode location sample.',
      );
    }
  }

  Future<Map<String, dynamic>?> _readLocationSample({
    required String source,
    required String? failureMessage,
  }) async {
    final sample = await _systemBridge.captureLocationSample();
    if (sample == null) {
      if (failureMessage == null) {
        return null;
      }
      throw ApiException(failureMessage);
    }

    return sample.toApiJson(source: source);
  }
}

class FindDeviceController {
  FindDeviceController(this._ref);

  final Ref _ref;
  DateTime? _lastLostModeSyncAt;

  Future<FindDeviceSnapshot> requestFreshLocation(String deviceId) async {
    final snapshot = await _ref
        .read(findDeviceRepositoryProvider)
        .requestFreshLocation(deviceId);
    _invalidate(deviceId);
    return snapshot;
  }

  Future<void> syncCurrentDeviceLocationIfLostModeActive() async {
    final now = DateTime.now();
    if (_lastLostModeSyncAt != null &&
        now.difference(_lastLostModeSyncAt!) < const Duration(minutes: 2)) {
      return;
    }

    final session = _ref.read(authControllerProvider).session;
    if (session == null) {
      return;
    }

    final device = await _ref
        .read(devicesRepositoryProvider)
        .fetchDeviceDetail(session.device.id);

    if (!device.isLost) {
      return;
    }

    await _ref
        .read(findDeviceRepositoryProvider)
        .syncLostModeLocation(device.id);
    _lastLostModeSyncAt = now;
    _invalidate(device.id);
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
