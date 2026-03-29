package com.emilolabs.labguard.vpn

import android.content.Context
import android.net.VpnService
import com.emilolabs.labguard.runtime.LabGuardSecureStateStore
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
    private val secureStateStore = LabGuardSecureStateStore(applicationContext)

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
            "supportsAlwaysOnSystemSettings" to true,
            "killSwitchManagedBySystem" to true,
            "permissionGranted" to permissionGranted,
            "packageName" to applicationContext.packageName,
            "notes" to
                "LabGuard uses the official WireGuard Android tunnel backend. Kill switch enforcement must use Android Always-on VPN and block-without-VPN system settings.",
        )
    }

    fun getStatus(permissionContext: Context): Map<String, Any?> {
        restoreInstalledProfileIfNeeded()
        val runtimePreferences =
            secureStateStore.readRuntimePreferences() ?: defaultRuntimePreferences()
        val profile = installedProfile
        val permissionGranted = VpnService.prepare(permissionContext) == null
        val statistics = activeStatistics()
        val latestHandshake = latestHandshake(statistics)
        val tunnelState = when {
            profile == null -> "PROFILE_MISSING"
            !permissionGranted -> "AUTH_REQUIRED"
            currentTunnelState() != Tunnel.State.UP -> if (lastError != null) "ERROR" else "DISCONNECTED"
            latestHandshake != null && isRecentHandshake(latestHandshake) -> "CONNECTED"
            connectedAtEpochMillis != null && withinHandshakeGracePeriod() -> "CONNECTING"
            else -> "ERROR"
        }
        val statusError =
            when {
                tunnelState == "CONNECTED" || tunnelState == "CONNECTING" -> null
                tunnelState == "DISCONNECTED" -> lastError
                tunnelState == "ERROR" ->
                    lastError ?: "WireGuard is up but no recent handshake was observed."
                else -> lastError
            }

        if (profile != null && tunnelState == "CONNECTED") {
            LabGuardVpnRuntimeService.start(
                context = applicationContext,
                tunnelName = profile.tunnelName,
                serverName = profile.serverName,
                locationLabel = profile.locationLabel,
            )
        } else {
            LabGuardVpnRuntimeService.stop(applicationContext)
        }

        return mapOf(
            "permissionGranted" to permissionGranted,
            "profileInstalled" to (profile != null),
            "tunnelState" to tunnelState,
            "tunnelName" to (profile?.tunnelName ?: "labguard"),
            "serverId" to (profile?.serverId ?: ""),
            "profileRevision" to (profile?.revision ?: 0),
            "desiredConnected" to runtimePreferences.desiredConnected,
            "killSwitchRequested" to runtimePreferences.killSwitchEnabled,
            "currentIp" to "Unavailable",
            "bytesReceived" to (statistics?.totalRx() ?: 0L),
            "bytesSent" to (statistics?.totalTx() ?: 0L),
            "connectedAt" to connectedAtEpochMillis?.let(::toIsoString),
            "lastHandshakeAt" to latestHandshake?.let(::toIsoString),
            "lastError" to statusError,
            "backendVersion" to backendVersion(),
        )
    }

    fun installProfile(
        deviceId: String,
        tunnelName: String,
        serverId: String,
        serverName: String,
        locationLabel: String,
        endpoint: String,
        exitIpAddress: String,
        dnsServers: List<String>,
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
                deviceId = deviceId,
                tunnelName = sanitizedTunnelName,
                serverId = serverId,
                serverName = serverName,
                locationLabel = locationLabel,
                endpoint = endpoint,
                exitIpAddress = exitIpAddress,
                dnsServers = dnsServers,
                revision = revision,
                configText = configText,
                config = parsedConfig,
                interfaceAddress = interfaceAddress,
            )
        activeTunnel = LabGuardTunnel(sanitizedTunnelName)
        connectedAtEpochMillis = null
        lastError = null
        persistInstalledProfile()

        return getStatus(applicationContext)
    }

    fun connect(permissionContext: Context): Map<String, Any?> {
        restoreInstalledProfileIfNeeded()
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
        } catch (error: Exception) {
            connectedAtEpochMillis = null
            lastError = error.message ?: "Unable to bring the WireGuard tunnel online."
            LabGuardVpnRuntimeService.stop(applicationContext)
            throw error
        }

        return getStatus(permissionContext)
    }

    fun disconnect(permissionContext: Context): Map<String, Any?> {
        restoreInstalledProfileIfNeeded()
        disconnectInternal()
        return getStatus(permissionContext)
    }

    fun clearProfile(permissionContext: Context): Map<String, Any?> {
        restoreInstalledProfileIfNeeded()
        val deviceId =
            installedProfile?.deviceId
                ?: secureStateStore.readSession()?.deviceId
                ?: secureStateStore.readAnyVpnProfile()?.deviceId
        disconnectInternal()
        installedProfile = null
        activeTunnel = null
        connectedAtEpochMillis = null
        lastError = null
        if (!deviceId.isNullOrBlank()) {
            secureStateStore.clearVpnProfile(deviceId)
        }
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

    private fun restoreInstalledProfileIfNeeded() {
        if (installedProfile != null) {
            return
        }

        val persistedProfile =
            secureStateStore.readSession()?.deviceId?.let(secureStateStore::readVpnProfile)
                ?: secureStateStore.readAnyVpnProfile()
                ?: return

        runCatching {
            val parsedConfig = parseConfig(persistedProfile.configText)
            val interfaceAddress =
                parsedConfig
                    .getInterface()
                    .getAddresses()
                    .firstOrNull()
                    ?.toString() ?: "Unavailable"

            installedProfile =
                InstalledProfile(
                    deviceId = persistedProfile.deviceId,
                    tunnelName = sanitizeTunnelName(persistedProfile.tunnelName),
                    serverId = persistedProfile.serverId,
                    serverName = persistedProfile.serverName,
                    locationLabel = persistedProfile.locationLabel,
                    endpoint = persistedProfile.endpoint,
                    exitIpAddress = persistedProfile.exitIpAddress,
                    dnsServers = persistedProfile.dnsServers,
                    revision = persistedProfile.revision,
                    configText = persistedProfile.configText,
                    config = parsedConfig,
                    interfaceAddress = interfaceAddress,
                )
            activeTunnel = LabGuardTunnel(installedProfile!!.tunnelName)
        }.onFailure { error ->
            lastError = error.message ?: "LabGuard could not restore the stored WireGuard profile."
        }
    }

    private fun persistInstalledProfile() {
        val profile = installedProfile ?: return
        val existing = secureStateStore.readVpnProfile(profile.deviceId)

        secureStateStore.writeVpnProfile(
            LabGuardSecureStateStore.StoredVpnProfile(
                deviceId = profile.deviceId,
                profileStatus = "ACTIVE",
                revision = profile.revision,
                tunnelName = profile.tunnelName,
                serverId = profile.serverId,
                serverName = profile.serverName,
                locationLabel = profile.locationLabel,
                endpoint = profile.endpoint,
                exitIpAddress = profile.exitIpAddress,
                dnsServers = profile.dnsServers,
                issuedAt = existing?.issuedAt,
                rotatedAt = existing?.rotatedAt,
                configText = profile.configText,
                note =
                    existing?.note
                        ?: "Stored by the Android VPN runtime for process recovery.",
            ),
        )
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

    private fun isRecentHandshake(epochMillis: Long): Boolean {
        return System.currentTimeMillis() - epochMillis <= HANDSHAKE_STALE_THRESHOLD_MS
    }

    private fun withinHandshakeGracePeriod(): Boolean {
        val connectedAt = connectedAtEpochMillis ?: return false
        return System.currentTimeMillis() - connectedAt <= HANDSHAKE_GRACE_PERIOD_MS
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

    private fun defaultRuntimePreferences(): LabGuardSecureStateStore.StoredRuntimePreferences {
        return LabGuardSecureStateStore.StoredRuntimePreferences(
            notificationsEnabled = true,
            autoConnectEnabled = true,
            killSwitchEnabled = true,
            desiredConnected = false,
            apiBaseUrl = "",
        )
    }

    private data class InstalledProfile(
        val deviceId: String,
        val tunnelName: String,
        val serverId: String,
        val serverName: String,
        val locationLabel: String,
        val endpoint: String,
        val exitIpAddress: String,
        val dnsServers: List<String>,
        val revision: Int,
        val configText: String,
        val config: Config,
        val interfaceAddress: String,
    )

    companion object {
        private const val HANDSHAKE_GRACE_PERIOD_MS = 15_000L
        private const val HANDSHAKE_STALE_THRESHOLD_MS = 120_000L

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
