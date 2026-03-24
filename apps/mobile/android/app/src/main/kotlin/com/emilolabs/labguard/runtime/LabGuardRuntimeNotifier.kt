package com.emilolabs.labguard.runtime

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import com.emilolabs.labguard.MainActivity
import com.emilolabs.labguard.R

class LabGuardRuntimeNotifier(
    private val context: Context,
) {
    fun showRecoveryAlert(
        title: String,
        message: String,
        alarmRequested: Boolean,
    ) {
        ensureChannels()
        notificationManager()?.notify(
            RECOVERY_NOTIFICATION_ID,
            buildNotification(
                channelId = RECOVERY_CHANNEL_ID,
                title = title,
                message = message,
                ongoing = alarmRequested,
            ),
        )
    }

    fun showSecurityAlert(
        title: String,
        message: String,
    ) {
        ensureChannels()
        notificationManager()?.notify(
            SECURITY_NOTIFICATION_ID,
            buildNotification(
                channelId = SECURITY_CHANNEL_ID,
                title = title,
                message = message,
            ),
        )
    }

    fun clearRecoveryAlerts() {
        notificationManager()?.cancel(RECOVERY_NOTIFICATION_ID)
    }

    private fun buildNotification(
        channelId: String,
        title: String,
        message: String,
        ongoing: Boolean = false,
    ): Notification {
        val launchIntent =
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
        val pendingIntent =
            PendingIntent.getActivity(
                context,
                0,
                launchIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification
                .Builder(context, channelId)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title)
                .setContentText(message)
                .setStyle(Notification.BigTextStyle().bigText(message))
                .setContentIntent(pendingIntent)
                .setAutoCancel(!ongoing)
                .setOngoing(ongoing)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification
                .Builder(context)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title)
                .setContentText(message)
                .setStyle(Notification.BigTextStyle().bigText(message))
                .setContentIntent(pendingIntent)
                .setAutoCancel(!ongoing)
                .setOngoing(ongoing)
                .build()
        }
    }

    private fun ensureChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val manager = notificationManager() ?: return
        val recoveryChannel =
            NotificationChannel(
                RECOVERY_CHANNEL_ID,
                "LabGuard Recovery",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Recovery and lost-device notifications from LabGuard."
                enableVibration(true)
            }
        val securityChannel =
            NotificationChannel(
                SECURITY_CHANNEL_ID,
                "LabGuard Security",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Security lifecycle notifications from LabGuard."
                enableVibration(true)
            }

        manager.createNotificationChannel(recoveryChannel)
        manager.createNotificationChannel(securityChannel)
    }

    private fun notificationManager(): NotificationManager? =
        context.getSystemService(NotificationManager::class.java)

    companion object {
        private const val RECOVERY_CHANNEL_ID = "labguard.runtime.recovery"
        private const val SECURITY_CHANNEL_ID = "labguard.runtime.security"
        private const val RECOVERY_NOTIFICATION_ID = 4101
        private const val SECURITY_NOTIFICATION_ID = 4102
    }
}
