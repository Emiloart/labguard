import 'package:flutter/material.dart';

import '../../../core/config/app_environment.dart';
import '../../../core/widgets/app_panel.dart';
import '../../../core/widgets/brand_lockup.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 120),
      children: [
        const BrandLockup(compact: true),
        const SizedBox(height: 18),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LabGuard by Emilo Labs',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'Version ${AppEnvironment.appVersion}\nEnvironment ${AppEnvironment.environment}\nAPI ${AppEnvironment.apiBaseUrl}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
