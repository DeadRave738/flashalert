package com.flashalert.flash_alert

import android.Manifest
import android.app.Notification
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.SystemClock
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.telephony.PhoneStateListener
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager

class FlashNotificationService : NotificationListenerService() {
    private val recent = LinkedHashMap<String, Long>()
    private val recentPackages = LinkedHashMap<String, Long>()
    @Volatile private var connected = false
    fun isConnected(): Boolean = connected
    private fun recordEvent() {
        getSharedPreferences("flashalert_v2", Context.MODE_PRIVATE).edit()
            .putLong("lastNotificationSeen", System.currentTimeMillis())
            .apply()
    }
    private var telephony: TelephonyManager? = null
    private var callback: TelephonyCallback? = null
    private var legacyListener: PhoneStateListener? = null

    override fun onListenerConnected() {
        super.onListenerConnected()
        connected = true
        attachPhoneListener()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val n = sbn ?: return
        recordEvent() // Metadata only: never store message text, title or sender.
        val flags = n.notification.flags
        if ((flags and Notification.FLAG_ONGOING_EVENT) != 0 ||
            (flags and Notification.FLAG_GROUP_SUMMARY) != 0 ||
            (flags and Notification.FLAG_FOREGROUND_SERVICE) != 0) return
        if (!n.isClearable || !FlashEngine.allowedNotification(this, n.packageName)) return
        val now = SystemClock.elapsedRealtime()
        if (now - (recent[n.key] ?: -10000L) < 2500L) return
        if (now - (recentPackages[n.packageName] ?: -10000L) < 800L) return
        recent[n.key] = now
        recentPackages[n.packageName] = now
        if (recent.size > 150) recent.remove(recent.keys.first())
        if (recentPackages.size > 80) recentPackages.remove(recentPackages.keys.first())
        FlashEngine.notification(this)
    }

    @Suppress("DEPRECATION")
    private fun attachPhoneListener() {
        if (checkSelfPermission(Manifest.permission.READ_PHONE_STATE) != PackageManager.PERMISSION_GRANTED) return
        if (callback != null || legacyListener != null) return
        val tm = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        telephony = tm
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val cb = object : TelephonyCallback(), TelephonyCallback.CallStateListener {
                    override fun onCallStateChanged(state: Int) = FlashEngine.callState(this@FlashNotificationService, state == TelephonyManager.CALL_STATE_RINGING)
                }
                tm.registerTelephonyCallback(mainExecutor, cb)
                callback = cb
            } else {
                val listener = object : PhoneStateListener() {
                    override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                        FlashEngine.callState(this@FlashNotificationService, state == TelephonyManager.CALL_STATE_RINGING)
                    }
                }
                tm.listen(listener, PhoneStateListener.LISTEN_CALL_STATE)
                legacyListener = listener
            }
            FlashEngine.callState(this, tm.callState == TelephonyManager.CALL_STATE_RINGING)
        } catch (_: SecurityException) { }
    }

    fun refreshPhoneListener() { attachPhoneListener() }

    override fun onListenerDisconnected() {
        connected = false
        super.onListenerDisconnected()
    }

    @Suppress("DEPRECATION")
    override fun onDestroy() {
        connected = false
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) callback?.let { telephony?.unregisterTelephonyCallback(it) }
            legacyListener?.let { telephony?.listen(it, PhoneStateListener.LISTEN_NONE) }
        } catch (_: Exception) { }
        callback = null
        legacyListener = null
        FlashEngine.callState(this, false)
        current = null
        super.onDestroy()
    }

    companion object {
        @Volatile var current: FlashNotificationService? = null
    }

    override fun onCreate() {
        super.onCreate()
        current = this
    }
}
