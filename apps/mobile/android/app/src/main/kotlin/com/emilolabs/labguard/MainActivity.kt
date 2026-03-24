package com.emilolabs.labguard

import com.emilolabs.labguard.vpn.LabGuardVpnMethodChannel
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    private val vpnMethodChannel = LabGuardVpnMethodChannel()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        vpnMethodChannel.attach(
            binaryMessenger = flutterEngine.dartExecutor.binaryMessenger,
            activity = this,
        )
    }
}
