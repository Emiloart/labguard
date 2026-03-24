package com.emilolabs.labguard.runtime

import androidx.work.Constraints
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.OutOfQuotaPolicy
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.emilolabs.labguard.vpn.LabGuardVpnManager

class LabGuardBootRestoreWorker(
    appContext: android.content.Context,
    params: WorkerParameters,
) : Worker(appContext, params) {
    private val secureStateStore = LabGuardSecureStateStore(applicationContext)
    private val vpnManager = LabGuardVpnManager.getInstance(applicationContext)
    private val notifier = LabGuardRuntimeNotifier(applicationContext)

    override fun doWork(): Result {
        secureStateStore.readSession() ?: return Result.success()
        val runtimePreferences =
            secureStateStore.readRuntimePreferences()
                ?: return Result.success()

        if (!runtimePreferences.autoConnectEnabled) {
            return Result.success()
        }

        val status = vpnManager.getStatus(applicationContext)
        val permissionGranted = status["permissionGranted"] as? Boolean ?: false
        val profileInstalled = status["profileInstalled"] as? Boolean ?: false
        val tunnelState = status["tunnelState"] as? String ?: "PROFILE_MISSING"

        if (!permissionGranted || !profileInstalled || tunnelState == "CONNECTED") {
            return Result.success()
        }

        return runCatching {
            vpnManager.connect(applicationContext)
            Result.success()
        }.getOrElse { error ->
            notifier.showSecurityAlert(
                title = "LabGuard tunnel restore failed",
                message =
                    error.message
                        ?: "The stored WireGuard tunnel could not be restored after device restart.",
            )
            Result.success()
        }
    }

    companion object {
        private const val WORK_NAME = "labguard-boot-restore"

        fun enqueue(context: android.content.Context) {
            val request =
                OneTimeWorkRequestBuilder<LabGuardBootRestoreWorker>()
                    .setConstraints(
                        Constraints
                            .Builder()
                            .setRequiredNetworkType(NetworkType.CONNECTED)
                            .build(),
                    ).setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
                    .build()

            WorkManager.getInstance(context.applicationContext).enqueueUniqueWork(
                WORK_NAME,
                ExistingWorkPolicy.REPLACE,
                request,
            )
        }
    }
}
