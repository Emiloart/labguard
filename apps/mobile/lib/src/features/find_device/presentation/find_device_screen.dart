import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_panel.dart';
import '../../../core/widgets/state_panels.dart';
import '../../../core/widgets/status_badge.dart';
import '../../devices/application/device_registry_provider.dart';
import '../../devices/domain/device_record.dart';
import '../../remote_actions/application/remote_actions_provider.dart';
import '../../remote_actions/domain/remote_command_record.dart';

class FindDeviceScreen extends ConsumerStatefulWidget {
  const FindDeviceScreen({super.key, required this.deviceId});

  final String deviceId;

  @override
  ConsumerState<FindDeviceScreen> createState() => _FindDeviceScreenState();
}

class _FindDeviceScreenState extends ConsumerState<FindDeviceScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(deviceDetailProvider(widget.deviceId));

    return detail.when(
      data: (item) => _buildContent(context, item),
      loading: () => ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 120),
        children: const [LoadingPanel(label: 'Loading find-device view')],
      ),
      error: (error, _) => ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 120),
        children: [
          ErrorPanel(
            message: error.toString(),
            onRetry: () => ref.refresh(deviceDetailProvider(widget.deviceId)),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, DeviceDetailRecord device) {
    final timestamp = DateFormat(
      'MMM d, yyyy • HH:mm',
    ).format(device.locationCapturedAt);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 120),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => context.go('/devices/${device.id}'),
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Find ${device.name}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppPanel(
          padding: const EdgeInsets.all(0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              height: 260,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    LabGuardColors.backgroundMuted,
                    LabGuardColors.panelElevated,
                    LabGuardColors.background,
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(child: CustomPaint(painter: _GridPainter())),
                  const Align(
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.place_rounded,
                      color: LabGuardColors.accent,
                      size: 42,
                    ),
                  ),
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: StatusBadge(
                        label: device.isLost
                            ? 'Lost mode active'
                            : 'Monitoring',
                        color: device.isLost
                            ? LabGuardColors.warning
                            : LabGuardColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusBadge(
                label: device.isLost ? 'Elevated recovery mode' : 'Normal mode',
                color: device.isLost
                    ? LabGuardColors.warning
                    : LabGuardColors.success,
              ),
              const SizedBox(height: 18),
              _LocationRow(
                label: 'Last location',
                value: device.lastKnownLocation,
              ),
              _LocationRow(label: 'Timestamp', value: timestamp),
              _LocationRow(label: 'Network', value: device.lastKnownNetwork),
              _LocationRow(label: 'IP address', value: device.lastKnownIp),
              _LocationRow(
                label: 'Recovery state',
                value: device.lostModeStatus,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.tonal(
                    onPressed: _busy ? null : () => _toggleLostMode(device),
                    child: Text(
                      device.isLost ? 'Mark Recovered' : 'Mark Device Lost',
                    ),
                  ),
                  FilledButton(
                    onPressed: _busy ? null : () => _ringAlarm(device.id),
                    child: const Text('Ring Alarm'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _toggleLostMode(DeviceDetailRecord device) async {
    setState(() {
      _busy = true;
    });

    try {
      if (device.isLost) {
        await ref
            .read(deviceActionsControllerProvider)
            .markRecovered(device.id);
      } else {
        await ref.read(deviceActionsControllerProvider).markLostMode(device.id);
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            device.isLost
                ? 'Lost mode cleared and device marked recovered.'
                : 'Lost mode enabled with elevated recovery tracking.',
          ),
        ),
      );
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
          _busy = false;
        });
      }
    }
  }

  Future<void> _ringAlarm(String deviceId) async {
    setState(() {
      _busy = true;
    });

    try {
      await ref
          .read(remoteActionsControllerProvider)
          .queueAndComplete(
            deviceId: deviceId,
            commandType: RemoteCommandType.ringAlarm,
            resultMessage: 'Alarm request delivered to the device.',
          );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Alarm command completed.')));
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
          _busy = false;
        });
      }
    }
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({required this.label, required this.value});

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
            width: 118,
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

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = LabGuardColors.border.withValues(alpha: 0.5)
      ..strokeWidth = 1;

    const spacing = 28.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
