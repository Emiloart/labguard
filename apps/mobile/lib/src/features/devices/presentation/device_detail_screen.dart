import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_panel.dart';
import '../../../core/widgets/state_panels.dart';
import '../../../core/widgets/status_badge.dart';
import '../../remote_actions/application/remote_actions_provider.dart';
import '../../remote_actions/domain/remote_command_record.dart';
import '../application/device_registry_provider.dart';
import '../domain/device_record.dart';

class DeviceDetailScreen extends ConsumerStatefulWidget {
  const DeviceDetailScreen({super.key, required this.deviceId});

  final String deviceId;

  @override
  ConsumerState<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends ConsumerState<DeviceDetailScreen> {
  String? _busyAction;

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(deviceDetailProvider(widget.deviceId));
    final commands = ref.watch(remoteCommandsProvider(widget.deviceId));

    if (detail.isLoading || commands.isLoading) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 120),
        children: const [LoadingPanel(label: 'Loading device detail')],
      );
    }

    final firstError = detail.error ?? commands.error;

    if (firstError != null &&
        (detail.valueOrNull == null || commands.valueOrNull == null)) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 120),
        children: [
          ErrorPanel(
            message: firstError.toString(),
            onRetry: () {
              ref.invalidate(deviceDetailProvider(widget.deviceId));
              ref.invalidate(remoteCommandsProvider(widget.deviceId));
            },
          ),
        ],
      );
    }

    final device = detail.valueOrNull!;
    final commandItems = commands.valueOrNull ?? const <RemoteCommandRecord>[];
    final dateFormat = DateFormat('MMM d, yyyy • HH:mm');

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 120),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => context.go('/devices'),
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                device.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            IconButton(
              onPressed: _busyAction == null
                  ? () => _renameDevice(context, device)
                  : null,
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusBadge(
                    label: _trustLabel(device.trustState),
                    color: _trustColor(device.trustState),
                  ),
                  StatusBadge(
                    label: device.isLost ? 'Lost mode' : 'Normal',
                    color: device.isLost
                        ? LabGuardColors.warning
                        : LabGuardColors.success,
                  ),
                  if (device.isPrimary)
                    const StatusBadge(
                      label: 'Primary',
                      color: LabGuardColors.accent,
                    ),
                ],
              ),
              const SizedBox(height: 18),
              _DetailRow(label: 'Model', value: device.model),
              _DetailRow(label: 'Platform', value: device.platform),
              _DetailRow(label: 'App version', value: device.appVersion),
              _DetailRow(
                label: 'Last active',
                value: dateFormat.format(device.lastActiveAt),
              ),
              _DetailRow(label: 'Battery', value: '${device.batteryLevel}%'),
              _DetailRow(
                label: 'Current VPN state',
                value: _vpnLabel(device.vpnStatus),
              ),
              _DetailRow(label: 'Last known IP', value: device.lastKnownIp),
              _DetailRow(label: 'Last network', value: device.lastKnownNetwork),
              _DetailRow(
                label: 'Last known location',
                value: device.lastKnownLocation,
              ),
              _DetailRow(
                label: 'Location timestamp',
                value: dateFormat.format(device.locationCapturedAt),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Security Controls',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.tonal(
                    onPressed: _busyAction == null
                        ? () => context.go('/devices/${device.id}/find')
                        : null,
                    child: const Text('Open Find Device'),
                  ),
                  FilledButton.tonal(
                    onPressed: _busyAction == null
                        ? () => _runDeviceAction(
                            label: 'rotate credentials',
                            action: () => ref
                                .read(deviceActionsControllerProvider)
                                .rotateCredentials(device.id),
                            successMessage:
                                'Device credentials rotated. Reconnect required.',
                          )
                        : null,
                    child: _ActionLabel(
                      busy: _busyAction == 'rotate credentials',
                      label: 'Rotate Credentials',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _busyAction == null
                        ? () => _confirmAndRun(
                            title: 'Suspend device?',
                            message:
                                'Suspending the device immediately pauses trusted access until you reapprove it.',
                            label: 'suspend device',
                            action: () => ref
                                .read(deviceActionsControllerProvider)
                                .suspendDevice(device.id),
                            successMessage: 'Device suspended.',
                          )
                        : null,
                    child: _ActionLabel(
                      busy: _busyAction == 'suspend device',
                      label: 'Suspend Device',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _busyAction == null
                        ? () => _confirmAndRun(
                            title: 'Revoke device access?',
                            message:
                                'This revokes device trust and VPN access. The device will require a fresh approval path.',
                            label: 'revoke device',
                            action: () => ref
                                .read(deviceActionsControllerProvider)
                                .revokeDevice(device.id),
                            successMessage: 'Device access revoked.',
                          )
                        : null,
                    child: _ActionLabel(
                      busy: _busyAction == 'revoke device',
                      label: 'Revoke Device',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Remote Commands',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton(
                    onPressed: _busyAction == null
                        ? () => _runRemoteCommand(
                            label: 'ring alarm',
                            commandType: RemoteCommandType.ringAlarm,
                            successMessage: 'Ring/alarm command completed.',
                            resultMessage:
                                'Alarm request delivered to the device.',
                          )
                        : null,
                    child: _ActionLabel(
                      busy: _busyAction == 'ring alarm',
                      label: 'Ring Alarm',
                    ),
                  ),
                  FilledButton(
                    onPressed: _busyAction == null
                        ? () => _runRemoteCommand(
                            label: 'remote sign out',
                            commandType: RemoteCommandType.signOut,
                            successMessage: 'Remote sign-out completed.',
                            resultMessage:
                                'Active sessions on the device were revoked.',
                          )
                        : null,
                    child: _ActionLabel(
                      busy: _busyAction == 'remote sign out',
                      label: 'Remote Sign Out',
                    ),
                  ),
                  FilledButton(
                    onPressed: _busyAction == null
                        ? () => _sendRecoveryMessage()
                        : null,
                    child: _ActionLabel(
                      busy: _busyAction == 'recovery message',
                      label: 'Recovery Message',
                    ),
                  ),
                ],
              ),
              if (commandItems.isNotEmpty) ...[
                const SizedBox(height: 18),
                for (final command in commandItems) ...[
                  _CommandRow(command: command),
                  if (command != commandItems.last) const SizedBox(height: 12),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Security History',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 18),
              for (final entry in device.securityHistory) ...[
                _HistoryRow(entry: entry),
                if (entry != device.securityHistory.last)
                  const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _renameDevice(
    BuildContext context,
    DeviceDetailRecord device,
  ) async {
    final controller = TextEditingController(text: device.name);
    final renamed = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: LabGuardColors.panel,
        title: const Text('Rename device'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Device label'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (renamed == null || renamed.isEmpty || renamed == device.name) {
      return;
    }

    await _runDeviceAction(
      label: 'rename device',
      action: () => ref
          .read(deviceActionsControllerProvider)
          .renameDevice(device.id, renamed),
      successMessage: 'Device renamed.',
    );
  }

  Future<void> _confirmAndRun({
    required String title,
    required String message,
    required String label,
    required Future<Object?> Function() action,
    required String successMessage,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: LabGuardColors.panel,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await _runAction(
      label: label,
      action: action,
      successMessage: successMessage,
    );
  }

  Future<void> _runDeviceAction({
    required String label,
    required Future<DeviceDetailRecord> Function() action,
    required String successMessage,
  }) {
    return _runAction(
      label: label,
      action: () async {
        await action();
        return null;
      },
      successMessage: successMessage,
    );
  }

  Future<void> _runRemoteCommand({
    required String label,
    required RemoteCommandType commandType,
    required String successMessage,
    required String resultMessage,
    String? message,
  }) {
    return _runAction(
      label: label,
      action: () async {
        await ref
            .read(remoteActionsControllerProvider)
            .queueAndComplete(
              deviceId: widget.deviceId,
              commandType: commandType,
              message: message,
              resultMessage: resultMessage,
            );
        return null;
      },
      successMessage: successMessage,
    );
  }

  Future<void> _sendRecoveryMessage() async {
    final controller = TextEditingController(
      text:
          'LabGuard owner is attempting recovery. Please call the number shown.',
    );
    final message = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: LabGuardColors.panel,
        title: const Text('Recovery message'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Message shown on the device',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (message == null || message.isEmpty) {
      return;
    }

    await _runRemoteCommand(
      label: 'recovery message',
      commandType: RemoteCommandType.showRecoveryMessage,
      message: message,
      successMessage: 'Recovery message displayed.',
      resultMessage: message,
    );
  }

  Future<void> _runAction({
    required String label,
    required Future<Object?> Function() action,
    required String successMessage,
  }) async {
    setState(() {
      _busyAction = label;
    });

    try {
      await action();
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _busyAction = null;
        });
      }
    }
  }

  String _trustLabel(DeviceTrustState trustState) {
    switch (trustState) {
      case DeviceTrustState.trusted:
        return 'Trusted';
      case DeviceTrustState.pendingApproval:
        return 'Pending approval';
      case DeviceTrustState.suspended:
        return 'Suspended';
      case DeviceTrustState.revoked:
        return 'Revoked';
    }
  }

  Color _trustColor(DeviceTrustState trustState) {
    switch (trustState) {
      case DeviceTrustState.trusted:
        return LabGuardColors.success;
      case DeviceTrustState.pendingApproval:
        return LabGuardColors.warning;
      case DeviceTrustState.suspended:
        return LabGuardColors.warning;
      case DeviceTrustState.revoked:
        return LabGuardColors.danger;
    }
  }

  String _vpnLabel(DeviceConnectivityStatus status) {
    switch (status) {
      case DeviceConnectivityStatus.connected:
        return 'Connected';
      case DeviceConnectivityStatus.disconnected:
        return 'Offline';
      case DeviceConnectivityStatus.degraded:
        return 'Degraded';
    }
  }
}

class _ActionLabel extends StatelessWidget {
  const _ActionLabel({required this.busy, required this.label});

  final bool busy;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (busy) ...[
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
        ],
        Text(label),
      ],
    );
  }
}

class _CommandRow extends StatelessWidget {
  const _CommandRow({required this.command});

  final RemoteCommandRecord command;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM d, HH:mm');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: LabGuardColors.panelElevated,
        border: Border.all(color: LabGuardColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _commandLabel(command.commandType),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              StatusBadge(
                label: _commandStatusLabel(command.status),
                color: _commandStatusColor(command.status),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            command.resultMessage ??
                command.message ??
                'Remote action queued through the LabGuard control plane.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            formatter.format(command.completedAt ?? command.queuedAt),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  static String _commandLabel(RemoteCommandType type) {
    switch (type) {
      case RemoteCommandType.signOut:
        return 'Remote sign out';
      case RemoteCommandType.revokeVpn:
        return 'Revoke VPN';
      case RemoteCommandType.rotateSession:
        return 'Rotate session';
      case RemoteCommandType.wipeAppData:
        return 'Wipe app data';
      case RemoteCommandType.ringAlarm:
        return 'Ring alarm';
      case RemoteCommandType.showRecoveryMessage:
        return 'Recovery message';
      case RemoteCommandType.markRecovered:
        return 'Mark recovered';
      case RemoteCommandType.disableDeviceAccess:
        return 'Disable device access';
    }
  }

  static String _commandStatusLabel(RemoteCommandStatus status) {
    switch (status) {
      case RemoteCommandStatus.delivered:
        return 'Delivered';
      case RemoteCommandStatus.succeeded:
        return 'Succeeded';
      case RemoteCommandStatus.failed:
        return 'Failed';
      case RemoteCommandStatus.queued:
        return 'Queued';
    }
  }

  static Color _commandStatusColor(RemoteCommandStatus status) {
    switch (status) {
      case RemoteCommandStatus.delivered:
        return LabGuardColors.accent;
      case RemoteCommandStatus.succeeded:
        return LabGuardColors.success;
      case RemoteCommandStatus.failed:
        return LabGuardColors.danger;
      case RemoteCommandStatus.queued:
        return LabGuardColors.warning;
    }
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final DeviceSecurityHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM d, HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(entry.title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(entry.detail, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 6),
        Text(
          formatter.format(entry.occurredAt),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
