package com.example.flutter_application_1

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val nativeNotificationChannel = "fleet_driver/native_notifications"
    private val deviceInfoChannel = "fleet_driver/device_info"
    private val trackingChannelId = "fleet_driver_tracking_alerts_v1"
    private val trackingNotificationId = 888

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Create notification channel for background service.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                trackingChannelId,
                "Ride Tracking Alerts",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Foreground ride tracking notifications and service status."
                setBlockable(false)
                setSound(null, null)
                enableVibration(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setShowBadge(false)
            }

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, nativeNotificationChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateTrackingProgress" -> {
                        try {
                            updateTrackingProgress(call)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("NATIVE_NOTIFY_ERROR", e.message, null)
                        }
                    }
                    "clearTrackingProgress" -> {
                        NotificationManagerCompat.from(this).cancel(trackingNotificationId)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceInfoChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAndroidId" -> {
                        try {
                            val androidId = Settings.Secure.getString(
                                contentResolver,
                                Settings.Secure.ANDROID_ID
                            )
                            result.success(androidId)
                        } catch (e: Exception) {
                            result.error("ANDROID_ID_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        
        // Request battery optimization exclusion to ensure background service runs
        requestBatteryOptimizationExclusion()
    }

    private fun updateTrackingProgress(call: MethodCall) {
        val title = call.argument<String>("title") ?: "Active Job - GPS Tracking"
        val content = call.argument<String>("content") ?: "Tracking in progress"
        val subText = call.argument<String>("subText") ?: "Arriving to destination"
        val progress = (call.argument<Int>("progress") ?: 0).coerceIn(0, 100)
        val indeterminate = call.argument<Boolean>("indeterminate") ?: false

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val contentIntent = launchIntent?.let {
            android.app.PendingIntent.getActivity(
                this,
                0,
                it,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
        }

        val builder = NotificationCompat.Builder(this, trackingChannelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(content)
            .setSubText(subText)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setAutoCancel(false)
            .setShowWhen(false)
            .setProgress(100, progress, indeterminate)
            .setStyle(NotificationCompat.BigTextStyle().bigText(content))

        if (contentIntent != null) {
            builder.setContentIntent(contentIntent)
        }

        NotificationManagerCompat.from(this).notify(trackingNotificationId, builder.build())
    }
    
    private fun requestBatteryOptimizationExclusion() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent()
            val packageName = packageName
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            
            // Check if battery optimization is already disabled
            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                // Request to disable battery optimization
                intent.action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                intent.data = Uri.parse("package:$packageName")
                try {
                    startActivity(intent)
                } catch (e: Exception) {
                    // If the intent fails, open battery optimization settings
                    val settingsIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                    startActivity(settingsIntent)
                }
            }
        }
    }
}

