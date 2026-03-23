import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_panel.dart';
import '../../../core/widgets/state_panels.dart';
import '../../../core/widgets/status_badge.dart';
import '../application/device_registry_provider.dart';
import '../domain/device_record.dart';

class DeviceDetailScreen extends ConsumerWidget {
  const DeviceDetailScreen({super.key, required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(deviceByIdProvider(deviceId));

    return device.when(
      data: (item) => _DeviceDetailContent(device: item),
      loading: () => ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 120),
        children: const [LoadingPanel(label: 'Loading device detail')],
      ),
      error: (error, _) => ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 120),
        children: [
          ErrorPanel(
            message: error.toString(),
            onRetry: () => ref.refresh(deviceByIdProvider(deviceId)),
          ),
        ],
      ),
    );
  }
}

class _DeviceDetailContent extends StatelessWidget {
  const _DeviceDetailContent({required this.device});

  final DeviceRecord device;

  @override
  Widget build(BuildContext context) {
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
                'Remote Actions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 18),
              FilledButton.tonal(
                onPressed: () => context.go('/devices/${device.id}/find'),
                child: const Text('Open Find Device'),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () {},
                child: const Text('Rotate Credentials'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {},
                child: const Text('Revoke Device Access'),
              ),
            ],
          ),
        ),
      ],
    );
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
