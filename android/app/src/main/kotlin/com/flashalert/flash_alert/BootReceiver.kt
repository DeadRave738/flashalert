package com.flashalert.flash_alert

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.service.notification.NotificationListenerService

/** Requests restoration of the existing notification listener after a reboot/update.
 *  Does not open the UI, start a persistent service, or bypass Android permissions.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return

        val component = ComponentName(context, FlashNotificationService::class.java)
        val allowed = Settings.Secure.getString(
            context.contentResolver, "enabled_notification_listeners"
        )?.split(':')?.any { it.equals(component.flattenToString(), ignoreCase = true) } == true
        if (!allowed) return

        // The Android notification manager owns the service lifecycle.
        // It binds FlashNotificationService which then registers the phone callback.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try {
                NotificationListenerService.requestRebind(component)
            } catch (_: RuntimeException) {
                // OEM firmware can defer service binding; system may retry later.
            }
        }
    }
}
