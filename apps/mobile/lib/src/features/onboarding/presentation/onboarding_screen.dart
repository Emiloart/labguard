import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_panel.dart';
import '../../../core/widgets/brand_lockup.dart';
import '../../../core/widgets/screen_intro.dart';
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
            const ScreenIntro(
              eyebrow: 'Trusted Fleet Security',
              title: 'Private infrastructure control in your pocket.',
              description:
                  'LabGuard protects a small trusted device fleet with secure VPN access, auditable recovery actions, and explicit lost-device workflows.',
              badge: 'ANDROID FIRST',
            ),
            const SizedBox(height: 24),
            const _OnboardingPoint(
              icon: Icons.verified_user_outlined,
              title: 'Trusted Access',
              body:
                  'Owner and invited members onboard approved devices only. Each device receives its own credentials.',
            ),
            const SizedBox(height: 16),
            const _OnboardingPoint(
              icon: Icons.location_searching_outlined,
              title: 'Device Recovery',
              body:
                  'Lost-device tracking is explicit, permission-aware, and elevated only while recovery mode is active.',
            ),
            const SizedBox(height: 16),
            const _OnboardingPoint(
              icon: Icons.policy_outlined,
              title: 'Remote Security Controls',
              body:
                  'Revoke VPN, rotate credentials, sign out, and confirm command outcomes with a full audit trail.',
            ),
            const SizedBox(height: 16),
            const _OnboardingPoint(
              icon: Icons.tune_outlined,
              title: 'Permissions Stay Explicit',
              body:
                  'LabGuard asks for notifications, location, and battery-review settings only when the related protection workflow needs them.',
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                await ref
                    .read(authControllerProvider.notifier)
                    .completeOnboarding();
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
  const _OnboardingPoint({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
