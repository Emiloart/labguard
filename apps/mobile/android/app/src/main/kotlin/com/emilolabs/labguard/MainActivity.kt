package com.emilolabs.labguard

import com.emilolabs.labguard.vpn.LabGuardVpnMethodChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private val vpnMethodChannel = LabGuardVpnMethodChannel()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        vpnMethodChannel.attach(
            binaryMessenger = flutterEngine.dartExecutor.binaryMessenger,
            context = applicationContext,
        )
    }
}
