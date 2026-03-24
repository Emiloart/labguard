package com.emilolabs.labguard.system

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class LabGuardSystemMethodChannel {
    fun attach(
        binaryMessenger: BinaryMessenger,
        activity: FlutterFragmentActivity,
    ) {
        MethodChannel(binaryMessenger, CHANNEL_NAME).setMethodCallHandler(
            LabGuardSystemMethodCallHandler(activity),
        )
    }

    companion object {
        const val CHANNEL_NAME = "com.emilolabs.labguard/system"
    }
}

private class LabGuardSystemMethodCallHandler(
    private val activity: FlutterFragmentActivity,
) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            "getSecurityPosture" -> result.success(buildSecurityPosture())
            "openNotificationSettings" -> {
                openNotificationSettings()
                result.success(null)
            }

            "openBatteryOptimizationSettings" -> {
                openBatteryOptimizationSettings()
                result.success(null)
            }

            "openApplicationSettings" -> {
                openApplicationSettings()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun buildSecurityPosture(): Map<String, Any> {
        val notificationsEnabled = NotificationManagerCompat.from(activity).areNotificationsEnabled()
        val fineLocationGranted =
            ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.ACCESS_FINE_LOCATION,
            ) == PackageManager.PERMISSION_GRANTED
        val coarseLocationGranted =
            ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            ) == PackageManager.PERMISSION_GRANTED
        val batteryOptimizationIgnored =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val powerManager = activity.getSystemService(PowerManager::class.java)
                powerManager?.isIgnoringBatteryOptimizations(activity.packageName) ?: false
            } else {
                true
            }

        return mapOf(
            "supported" to true,
            "sdkInt" to Build.VERSION.SDK_INT,
            "notificationsEnabled" to notificationsEnabled,
            "postNotificationsRuntimePermissionRequired" to
                (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU),
            "locationPermissionStatus" to
                when {
                    fineLocationGranted -> "granted_precise"
                    coarseLocationGranted -> "granted_approximate"
                    else -> "denied"
                },
            "batteryOptimizationIgnored" to batteryOptimizationIgnored,
        )
    }

    private fun openNotificationSettings() {
        val intent =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
                }
            } else {
                buildApplicationSettingsIntent()
            }

        activity.startActivity(intent)
    }

    private fun openBatteryOptimizationSettings() {
        val intent =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            } else {
                buildApplicationSettingsIntent()
            }

        activity.startActivity(intent)
    }

    private fun openApplicationSettings() {
        activity.startActivity(buildApplicationSettingsIntent())
    }

    private fun buildApplicationSettingsIntent(): Intent {
        return Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.fromParts("package", activity.packageName, null),
        )
    }
}
