package com.emilolabs.labguard.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import com.emilolabs.labguard.MainActivity
import com.emilolabs.labguard.R

class LabGuardVpnRuntimeService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        ensureNotificationChannel()
        val tunnelName = intent?.getStringExtra(EXTRA_TUNNEL_NAME) ?: "labguard"
        val serverId = intent?.getStringExtra(EXTRA_SERVER_ID) ?: "wg-01"
        startForeground(
            NOTIFICATION_ID,
            buildNotification(tunnelName = tunnelName, serverId = serverId),
        )
        return START_STICKY
    }

    private fun buildNotification(
        tunnelName: String,
        serverId: String,
    ): Notification {
        val launchIntent =
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
        val pendingIntent =
            PendingIntent.getActivity(
                this,
                0,
                launchIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification
                .Builder(this, CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("LabGuard tunnel active")
                .setContentText("WireGuard session $tunnelName on $serverId")
                .setOngoing(true)
                .setContentIntent(pendingIntent)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification
                .Builder(this)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("LabGuard tunnel active")
                .setContentText("WireGuard session $tunnelName on $serverId")
                .setOngoing(true)
                .setContentIntent(pendingIntent)
                .build()
        }
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val notificationManager =
            getSystemService(NotificationManager::class.java) ?: return

        val channel =
            NotificationChannel(
                CHANNEL_ID,
                "LabGuard VPN",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Foreground service status for the LabGuard WireGuard tunnel."
                setShowBadge(false)
            }

        notificationManager.createNotificationChannel(channel)
    }

    companion object {
        private const val CHANNEL_ID = "labguard.vpn.runtime"
        private const val EXTRA_TUNNEL_NAME = "extra_tunnel_name"
        private const val EXTRA_SERVER_ID = "extra_server_id"
        private const val NOTIFICATION_ID = 3107

        fun start(
            context: Context,
            tunnelName: String,
            serverId: String,
        ) {
            val intent =
                Intent(context, LabGuardVpnRuntimeService::class.java).apply {
                    putExtra(EXTRA_TUNNEL_NAME, tunnelName)
                    putExtra(EXTRA_SERVER_ID, serverId)
                }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, LabGuardVpnRuntimeService::class.java))
        }
    }
}
