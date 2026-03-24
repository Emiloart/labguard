package com.emilolabs.labguard.vpn

import com.wireguard.android.backend.Tunnel

class LabGuardTunnel(
    private val tunnelName: String,
) : Tunnel {
    @Volatile
    var state: Tunnel.State = Tunnel.State.DOWN
        private set

    override fun getName(): String = tunnelName

    override fun onStateChange(newState: Tunnel.State) {
        state = newState
    }
}
