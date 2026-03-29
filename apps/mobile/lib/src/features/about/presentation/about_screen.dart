import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/material.dart';

import '../../../core/config/app_environment.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_panel.dart';
import '../../../core/widgets/brand_lockup.dart';
import '../../../core/widgets/panel_header.dart';
import '../../../core/widgets/screen_intro.dart';
import '../../../core/widgets/state_panels.dart';
import '../../../core/widgets/status_badge.dart';
import '../application/about_runtime_status_provider.dart';
import '../domain/about_runtime_status.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionParts = AppEnvironment.appVersion.split('+');
    final releaseVersion = versionParts.first;
    final buildNumber = versionParts.length > 1 ? versionParts.last : '1';
    final runtimeStatus = ref.watch(aboutRuntimeStatusProvider);

    return ListView(
      padding: AppMetrics.pagePadding,
      children: [
        const BrandLockup(compact: true),
        const SizedBox(height: 20),
        ScreenIntro(
          eyebrow: AppEnvironment.brandAttribution,
          title: 'LabGuard',
          description:
              'Private infrastructure control for trusted devices. Android-first. Built by Emilo Labs.',
          badge: AppEnvironment.releaseTrack.toUpperCase(),
        ),
        const SizedBox(height: AppMetrics.sectionGap),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PanelHeader(
                title: 'Build Identity',
                subtitle: 'Version details for the current LabGuard build.',
              ),
              const SizedBox(height: 14),
              _AboutDetailRow(label: 'Product', value: AppEnvironment.appName),
              _AboutDetailRow(label: 'Version', value: releaseVersion),
              _AboutDetailRow(label: 'Build', value: buildNumber),
              const _AboutDetailRow(
                label: 'Platform',
                value: 'Android-first Flutter client',
              ),
              _AboutDetailRow(
                label: 'Track',
                value: AppEnvironment.releaseTrack,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppMetrics.sectionGap),
        runtimeStatus.when(
          data: (status) => _RuntimeReadinessPanel(status: status),
          loading: () => const LoadingPanel(
            label: 'Checking service readiness',
            message:
                'Confirming that the control plane is reachable and that VPN regions are prepared.',
          ),
          error: (error, _) => ErrorPanel(
            message:
                "Can't check service readiness right now. Open LabGuard again after the API is reachable.",
            onRetry: () => ref.invalidate(aboutRuntimeStatusProvider),
          ),
        ),
        const SizedBox(height: AppMetrics.sectionGap),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PanelHeader(
                title: 'Operational Scope',
                subtitle:
                    'LabGuard is built for a small trusted fleet, not a public VPN audience.',
              ),
              const SizedBox(height: 14),
              const _CapabilityLine(
                title: 'Private tunnel',
                body:
                    'Protected access for approved devices with clear connect, disconnect, and recovery controls.',
              ),
              const SizedBox(height: 12),
              const _CapabilityLine(
                title: 'Trusted devices',
                body:
                    'Review device trust, recent activity, and recovery state in one place.',
              ),
              const SizedBox(height: 12),
              const _CapabilityLine(
                title: 'Recovery',
                body:
                    'Lost mode, location refresh, recovery messaging, and remote actions stay visible and deliberate.',
              ),
              const SizedBox(height: 12),
              const _CapabilityLine(
                title: 'Account protection',
                body:
                    'Sign-in, approvals, and remote actions are designed for a small trusted operator group.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RuntimeReadinessPanel extends StatelessWidget {
  const _RuntimeReadinessPanel({required this.status});

  final AboutRuntimeStatus status;

  @override
  Widget build(BuildContext context) {
    final serviceTone = status.reachable
        ? LabGuardColors.success
        : LabGuardColors.warning;

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelHeader(
            title: 'Service Readiness',
            subtitle: status.summary,
            trailing: StatusBadge(
              label: status.reachable ? 'Reachable' : 'Check service',
              color: serviceTone,
            ),
          ),
          const SizedBox(height: 14),
          _AboutDetailRow(label: 'Control plane', value: 'LabGuard API reachable'),
          _AboutDetailRow(
            label: 'Release stage',
            value: status.stage == 'operator_preview'
                ? 'Operator preview'
                : status.stage,
          ),
          _AboutDetailRow(
            label: 'Backend mode',
            value: status.seededBootstrapActive
                ? 'Seeded internal preview'
                : 'Persistent production mode',
          ),
          const SizedBox(height: 6),
          for (final region in status.vpnRegions) ...[
            const SizedBox(height: 10),
            _RegionReadinessRow(region: region),
          ],
        ],
      ),
    );
  }
}

class _RegionReadinessRow extends StatelessWidget {
  const _RegionReadinessRow({required this.region});

  final AboutRuntimeRegion region;

  @override
  Widget build(BuildContext context) {
    final color = region.ready
        ? LabGuardColors.success
        : switch (region.availabilityState) {
            'incomplete_config' || 'invalid_config' => LabGuardColors.warning,
            _ => LabGuardColors.textSecondary,
          };
    final label = region.ready
        ? 'Ready'
        : switch (region.availabilityState) {
            'incomplete_config' => 'Setup incomplete',
            'invalid_config' => 'Config issue',
            _ => 'Not live',
          };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppMetrics.tileRadius),
        border: Border.all(color: LabGuardColors.border),
        color: LabGuardColors.panelSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  region.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              StatusBadge(label: label, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            region.locationLabel,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            region.availabilityMessage,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _AboutDetailRow extends StatelessWidget {
  const _AboutDetailRow({required this.label, required this.value});

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
            width: 104,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _CapabilityLine extends StatelessWidget {
  const _CapabilityLine({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(body, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
