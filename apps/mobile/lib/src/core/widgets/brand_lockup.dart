import 'package:flutter/material.dart';

import '../config/app_environment.dart';
import '../theme/app_colors.dart';

class BrandLockup extends StatelessWidget {
  const BrandLockup({
    super.key,
    this.compact = false,
    this.showAttribution = true,
    this.alignment = CrossAxisAlignment.start,
  });

  final bool compact;
  final bool showAttribution;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final titleTheme = compact
        ? Theme.of(context).textTheme.headlineSmall
        : Theme.of(context).textTheme.displaySmall;
    final iconSize = compact ? 56.0 : 72.0;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Container(
          height: iconSize,
          width: iconSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 18 : 24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [LabGuardColors.panelElevated, LabGuardColors.background],
            ),
            border: Border.all(color: LabGuardColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x223AA9C7),
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.verified_user_outlined,
            color: LabGuardColors.accent,
            size: 30,
          ),
        ),
        SizedBox(height: compact ? 18 : 24),
        Text(
          AppEnvironment.appName,
          style: titleTheme?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (showAttribution) ...[
          const SizedBox(height: 6),
          const Text(
            AppEnvironment.brandAttribution,
            style: TextStyle(
              color: LabGuardColors.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ],
    );
  }
}
