import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/about/presentation/about_screen.dart';
import '../../features/audit/presentation/audit_logs_screen.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/devices/presentation/device_detail_screen.dart';
import '../../features/devices/presentation/devices_screen.dart';
import '../../features/events/presentation/security_events_screen.dart';
import '../../features/find_device/presentation/find_device_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/vpn/presentation/vpn_screen.dart';
import '../shell/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'labguard-root',
);

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(location: state.uri.path, child: child);
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(path: '/vpn', builder: (context, state) => const VpnScreen()),
          GoRoute(
            path: '/devices',
            builder: (context, state) => const DevicesScreen(),
            routes: [
              GoRoute(
                path: ':deviceId',
                builder: (context, state) {
                  final deviceId = state.pathParameters['deviceId']!;
                  return DeviceDetailScreen(deviceId: deviceId);
                },
                routes: [
                  GoRoute(
                    path: 'find',
                    builder: (context, state) {
                      final deviceId = state.pathParameters['deviceId']!;
                      return FindDeviceScreen(deviceId: deviceId);
                    },
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/events',
            builder: (context, state) => const SecurityEventsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: 'about',
                builder: (context, state) => const AboutScreen(),
              ),
              GoRoute(
                path: 'audit',
                builder: (context, state) => const AuditLogsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final location = state.uri.path;

      switch (authState.stage) {
        case AuthStage.booting:
          return location == '/splash' ? null : '/splash';
        case AuthStage.onboarding:
          return location == '/onboarding' ? null : '/onboarding';
        case AuthStage.signedOut:
          return location == '/login' ? null : '/login';
        case AuthStage.signedIn:
          if (location == '/splash' ||
              location == '/onboarding' ||
              location == '/login') {
            return '/dashboard';
          }
          return null;
      }
    },
  );
});
