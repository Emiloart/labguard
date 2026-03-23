import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_panel.dart';
import '../../../core/widgets/status_badge.dart';
import '../../devices/application/device_registry_provider.dart';

class FindDeviceScreen extends ConsumerWidget {
  const FindDeviceScreen({super.key, required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(deviceByIdProvider(deviceId));

    if (device == null) {
      return Center(
        child: Text(
          'Location feed unavailable.',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      );
    }

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
              const StatusBadge(
                label: 'Lost mode active',
                color: LabGuardColors.warning,
              ),
              const SizedBox(height: 18),
              _LocationRow(
                label: 'Last location',
                value: device.lastKnownLocation,
              ),
              _LocationRow(label: 'Timestamp', value: timestamp),
              _LocationRow(label: 'Network', value: device.lastKnownNetwork),
              _LocationRow(label: 'IP address', value: device.lastKnownIp),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () {},
                child: const Text('Mark Recovered'),
              ),
            ],
          ),
        ),
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
