import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/network/labguard_api_client.dart';
import '../../dashboard/application/dashboard_controller.dart';
import '../../devices/application/device_registry_provider.dart';
import '../../events/application/security_events_provider.dart';
import '../domain/remote_command_record.dart';

final remoteActionsRepositoryProvider = Provider<RemoteActionsRepository>((
  ref,
) {
  return RemoteActionsRepository(client: ref.watch(labGuardApiClientProvider));
});

final remoteCommandsProvider =
    FutureProvider.family<List<RemoteCommandRecord>, String>((ref, deviceId) {
      return ref.watch(remoteActionsRepositoryProvider).fetchCommands(deviceId);
    });

final remoteActionsControllerProvider = Provider<RemoteActionsController>((
  ref,
) {
  return RemoteActionsController(ref);
});

class RemoteActionsRepository {
  RemoteActionsRepository({required Dio client}) : _client = client;

  final Dio _client;

  Future<List<RemoteCommandRecord>> fetchCommands(String deviceId) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/v1/remote-actions/$deviceId',
      );
      final items = response.data?['items'] as List<dynamic>? ?? const [];

      return items
          .whereType<Map<String, dynamic>>()
          .map(RemoteCommandRecord.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw ApiException(
        error.message ?? 'Unable to load remote action history.',
      );
    }
  }

  Future<RemoteCommandRecord> queueCommand({
    required String deviceId,
    required RemoteCommandType commandType,
    String? message,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/v1/remote-actions/$deviceId',
        data: {
          'commandType': _commandTypeToWire(commandType),
          if (message != null && message.isNotEmpty) 'message': message,
        },
      );

      return RemoteCommandRecord.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw ApiException(error.message ?? 'Unable to queue the remote action.');
    }
  }

  Future<RemoteCommandRecord> retryCommand(String commandId) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/v1/remote-actions/$commandId/retry',
      );

      return RemoteCommandRecord.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw ApiException(error.message ?? 'Unable to retry the remote action.');
    }
  }

  Future<RemoteCommandRecord> reportResult({
    required String commandId,
    RemoteCommandStatus status = RemoteCommandStatus.succeeded,
    String? resultMessage,
    String? failureCode,
    String? bearerToken,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/v1/remote-actions/$commandId/result',
        data: {
          'status': _commandStatusToWire(status),
          if (resultMessage != null && resultMessage.isNotEmpty)
            'resultMessage': resultMessage,
          if (failureCode != null && failureCode.isNotEmpty)
            'failureCode': failureCode,
        },
        options: Options(
          extra: {if (bearerToken != null) 'skipAuth': true, 'skipRetry': true},
          headers: {
            if (bearerToken != null) 'Authorization': 'Bearer $bearerToken',
          },
        ),
      );

      return RemoteCommandRecord.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw ApiException(
        error.message ?? 'Unable to record the remote action result.',
      );
    }
  }

  String _commandTypeToWire(RemoteCommandType type) {
    switch (type) {
      case RemoteCommandType.signOut:
        return 'SIGN_OUT';
      case RemoteCommandType.revokeVpn:
        return 'REVOKE_VPN';
      case RemoteCommandType.rotateSession:
        return 'ROTATE_SESSION';
      case RemoteCommandType.wipeAppData:
        return 'WIPE_APP_DATA';
      case RemoteCommandType.ringAlarm:
        return 'RING_ALARM';
      case RemoteCommandType.showRecoveryMessage:
        return 'SHOW_RECOVERY_MESSAGE';
      case RemoteCommandType.markRecovered:
        return 'MARK_RECOVERED';
      case RemoteCommandType.disableDeviceAccess:
        return 'DISABLE_DEVICE_ACCESS';
    }
  }

  String _commandStatusToWire(RemoteCommandStatus status) {
    switch (status) {
      case RemoteCommandStatus.delivered:
        return 'DELIVERED';
      case RemoteCommandStatus.succeeded:
        return 'SUCCEEDED';
      case RemoteCommandStatus.failed:
        return 'FAILED';
      case RemoteCommandStatus.queued:
        return 'QUEUED';
    }
  }
}

class RemoteActionsController {
  RemoteActionsController(this._ref);

  final Ref _ref;

  Future<RemoteCommandRecord> queueCommand({
    required String deviceId,
    required RemoteCommandType commandType,
    String? message,
  }) async {
    final command = await _ref
        .read(remoteActionsRepositoryProvider)
        .queueCommand(
          deviceId: deviceId,
          commandType: commandType,
          message: message,
        );

    _invalidateState(deviceId);
    return command;
  }

  Future<RemoteCommandRecord> retryCommand({
    required String deviceId,
    required String commandId,
  }) async {
    final command = await _ref
        .read(remoteActionsRepositoryProvider)
        .retryCommand(commandId);

    _invalidateState(deviceId);
    return command;
  }

  Future<RemoteCommandRecord> reportCommandResult({
    required String deviceId,
    required String commandId,
    required RemoteCommandStatus status,
    String? resultMessage,
    String? failureCode,
    String? bearerToken,
  }) async {
    final command = await _ref
        .read(remoteActionsRepositoryProvider)
        .reportResult(
          commandId: commandId,
          status: status,
          resultMessage: resultMessage,
          failureCode: failureCode,
          bearerToken: bearerToken,
        );

    _invalidateState(deviceId);
    return command;
  }

  void _invalidateState(String deviceId) {
    _ref.invalidate(remoteCommandsProvider(deviceId));
    _ref.invalidate(deviceRegistryProvider);
    _ref.invalidate(deviceByIdProvider(deviceId));
    _ref.invalidate(deviceDetailProvider(deviceId));
    _ref.invalidate(securityEventsProvider);
    _ref.invalidate(dashboardSummaryProvider);
  }
}
