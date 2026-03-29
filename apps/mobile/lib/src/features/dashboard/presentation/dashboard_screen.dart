import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_panel.dart';
import '../../../core/widgets/brand_lockup.dart';
import '../../../core/widgets/panel_header.dart';
import '../../../core/widgets/screen_intro.dart';
import '../../../core/widgets/state_panels.dart';
import '../../../core/widgets/status_badge.dart';
import '../../remote_actions/data/recovery_signal_store.dart';
import '../application/dashboard_controller.dart';
import '../domain/dashboard_summary.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider);
    final recoverySignal = ref.watch(recoverySignalProvider);
    final cachedSummary = summary.valueOrNull;

    if (cachedSummary != null) {
      return _DashboardContent(
        summary: cachedSummary,
        recoverySignal: recoverySignal.valueOrNull,
        isRefreshing: summary.isLoading,
      );
    }

    return summary.when(
      data: (data) => _DashboardContent(
        summary: data,
        recoverySignal: recoverySignal.valueOrNull,
      ),
      loading: () => ListView(
        padding: AppMetrics.pagePadding,
        children: const [
          BrandLockup(compact: true, showAttribution: false),
          SizedBox(height: 20),
          LoadingPanel(
            label: 'Loading security dashboard',
            message:
                'Preparing tunnel status, device posture, and unread alerts.',
          ),
        ],
      ),
      error: (error, _) => ListView(
        padding: AppMetrics.pagePadding,
        children: [
          const BrandLockup(compact: true, showAttribution: false),
          const SizedBox(height: 20),
          ErrorPanel(
            message: error.toString(),
            onRetry: () => ref.refresh(dashboardSummaryProvider),
          ),
        ],
      ),
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  const _DashboardContent({
    required this.summary,
    required this.recoverySignal,
    this.isRefreshing = false,
  });

  final DashboardSummary summary;
  final RecoverySignal? recoverySignal;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vpnProvisioned =
        summary.vpnOverview.serverName != 'VPN not provisioned';

    return ListView(
      padding: AppMetrics.pagePadding,
      children: [
        const BrandLockup(compact: true, showAttribution: false),
        const SizedBox(height: 20),
        if (isRefreshing) ...[
          const LinearProgressIndicator(minHeight: 3),
          const SizedBox(height: 16),
        ],
        ScreenIntro(
          eyebrow: 'Trusted Operations',
          title: 'Security Dashboard',
          description:
              '${summary.viewerDisplayName} • ${summary.accountName}. Review tunnel posture, device trust, and recovery activity at a glance.',
          badge: summary.viewerRole,
        ),
        const SizedBox(height: AppMetrics.sectionGap),
        if (recoverySignal != null) ...[
          AppPanel(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.campaign_outlined,
                  color: LabGuardColors.warning,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PanelHeader(
                        title: recoverySignal!.alarmRequested
                            ? 'Recovery alarm active'
                            : 'Recovery message received',
                        subtitle: recoverySignal!.message,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await ref.read(recoverySignalStoreProvider).clear();
                    ref
                        .read(recoverySignalInvalidationProvider.notifier)
                        .state++;
                  },
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (summary.criticalAlertsCount > 0) ...[
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
                    '${summary.criticalAlertsCount} critical security event${summary.criticalAlertsCount == 1 ? '' : 's'} require review.',
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
              PanelHeader(
                title: 'Private Tunnel',
                subtitle: !vpnProvisioned
                    ? 'No live VPN region is provisioned for this account.'
                    : summary.vpnOverview.connected
                    ? 'Your WireGuard tunnel is active and reporting live session state.'
                    : 'The device is currently offline from the LabGuard tunnel.',
                trailing: StatusBadge(
                  label: !vpnProvisioned
                      ? 'Unavailable'
                      : summary.vpnOverview.connected
                      ? 'Connected'
                      : 'Offline',
                  color: !vpnProvisioned
                      ? LabGuardColors.textSecondary
                      : summary.vpnOverview.connected
                      ? LabGuardColors.success
                      : LabGuardColors.warning,
                ),
              ),
              const SizedBox(height: AppMetrics.contentGap),
              Text(
                summary.vpnOverview.serverName,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                summary.vpnOverview.connected
                    ? 'Protected now • Session ${summary.vpnOverview.sessionLabel}'
                    : vpnProvisioned
                    ? 'Ready when you want to reconnect.'
                    : 'Set up a live region to enable the tunnel.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => context.go('/vpn'),
                child: Text(
                  vpnProvisioned ? 'Open VPN Controls' : 'Review VPN Setup',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PanelHeader(
                title: 'Security Summary',
                subtitle:
                    'Trusted devices, active recovery work, and unread alert volume for this account.',
              ),
              const SizedBox(height: AppMetrics.contentGap),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricTile(
                    label: 'Trusted devices',
                    value: '${summary.trustedDevicesCount}',
                  ),
                  _MetricTile(
                    label: 'Lost mode',
                    value: '${summary.lostDevicesCount}',
                  ),
                  _MetricTile(
                    label: 'Unread alerts',
                    value: '${summary.unreadAlertsCount}',
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
              const PanelHeader(
                title: 'Quick Actions',
                subtitle:
                    'Open the surfaces used most often during daily monitoring and recovery.',
              ),
              const SizedBox(height: AppMetrics.contentGap),
              if (summary.quickActions.isEmpty)
                EmptyPanel(
                  title: 'No quick actions available',
                  message:
                      'This account does not currently expose any dashboard shortcuts.',
                  icon: Icons.dashboard_customize_outlined,
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final action in summary.quickActions)
                      _QuickAction(
                        label: action.label,
                        icon: _iconForAction(action.id),
                        onTap: () => context.go(action.route),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _iconForAction(String id) {
    switch (id) {
      case 'devices':
        return Icons.devices_outlined;
      case 'events':
        return Icons.notifications_active_outlined;
      case 'settings':
      default:
        return Icons.tune_outlined;
    }
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
        borderRadius: BorderRadius.circular(AppMetrics.tileRadius),
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
    return Semantics(
      button: true,
      label: 'Open $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppMetrics.tileRadius),
        child: Ink(
          width: 150,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: LabGuardColors.panelElevated,
            borderRadius: BorderRadius.circular(AppMetrics.tileRadius),
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
      ),
    );
  }
}
