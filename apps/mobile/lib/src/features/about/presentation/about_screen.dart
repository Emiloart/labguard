import 'package:flutter/material.dart';

import '../../../core/config/app_environment.dart';
import '../../../core/widgets/app_panel.dart';
import '../../../core/widgets/brand_lockup.dart';
import '../../../core/widgets/screen_intro.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 120),
      children: [
        const BrandLockup(compact: true),
        const SizedBox(height: 20),
        ScreenIntro(
          eyebrow: AppEnvironment.brandAttribution,
          title: 'About LabGuard',
          description:
              'LabGuard is a private Android-first security suite for trusted operators and approved devices only.',
          badge: AppEnvironment.releaseTrack.toUpperCase(),
        ),
        const SizedBox(height: 16),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Build Identity',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              _AboutDetailRow(
                label: 'Version',
                value: AppEnvironment.appVersion,
              ),
              _AboutDetailRow(
                label: 'Environment',
                value: AppEnvironment.environment,
              ),
              _AboutDetailRow(
                label: 'Release track',
                value: AppEnvironment.releaseTrack,
              ),
              _AboutDetailRow(
                label: 'API base',
                value: AppEnvironment.apiBaseUrl,
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
                'Operational Scope',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              const _CapabilityLine(
                title: 'WireGuard tunnel control',
                body:
                    'Per-device profile handling, Android VPN permission control, foreground runtime service, and reconnect policy.',
              ),
              const SizedBox(height: 12),
              const _CapabilityLine(
                title: 'Trusted device registry',
                body:
                    'Device approval state, last activity, VPN posture, recovery state, and per-device revocation workflows.',
              ),
              const SizedBox(height: 12),
              const _CapabilityLine(
                title: 'Explicit recovery operations',
                body:
                    'Lost mode, last-known location, recovery messaging, alarm requests, and remote security actions remain operator-visible and auditable.',
              ),
              const SizedBox(height: 12),
              const _CapabilityLine(
                title: 'Security-first control plane',
                body:
                    'Token/session rotation, audit logs, remote command lifecycle tracking, and policy-driven runtime posture checks.',
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
                'Release Readiness',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'This repository is prepared for an internal trusted-user release, but the control plane still includes mock data modules for provisioning and command state. Replace those modules with persistent production services before any external rollout.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'See the repository release playbook for verification gates, Android signing steps, VPN validation, and rollback procedure.',
                style: Theme.of(context).textTheme.bodySmall,
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
