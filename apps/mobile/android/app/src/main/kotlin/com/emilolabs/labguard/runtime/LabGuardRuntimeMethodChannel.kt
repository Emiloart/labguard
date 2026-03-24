package com.emilolabs.labguard.runtime

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class LabGuardRuntimeMethodChannel {
    fun attach(
        binaryMessenger: BinaryMessenger,
        context: Context,
    ) {
        MethodChannel(binaryMessenger, CHANNEL_NAME).setMethodCallHandler(
            LabGuardRuntimeMethodCallHandler(context.applicationContext),
        )
    }

    companion object {
        const val CHANNEL_NAME = "com.emilolabs.labguard/runtime"
    }
}

private class LabGuardRuntimeMethodCallHandler(
    private val context: Context,
) : MethodChannel.MethodCallHandler {
    private val secureStateStore = LabGuardSecureStateStore(context)

    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            "configureBackgroundSync" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                val apiBaseUrl = call.argument<String>("apiBaseUrl").orEmpty()
                val existingPreferences =
                    secureStateStore.readRuntimePreferences() ?: defaultRuntimePreferences()

                LabGuardCommandSyncScheduler.configure(
                    context = context,
                    enabled = enabled,
                    apiBaseUrl = apiBaseUrl,
                )
                secureStateStore.writeRuntimePreferences(
                    existingPreferences.copy(
                        apiBaseUrl = if (enabled) apiBaseUrl else "",
                    ),
                )
                result.success(null)
            }

            "triggerBackgroundSync" -> {
                val apiBaseUrl = call.argument<String>("apiBaseUrl").orEmpty()
                LabGuardCommandSyncScheduler.triggerNow(
                    context = context,
                    apiBaseUrl = apiBaseUrl,
                )
                result.success(null)
            }

            "syncRuntimePreferences" -> {
                val notificationsEnabled = call.argument<Boolean>("notificationsEnabled") ?: true
                val autoConnectEnabled = call.argument<Boolean>("autoConnectEnabled") ?: true
                val existingPreferences =
                    secureStateStore.readRuntimePreferences() ?: defaultRuntimePreferences()

                secureStateStore.writeRuntimePreferences(
                    existingPreferences.copy(
                        notificationsEnabled = notificationsEnabled,
                        autoConnectEnabled = autoConnectEnabled,
                    ),
                )
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun defaultRuntimePreferences(): LabGuardSecureStateStore.StoredRuntimePreferences {
        return LabGuardSecureStateStore.StoredRuntimePreferences(
            notificationsEnabled = true,
            autoConnectEnabled = true,
            apiBaseUrl = "",
        )
    }
}
