package com.emilolabs.labguard.system

import android.Manifest
import android.annotation.SuppressLint
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.time.Instant
import java.util.Locale

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
    private var notificationPermissionResult: MethodChannel.Result? = null
    private var locationPermissionResult: MethodChannel.Result? = null
    private var locationSampleResult: MethodChannel.Result? = null
    private val notificationPermissionLauncher =
        activity.registerForActivityResult(ActivityResultContracts.RequestPermission()) {
            notificationPermissionResult?.success(buildSecurityPosture())
            notificationPermissionResult = null
        }
    private val locationPermissionLauncher =
        activity.registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {
            locationPermissionResult?.success(buildSecurityPosture())
            locationPermissionResult = null
        }

    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            "getSecurityPosture" -> result.success(buildSecurityPosture())
            "requestNotificationPermission" -> requestNotificationPermission(result)
            "requestLocationPermission" -> requestLocationPermission(result)
            "getDeviceIdentity" -> result.success(buildDeviceIdentity())
            "captureLocationSample" -> captureLocationSample(result)
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

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (!ensureNoPendingRequest(result)) {
            return
        }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(buildSecurityPosture())
            return
        }

        notificationPermissionResult = result
        notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
    }

    private fun requestLocationPermission(result: MethodChannel.Result) {
        if (!ensureNoPendingRequest(result)) {
            return
        }

        locationPermissionResult = result
        locationPermissionLauncher.launch(
            arrayOf(
                Manifest.permission.ACCESS_COARSE_LOCATION,
                Manifest.permission.ACCESS_FINE_LOCATION,
            ),
        )
    }

    private fun buildDeviceIdentity(): Map<String, Any> {
        val manufacturer = Build.MANUFACTURER?.replaceFirstChar { it.titlecase(Locale.US) }.orEmpty()
        val model = Build.MODEL.orEmpty().ifBlank { "Android device" }
        val label =
            listOf(manufacturer, model)
                .filter { it.isNotBlank() }
                .distinct()
                .joinToString(separator = " ")
                .ifBlank { "Android device" }

        return mapOf(
            "name" to label,
            "model" to label,
            "platform" to "Android",
            "osVersion" to (Build.VERSION.RELEASE ?: Build.VERSION.SDK_INT.toString()),
        )
    }

    @SuppressLint("MissingPermission")
    private fun captureLocationSample(result: MethodChannel.Result) {
        if (!hasLocationPermission()) {
            result.success(emptyMap<String, Any>())
            return
        }

        val locationManager = activity.getSystemService(LocationManager::class.java)
        if (locationManager == null) {
            result.success(emptyMap<String, Any>())
            return
        }

        val provider = preferredLocationProvider(locationManager)
        if (provider == null) {
            result.success(bestKnownLocation(locationManager)?.let(::buildLocationSample) ?: emptyMap())
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (locationSampleResult != null) {
                result.error(
                    "location_request_in_progress",
                    "Another location refresh is already in progress.",
                    null,
                )
                return
            }

            locationSampleResult = result
            locationManager.getCurrentLocation(provider, null, activity.mainExecutor) { location ->
                val resolved = location ?: bestKnownLocation(locationManager)
                locationSampleResult?.success(
                    resolved?.let(::buildLocationSample) ?: emptyMap<String, Any>(),
                )
                locationSampleResult = null
            }
            return
        }

        result.success(bestKnownLocation(locationManager)?.let(::buildLocationSample) ?: emptyMap())
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

    private fun hasLocationPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            activity,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            ) == PackageManager.PERMISSION_GRANTED
    }

    private fun preferredLocationProvider(locationManager: LocationManager): String? {
        val fineLocationGranted =
            ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.ACCESS_FINE_LOCATION,
            ) == PackageManager.PERMISSION_GRANTED
        val enabledProviders = locationManager.getProviders(true)

        return when {
            fineLocationGranted && enabledProviders.contains(LocationManager.GPS_PROVIDER) ->
                LocationManager.GPS_PROVIDER
            enabledProviders.contains(LocationManager.NETWORK_PROVIDER) ->
                LocationManager.NETWORK_PROVIDER
            enabledProviders.contains(LocationManager.PASSIVE_PROVIDER) ->
                LocationManager.PASSIVE_PROVIDER
            else -> enabledProviders.firstOrNull()
        }
    }

    @SuppressLint("MissingPermission")
    private fun bestKnownLocation(locationManager: LocationManager): Location? {
        val providers =
            buildList {
                preferredLocationProvider(locationManager)?.let(::add)
                if (locationManager.getProviders(true).contains(LocationManager.NETWORK_PROVIDER)) {
                    add(LocationManager.NETWORK_PROVIDER)
                }
                if (locationManager.getProviders(true).contains(LocationManager.PASSIVE_PROVIDER)) {
                    add(LocationManager.PASSIVE_PROVIDER)
                }
            }.distinct()

        return providers
            .mapNotNull { provider ->
                runCatching { locationManager.getLastKnownLocation(provider) }.getOrNull()
            }.maxByOrNull { candidate ->
                val agePenalty = (System.currentTimeMillis() - candidate.time).coerceAtLeast(0L)
                val accuracyScore = candidate.accuracy.toDouble()
                -(agePenalty / 1_000L) - accuracyScore
            }
    }

    private fun buildLocationSample(location: Location): Map<String, Any> {
        val latitude = location.latitude
        val longitude = location.longitude
        val capturedAt =
            if (location.time > 0) {
                Instant.ofEpochMilli(location.time).toString()
            } else {
                Instant.now().toString()
            }

        return mapOf(
            "latitude" to latitude,
            "longitude" to longitude,
            "accuracyMeters" to location.accuracy.toDouble(),
            "capturedAt" to capturedAt,
            "label" to String.format(Locale.US, "%.4f, %.4f", latitude, longitude),
            "networkLabel" to currentNetworkLabel(),
            "provider" to (location.provider ?: "android"),
        )
    }

    private fun currentNetworkLabel(): String {
        val connectivityManager = activity.getSystemService(ConnectivityManager::class.java)
        val capabilities =
            connectivityManager?.getNetworkCapabilities(connectivityManager.activeNetwork)
                ?: return "Offline"

        return when {
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "Wi-Fi"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "Cellular"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "Ethernet"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN) -> "VPN"
            else -> "Online"
        }
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

    private fun ensureNoPendingRequest(result: MethodChannel.Result): Boolean {
        if (
            notificationPermissionResult != null ||
            locationPermissionResult != null ||
            locationSampleResult != null
        ) {
            result.error(
                "request_in_progress",
                "Another Android permission request is already pending.",
                null,
            )
            return false
        }

        return true
    }
}
