import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/domain/auth_state.dart';
import '../../features/remote_actions/application/remote_command_runtime.dart';
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
          _startPolling();
          unawaited(_synchronize());
        } else {
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
      await ref.read(remoteCommandRuntimeProvider).synchronizeCurrentDevice();
    } catch (_) {
      // Runtime reconciliation should not crash the shell.
    }

    if (ref.read(authControllerProvider).stage != AuthStage.signedIn) {
      return;
    }

    try {
      await ref.read(vpnSessionControllerProvider.notifier).refresh();
    } catch (_) {
      // VPN refresh errors are surfaced in the VPN screen itself.
    }
  }
}
