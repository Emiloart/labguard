import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_panel.dart';
import '../../../core/widgets/brand_lockup.dart';
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.errorMessage!)));
        ref.read(authControllerProvider.notifier).clearError();
      }
    });

    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BrandLockup(),
              const SizedBox(height: 28),
              Text(
                'Secure access for trusted LabGuard members.',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                'Owner and invited users authenticate here, register the device, and receive approved access to VPN and security actions.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),
              AppPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Email or handle'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _identityController,
                      decoration: InputDecoration(
                        hintText: 'owner@emilolabs.com',
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text('Invite code'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _inviteCodeController,
                      decoration: InputDecoration(
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
                child: Text(
                  authState.isBusy
                      ? 'Approving Device...'
                      : 'Approve Device and Continue',
                ),
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
                child: const Text('Use Existing Trusted Session'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
