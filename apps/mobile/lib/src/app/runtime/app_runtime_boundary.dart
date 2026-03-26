import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_environment.dart';
import '../../core/platform/android_background_runtime_bridge.dart';
import '../../core/security/app_lock_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_panel.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/domain/auth_state.dart';
import '../../features/find_device/application/find_device_provider.dart';
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
      ref.read(appLockControllerProvider).lock();
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
    final appLockState = ref.watch(appLockStateProvider);
    final shouldRun = authStage == AuthStage.signedIn;

    if (shouldRun != _runtimeActive) {
      _runtimeActive = shouldRun;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        if (_runtimeActive) {
          final controller = ref.read(appLockControllerProvider);
          if (appLockState.canUseBiometrics || appLockState.canUsePin) {
            controller.lock();
          }
          unawaited(_configureBackgroundSync(enabled: true));
          _startPolling();
          unawaited(_synchronize());
        } else {
          ref.read(appLockControllerProvider).clearLock();
          unawaited(_configureBackgroundSync(enabled: false));
          _stopPolling();
        }
      });
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (appLockState.requiresUnlock) const _AppLockGate(),
      ],
    );
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

    try {
      await ref
          .read(findDeviceControllerProvider)
          .syncCurrentDeviceLocationIfLostModeActive();
    } catch (_) {
      // Lost-mode location refresh should not crash the shell.
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

class _AppLockGate extends ConsumerStatefulWidget {
  const _AppLockGate();

  @override
  ConsumerState<_AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<_AppLockGate> {
  final TextEditingController _pinController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lockState = ref.watch(appLockStateProvider);
    final controller = ref.read(appLockControllerProvider);

    return ColoredBox(
      color: LabGuardColors.background.withValues(alpha: 0.92),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AppPanel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Secure Access Locked',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _subtitle(lockState),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (lockState.canUsePin) ...[
                      const SizedBox(height: 18),
                      TextField(
                        controller: _pinController,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => controller.clearError(),
                        decoration: const InputDecoration(
                          labelText: 'App PIN',
                          hintText: 'Enter your security PIN',
                        ),
                      ),
                    ],
                    if (lockState.errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        lockState.errorMessage!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: LabGuardColors.warning,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed:
                                lockState.unlockInFlight ||
                                    lockState.policyLoading
                                ? null
                                : () async {
                                    final unlocked = await controller.unlock(
                                      pin: _pinController.text,
                                    );
                                    if (unlocked && mounted) {
                                      _pinController.clear();
                                    }
                                  },
                            child: lockState.unlockInFlight
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(_primaryLabel(lockState)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _subtitle(AppLockState state) {
    if (state.policyLoading) {
      return 'Loading secure access policy for this trusted LabGuard session.';
    }
    if (state.canUseBiometrics && state.canUsePin) {
      return 'Verify a trusted biometric or enter the app PIN before protected controls resume.';
    }
    if (state.canUseBiometrics) {
      return 'Verify a trusted biometric before protected controls resume.';
    }
    return 'Enter the app PIN before protected controls resume.';
  }

  String _primaryLabel(AppLockState state) {
    if (state.canUseBiometrics && state.canUsePin) {
      return 'Unlock Secure Access';
    }
    if (state.canUseBiometrics) {
      return 'Use Biometrics';
    }
    return 'Verify PIN';
  }
}
