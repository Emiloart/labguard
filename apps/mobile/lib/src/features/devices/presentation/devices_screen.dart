import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_panel.dart';
import '../../../core/widgets/status_badge.dart';
import '../application/device_registry_provider.dart';
import '../domain/device_record.dart';

class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(deviceRegistryProvider);
    final dateFormat = DateFormat('MMM d, HH:mm');

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 120),
      itemCount: devices.length + 1,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Device Registry',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Trusted devices, approval state, last activity, and recovery status live here.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          );
        }

        final device = devices[index - 1];

        return InkWell(
          onTap: () => context.go('/devices/${device.id}'),
          borderRadius: BorderRadius.circular(24),
          child: AppPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        device.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (device.isPrimary)
                      const StatusBadge(
                        label: 'Primary',
                        color: LabGuardColors.accent,
                      ),
                    if (device.isLost) ...[
                      const SizedBox(width: 8),
                      const StatusBadge(
                        label: 'Lost',
                        color: LabGuardColors.warning,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${device.model} • ${device.platform}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _InfoChip(
                      label: 'Trust',
                      value: _trustLabel(device.trustState),
                    ),
                    _InfoChip(label: 'VPN', value: _vpnLabel(device.vpnStatus)),
                    _InfoChip(
                      label: 'Battery',
                      value: '${device.batteryLevel}%',
                    ),
                    _InfoChip(
                      label: 'Last seen',
                      value: dateFormat.format(device.lastActiveAt),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _trustLabel(DeviceTrustState trustState) {
    switch (trustState) {
      case DeviceTrustState.trusted:
        return 'Trusted';
      case DeviceTrustState.pendingApproval:
        return 'Pending';
      case DeviceTrustState.suspended:
        return 'Suspended';
      case DeviceTrustState.revoked:
        return 'Revoked';
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: LabGuardColors.panelElevated,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: LabGuardColors.textPrimary),
      ),
    );
  }
}
