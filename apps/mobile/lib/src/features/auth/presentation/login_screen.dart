import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_panel.dart';
import '../../../core/widgets/brand_lockup.dart';
import '../../../core/widgets/screen_intro.dart';
import '../application/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final TextEditingController _identityController;
  late final TextEditingController _inviteCodeController;

  @override
  void initState() {
    super.initState();
    _identityController = TextEditingController(text: 'owner@emilolabs.com');
    _inviteCodeController = TextEditingController();
  }

  @override
  void dispose() {
    _identityController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        showAppSnackBar(
          context,
          message: next.errorMessage!,
          tone: AppFeedbackTone.warning,
        );
        ref.read(authControllerProvider.notifier).clearError();
      }
    });

    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppMetrics.pagePaddingWide,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BrandLockup(compact: true),
              const SizedBox(height: 28),
              const ScreenIntro(
                eyebrow: 'Trusted Access',
                title: 'Sign in to LabGuard',
                description:
                    'Use an approved account to open this device and resume protected controls.',
                badge: 'BUILT BY EMILO LABS',
              ),
              const SizedBox(height: 28),
              AppPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Access details',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 18),
                    const Text('Email or handle'),
                    const SizedBox(height: 12),
                    AutofillGroup(
                      child: TextField(
                        controller: _identityController,
                        autofillHints: const [AutofillHints.username],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'owner@emilolabs.com',
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text('Invite code'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _inviteCodeController,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        hintText: 'Optional trusted invite code',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: authState.isBusy
                    ? null
                    : () async {
                        await ref
                            .read(authControllerProvider.notifier)
                            .signIn(
                              identity: _identityController.text.trim(),
                              inviteCode: _inviteCodeController.text.trim(),
                            );
                      },
                child: Text(authState.isBusy ? 'Signing in...' : 'Continue'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: authState.isBusy
                    ? null
                    : () async {
                        await ref
                            .read(authControllerProvider.notifier)
                            .restoreTrustedSession();
                      },
                child: const Text('Restore trusted session'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
