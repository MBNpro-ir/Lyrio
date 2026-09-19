package com.mbn.lyrio

import android.Manifest
import android.app.Activity
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

object NativeBridge {
    fun attach(engine: FlutterEngine, context: Context, activity: Activity? = null) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "com.mbn.lyrio/native").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "state" -> result.success(LyrioCore.state().toString())
                    "refresh" -> { LyrioCore.connect(); LyrioCore.fetch(true); result.success(null) }
                    "saveSettings" -> { LyrioCore.saveSettings(JSONObject(call.arguments as String)); result.success(null) }
                    "saveKey" -> {
                        KeyVault.write(context, call.argument<String>("id")!!, call.argument<String>("key")!!.trim())
                        LyrioCore.fetch(true); result.success(null)
                    }
                    "clearCache" -> { LyricsProviders.clearCache(context); result.success(null) }
                    "clearError" -> { LyrioCore.serviceError = ""; result.success(null) }
                    "overlay" -> {
                        if (call.arguments == true) {
                            check(activity != null && Settings.canDrawOverlays(context)) { "Grant Display over other apps, then turn on Floating lyrics." }
                            check(LyrioCore.listenerEnabled()) { "Enable notification access first." }
                            if (Build.VERSION.SDK_INT >= 33) check(context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) { "Allow service notifications first." }
                            LyrioCore.serviceError = ""
                            val intent = Intent(context, LyrioOverlayService::class.java)
                            context.startForegroundService(intent)
                        } else {
                            LyrioCore.preferences().edit().putBoolean("overlayEnabled", false).apply()
                            context.stopService(Intent(context, LyrioOverlayService::class.java))
                        }
                        result.success(null)
                    }
                    "move" -> {
                        LyrioOverlayService.instance?.move(call.argument<Number>("dx")!!.toFloat(), call.argument<Number>("dy")!!.toFloat())
                        result.success(null)
                    }
                    "compact" -> { LyrioOverlayService.instance?.compact(call.arguments as Boolean); result.success(null) }
                    "permission" -> {
                        check(activity != null) { "Open Lyrio to manage permissions." }
                        when (call.arguments as String) {
                            "listener" -> activity.startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                            "overlay" -> activity.startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:${context.packageName}")))
                            "battery" -> activity.startActivity(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:${context.packageName}")))
                            "notifications" -> if (Build.VERSION.SDK_INT >= 33 && activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                                activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 41)
                            } else activity.startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName))
                            "app" -> activity.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}")))
                        }
                        result.success(null)
                    }
                    "openUrl" -> {
                        val uri = Uri.parse(call.arguments as String)
                        require(uri.scheme == "https") { "Only HTTPS links are supported." }
                        context.startActivity(Intent(Intent.ACTION_VIEW, uri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("LYRIO", e.message ?: "Android could not complete this action.", null)
            }
        }
    }
}
