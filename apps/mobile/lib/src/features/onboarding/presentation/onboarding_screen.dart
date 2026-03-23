import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_panel.dart';
import '../../../core/widgets/brand_lockup.dart';
import '../../auth/application/auth_controller.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          children: [
            const BrandLockup(),
            const SizedBox(height: 28),
            Text(
              'Private infrastructure control in your pocket.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            Text(
              'LabGuard protects a small trusted device fleet with secure VPN access, auditable recovery actions, and explicit lost-device workflows.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            const _OnboardingPoint(
              title: 'Trusted Access',
              body:
                  'Owner and invited members onboard approved devices only. Each device receives its own credentials.',
            ),
            const SizedBox(height: 16),
            const _OnboardingPoint(
              title: 'Device Recovery',
              body:
                  'Lost-device tracking is explicit, permission-aware, and elevated only while recovery mode is active.',
            ),
            const SizedBox(height: 16),
            const _OnboardingPoint(
              title: 'Remote Security Controls',
              body:
                  'Revoke VPN, rotate credentials, sign out, and confirm command outcomes with a full audit trail.',
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                ref.read(authControllerProvider.notifier).completeOnboarding();
              },
              child: const Text('Continue to Secure Access'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPoint extends StatelessWidget {
  const _OnboardingPoint({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
