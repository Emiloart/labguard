package com.emilolabs.labguard

import com.emilolabs.labguard.runtime.LabGuardRuntimeMethodChannel
import com.emilolabs.labguard.system.LabGuardSystemMethodChannel
import com.emilolabs.labguard.vpn.LabGuardVpnMethodChannel
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    private val vpnMethodChannel = LabGuardVpnMethodChannel()
    private val runtimeMethodChannel = LabGuardRuntimeMethodChannel()
    private val systemMethodChannel = LabGuardSystemMethodChannel()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        vpnMethodChannel.attach(
            binaryMessenger = flutterEngine.dartExecutor.binaryMessenger,
            activity = this,
        )
        runtimeMethodChannel.attach(
            binaryMessenger = flutterEngine.dartExecutor.binaryMessenger,
            context = applicationContext,
        )
        systemMethodChannel.attach(
            binaryMessenger = flutterEngine.dartExecutor.binaryMessenger,
            activity = this,
        )
    }
}
