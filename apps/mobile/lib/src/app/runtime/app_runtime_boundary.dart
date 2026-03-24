import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_environment.dart';
import '../../core/platform/android_background_runtime_bridge.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/domain/auth_state.dart';
import '../../features/remote_actions/application/remote_command_runtime.dart';
import '../../features/remote_actions/data/recovery_signal_store.dart';
import '../../features/settings/application/settings_controller.dart';
import '../../features/vpn/application/vpn_session_controller.dart';

class AppRuntimeBoundary extends ConsumerStatefulWidget {
  const AppRuntimeBoundary({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppRuntimeBoundary> createState() => _AppRuntimeBoundaryState();
}

class _AppRuntimeBoundaryState extends ConsumerState<AppRuntimeBoundary>
    with WidgetsBindingObserver {
  Timer? _poller;
  bool _runtimeActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_runtimeActive) {
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_scheduleBackgroundSyncNow());
    }

    if (state == AppLifecycleState.resumed) {
      unawaited(_synchronize());
    }
  }

  @override
  Widget build(BuildContext context) {
    final authStage = ref.watch(
      authControllerProvider.select((state) => state.stage),
    );
    final shouldRun = authStage == AuthStage.signedIn;

    if (shouldRun != _runtimeActive) {
      _runtimeActive = shouldRun;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        if (_runtimeActive) {
          unawaited(_configureBackgroundSync(enabled: true));
          _startPolling();
          unawaited(_synchronize());
        } else {
          unawaited(_configureBackgroundSync(enabled: false));
          _stopPolling();
        }
      });
    }

    return widget.child;
  }

  void _startPolling() {
    _poller ??= Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(_synchronize());
    });
  }

  void _stopPolling() {
    _poller?.cancel();
    _poller = null;
  }

  Future<void> _synchronize() async {
    try {
      await ref.read(authControllerProvider.notifier).revalidateStoredSession();
    } catch (_) {
      // Session revalidation should not crash the shell.
    }

    ref.read(recoverySignalInvalidationProvider.notifier).state++;

    if (ref.read(authControllerProvider).stage != AuthStage.signedIn) {
      return;
    }

    try {
      await ref.read(settingsControllerProvider.future);
    } catch (_) {
      // Preference sync should not crash the shell or block command handling.
    }

    try {
      await ref.read(remoteCommandRuntimeProvider).synchronizeCurrentDevice();
    } catch (_) {
      // Runtime reconciliation should not crash the shell.
    }

    try {
      await ref.read(vpnSessionControllerProvider.notifier).refresh();
    } catch (_) {
      // VPN refresh errors are surfaced in the VPN screen itself.
    }
  }

  Future<void> _configureBackgroundSync({required bool enabled}) {
    return ref
        .read(androidBackgroundRuntimeBridgeProvider)
        .configureBackgroundSync(
          enabled: enabled,
          apiBaseUrl: AppEnvironment.apiBaseUrl,
        );
  }

  Future<void> _scheduleBackgroundSyncNow() {
    return ref
        .read(androidBackgroundRuntimeBridgeProvider)
        .triggerBackgroundSync(apiBaseUrl: AppEnvironment.apiBaseUrl);
  }
}
