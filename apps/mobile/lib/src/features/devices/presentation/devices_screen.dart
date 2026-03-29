import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_panel.dart';
import '../../../core/widgets/screen_intro.dart';
import '../../../core/widgets/state_panels.dart';
import '../../../core/widgets/status_badge.dart';
import '../application/device_registry_provider.dart';
import '../domain/device_record.dart';

class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(deviceRegistryProvider);
    final cachedDevices = devices.valueOrNull;

    if (cachedDevices != null) {
      return _DevicesContent(
        devices: cachedDevices,
        isRefreshing: devices.isLoading,
      );
    }

    return devices.when(
      data: (items) => _DevicesContent(devices: items),
      loading: () => ListView(
        padding: AppMetrics.pagePadding,
        children: const [
          LoadingPanel(
            label: 'Loading device registry',
            message:
                'Preparing approved device state, trust posture, and last-seen metadata.',
          ),
        ],
      ),
      error: (error, _) => ListView(
        padding: AppMetrics.pagePadding,
        children: [
          ErrorPanel(
            message: error.toString(),
            onRetry: () => ref.refresh(deviceRegistryProvider),
          ),
        ],
      ),
    );
  }
}

class _DevicesContent extends StatelessWidget {
  const _DevicesContent({required this.devices, this.isRefreshing = false});

  final List<DeviceRecord> devices;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, HH:mm');

    return ListView(
      padding: AppMetrics.pagePadding,
      children: [
        if (isRefreshing) ...[
          const LinearProgressIndicator(minHeight: 3),
          const SizedBox(height: 16),
        ],
        ScreenIntro(
          eyebrow: 'Trusted Fleet',
          title: 'Device Registry',
          description:
              'Trusted devices, approval state, last activity, and recovery status live here.',
          badge: devices.isEmpty
              ? 'NO DEVICES'
              : '${devices.length} REGISTERED',
        ),
        const SizedBox(height: AppMetrics.sectionGap),
        if (devices.isEmpty)
          EmptyPanel(
            title: 'No devices are registered yet',
            message:
                'Sign in on an approved Android device to create the first trusted LabGuard entry for this account.',
            icon: Icons.devices_outlined,
          )
        else ...[
          for (final device in devices) ...[
            Semantics(
              button: true,
              label: 'Open details for ${device.name}',
              child: InkWell(
                onTap: () => context.go('/devices/${device.id}'),
                borderRadius: BorderRadius.circular(AppMetrics.panelRadius),
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
                          StatusBadge(
                            label: _trustLabel(device.trustState),
                            color: _trustColor(device.trustState),
                          ),
                          if (device.isPrimary) ...[
                            const SizedBox(width: 8),
                            const StatusBadge(
                              label: 'Primary',
                              color: LabGuardColors.accent,
                            ),
                          ],
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
                            label: 'VPN',
                            value: _vpnLabel(device.vpnStatus),
                          ),
                          _InfoChip(
                            label: 'Battery',
                            value: '${device.batteryLevel}%',
                          ),
                          _InfoChip(
                            label: 'Last seen',
                            value: dateFormat.format(device.lastActiveAt),
                          ),
                          _InfoChip(
                            label: 'Network',
                            value: device.lastKnownNetwork,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Last IP ${device.lastKnownIp}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (device != devices.last) const SizedBox(height: 16),
          ],
        ],
      ],
    );
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
        borderRadius: BorderRadius.circular(AppMetrics.chipRadius),
        border: Border.all(color: LabGuardColors.border),
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
