import 'package:flutter/material.dart';

import '../../../core/config/app_environment.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/brand_lockup.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: TweenAnimationBuilder<double>(
          duration: AppMetrics.emphasizedDuration,
          curve: Curves.easeOutCubic,
          tween: Tween(begin: 0, end: 1),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 24 * (1 - value)),
                child: child,
              ),
            );
          },
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BrandLockup(),
                    const SizedBox(height: 24),
                    Text(
                      'Preparing secure access, trusted device state, and recovery services.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 14),
                    Semantics(
                      liveRegion: true,
                      label: 'Preparing LabGuard secure runtime',
                      child: LinearProgressIndicator(minHeight: 4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${AppEnvironment.releaseTrack} • ${AppEnvironment.appVersion}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Private security suite for trusted Emilo Labs operators.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
