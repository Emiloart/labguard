import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_panel.dart';
import '../../../core/widgets/panel_header.dart';
import '../../../core/widgets/screen_intro.dart';
import '../../../core/widgets/state_panels.dart';
import '../../../core/widgets/status_badge.dart';
import '../application/audit_logs_provider.dart';
import '../domain/audit_log_record.dart';

class AuditLogsScreen extends ConsumerWidget {
  const AuditLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditLogs = ref.watch(auditLogsProvider);

    return auditLogs.when(
      data: (items) => _AuditLogsContent(items: items),
      loading: () => ListView(
        padding: AppMetrics.pagePadding,
        children: const [
          LoadingPanel(
            label: 'Loading audit trail',
            message:
                'Preparing sensitive action history, actor metadata, and command outcomes.',
          ),
        ],
      ),
      error: (error, _) => ListView(
        padding: AppMetrics.pagePadding,
        children: [
          ErrorPanel(
            message: error.toString(),
            onRetry: () => ref.refresh(auditLogsProvider),
          ),
        ],
      ),
    );
  }
}

class _AuditLogsContent extends StatelessWidget {
  const _AuditLogsContent({required this.items});

  final List<AuditLogRecord> items;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM d, yyyy • HH:mm');

    return ListView(
      padding: AppMetrics.pagePadding,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => context.go('/settings'),
              tooltip: 'Back to settings',
              icon: const Icon(Icons.arrow_back),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ScreenIntro(
          eyebrow: 'Auditability',
          title: 'Audit Trail',
          description:
              'Sensitive actions, token changes, trust transitions, and remote command results are recorded here.',
          badge: items.isEmpty ? 'NO ENTRIES' : '${items.length} ENTRIES',
        ),
        const SizedBox(height: AppMetrics.sectionGap),
        if (items.isEmpty)
          const EmptyPanel(
            title: 'No audit entries are available',
            message:
                'Sensitive actions will appear here once trust changes, token work, or remote commands are recorded.',
            icon: Icons.fact_check_outlined,
          )
        else ...[
          for (final item in items) ...[
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      StatusBadge(
                        label: item.outcome == AuditLogOutcome.success
                            ? 'Success'
                            : 'Failure',
                        color: item.outcome == AuditLogOutcome.success
                            ? LabGuardColors.success
                            : LabGuardColors.danger,
                      ),
                      const SizedBox(width: 8),
                      StatusBadge(
                        label: item.targetType,
                        color: LabGuardColors.accent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  PanelHeader(
                    title: item.action.replaceAll('_', ' '),
                    subtitle: item.summary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${item.actorLabel} • ${item.targetId} • ${formatter.format(item.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (item != items.last) const SizedBox(height: 16),
          ],
        ],
      ],
    );
  }
}
