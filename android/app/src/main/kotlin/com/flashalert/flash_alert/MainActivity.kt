package com.flashalert.flash_alert

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.text.TextUtils
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

class MainActivity : FlutterActivity() {
    private val channelName = "com.flashalert.flash/torch"
    private val cameraRequest = 4017
    private val phoneRequest = 4018
    private var pendingTest: Pair<Map<*, *>, MethodChannel.Result>? = null
    private var pendingPhone: MethodChannel.Result? = null

    private val prefs by lazy { getSharedPreferences("flashalert_v2", Context.MODE_PRIVATE) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "blink" -> {
                    val options = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
                        pendingTest = options to result
                        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.CAMERA), cameraRequest)
                    } else runTest(options, result)
                }
                "getSettings" -> result.success(settingsMap())
                "saveSettings" -> {
                    val options = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                    val editor = prefs.edit()
                    listOf("calls", "notifications", "quietEnabled", "quietCalls", "batterySavingNotifications").forEach { key ->
                        (options[key] as? Boolean)?.let { editor.putBoolean(key, it) }
                    }
                    listOf("onMs", "offMs", "callOnMs", "callOffMs").forEach { key ->
                        (options[key] as? Number)?.toInt()?.let { editor.putInt(key, it.coerceIn(20, 600)) }
                    }
                    listOf("quietStart", "quietEnd").forEach { key ->
                        (options[key] as? Number)?.toInt()?.let { editor.putInt(key, it.coerceIn(0, 1439)) }
                    }
                    (options["pattern"] as? String)?.takeIf { it in listOf("normal", "double", "fast") }?.let { editor.putString("pattern", it) }
                    (options["count"] as? Number)?.toInt()?.let { editor.putInt("count", it.coerceIn(1, 10)) }
                    (options["ignored"] as? List<*>)?.let { list ->
                        val arr = JSONArray()
                        list.filterIsInstance<String>().forEach { arr.put(it) }
                        editor.putString("ignored", arr.toString())
                    }
                    editor.apply()
                    FlashEngine.settingsChanged(this)
                    result.success(settingsMap())
                }
                "status" -> result.success(mapOf(
                    "camera" to (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED),
                    "phone" to (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED),
                    "listener" to notificationAccess(),
                    "listenerRunning" to (FlashNotificationService.current?.isConnected() == true),
                    "batteryUnrestricted" to (getSystemService(Context.POWER_SERVICE) as PowerManager)
                        .isIgnoringBatteryOptimizations(packageName),
                    "lastNotificationSeen" to prefs.getLong("lastNotificationSeen", 0L)
                ))
                "requestCamera" -> {
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) result.success(true)
                    else { pendingTest = null; ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.CAMERA), cameraRequest); result.success(false) }
                }
                "requestPhone" -> {
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED) result.success(true)
                    else {
                        pendingPhone = result
                        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.READ_PHONE_STATE), phoneRequest)
                    }
                }
                "openNotificationAccess" -> {
                    try { startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)); result.success(null) }
                    catch (e: Exception) { result.error("SETTINGS", e.message, null) }
                }
                "openBatterySettings" -> {
                    try { startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)); result.success(null) }
                    catch (e: Exception) { result.error("SETTINGS", e.message, null) }
                }
                "getApps" -> result.success(installedLaunchers())
                else -> result.notImplemented()
            }
        }
    }

    private fun settingsMap(): Map<String, Any> {
        val ignored = JSONArray(prefs.getString("ignored", "[]") ?: "[]")
        val packages = mutableListOf<String>()
        for (i in 0 until ignored.length()) packages.add(ignored.optString(i))
        return mapOf(
            "calls" to prefs.getBoolean("calls", false),
            "notifications" to prefs.getBoolean("notifications", false),
            "batterySavingNotifications" to prefs.getBoolean("batterySavingNotifications", true),
            "onMs" to prefs.getInt("onMs", 200),
            "offMs" to prefs.getInt("offMs", 200),
            "callOnMs" to prefs.getInt("callOnMs", 200),
            "callOffMs" to prefs.getInt("callOffMs", 200),
            "count" to prefs.getInt("count", 5),
            "pattern" to (prefs.getString("pattern", "normal") ?: "normal"),
            "quietEnabled" to prefs.getBoolean("quietEnabled", false),
            "quietCalls" to prefs.getBoolean("quietCalls", false),
            "quietStart" to prefs.getInt("quietStart", 1380),
            "quietEnd" to prefs.getInt("quietEnd", 420),
            "ignored" to packages
        )
    }

    private fun notificationAccess(): Boolean {
        val component = ComponentName(this, FlashNotificationService::class.java).flattenToString()
        val enabled = Settings.Secure.getString(contentResolver, "enabled_notification_listeners") ?: ""
        return enabled.split(':').any { it.equals(component, ignoreCase = true) }
    }

    private fun installedLaunchers(): List<Map<String, String>> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        @Suppress("DEPRECATION")
        val apps = packageManager.queryIntentActivities(intent, 0)
        return apps.mapNotNull { info ->
            val pkg = info.activityInfo?.packageName ?: return@mapNotNull null
            if (pkg == packageName) null else mapOf("package" to pkg, "name" to info.loadLabel(packageManager).toString())
        }.distinctBy { it["package"] }.sortedBy { it["name"]?.lowercase() }
    }

    private fun runTest(options: Map<*, *>, result: MethodChannel.Result) {
        FlashEngine.test(
            this,
            (options["onMs"] as? Number)?.toInt() ?: 200,
            (options["offMs"] as? Number)?.toInt() ?: 200,
            (options["count"] as? Number)?.toInt() ?: 5
        ) { error -> if (error == null) result.success(null) else result.error("FLASH", error, null) }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        when (requestCode) {
            cameraRequest -> {
                val pending = pendingTest
                pendingTest = null
                if (pending != null) {
                    if (granted) runTest(pending.first, pending.second)
                    else pending.second.error("PERMISSION", "Нужно разрешение камеры", null)
                }
            }
            phoneRequest -> {
                pendingPhone?.success(granted)
                pendingPhone = null
                if (granted) FlashNotificationService.current?.refreshPhoneListener()
            }
        }
    }
}
