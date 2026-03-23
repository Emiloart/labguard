import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dashboard_repository.dart';
import '../domain/dashboard_summary.dart';

final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) async {
  return ref.watch(dashboardRepositoryProvider).fetchSummary();
});
