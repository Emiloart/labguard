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
        return StoredSession.fromStoredPayload(payload)
    }

    fun writeSession(session: StoredSession) {
        writeRaw(AUTH_SESSION_KEY, session.toStoredPayload().toString())
    }

    fun clearAuthSession() {
        deleteRaw(AUTH_SESSION_KEY)
    }

    fun readRuntimePreferences(): StoredRuntimePreferences? {
        val raw = readRaw(RUNTIME_PREFERENCES_KEY) ?: return null
        val payload = runCatching { JSONObject(raw) }.getOrNull() ?: return null

        return StoredRuntimePreferences(
            notificationsEnabled = payload.optBoolean("notificationsEnabled", true),
            autoConnectEnabled = payload.optBoolean("autoConnectEnabled", true),
            killSwitchEnabled = payload.optBoolean("killSwitchEnabled", true),
            desiredConnected = payload.optBoolean("desiredConnected", false),
            apiBaseUrl = payload.optString("apiBaseUrl", ""),
        )
    }

    fun writeRuntimePreferences(preferences: StoredRuntimePreferences) {
        val payload =
            JSONObject()
                .put("notificationsEnabled", preferences.notificationsEnabled)
                .put("autoConnectEnabled", preferences.autoConnectEnabled)
                .put("killSwitchEnabled", preferences.killSwitchEnabled)
                .put("desiredConnected", preferences.desiredConnected)
                .put("apiBaseUrl", preferences.apiBaseUrl)

        writeRaw(RUNTIME_PREFERENCES_KEY, payload.toString())
    }

    fun readRecoverySignal(): StoredRecoverySignal? {
        val raw = readRaw(RECOVERY_SIGNAL_KEY) ?: return null
        val payload = runCatching { JSONObject(raw) }.getOrNull() ?: return null
        val message = payload.optString("message", "")

        if (message.isBlank()) {
            return null
        }

        return StoredRecoverySignal(
            message = message,
            receivedAt = payload.optString("receivedAt", ""),
            alarmRequested = payload.optBoolean("alarmRequested", false),
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
        val expiresInSeconds: Int,
        val deviceId: String,
        val deviceName: String,
        val deviceTrustState: String,
        val viewerId: String,
        val viewerEmail: String,
        val accountName: String,
        val accountId: String,
        val brandAttribution: String,
        val viewerLabel: String,
        val viewerRole: String,
    ) {
        fun toStoredPayload(): JSONObject {
            return JSONObject()
                .put("accessToken", accessToken)
                .put("refreshToken", refreshToken)
                .put("expiresInSeconds", expiresInSeconds)
                .put(
                    "viewer",
                    JSONObject()
                        .put("id", viewerId)
                        .put("email", viewerEmail)
                        .put("displayName", viewerLabel)
                        .put("role", viewerRole),
                ).put(
                    "account",
                    JSONObject()
                        .put("id", accountId)
                        .put("name", accountName)
                        .put("brandAttribution", brandAttribution),
                ).put(
                    "device",
                    JSONObject()
                        .put("id", deviceId)
                        .put("name", deviceName)
                        .put("trustState", deviceTrustState),
                )
        }

        companion object {
            fun fromStoredPayload(payload: JSONObject): StoredSession? {
                val normalized =
                    if (payload.has("viewer") || payload.has("account") || payload.has("device")) {
                        payload
                    } else {
                        JSONObject()
                            .put("accessToken", payload.optString("accessToken", ""))
                            .put("refreshToken", payload.optString("refreshToken", ""))
                            .put("expiresInSeconds", payload.optInt("expiresInSeconds", 0))
                            .put("viewer", payload.optJSONObject("viewer") ?: JSONObject())
                            .put("account", payload.optJSONObject("account") ?: JSONObject())
                            .put("device", payload.optJSONObject("device") ?: JSONObject())
                    }

                val device = normalized.optJSONObject("device") ?: JSONObject()
                val account = normalized.optJSONObject("account") ?: JSONObject()
                val viewer = normalized.optJSONObject("viewer") ?: JSONObject()
                val accessToken = normalized.optString("accessToken", "")
                val refreshToken = normalized.optString("refreshToken", "")
                val deviceId = device.optString("id", "")

                if (
                    accessToken.isBlank() ||
                    refreshToken.isBlank() ||
                    deviceId.isBlank()
                ) {
                    return null
                }

                return StoredSession(
                    accessToken = accessToken,
                    refreshToken = refreshToken,
                    expiresInSeconds = normalized.optInt("expiresInSeconds", 0),
                    deviceId = deviceId,
                    deviceName = device.optString("name", "Unknown device"),
                    deviceTrustState = device.optString("trustState", "PENDING_APPROVAL"),
                    viewerId = viewer.optString("id", ""),
                    viewerEmail = viewer.optString("email", ""),
                    accountName = account.optString("name", "Emilo Labs"),
                    accountId = account.optString("id", ""),
                    brandAttribution =
                        account.optString("brandAttribution", "Built by Emilo Labs"),
                    viewerLabel = viewer.optString("displayName", "LabGuard User"),
                    viewerRole = viewer.optString("role", "MEMBER"),
                )
            }

            fun fromEnvelopePayload(payload: JSONObject): StoredSession? {
                val session = payload.optJSONObject("session") ?: return null

                return fromStoredPayload(
                    JSONObject()
                        .put("accessToken", payload.optString("accessToken", ""))
                        .put("refreshToken", payload.optString("refreshToken", ""))
                        .put("expiresInSeconds", payload.optInt("expiresInSeconds", 0))
                        .put("viewer", session.optJSONObject("viewer") ?: JSONObject())
                        .put("account", session.optJSONObject("account") ?: JSONObject())
                        .put("device", session.optJSONObject("device") ?: JSONObject()),
                )
            }
        }
    }

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

    data class StoredRuntimePreferences(
        val notificationsEnabled: Boolean,
        val autoConnectEnabled: Boolean,
        val killSwitchEnabled: Boolean,
        val desiredConnected: Boolean,
        val apiBaseUrl: String,
    )

    data class StoredRecoverySignal(
        val message: String,
        val receivedAt: String,
        val alarmRequested: Boolean,
    )

    companion object {
        const val AUTH_SESSION_KEY = "labguard.auth.session"
        const val RECOVERY_SIGNAL_KEY = "labguard.device.recovery_signal"
        const val RUNTIME_PREFERENCES_KEY = "labguard.runtime.preferences"
        const val VPN_PROFILE_KEY_PREFIX = "labguard.vpn.profile."
    }
}

private fun JSONObject.optNullableString(key: String): String? {
    val value = optString(key, "")
    return value.ifBlank { null }
}
