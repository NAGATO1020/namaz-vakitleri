package com.tunahan.namaz_vakitleri

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Telefon yeniden başlatıldığında (ve uygulama güncellendiğinde) alarmlar
 * silinir; hepsini yeniden kurar ve kalıcı bildirimi geri getirir.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            "android.intent.action.QUICKBOOT_POWERON" -> {
                AlarmScheduler.rescheduleAll(context)
                PrayerWidgetUpdater.updateAll(context)
            }
        }
    }
}
