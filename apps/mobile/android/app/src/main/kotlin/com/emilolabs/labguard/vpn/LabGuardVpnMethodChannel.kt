package com.emilolabs.labguard.vpn

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class LabGuardVpnMethodChannel : MethodChannel.MethodCallHandler {
    fun attach(binaryMessenger: BinaryMessenger, context: Context) {
        val applicationContext = context.applicationContext
        MethodChannel(binaryMessenger, CHANNEL_NAME).setMethodCallHandler(
            LabGuardVpnMethodCallHandler(applicationContext),
        )
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        result.notImplemented()
    }

    companion object {
        const val CHANNEL_NAME = "com.emilolabs.labguard/vpn"
    }
}

private class LabGuardVpnMethodCallHandler(
    private val applicationContext: Context,
) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getPlatformCapabilities" -> {
                result.success(
                    mapOf(
                        "platform" to "android",
                        "vpnServicePrepared" to false,
                        "wireGuardBackendIntegrated" to false,
                        "packageName" to applicationContext.packageName,
                        "notes" to "Phase 1 placeholder. WireGuard and VpnService integration lands in Phase 3.",
                    ),
                )
            }

            "prepareVpn" -> {
                result.success(
                    mapOf(
                        "status" to "planned",
                        "message" to "Native VPN preparation bridge scaffolded. No tunnel lifecycle is active yet.",
                    ),
                )
            }

            else -> result.notImplemented()
        }
    }
}
