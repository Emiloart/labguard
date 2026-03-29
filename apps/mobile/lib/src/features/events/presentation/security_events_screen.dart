import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_panel.dart';
import '../../../core/widgets/panel_header.dart';
import '../../../core/widgets/screen_intro.dart';
import '../../../core/widgets/state_panels.dart';
import '../../../core/widgets/status_badge.dart';
import '../application/security_events_provider.dart';
import '../domain/security_event_record.dart';

class SecurityEventsScreen extends ConsumerWidget {
  const SecurityEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(securityEventsProvider);
    final cachedEvents = events.valueOrNull;

    if (cachedEvents != null) {
      return _SecurityEventsContent(
        events: cachedEvents,
        isRefreshing: events.isLoading,
      );
    }

    return events.when(
      data: (items) => _SecurityEventsContent(events: items),
      loading: () => ListView(
        padding: AppMetrics.pagePadding,
        children: const [
          LoadingPanel(
            label: 'Loading security events',
            message:
                'Preparing alert severity, unread state, and recent command outcomes.',
          ),
        ],
      ),
      error: (error, _) => ListView(
        padding: AppMetrics.pagePadding,
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

class _SecurityEventsContent extends ConsumerWidget {
  const _SecurityEventsContent({
    required this.events,
    this.isRefreshing = false,
  });

  final List<SecurityEventRecord> events;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatter = DateFormat('MMM d, HH:mm');
    final unreadCount = events.where((event) => event.unread).length;

    return ListView(
      padding: AppMetrics.pagePadding,
      children: [
        if (isRefreshing) ...[
          const LinearProgressIndicator(minHeight: 3),
          const SizedBox(height: 16),
        ],
        ScreenIntro(
          eyebrow: 'Security Telemetry',
          title: 'Security Events',
          description:
              'Unread alerts, suspicious state changes, remote action outcomes, and VPN events surface here.',
          badge: unreadCount == 0 ? 'CLEAR' : '$unreadCount UNREAD',
        ),
        const SizedBox(height: AppMetrics.sectionGap),
        if (events.isEmpty)
          const EmptyPanel(
            title: 'No security events are waiting',
            message:
                'New VPN incidents, trust transitions, and remote command outcomes will appear here when they are raised.',
            icon: Icons.notifications_none_outlined,
          )
        else ...[
          for (final event in events) ...[
            AppPanel(
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
                  PanelHeader(title: event.title, subtitle: event.summary),
                  const SizedBox(height: 12),
                  Text(
                    '${event.deviceName ?? 'Account'} • ${formatter.format(event.occurredAt)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (event.unread) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          await ref
                              .read(securityEventsControllerProvider)
                              .markRead(event.id);
                        },
                        icon: const Icon(Icons.done_outlined),
                        label: const Text('Mark read'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (event != events.last) const SizedBox(height: 16),
          ],
        ],
      ],
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
