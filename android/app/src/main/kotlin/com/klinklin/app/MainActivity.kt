package com.klinklin.app

import android.content.Context
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.klinklin.app/location"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "klinklin_high_importance_channel"
            val channelName = "KlinKlin Notifications"
            val channelDescription = "Notifikasi operasional, quotation, stok opname, dan insiden"
            val importance = NotificationManager.IMPORTANCE_HIGH

            val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val audioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .build()

            val channel = NotificationChannel(channelId, channelName, importance).apply {
                description = channelDescription
                enableLights(true)
                enableVibration(true)
                setSound(soundUri, audioAttributes)
            }

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "isMockLocation") {
                try {
                    val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
                    val location = locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER)
                    
                    var isMock = false
                    if (location != null) {
                        isMock = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            location.isMock
                        } else {
                            location.isFromMockProvider
                        }
                    }
                    result.success(isMock)
                } catch (e: Exception) {
                    result.success(false)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
