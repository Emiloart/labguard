package com.emilolabs.labguard.vpn

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.provider.Settings
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class LabGuardVpnMethodChannel {
    fun attach(binaryMessenger: BinaryMessenger, activity: FlutterFragmentActivity) {
        MethodChannel(binaryMessenger, CHANNEL_NAME).setMethodCallHandler(
            LabGuardVpnMethodCallHandler(activity),
        )
    }

    companion object {
        const val CHANNEL_NAME = "com.emilolabs.labguard/vpn"
    }
}

private class LabGuardVpnMethodCallHandler(
    private val activity: FlutterFragmentActivity,
) : MethodChannel.MethodCallHandler {
    private val manager = LabGuardVpnManager.getInstance(activity.applicationContext)
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private var pendingPrepareResult: MethodChannel.Result? = null
    private val permissionLauncher =
        activity.registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            val pendingResult = pendingPrepareResult ?: return@registerForActivityResult
            pendingPrepareResult = null
            val payload = manager.getPlatformCapabilities(activity)

            if (result.resultCode == Activity.RESULT_OK) {
                pendingResult.success(payload)
            } else {
                pendingResult.success(
                    payload + mapOf("notes" to "Android VPN permission was not granted."),
                )
            }
        }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getPlatformCapabilities" -> result.success(
                manager.getPlatformCapabilities(activity),
            )

            "getStatus" -> runAsync(result) {
                manager.getStatus(activity)
            }

            "prepareVpn" -> {
                if (pendingPrepareResult != null) {
                    result.error(
                        "vpn_prepare_in_progress",
                        "A VPN preparation request is already pending.",
                        null,
                    )
                    return
                }

                val prepareIntent = VpnService.prepare(activity)
                if (prepareIntent == null) {
                    result.success(manager.getPlatformCapabilities(activity))
                    return
                }

                pendingPrepareResult = result
                permissionLauncher.launch(prepareIntent)
            }

            "installProfile" -> {
                val deviceId = call.argument<String>("deviceId")
                val tunnelName = call.argument<String>("tunnelName")
                val serverId = call.argument<String>("serverId")
                val revision = call.argument<Int>("revision")
                val config = call.argument<String>("config")

                if (deviceId.isNullOrBlank() ||
                    tunnelName.isNullOrBlank() ||
                    serverId.isNullOrBlank() ||
                    revision == null ||
                    config.isNullOrBlank()
                ) {
                    result.error(
                        "vpn_invalid_profile",
                        "Tunnel installation requires deviceId, tunnelName, serverId, revision, and config.",
                        null,
                    )
                    return
                }

                runAsync(result) {
                    manager.installProfile(
                        deviceId = deviceId,
                        tunnelName = tunnelName,
                        serverId = serverId,
                        revision = revision,
                        configText = config,
                    )
                }
            }

            "connect" -> runAsync(result) {
                manager.connect(activity)
            }

            "disconnect" -> runAsync(result) {
                manager.disconnect(activity)
            }

            "clearProfile" -> runAsync(result) {
                manager.clearProfile(activity)
            }

            "openVpnSettings" -> {
                activity.startActivity(Intent(Settings.ACTION_VPN_SETTINGS))
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun runAsync(
        result: MethodChannel.Result,
        block: () -> Map<String, Any?>,
    ) {
        executor.execute {
            try {
                val payload = block()
                activity.runOnUiThread {
                    result.success(payload)
                }
            } catch (error: Exception) {
                activity.runOnUiThread {
                    result.error(
                        "vpn_bridge_failure",
                        error.message ?: "Unexpected VPN bridge failure.",
                        null,
                    )
                }
            }
        }
    }
}
