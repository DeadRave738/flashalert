package com.flashalert.flash_alert

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import android.content.pm.PackageManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import org.json.JSONArray
import java.util.Calendar

/** One torch owner for test, incoming calls, and notifications. */
internal object FlashEngine {
    private val handler = Handler(Looper.getMainLooper())
    private var job: Runnable? = null
    private var cameraId: String? = null
    private var activeMode: String? = null
    private var generation = 0L
    private var ringing = false
    private var lastNotificationStart = Long.MIN_VALUE / 2
    private const val NOTIFICATION_COOLDOWN_MS = 3000L
    private const val MAX_NOTIFICATION_MS = 15_000L
    private const val MAX_CALL_MS = 120_000L

    private fun prefs(context: Context) = context.applicationContext.getSharedPreferences("flashalert_v2", Context.MODE_PRIVATE)
    fun enabled(context: Context, name: String) = prefs(context).getBoolean(name, false)
    fun number(context: Context, name: String, fallback: Int) = prefs(context).getInt(name, fallback).coerceIn(20, 600)
    fun count(context: Context) = prefs(context).getInt("count", 5).coerceIn(1, 10)

    private fun quietNow(context: Context, forCall: Boolean): Boolean {
        val p = prefs(context)
        if (!p.getBoolean("quietEnabled", false)) return false
        if (forCall && !p.getBoolean("quietCalls", false)) return false
        val begin = p.getInt("quietStart", 1380).coerceIn(0, 1439)
        val end = p.getInt("quietEnd", 420).coerceIn(0, 1439)
        val calendar = Calendar.getInstance()
        val now = calendar.get(Calendar.HOUR_OF_DAY) * 60 + calendar.get(Calendar.MINUTE)
        return if (begin == end) true
               else if (begin < end) now in begin until end
               else now >= begin || now < end
    }

    // No network, sensors, or background polling. Android battery snapshot on demand.
    private fun lowBattery(context: Context): Boolean {
        val battery = context.applicationContext.registerReceiver(
            null, IntentFilter(Intent.ACTION_BATTERY_CHANGED)) ?: return false
        val plugged = battery.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0)
        if (plugged != 0) return false
        val level = battery.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = battery.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
        return level >= 0 && scale > 0 && level * 100 / scale <= 15
    }

    // Thermal status 4=SEVERE, 5=CRITICAL, 6=EMERGENCY, 7=SHUTDOWN.
    // This is an OS heuristic, not a measurement of LED temperature.
    private fun severeThermal(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.currentThermalStatus >= PowerManager.THERMAL_STATUS_SEVERE
    }

    private fun batterySavingNotifications(context: Context): Boolean =
        prefs(context).getBoolean("batterySavingNotifications", true)

    private fun notificationSafetyAllows(context: Context): Boolean =
        !severeThermal(context) &&
            (!batterySavingNotifications(context) || !lowBattery(context))

    private fun pattern(context: Context): String =
        prefs(context).getString("pattern", "normal")?.takeIf { it in listOf("normal", "double", "fast") } ?: "normal"

    fun allowedNotification(context: Context, pkg: String): Boolean {
        if (!enabled(context, "notifications") || pkg == context.packageName || quietNow(context, false) || !notificationSafetyAllows(context)) return false
        val ignored = JSONArray(prefs(context).getString("ignored", "[]") ?: "[]")
        for (i in 0 until ignored.length()) if (ignored.optString(i) == pkg) return false
        return context.checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
    }

    @Synchronized private fun stopInternal(context: Context) {
        generation++
        job?.let(handler::removeCallbacks)
        job = null
        activeMode = null
        try {
            val id = cameraId
            if (id != null) (context.applicationContext.getSystemService(Context.CAMERA_SERVICE) as CameraManager).setTorchMode(id, false)
        } catch (_: Exception) { }
    }

    fun stop(context: Context) { handler.post { stopInternal(context) } }

    private fun findCamera(context: Context): Pair<CameraManager, String> {
        val cm = context.applicationContext.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val cached = cameraId
        if (cached != null && cm.cameraIdList.contains(cached)) return cm to cached
        val id = cm.cameraIdList.firstOrNull { candidate ->
            val c = cm.getCameraCharacteristics(candidate)
            c.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true &&
                c.get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_BACK
        } ?: throw IllegalStateException("Не найдена задняя вспышка")
        cameraId = id
        return cm to id
    }

    /** Completion always delivered on main thread; call has priority over other blinking. */
    fun test(context: Context, onMs: Int, offMs: Int, flashes: Int, done: (String?) -> Unit) {
        handler.post {
            if (activeMode != null || ringing) { done("Вспышка занята"); return@post }
            if (severeThermal(context)) { done("Android сообщает о перегреве устройства"); return@post }
            start(context, "test", onMs, offMs, flashes, done)
        }
    }

    fun notification(context: Context) {
        handler.post {
            if (ringing || activeMode != null || !enabled(context, "notifications") || quietNow(context, false) || !notificationSafetyAllows(context)) return@post
            val now = SystemClock.elapsedRealtime()
            if (now - lastNotificationStart < NOTIFICATION_COOLDOWN_MS) return@post
            lastNotificationStart = now
            start(context, "notification", number(context, "onMs", 200), number(context, "offMs", 200), count(context), null)
        }
    }

    fun callState(context: Context, isRinging: Boolean) {
        handler.post {
            if (ringing == isRinging && !(isRinging && activeMode != "call")) return@post
            ringing = isRinging
            if (!isRinging) {
                if (activeMode == "call") stopInternal(context)
                return@post
            }
            if (!enabled(context, "calls") || quietNow(context, true) || severeThermal(context) || context.checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) return@post
            stopInternal(context)
            start(context, "call", number(context, "callOnMs", 200), number(context, "callOffMs", 200), null, null)
        }
    }

    fun settingsChanged(context: Context) {
        handler.post {
            if (ringing && (!enabled(context, "calls") || quietNow(context, true))) {
                if (activeMode == "call") stopInternal(context)
            } else if (ringing && enabled(context, "calls") && !quietNow(context, true) && !severeThermal(context) && activeMode != "call") {
                start(context, "call", number(context, "callOnMs", 200), number(context, "callOffMs", 200), null, null)
            }
        }
    }

    private fun start(context: Context, mode: String, on: Int, off: Int, flashes: Int?, done: ((String?) -> Unit)?) {
        val (manager, id) = try { findCamera(context) } catch (e: Exception) { done?.invoke(e.message ?: "Камера недоступна"); return }
        stopInternal(context)
        activeMode = mode
        val token = generation
        val startTime = SystemClock.elapsedRealtime()
        val onDelay = on.coerceIn(20, 600).toLong()
        val offDelay = off.coerceIn(20, 600).toLong()
        val rhythm = pattern(context)
        var step = 0
        val task = object : Runnable {
            override fun run() {
                if (token != generation) return
                if (severeThermal(context) ||
                    (flashes != null && step >= flashes.coerceIn(1, 10) * 2) ||
                    (mode == "notification" && SystemClock.elapsedRealtime() - startTime >= MAX_NOTIFICATION_MS) ||
                    (mode == "call" && (SystemClock.elapsedRealtime() - startTime >= MAX_CALL_MS || quietNow(context, true))) ||
                    (mode == "notification" && (quietNow(context, false) || !notificationSafetyAllows(context)))) {
                    stopInternal(context)
                    done?.invoke(null)
                    return
                }
                try {
                    val torchOn = step % 2 == 0
                    manager.setTorchMode(id, torchOn)
                    step++
                    val delay = when (rhythm) {
                        "fast" -> if (torchOn) minOf(onDelay, 60L) else minOf(offDelay, 60L)
                        "double" -> if (torchOn) onDelay else if (step % 4 == 0) maxOf(offDelay, 260L) else offDelay
                        else -> if (torchOn) onDelay else offDelay
                    }
                    handler.postDelayed(this, delay)
                    job = this
                } catch (e: Exception) {
                    stopInternal(context)
                    done?.invoke(e.message ?: "Не удалось включить вспышку")
                }
            }
        }
        job = task
        handler.post(task)
    }
}
