package com.emilolabs.labguard.runtime

import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.OutOfQuotaPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import java.util.concurrent.TimeUnit

object LabGuardCommandSyncScheduler {
    fun configure(
        context: Context,
        enabled: Boolean,
        apiBaseUrl: String,
    ) {
        if (!enabled || apiBaseUrl.isBlank()) {
            disable(context)
            return
        }

        val manager = WorkManager.getInstance(context.applicationContext)
        val constraints =
            Constraints
                .Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()
        val inputData = workDataOf(LabGuardCommandSyncWorker.KEY_API_BASE_URL to apiBaseUrl)
        val periodicRequest =
            PeriodicWorkRequestBuilder<LabGuardCommandSyncWorker>(15, TimeUnit.MINUTES)
                .setConstraints(constraints)
                .setInputData(inputData)
                .addTag(PERIODIC_TAG)
                .build()

        manager.enqueueUniquePeriodicWork(
            PERIODIC_WORK_NAME,
            ExistingPeriodicWorkPolicy.UPDATE,
            periodicRequest,
        )
    }

    fun triggerNow(
        context: Context,
        apiBaseUrl: String,
    ) {
        if (apiBaseUrl.isBlank()) {
            return
        }

        val manager = WorkManager.getInstance(context.applicationContext)
        val request =
            OneTimeWorkRequestBuilder<LabGuardCommandSyncWorker>()
                .setConstraints(
                    Constraints
                        .Builder()
                        .setRequiredNetworkType(NetworkType.CONNECTED)
                        .build(),
                ).setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
                .setInputData(workDataOf(LabGuardCommandSyncWorker.KEY_API_BASE_URL to apiBaseUrl))
                .addTag(IMMEDIATE_TAG)
                .build()

        manager.enqueueUniqueWork(
            IMMEDIATE_WORK_NAME,
            ExistingWorkPolicy.REPLACE,
            request,
        )
    }

    fun disable(context: Context) {
        val manager = WorkManager.getInstance(context.applicationContext)
        manager.cancelUniqueWork(PERIODIC_WORK_NAME)
        manager.cancelUniqueWork(IMMEDIATE_WORK_NAME)
    }

    private const val PERIODIC_WORK_NAME = "labguard-command-sync-periodic"
    private const val IMMEDIATE_WORK_NAME = "labguard-command-sync-immediate"
    private const val PERIODIC_TAG = "labguard-command-sync"
    private const val IMMEDIATE_TAG = "labguard-command-sync-now"
}
