import 'package:flutter/material.dart';

import '../../../core/config/app_environment.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_panel.dart';
import '../../../core/widgets/brand_lockup.dart';
import '../../../core/widgets/panel_header.dart';
import '../../../core/widgets/screen_intro.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final versionParts = AppEnvironment.appVersion.split('+');
    final releaseVersion = versionParts.first;
    final buildNumber = versionParts.length > 1 ? versionParts.last : '1';

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
            ],
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
