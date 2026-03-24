package com.emilolabs.labguard.runtime

import android.content.Context
import com.it_nomads.fluttersecurestorage.FlutterSecureStorage
import org.json.JSONArray
import org.json.JSONObject

class LabGuardSecureStateStore(
    context: Context,
) {
    private val secureStorage = FlutterSecureStorage(context.applicationContext, hashMapOf())

    fun readSession(): StoredSession? {
        val raw = readRaw(AUTH_SESSION_KEY) ?: return null
        val payload = runCatching { JSONObject(raw) }.getOrNull() ?: return null
        val device = payload.optJSONObject("device") ?: JSONObject()
        val account = payload.optJSONObject("account") ?: JSONObject()
        val viewer = payload.optJSONObject("viewer") ?: JSONObject()
        val accessToken = payload.optString("accessToken", "")
        val refreshToken = payload.optString("refreshToken", "")
        val deviceId = device.optString("id", "")

        if (accessToken.isBlank() || refreshToken.isBlank() || deviceId.isBlank()) {
            return null
        }

        return StoredSession(
            accessToken = accessToken,
            refreshToken = refreshToken,
            deviceId = deviceId,
            deviceName = device.optString("name", "Unknown device"),
            accountName = account.optString("name", "Emilo Labs"),
            viewerLabel = viewer.optString("displayName", "LabGuard User"),
        )
    }

    fun readVpnProfile(deviceId: String): StoredVpnProfile? {
        val raw = readRaw("$VPN_PROFILE_KEY_PREFIX$deviceId") ?: return null
        return parseVpnProfile(raw)
    }

    fun readAnyVpnProfile(): StoredVpnProfile? {
        val items = secureStorage.readAll()

        return items.entries
            .firstOrNull { it.key.startsWith(VPN_PROFILE_KEY_PREFIX) }
            ?.value
            ?.let(::parseVpnProfile)
    }

    fun writeVpnProfile(profile: StoredVpnProfile) {
        val payload =
            JSONObject()
                .put("deviceId", profile.deviceId)
                .put("profileStatus", profile.profileStatus)
                .put("revision", profile.revision)
                .put("tunnelName", profile.tunnelName)
                .put("serverId", profile.serverId)
                .put("serverName", profile.serverName)
                .put("endpoint", profile.endpoint)
                .put("dnsServers", JSONArray(profile.dnsServers))
                .put("issuedAt", profile.issuedAt)
                .put("rotatedAt", profile.rotatedAt)
                .put("config", profile.configText)
                .put("note", profile.note)

        writeRaw("$VPN_PROFILE_KEY_PREFIX${profile.deviceId}", payload.toString())
    }

    fun clearAuthSession() {
        deleteRaw(AUTH_SESSION_KEY)
    }

    fun clearVpnProfile(deviceId: String) {
        deleteRaw("$VPN_PROFILE_KEY_PREFIX$deviceId")
    }

    fun writeRecoverySignal(
        message: String,
        alarmRequested: Boolean,
    ) {
        val payload =
            JSONObject()
                .put("message", message)
                .put("receivedAt", java.time.Instant.now().toString())
                .put("alarmRequested", alarmRequested)

        writeRaw(RECOVERY_SIGNAL_KEY, payload.toString())
    }

    fun clearRecoverySignal() {
        deleteRaw(RECOVERY_SIGNAL_KEY)
    }

    fun clearAll() {
        secureStorage.deleteAll()
    }

    private fun parseVpnProfile(raw: String): StoredVpnProfile? {
        val payload = runCatching { JSONObject(raw) }.getOrNull() ?: return null
        val deviceId = payload.optString("deviceId", "")
        val configText = payload.optString("config", "")

        if (deviceId.isBlank() || configText.isBlank()) {
            return null
        }

        val rawDnsServers = payload.optJSONArray("dnsServers")
        val dnsServers = mutableListOf<String>()
        if (rawDnsServers != null) {
            for (index in 0 until rawDnsServers.length()) {
                dnsServers += rawDnsServers.optString(index)
            }
        }

        return StoredVpnProfile(
            deviceId = deviceId,
            profileStatus = payload.optString("profileStatus", "ACTIVE"),
            revision = payload.optInt("revision", 0),
            tunnelName = payload.optString("tunnelName", "labguard"),
            serverId = payload.optString("serverId", ""),
            serverName = payload.optString("serverName", "Unassigned"),
            endpoint = payload.optString("endpoint", ""),
            dnsServers = dnsServers,
            issuedAt = payload.optNullableString("issuedAt"),
            rotatedAt = payload.optNullableString("rotatedAt"),
            configText = configText,
            note = payload.optString("note", ""),
        )
    }

    private fun readRaw(key: String): String? {
        val prefixedKey = secureStorage.addPrefixToKey(key)
        if (!secureStorage.containsKey(prefixedKey)) {
            return null
        }

        return secureStorage.read(prefixedKey)
    }

    private fun writeRaw(
        key: String,
        value: String,
    ) {
        secureStorage.write(secureStorage.addPrefixToKey(key), value)
    }

    private fun deleteRaw(key: String) {
        secureStorage.delete(secureStorage.addPrefixToKey(key))
    }

    data class StoredSession(
        val accessToken: String,
        val refreshToken: String,
        val deviceId: String,
        val deviceName: String,
        val accountName: String,
        val viewerLabel: String,
    )

    data class StoredVpnProfile(
        val deviceId: String,
        val profileStatus: String,
        val revision: Int,
        val tunnelName: String,
        val serverId: String,
        val serverName: String,
        val endpoint: String,
        val dnsServers: List<String>,
        val issuedAt: String?,
        val rotatedAt: String?,
        val configText: String,
        val note: String,
    )

    companion object {
        const val AUTH_SESSION_KEY = "labguard.auth.session"
        const val RECOVERY_SIGNAL_KEY = "labguard.device.recovery_signal"
        const val VPN_PROFILE_KEY_PREFIX = "labguard.vpn.profile."
    }
}

private fun JSONObject.optNullableString(key: String): String? {
    val value = optString(key, "")
    return value.ifBlank { null }
}
