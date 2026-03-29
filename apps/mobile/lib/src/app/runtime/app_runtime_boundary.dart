import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_environment.dart';
import '../../core/platform/android_background_runtime_bridge.dart';
import '../../core/security/app_lock_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';
import '../../core/widgets/app_panel.dart';
import '../../core/widgets/panel_header.dart';
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
  String? _activeSessionDeviceId;
  String? _pendingLaunchLockDeviceId;

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

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_scheduleBackgroundSyncNow());
    }

    if (state == AppLifecycleState.resumed) {
      unawaited(_synchronize());
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final authStage = authState.stage;
    final sessionDeviceId = authState.session?.device.id;
    final appLockState = ref.watch(appLockStateProvider);
    final shouldRun = authStage == AuthStage.signedIn;
    final protectionAvailable =
        appLockState.canUseBiometrics || appLockState.canUsePin;

    if (shouldRun &&
        sessionDeviceId != null &&
        sessionDeviceId.isNotEmpty &&
        _activeSessionDeviceId != sessionDeviceId) {
      _activeSessionDeviceId = sessionDeviceId;
      _pendingLaunchLockDeviceId = sessionDeviceId;
    }

    final shouldArmLaunchLock =
        shouldRun &&
        sessionDeviceId != null &&
        sessionDeviceId.isNotEmpty &&
        protectionAvailable &&
        _pendingLaunchLockDeviceId == sessionDeviceId;

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
          _activeSessionDeviceId = null;
          _pendingLaunchLockDeviceId = null;
          ref.read(appLockControllerProvider).clearLock();
          unawaited(_configureBackgroundSync(enabled: false));
          _stopPolling();
        }
      });
    }

    if (shouldArmLaunchLock) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _pendingLaunchLockDeviceId != sessionDeviceId) {
          return;
        }

        ref.read(appLockControllerProvider).lock();
        _pendingLaunchLockDeviceId = null;
      });
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        AnimatedSwitcher(
          duration: AppMetrics.standardDuration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOutCubic,
          child: appLockState.requiresUnlock
              ? const _AppLockGate()
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  void _startPolling() {
    _poller ??= Timer.periodic(const Duration(minutes: 1), (_) {
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
  bool _autoUnlockAttempted = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lockState = ref.watch(appLockStateProvider);
    final controller = ref.read(appLockControllerProvider);

    if (!lockState.locked) {
      _autoUnlockAttempted = false;
    }

    final shouldAutoPromptBiometric =
        lockState.locked &&
        lockState.canUseBiometrics &&
        !lockState.policyLoading &&
        !lockState.unlockInFlight &&
        !_autoUnlockAttempted;

    if (shouldAutoPromptBiometric) {
      _autoUnlockAttempted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) {
          return;
        }

        final unlocked = await controller.unlock();
        if (unlocked && mounted) {
          _pinController.clear();
        }
      });
    }

    return ColoredBox(
      color: LabGuardColors.background.withValues(alpha: 0.92),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: AppMetrics.modalPadding,
              child: AppPanel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PanelHeader(
                      title: 'Unlock LabGuard',
                      subtitle: _subtitle(lockState),
                    ),
                    if (lockState.canUsePin) ...[
                      const SizedBox(height: 18),
                      TextField(
                        controller: _pinController,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        onChanged: (_) => controller.clearError(),
                        decoration: const InputDecoration(
                          labelText: 'App PIN',
                          hintText: 'Enter your 4-digit code',
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
      return 'Loading the secure access policy for this device.';
    }
    if (state.canUseBiometrics && state.canUsePin) {
      return 'Use biometrics or your app PIN to reopen LabGuard.';
    }
    if (state.canUseBiometrics) {
      return 'Use biometrics to reopen LabGuard.';
    }
    return 'Enter your app PIN to reopen LabGuard.';
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
