import 'package:flutter/material.dart';

import '../../../core/widgets/brand_lockup.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BrandLockup(),
                const SizedBox(height: 24),
                Text(
                  'Provisioning secure access...',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 14),
                const LinearProgressIndicator(minHeight: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
