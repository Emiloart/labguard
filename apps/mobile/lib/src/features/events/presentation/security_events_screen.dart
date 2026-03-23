import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_panel.dart';
import '../../../core/widgets/state_panels.dart';
import '../../../core/widgets/status_badge.dart';
import '../application/security_events_provider.dart';
import '../domain/security_event_record.dart';

class SecurityEventsScreen extends ConsumerWidget {
  const SecurityEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(securityEventsProvider);

    return events.when(
      data: (items) => _SecurityEventsContent(events: items),
      loading: () => ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 120),
        children: const [LoadingPanel(label: 'Loading security events')],
      ),
      error: (error, _) => ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 120),
        children: [
          ErrorPanel(
            message: error.toString(),
            onRetry: () => ref.refresh(securityEventsProvider),
          ),
        ],
      ),
    );
  }
}

class _SecurityEventsContent extends StatelessWidget {
  const _SecurityEventsContent({required this.events});

  final List<SecurityEventRecord> events;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM d, HH:mm');

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 120),
      itemCount: events.length + 1,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Security Events',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Unread alerts, suspicious state changes, remote action outcomes, and VPN events surface here.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          );
        }

        final event = events[index - 1];

        return AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusBadge(
                    label: _severityLabel(event.severity),
                    color: _severityColor(event.severity),
                  ),
                  if (event.unread) ...[
                    const SizedBox(width: 8),
                    const StatusBadge(
                      label: 'Unread',
                      color: LabGuardColors.accent,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Text(event.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                event.summary,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              Text(
                '${event.deviceName ?? 'Account'} • ${formatter.format(event.occurredAt)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        );
      },
    );
  }

  String _severityLabel(EventSeverity severity) {
    switch (severity) {
      case EventSeverity.critical:
        return 'Critical';
      case EventSeverity.warning:
        return 'Warning';
      case EventSeverity.info:
        return 'Info';
    }
  }

  Color _severityColor(EventSeverity severity) {
    switch (severity) {
      case EventSeverity.critical:
        return LabGuardColors.danger;
      case EventSeverity.warning:
        return LabGuardColors.warning;
      case EventSeverity.info:
        return LabGuardColors.accent;
    }
  }
}
