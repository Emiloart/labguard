import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/android_background_runtime_bridge.dart';
import '../../../core/platform/android_vpn_bridge.dart';
import '../../../core/security/secure_store.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_session_store.dart';
import '../../auth/domain/auth_session.dart';
import '../../dashboard/application/dashboard_controller.dart';
import '../../devices/application/device_registry_provider.dart';
import '../../events/application/security_events_provider.dart';
import '../../vpn/application/vpn_session_controller.dart';
import '../data/recovery_signal_store.dart';
import '../domain/remote_command_record.dart';
import 'remote_actions_provider.dart';

final remoteCommandRuntimeProvider = Provider<RemoteCommandRuntime>((ref) {
  return RemoteCommandRuntime(ref);
});

class RemoteCommandRuntime {
  RemoteCommandRuntime(this._ref);

  final Ref _ref;
  bool _syncInFlight = false;
  final Set<String> _processing = <String>{};

  Future<void> synchronizeCurrentDevice() async {
    final session = _ref.read(authControllerProvider).session;

    if (_syncInFlight || session == null) {
      return;
    }

    _syncInFlight = true;

    try {
      final commands = await _ref
          .read(remoteActionsRepositoryProvider)
          .fetchCommands(session.device.id);

      for (final command in commands) {
        if (!command.isPending || _processing.contains(command.commandId)) {
          continue;
        }

        await _executeCommand(session, command);
      }
    } finally {
      _syncInFlight = false;
    }
  }

  Future<void> _executeCommand(
    AuthSession session,
    RemoteCommandRecord command,
  ) async {
    _processing.add(command.commandId);

    try {
      if (command.status == RemoteCommandStatus.queued) {
        await _ref
            .read(remoteActionsControllerProvider)
            .reportCommandResult(
              deviceId: command.deviceId,
              commandId: command.commandId,
              status: RemoteCommandStatus.delivered,
              resultMessage: _deliveryMessage(command),
              bearerToken: session.accessToken,
            );
      }

      final outcome = await _performLocalAction(session, command);

      await _ref
          .read(remoteActionsControllerProvider)
          .reportCommandResult(
            deviceId: command.deviceId,
            commandId: command.commandId,
            status: outcome.status,
            resultMessage: outcome.resultMessage,
            bearerToken: session.accessToken,
          );

      if (outcome.afterReport != null) {
        await outcome.afterReport!.call();
      }
    } catch (error) {
      final message = error.toString();

      try {
        await _ref
            .read(remoteActionsControllerProvider)
            .reportCommandResult(
              deviceId: command.deviceId,
              commandId: command.commandId,
              status: RemoteCommandStatus.failed,
              resultMessage: message,
              failureCode: 'LOCAL_ACTION_FAILED',
              bearerToken: session.accessToken,
            );
      } catch (_) {
        // The runtime will retry on the next synchronization cycle.
      }
    } finally {
      _processing.remove(command.commandId);
    }
  }

  Future<_CommandExecutionOutcome> _performLocalAction(
    AuthSession session,
    RemoteCommandRecord command,
  ) async {
    switch (command.commandType) {
      case RemoteCommandType.signOut:
        await _disconnectAndClearProfile(session.device.id);
        return _CommandExecutionOutcome(
          status: RemoteCommandStatus.succeeded,
          resultMessage:
              'LabGuard signed this device out and cleared VPN access.',
          afterReport: _clearSessionOnly,
        );
      case RemoteCommandType.revokeVpn:
        await _disconnectAndClearProfile(session.device.id);
        return const _CommandExecutionOutcome(
          status: RemoteCommandStatus.succeeded,
          resultMessage:
              'The local WireGuard profile was removed and the tunnel was stopped.',
        );
      case RemoteCommandType.rotateSession:
        await _disconnectAndClearProfile(session.device.id);
        return _CommandExecutionOutcome(
          status: RemoteCommandStatus.succeeded,
          resultMessage:
              'Local session material was rotated and this device must authenticate again.',
          afterReport: _clearSessionOnly,
        );
      case RemoteCommandType.wipeAppData:
        await _disconnectAndClearProfile(session.device.id);
        return _CommandExecutionOutcome(
          status: RemoteCommandStatus.succeeded,
          resultMessage:
              'LabGuard cleared locally stored session, VPN, and recovery data.',
          afterReport: _wipeLocalState,
        );
      case RemoteCommandType.ringAlarm:
        await _storeRecoverySignal(
          message:
              command.message ??
              'LabGuard recovery mode is active. This device was asked to ring for recovery.',
          alarmRequested: true,
        );
        await SystemSound.play(SystemSoundType.alert);
        await HapticFeedback.heavyImpact();
        return const _CommandExecutionOutcome(
          status: RemoteCommandStatus.succeeded,
          resultMessage:
              'An in-app recovery alarm was triggered on the device.',
        );
      case RemoteCommandType.showRecoveryMessage:
        await _storeRecoverySignal(
          message:
              command.message ??
              'LabGuard owner is attempting recovery. Follow the recovery instructions on screen.',
          alarmRequested: false,
        );
        return _CommandExecutionOutcome(
          status: RemoteCommandStatus.succeeded,
          resultMessage:
              command.message ??
              'Recovery messaging was stored for the device.',
        );
      case RemoteCommandType.markRecovered:
        await _clearRecoverySignal();
        return const _CommandExecutionOutcome(
          status: RemoteCommandStatus.succeeded,
          resultMessage:
              'Local recovery indicators were cleared on the device.',
        );
      case RemoteCommandType.disableDeviceAccess:
        await _disconnectAndClearProfile(session.device.id);
        return _CommandExecutionOutcome(
          status: RemoteCommandStatus.succeeded,
          resultMessage:
              'Local LabGuard access was disabled and the device must be reapproved.',
          afterReport: _clearSessionOnly,
        );
    }
  }

  Future<void> _disconnectAndClearProfile(String deviceId) async {
    await _ref
        .read(androidBackgroundRuntimeBridgeProvider)
        .setVpnConnectionIntent(desiredConnected: false);

    try {
      await _ref.read(androidVpnBridgeProvider).disconnect();
    } catch (_) {
      // Local profile clearing still needs to proceed.
    }

    try {
      await _ref.read(androidVpnBridgeProvider).clearProfile();
    } catch (_) {
      // If the native profile is already gone, the secure store still needs clearing.
    }

    await _ref.read(secureStoreProvider).delete(_profileStorageKey(deviceId));
    _invalidateLocalState(deviceId);
  }

  Future<void> _clearSessionOnly() async {
    await _ref.read(authSessionStoreProvider).clearSession();
    _ref.read(authSessionInvalidationProvider.notifier).state++;
  }

  Future<void> _wipeLocalState() async {
    await _ref.read(secureStoreProvider).deleteAll();
    _ref.read(recoverySignalInvalidationProvider.notifier).state++;
    _ref.read(authSessionInvalidationProvider.notifier).state++;
  }

  Future<void> _storeRecoverySignal({
    required String message,
    required bool alarmRequested,
  }) async {
    await _ref
        .read(recoverySignalStoreProvider)
        .write(
          RecoverySignal(
            message: message,
            receivedAt: DateTime.now().toUtc(),
            alarmRequested: alarmRequested,
          ),
        );
    _ref.read(recoverySignalInvalidationProvider.notifier).state++;
    _invalidateGlobalState();
  }

  Future<void> _clearRecoverySignal() async {
    await _ref.read(recoverySignalStoreProvider).clear();
    _ref.read(recoverySignalInvalidationProvider.notifier).state++;
    _invalidateGlobalState();
  }

  void _invalidateLocalState(String deviceId) {
    _ref.invalidate(vpnSessionControllerProvider);
    _ref.invalidate(remoteCommandsProvider(deviceId));
    _invalidateGlobalState();
  }

  void _invalidateGlobalState() {
    _ref.invalidate(dashboardSummaryProvider);
    _ref.invalidate(deviceRegistryProvider);
    _ref.invalidate(securityEventsProvider);
  }

  String _deliveryMessage(RemoteCommandRecord command) {
    switch (command.commandType) {
      case RemoteCommandType.ringAlarm:
        return 'The device acknowledged the recovery alarm request.';
      case RemoteCommandType.showRecoveryMessage:
        return 'The device accepted the recovery message for display.';
      case RemoteCommandType.signOut:
      case RemoteCommandType.rotateSession:
      case RemoteCommandType.disableDeviceAccess:
      case RemoteCommandType.wipeAppData:
      case RemoteCommandType.revokeVpn:
      case RemoteCommandType.markRecovered:
        return 'The device acknowledged the remote security action.';
    }
  }

  String _profileStorageKey(String deviceId) =>
      'labguard.vpn.profile.$deviceId';
}

class _CommandExecutionOutcome {
  const _CommandExecutionOutcome({
    required this.status,
    required this.resultMessage,
    this.afterReport,
  });

  final RemoteCommandStatus status;
  final String resultMessage;
  final Future<void> Function()? afterReport;
}
