import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_panel.dart';
import '../../../core/widgets/brand_lockup.dart';
import '../../../core/widgets/status_badge.dart';
import '../../devices/application/device_registry_provider.dart';
import '../../events/application/security_events_provider.dart';
import '../../vpn/application/vpn_preferences_controller.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(deviceRegistryProvider);
    final events = ref.watch(securityEventsProvider);
    final vpnOverview = ref.watch(vpnOverviewProvider);
    final lostCount = devices.where((device) => device.isLost).length;
    final unreadCriticalCount = events
        .where((event) => event.unread && event.severity.isCritical)
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 120),
      children: [
        const BrandLockup(compact: true, showAttribution: false),
        const SizedBox(height: 20),
        if (unreadCriticalCount > 0) ...[
          AppPanel(
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: LabGuardColors.warning,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    '$unreadCriticalCount critical security event${unreadCriticalCount == 1 ? '' : 's'} require review.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/events'),
                  child: const Text('Review'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Private Tunnel',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  StatusBadge(
                    label: vpnOverview.connected ? 'Connected' : 'Offline',
                    color: vpnOverview.connected
                        ? LabGuardColors.success
                        : LabGuardColors.warning,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                vpnOverview.serverName,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                'Current IP ${vpnOverview.currentIp} • Session ${vpnOverview.sessionLabel}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => context.go('/vpn'),
                child: const Text('Open VPN Controls'),
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
                'Security Summary',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricTile(
                    label: 'Trusted devices',
                    value: '${devices.length}',
                  ),
                  _MetricTile(label: 'Lost mode', value: '$lostCount'),
                  _MetricTile(
                    label: 'Unread alerts',
                    value: '${events.where((event) => event.unread).length}',
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
                'Quick Actions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _QuickAction(
                    label: 'Devices',
                    icon: Icons.devices_outlined,
                    onTap: () => context.go('/devices'),
                  ),
                  _QuickAction(
                    label: 'Events',
                    icon: Icons.notifications_active_outlined,
                    onTap: () => context.go('/events'),
                  ),
                  _QuickAction(
                    label: 'Settings',
                    icon: Icons.tune_outlined,
                    onTap: () => context.go('/settings'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LabGuardColors.panelElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LabGuardColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        width: 150,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: LabGuardColors.panelElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: LabGuardColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: LabGuardColors.accent),
            const SizedBox(height: 12),
            Text(label, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
