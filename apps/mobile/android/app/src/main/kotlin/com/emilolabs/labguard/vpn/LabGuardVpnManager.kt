package com.emilolabs.labguard.vpn

import android.content.Context
import android.net.VpnService
import com.wireguard.android.backend.GoBackend
import com.wireguard.android.backend.Statistics
import com.wireguard.android.backend.Tunnel
import com.wireguard.config.Config
import java.io.BufferedReader
import java.io.StringReader
import java.time.Instant

class LabGuardVpnManager private constructor(
    private val applicationContext: Context,
) {
    private val backend = GoBackend(applicationContext)

    @Volatile
    private var installedProfile: InstalledProfile? = null

    @Volatile
    private var activeTunnel: LabGuardTunnel? = null

    @Volatile
    private var connectedAtEpochMillis: Long? = null

    @Volatile
    private var lastError: String? = null

    fun getPlatformCapabilities(permissionContext: Context): Map<String, Any?> {
        val permissionGranted = VpnService.prepare(permissionContext) == null

        return mapOf(
            "platform" to "android",
            "vpnServicePrepared" to permissionGranted,
            "wireGuardBackendIntegrated" to true,
            "permissionGranted" to permissionGranted,
            "packageName" to applicationContext.packageName,
            "notes" to "LabGuard uses the official WireGuard Android tunnel backend for the Phase 3 VPN core.",
        )
    }

    fun getStatus(permissionContext: Context): Map<String, Any?> {
        val profile = installedProfile
        val permissionGranted = VpnService.prepare(permissionContext) == null
        val tunnelState = when {
            profile == null -> "PROFILE_MISSING"
            currentTunnelState() == Tunnel.State.UP -> "CONNECTED"
            !permissionGranted -> "AUTH_REQUIRED"
            lastError != null -> "ERROR"
            else -> "DISCONNECTED"
        }
        val statistics = activeStatistics()
        val latestHandshake = latestHandshake(statistics)

        return mapOf(
            "permissionGranted" to permissionGranted,
            "profileInstalled" to (profile != null),
            "tunnelState" to tunnelState,
            "tunnelName" to (profile?.tunnelName ?: "labguard"),
            "serverId" to (profile?.serverId ?: ""),
            "profileRevision" to (profile?.revision ?: 0),
            "currentIp" to if (tunnelState == "CONNECTED") profile?.interfaceAddress ?: "Unavailable" else "Unavailable",
            "bytesReceived" to (statistics?.totalRx() ?: 0L),
            "bytesSent" to (statistics?.totalTx() ?: 0L),
            "connectedAt" to connectedAtEpochMillis?.let(::toIsoString),
            "lastHandshakeAt" to latestHandshake?.let(::toIsoString),
            "lastError" to lastError,
            "backendVersion" to backendVersion(),
        )
    }

    fun installProfile(
        tunnelName: String,
        serverId: String,
        revision: Int,
        configText: String,
    ): Map<String, Any?> {
        if (currentTunnelState() == Tunnel.State.UP) {
            disconnectInternal()
        }

        val sanitizedTunnelName = sanitizeTunnelName(tunnelName)
        val parsedConfig = parseConfig(configText)
        val interfaceAddress =
            parsedConfig
                .getInterface()
                .getAddresses()
                .firstOrNull()
                ?.toString() ?: "Unavailable"

        installedProfile =
            InstalledProfile(
                tunnelName = sanitizedTunnelName,
                serverId = serverId,
                revision = revision,
                config = parsedConfig,
                interfaceAddress = interfaceAddress,
            )
        activeTunnel = LabGuardTunnel(sanitizedTunnelName)
        connectedAtEpochMillis = null
        lastError = null

        return getStatus(applicationContext)
    }

    fun connect(permissionContext: Context): Map<String, Any?> {
        val profile = installedProfile
            ?: throw IllegalStateException("No WireGuard profile is installed for LabGuard.")

        if (VpnService.prepare(permissionContext) != null) {
            lastError = "Android VPN permission is required before the tunnel can start."
            return getStatus(permissionContext)
        }

        val tunnel = activeTunnel ?: LabGuardTunnel(profile.tunnelName).also { activeTunnel = it }

        try {
            lastError = null
            backend.setState(tunnel, Tunnel.State.UP, profile.config)
            connectedAtEpochMillis = System.currentTimeMillis()
            LabGuardVpnRuntimeService.start(
                context = applicationContext,
                tunnelName = profile.tunnelName,
                serverId = profile.serverId,
            )
        } catch (error: Exception) {
            connectedAtEpochMillis = null
            lastError = error.message ?: "Unable to bring the WireGuard tunnel online."
            LabGuardVpnRuntimeService.stop(applicationContext)
            throw error
        }

        return getStatus(permissionContext)
    }

    fun disconnect(permissionContext: Context): Map<String, Any?> {
        disconnectInternal()
        return getStatus(permissionContext)
    }

    fun clearProfile(permissionContext: Context): Map<String, Any?> {
        disconnectInternal()
        installedProfile = null
        activeTunnel = null
        connectedAtEpochMillis = null
        lastError = null
        return getStatus(permissionContext)
    }

    private fun disconnectInternal() {
        val tunnel = activeTunnel

        if (tunnel != null && currentTunnelState() == Tunnel.State.UP) {
            runCatching {
                backend.setState(tunnel, Tunnel.State.DOWN, null)
            }.onFailure { error ->
                lastError = error.message ?: "Failed to stop the WireGuard tunnel cleanly."
            }
        }

        connectedAtEpochMillis = null
        LabGuardVpnRuntimeService.stop(applicationContext)
    }

    private fun currentTunnelState(): Tunnel.State {
        val tunnel = activeTunnel ?: return Tunnel.State.DOWN
        return runCatching {
            backend.getState(tunnel)
        }.getOrElse {
            Tunnel.State.DOWN
        }
    }

    private fun activeStatistics(): Statistics? {
        val tunnel = activeTunnel ?: return null
        if (currentTunnelState() != Tunnel.State.UP) {
            return null
        }

        return runCatching {
            backend.getStatistics(tunnel)
        }.getOrNull()
    }

    private fun latestHandshake(statistics: Statistics?): Long? {
        if (statistics == null) {
            return null
        }

        var latest: Long? = null
        for (peer in statistics.peers()) {
            val peerStats = statistics.peer(peer) ?: continue
            val handshake = peerStats.latestHandshakeEpochMillis()
            if (handshake <= 0) {
                continue
            }

            latest = maxOf(latest ?: handshake, handshake)
        }

        return latest
    }

    private fun parseConfig(configText: String): Config {
        return BufferedReader(StringReader(configText)).use(Config::parse)
    }

    private fun backendVersion(): String {
        return runCatching {
            backend.version
        }.getOrDefault("Unavailable")
    }

    private fun sanitizeTunnelName(value: String): String {
        val sanitized = value.replace(Regex("[^a-zA-Z0-9_=+.-]"), "").take(15)
        return if (sanitized.isBlank()) {
            "labguard"
        } else {
            sanitized
        }
    }

    private fun toIsoString(epochMillis: Long): String = Instant.ofEpochMilli(epochMillis).toString()

    private data class InstalledProfile(
        val tunnelName: String,
        val serverId: String,
        val revision: Int,
        val config: Config,
        val interfaceAddress: String,
    )

    companion object {
        @Volatile
        private var instance: LabGuardVpnManager? = null

        fun getInstance(context: Context): LabGuardVpnManager {
            return instance ?: synchronized(this) {
                instance ?: LabGuardVpnManager(context.applicationContext).also {
                    instance = it
                }
            }
        }
    }
}
