import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const _destinations = [
    _ShellDestination(
      label: 'Dashboard',
      icon: Icons.shield_outlined,
      path: '/dashboard',
    ),
    _ShellDestination(label: 'VPN', icon: Icons.lock_outline, path: '/vpn'),
    _ShellDestination(
      label: 'Devices',
      icon: Icons.devices_outlined,
      path: '/devices',
    ),
    _ShellDestination(
      label: 'Events',
      icon: Icons.notifications_active_outlined,
      path: '/events',
    ),
    _ShellDestination(
      label: 'Settings',
      icon: Icons.tune_outlined,
      path: '/settings',
    ),
  ];

  int get _currentIndex {
    for (var index = 0; index < _destinations.length; index++) {
      if (location == _destinations[index].path ||
          location.startsWith('${_destinations[index].path}/')) {
        return index;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              LabGuardColors.background,
              LabGuardColors.backgroundMuted,
              LabGuardColors.background,
            ],
          ),
        ),
        child: SafeArea(child: child),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Semantics(
              container: true,
              label: 'LabGuard primary navigation',
              child: NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) {
                  context.go(_destinations[index].path);
                },
                destinations: [
                  for (final destination in _destinations)
                    NavigationDestination(
                      icon: Icon(destination.icon),
                      label: destination.label,
                      tooltip: 'Open ${destination.label}',
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellDestination {
  const _ShellDestination({
    required this.label,
    required this.icon,
    required this.path,
  });

  final String label;
  final IconData icon;
  final String path;
}
