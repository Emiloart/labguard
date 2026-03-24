package com.emilolabs.labguard.runtime

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class LabGuardBootReceiver : BroadcastReceiver() {
    override fun onReceive(
        context: Context,
        intent: Intent?,
    ) {
        val action = intent?.action ?: return
        if (
            action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED &&
            action != Intent.ACTION_USER_UNLOCKED
        ) {
            return
        }

        val applicationContext = context.applicationContext
        val secureStateStore = LabGuardSecureStateStore(applicationContext)
        val notifier = LabGuardRuntimeNotifier(applicationContext)
        val session = runCatching { secureStateStore.readSession() }.getOrNull()

        if (session == null) {
            notifier.clearRecoveryAlerts()
            LabGuardCommandSyncScheduler.disable(applicationContext)
            return
        }

        val runtimePreferences = runCatching { secureStateStore.readRuntimePreferences() }.getOrNull()
        val recoverySignal = runCatching { secureStateStore.readRecoverySignal() }.getOrNull()

        recoverySignal?.let { signal ->
            notifier.showRecoveryAlert(
                title =
                    if (signal.alarmRequested) {
                        "LabGuard recovery alarm"
                    } else {
                        "LabGuard recovery message"
                    },
                message = signal.message,
                alarmRequested = signal.alarmRequested,
            )
        }

        val apiBaseUrl = runtimePreferences?.apiBaseUrl?.trim()?.trimEnd('/').orEmpty()
        if (apiBaseUrl.isNotBlank()) {
            LabGuardCommandSyncScheduler.configure(
                context = applicationContext,
                enabled = true,
                apiBaseUrl = apiBaseUrl,
            )
            LabGuardCommandSyncScheduler.triggerNow(
                context = applicationContext,
                apiBaseUrl = apiBaseUrl,
            )
        } else {
            LabGuardCommandSyncScheduler.disable(applicationContext)
        }

        if (runtimePreferences?.autoConnectEnabled == true) {
            LabGuardBootRestoreWorker.enqueue(applicationContext)
        }
    }
}
