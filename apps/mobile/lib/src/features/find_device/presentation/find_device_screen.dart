import 'dart:math' as math;

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
import '../application/find_device_provider.dart';
import '../domain/find_device_snapshot.dart';

class FindDeviceScreen extends ConsumerStatefulWidget {
  const FindDeviceScreen({super.key, required this.deviceId});

  final String deviceId;

  @override
  ConsumerState<FindDeviceScreen> createState() => _FindDeviceScreenState();
}

class _FindDeviceScreenState extends ConsumerState<FindDeviceScreen> {
  String? _busyAction;

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(deviceDetailProvider(widget.deviceId));
    final snapshot = ref.watch(findDeviceSnapshotProvider(widget.deviceId));

    if (detail.isLoading || snapshot.isLoading) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 120),
        children: const [LoadingPanel(label: 'Loading find-device view')],
      );
    }

    final firstError = detail.error ?? snapshot.error;
    if (firstError != null &&
        (detail.valueOrNull == null || snapshot.valueOrNull == null)) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 120),
        children: [
          ErrorPanel(
            message: firstError.toString(),
            onRetry: () {
              ref.invalidate(deviceDetailProvider(widget.deviceId));
              ref.invalidate(findDeviceSnapshotProvider(widget.deviceId));
            },
          ),
        ],
      );
    }

    final device = detail.valueOrNull!;
    final locationSnapshot = snapshot.valueOrNull!;
    final currentLocation = locationSnapshot.currentLocation;
    final timestampFormatter = DateFormat('MMM d, yyyy • HH:mm');

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
              height: 280,
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
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _LocationMapPainter(
                        items: locationSnapshot.items,
                      ),
                    ),
                  ),
                  if (currentLocation != null)
                    Positioned(
                      left: 20,
                      bottom: 18,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: LabGuardColors.panel.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: LabGuardColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentLocation.label,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${currentLocation.latitude.toStringAsFixed(4)}, ${currentLocation.longitude.toStringAsFixed(4)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    top: 18,
                    right: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        StatusBadge(
                          label: device.isLost
                              ? 'Lost mode active'
                              : 'Monitoring only',
                          color: device.isLost
                              ? LabGuardColors.warning
                              : LabGuardColors.accent,
                        ),
                        const SizedBox(height: 8),
                        StatusBadge(
                          label: locationSnapshot.liveTrackingEnabled
                              ? 'Live updates online'
                              : 'Minimal telemetry',
                          color: locationSnapshot.liveTrackingEnabled
                              ? LabGuardColors.success
                              : LabGuardColors.warning,
                        ),
                      ],
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
              Text(
                'Recovery Status',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 18),
              _LocationRow(
                label: 'Last location',
                value: currentLocation?.label ?? device.lastKnownLocation,
              ),
              _LocationRow(
                label: 'Timestamp',
                value: currentLocation == null
                    ? timestampFormatter.format(device.locationCapturedAt)
                    : timestampFormatter.format(currentLocation.capturedAt),
              ),
              _LocationRow(
                label: 'Accuracy',
                value: currentLocation == null
                    ? 'Unavailable'
                    : '${currentLocation.accuracyMeters.toStringAsFixed(0)} m',
              ),
              _LocationRow(
                label: 'Network',
                value:
                    currentLocation?.lastKnownNetwork ??
                    device.lastKnownNetwork,
              ),
              _LocationRow(
                label: 'IP address',
                value: currentLocation?.lastKnownIp ?? device.lastKnownIp,
              ),
              _LocationRow(
                label: 'Update mode',
                value: locationSnapshot.updateFrequencyLabel,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.tonal(
                    onPressed: _busyAction == null
                        ? () => _toggleLostMode(device)
                        : null,
                    child: Text(
                      device.isLost ? 'Mark Recovered' : 'Mark Device Lost',
                    ),
                  ),
                  FilledButton(
                    onPressed: _busyAction == null
                        ? _requestFreshLocation
                        : null,
                    child: _BusyLabel(
                      busy: _busyAction == 'fresh location',
                      label: 'Request Fresh Location',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _busyAction == null ? _ringAlarm : null,
                    child: _BusyLabel(
                      busy: _busyAction == 'ring alarm',
                      label: 'Ring Alarm',
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
                'Location Timeline',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 18),
              for (final item in locationSnapshot.items.take(6)) ...[
                _TimelineRow(item: item),
                if (item != locationSnapshot.items.take(6).last)
                  const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _toggleLostMode(DeviceDetailRecord device) async {
    await _runBusy(
      device.isLost ? 'mark recovered' : 'mark lost',
      () async {
        if (device.isLost) {
          await ref
              .read(deviceActionsControllerProvider)
              .markRecovered(device.id);
        } else {
          await ref
              .read(deviceActionsControllerProvider)
              .markLostMode(device.id);
        }
      },
      device.isLost
          ? 'Lost mode cleared and device marked recovered.'
          : 'Lost mode enabled with elevated recovery tracking.',
    );
  }

  Future<void> _requestFreshLocation() async {
    await _runBusy('fresh location', () async {
      await ref
          .read(findDeviceControllerProvider)
          .requestFreshLocation(widget.deviceId);
    }, 'A fresh location sample was recorded.');
  }

  Future<void> _ringAlarm() async {
    await _runBusy('ring alarm', () async {
      await ref
          .read(remoteActionsControllerProvider)
          .queueAndComplete(
            deviceId: widget.deviceId,
            commandType: RemoteCommandType.ringAlarm,
            resultMessage: 'Alarm request delivered to the device.',
          );
    }, 'Alarm command completed.');
  }

  Future<void> _runBusy(
    String action,
    Future<void> Function() work,
    String successMessage,
  ) async {
    setState(() {
      _busyAction = action;
    });

    try {
      await work();
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
}

class _BusyLabel extends StatelessWidget {
  const _BusyLabel({required this.busy, required this.label});

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

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.item});

  final FindDeviceLocationRecord item;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM d, HH:mm');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 5),
          decoration: const BoxDecoration(
            color: LabGuardColors.accent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.label, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                '${item.latitude.toStringAsFixed(4)}, ${item.longitude.toStringAsFixed(4)} • ${item.accuracyMeters.toStringAsFixed(0)} m',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '${item.source.replaceAll('_', ' ')} • ${formatter.format(item.capturedAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LocationMapPainter extends CustomPainter {
  const _LocationMapPainter({required this.items});

  final List<FindDeviceLocationRecord> items;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = LabGuardColors.border.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    const spacing = 30.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (items.isEmpty) {
      return;
    }

    final minLat = items.map((item) => item.latitude).reduce(math.min);
    final maxLat = items.map((item) => item.latitude).reduce(math.max);
    final minLng = items.map((item) => item.longitude).reduce(math.min);
    final maxLng = items.map((item) => item.longitude).reduce(math.max);

    Offset project(FindDeviceLocationRecord item) {
      final latSpan = maxLat - minLat;
      final lngSpan = maxLng - minLng;
      final x = lngSpan == 0
          ? size.width / 2
          : ((item.longitude - minLng) / lngSpan) * (size.width - 56) + 28;
      final y = latSpan == 0
          ? size.height / 2
          : size.height -
                (((item.latitude - minLat) / latSpan) * (size.height - 56) +
                    28);
      return Offset(x, y);
    }

    final trailPaint = Paint()
      ..color = LabGuardColors.accent.withValues(alpha: 0.45)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()..color = LabGuardColors.accent;
    final latestPaint = Paint()..color = LabGuardColors.warning;

    final points = items.map(project).toList(growable: false);
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, trailPaint);

    for (final point in points.skip(1)) {
      canvas.drawCircle(point, 5, dotPaint);
    }
    canvas.drawCircle(points.first, 8, latestPaint);
  }

  @override
  bool shouldRepaint(covariant _LocationMapPainter oldDelegate) {
    return oldDelegate.items != items;
  }
}
