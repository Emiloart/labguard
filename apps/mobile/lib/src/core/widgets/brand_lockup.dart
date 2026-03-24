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
    final semanticsLabel = showAttribution
        ? '${AppEnvironment.appName}. ${AppEnvironment.brandAttribution}.'
        : AppEnvironment.appName;

    return Semantics(
      container: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Column(
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
                  colors: [
                    LabGuardColors.panelElevated,
                    LabGuardColors.background,
                  ],
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
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: compact ? 9 : 11,
                    right: compact ? 9 : 11,
                    child: Container(
                      height: compact ? 8 : 10,
                      width: compact ? 8 : 10,
                      decoration: const BoxDecoration(
                        color: LabGuardColors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.verified_user_outlined,
                    color: LabGuardColors.accent,
                    size: 30,
                  ),
                ],
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
        ),
      ),
    );
  }
}
