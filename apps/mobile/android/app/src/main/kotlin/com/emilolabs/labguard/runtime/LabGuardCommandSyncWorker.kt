package com.emilolabs.labguard.runtime

import android.app.ActivityManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.nio.charset.StandardCharsets
import org.json.JSONArray
import org.json.JSONObject

class LabGuardCommandSyncWorker(
    appContext: android.content.Context,
    params: WorkerParameters,
) : Worker(appContext, params) {
    private val secureStateStore = LabGuardSecureStateStore(applicationContext)
    private val vpnManager = com.emilolabs.labguard.vpn.LabGuardVpnManager.getInstance(applicationContext)
    private val notifier = LabGuardRuntimeNotifier(applicationContext)

    override fun doWork(): Result {
        if (isAppForeground()) {
            return Result.success()
        }

        val apiBaseUrl =
            inputData
                .getString(KEY_API_BASE_URL)
                ?.trim()
                ?.trimEnd('/') ?: return Result.success()
        val session = secureStateStore.readSession() ?: return Result.success()

        return try {
            val commands = fetchCommands(apiBaseUrl, session)

            for (command in commands) {
                if (isStopped) {
                    return Result.retry()
                }
                if (!command.isPending()) {
                    continue
                }

                val shouldContinue = processCommand(apiBaseUrl, session, command)
                if (!shouldContinue) {
                    return Result.success()
                }
            }

            Result.success()
        } catch (error: HttpStatusException) {
            if (error.statusCode == HttpURLConnection.HTTP_UNAUTHORIZED) {
                secureStateStore.clearAuthSession()
                LabGuardCommandSyncScheduler.disable(applicationContext)
                Result.success()
            } else if (error.statusCode >= 500) {
                Result.retry()
            } else {
                Result.success()
            }
        } catch (_: IOException) {
            Result.retry()
        }
    }

    private fun processCommand(
        apiBaseUrl: String,
        session: LabGuardSecureStateStore.StoredSession,
        command: PendingRemoteCommand,
    ): Boolean {
        if (command.status == STATUS_QUEUED) {
            reportCommandStatus(
                apiBaseUrl = apiBaseUrl,
                accessToken = session.accessToken,
                commandId = command.commandId,
                status = STATUS_DELIVERED,
                resultMessage = deliveryMessage(command),
            )
        }

        val outcome = performLocalAction(command, session)

        reportCommandStatus(
            apiBaseUrl = apiBaseUrl,
            accessToken = session.accessToken,
            commandId = command.commandId,
            status = outcome.status,
            resultMessage = outcome.resultMessage,
            failureCode = outcome.failureCode,
        )

        outcome.afterReport?.invoke()
        return !outcome.haltSync
    }

    private fun performLocalAction(
        command: PendingRemoteCommand,
        session: LabGuardSecureStateStore.StoredSession,
    ): CommandOutcome {
        return when (command.commandType) {
            "SIGN_OUT" -> {
                vpnManager.clearProfile(applicationContext)
                notifier.showSecurityAlert(
                    title = "LabGuard signed out",
                    message = "Trusted access was revoked on ${session.deviceName}.",
                )
                CommandOutcome(
                    status = STATUS_SUCCEEDED,
                    resultMessage = "Trusted access and local VPN material were revoked on the device.",
                    afterReport = {
                        secureStateStore.clearAuthSession()
                        LabGuardCommandSyncScheduler.disable(applicationContext)
                    },
                    haltSync = true,
                )
            }

            "REVOKE_VPN" -> {
                vpnManager.clearProfile(applicationContext)
                notifier.showSecurityAlert(
                    title = "LabGuard VPN revoked",
                    message = "The local WireGuard profile was removed from ${session.deviceName}.",
                )
                CommandOutcome(
                    status = STATUS_SUCCEEDED,
                    resultMessage = "The local WireGuard profile was removed and the tunnel was stopped.",
                )
            }

            "ROTATE_SESSION" -> {
                vpnManager.clearProfile(applicationContext)
                notifier.showSecurityAlert(
                    title = "LabGuard session rotated",
                    message = "This device must authenticate again before access resumes.",
                )
                CommandOutcome(
                    status = STATUS_SUCCEEDED,
                    resultMessage = "Local session material was invalidated and the device must authenticate again.",
                    afterReport = {
                        secureStateStore.clearAuthSession()
                        LabGuardCommandSyncScheduler.disable(applicationContext)
                    },
                    haltSync = true,
                )
            }

            "WIPE_APP_DATA" -> {
                vpnManager.clearProfile(applicationContext)
                notifier.showSecurityAlert(
                    title = "LabGuard local data wiped",
                    message = "App-sensitive LabGuard data was cleared from this device.",
                )
                CommandOutcome(
                    status = STATUS_SUCCEEDED,
                    resultMessage = "LabGuard cleared locally stored session, VPN, and recovery data.",
                    afterReport = {
                        secureStateStore.clearAll()
                        LabGuardCommandSyncScheduler.disable(applicationContext)
                    },
                    haltSync = true,
                )
            }

            "RING_ALARM" -> {
                val message =
                    command.message
                        ?: "LabGuard recovery mode is active. This device was asked to ring for recovery."
                secureStateStore.writeRecoverySignal(
                    message = message,
                    alarmRequested = true,
                )
                notifier.showRecoveryAlert(
                    title = "LabGuard recovery alarm",
                    message = message,
                    alarmRequested = true,
                )
                CommandOutcome(
                    status = STATUS_SUCCEEDED,
                    resultMessage = "An in-app recovery alarm was triggered on the device.",
                )
            }

            "SHOW_RECOVERY_MESSAGE" -> {
                val message =
                    command.message
                        ?: "LabGuard owner is attempting recovery. Follow the recovery instructions on screen."
                secureStateStore.writeRecoverySignal(
                    message = message,
                    alarmRequested = false,
                )
                notifier.showRecoveryAlert(
                    title = "LabGuard recovery message",
                    message = message,
                    alarmRequested = false,
                )
                CommandOutcome(
                    status = STATUS_SUCCEEDED,
                    resultMessage = message,
                )
            }

            "MARK_RECOVERED" -> {
                secureStateStore.clearRecoverySignal()
                notifier.clearRecoveryAlerts()
                CommandOutcome(
                    status = STATUS_SUCCEEDED,
                    resultMessage = "Local recovery indicators were cleared on the device.",
                )
            }

            "DISABLE_DEVICE_ACCESS" -> {
                vpnManager.clearProfile(applicationContext)
                notifier.showSecurityAlert(
                    title = "LabGuard access disabled",
                    message = "Device access was disabled and reapproval is now required.",
                )
                CommandOutcome(
                    status = STATUS_SUCCEEDED,
                    resultMessage = "Local LabGuard access was disabled and the device must be reapproved.",
                    afterReport = {
                        secureStateStore.clearAuthSession()
                        LabGuardCommandSyncScheduler.disable(applicationContext)
                    },
                    haltSync = true,
                )
            }

            else ->
                CommandOutcome(
                    status = STATUS_FAILED,
                    resultMessage = "Unknown remote command type: ${command.commandType}",
                    failureCode = "UNKNOWN_COMMAND",
                )
        }
    }

    private fun fetchCommands(
        apiBaseUrl: String,
        session: LabGuardSecureStateStore.StoredSession,
    ): List<PendingRemoteCommand> {
        val response =
            executeRequest(
                method = "GET",
                url = "$apiBaseUrl/v1/remote-actions/${session.deviceId}",
                accessToken = session.accessToken,
            )
        val root = if (response.isBlank()) JSONObject() else JSONObject(response)
        val items = root.optJSONArray("items") ?: JSONArray()
        val commands = mutableListOf<PendingRemoteCommand>()

        for (index in 0 until items.length()) {
            val item = items.optJSONObject(index) ?: continue
            commands +=
                PendingRemoteCommand(
                    commandId = item.optString("commandId", ""),
                    deviceId = item.optString("deviceId", ""),
                    commandType = item.optString("commandType", ""),
                    status = item.optString("status", STATUS_QUEUED),
                    message = item.optNullableString("message"),
                )
        }

        return commands
    }

    private fun reportCommandStatus(
        apiBaseUrl: String,
        accessToken: String,
        commandId: String,
        status: String,
        resultMessage: String,
        failureCode: String? = null,
    ) {
        val body =
            JSONObject()
                .put("status", status)
                .put("resultMessage", resultMessage)
                .apply {
                    if (failureCode != null) {
                        put("failureCode", failureCode)
                    }
                }

        executeRequest(
            method = "POST",
            url = "$apiBaseUrl/v1/remote-actions/$commandId/result",
            accessToken = accessToken,
            body = body.toString(),
        )
    }

    @Throws(IOException::class, HttpStatusException::class)
    private fun executeRequest(
        method: String,
        url: String,
        accessToken: String,
        body: String? = null,
    ): String {
        val connection = (URL(url).openConnection() as HttpURLConnection).apply {
            requestMethod = method
            connectTimeout = 8_000
            readTimeout = 12_000
            doInput = true
            setRequestProperty("Accept", "application/json")
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("Authorization", "Bearer $accessToken")
        }

        try {
            if (!body.isNullOrBlank()) {
                connection.doOutput = true
                connection.outputStream.use { stream ->
                    stream.write(body.toByteArray(StandardCharsets.UTF_8))
                }
            }

            val statusCode = connection.responseCode
            val response =
                (if (statusCode in 200..299) connection.inputStream else connection.errorStream)
                    ?.bufferedReader()
                    ?.use { it.readText() }
                    .orEmpty()

            if (statusCode !in 200..299) {
                throw HttpStatusException(
                    statusCode = statusCode,
                    message = if (response.isBlank()) "HTTP $statusCode" else response,
                )
            }

            return response
        } finally {
            connection.disconnect()
        }
    }

    private fun deliveryMessage(command: PendingRemoteCommand): String {
        return when (command.commandType) {
            "RING_ALARM" -> "The device acknowledged the recovery alarm request."
            "SHOW_RECOVERY_MESSAGE" -> "The device accepted the recovery message for display."
            else -> "The device acknowledged the remote security action."
        }
    }

    private fun isAppForeground(): Boolean {
        val activityManager =
            applicationContext.getSystemService(ActivityManager::class.java) ?: return false
        val ownPid = android.os.Process.myPid()

        return activityManager.runningAppProcesses.orEmpty().any { process ->
            process.pid == ownPid &&
                process.importance <= ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND
        }
    }

    data class PendingRemoteCommand(
        val commandId: String,
        val deviceId: String,
        val commandType: String,
        val status: String,
        val message: String?,
    ) {
        fun isPending(): Boolean =
            status == LabGuardCommandSyncWorker.STATUS_QUEUED ||
                status == LabGuardCommandSyncWorker.STATUS_DELIVERED
    }

    data class CommandOutcome(
        val status: String,
        val resultMessage: String,
        val failureCode: String? = null,
        val afterReport: (() -> Unit)? = null,
        val haltSync: Boolean = false,
    )

    class HttpStatusException(
        val statusCode: Int,
        message: String,
    ) : IOException(message)

    companion object {
        const val KEY_API_BASE_URL = "api_base_url"
        private const val STATUS_QUEUED = "QUEUED"
        private const val STATUS_DELIVERED = "DELIVERED"
        private const val STATUS_SUCCEEDED = "SUCCEEDED"
        private const val STATUS_FAILED = "FAILED"
    }
}

private fun JSONObject.optNullableString(key: String): String? {
    val value = optString(key, "")
    return value.ifBlank { null }
}
