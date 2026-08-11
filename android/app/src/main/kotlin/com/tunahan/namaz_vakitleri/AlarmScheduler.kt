package com.tunahan.namaz_vakitleri

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Vakit bildirimlerini ve kalıcı bildirimin yenilenmesini zamanlar.
 *
 * Alarmlar `setExactAndAllowWhileIdle` ile kurulur; Doze modunda bile
 * vaktinde gelmesi için gereken budur. Tam zamanlı alarm izni yoksa
 * (`canScheduleExactAlarms() == false`) yaklaşık alarma düşülür — bildirim
 * birkaç dakika gecikebilir ama hiç gelmemesinden iyidir.
 */
object AlarmScheduler {

    private const val TAG = "AlarmScheduler"

    const val ACTION_PRAYER = "com.tunahan.namaz_vakitleri.PRAYER_ALERT"
    const val ACTION_REFRESH_ONGOING = "com.tunahan.namaz_vakitleri.REFRESH_ONGOING"

    /// Kullanıcı kalıcı bildirimi kaydırıp attığında sistem bunu gönderir.
    const val ACTION_ONGOING_DISMISSED =
        "com.tunahan.namaz_vakitleri.ONGOING_DISMISSED"

    /// Günlük arka plan yenilemesi.
    const val ACTION_DAILY_REFRESH =
        "com.tunahan.namaz_vakitleri.DAILY_REFRESH"

    const val EXTRA_PRAYER_INDEX = "prayer_index"

    /** Kalıcı bildirimin yenilenme alarmı için sabit istek kodu. */
    private const val REQUEST_ONGOING = 900_000

    /** Günlük arka plan yenilemesi için sabit istek kodu. */
    private const val REQUEST_DAILY = 930_000

    /** Vakit alarmları: 910_000 + vakit indeksi. */
    private fun prayerRequestCode(index: Int) = 910_000 + index

    /**
     * Ayarlar veya vakitler değiştiğinde çağrılır: eski alarmları iptal eder,
     * bugünden itibaren gelecek olan seçili vakitler için yenilerini kurar ve
     * kalıcı bildirimi tazeler.
     */
    fun rescheduleAll(context: Context) {
        reschedulePrayerAlarms(context)
        OngoingNotification.refresh(context)

        // Günlük yenilemeyi kur; elde veri bitmek üzereyse beklemeden dene.
        // `runIfNeeded` hem "yeterince zaman geçti mi" hem de "zâten çalışıyor
        // mu" kontrolünü yapar — aksi hâlde yenileme kendini tetikleyip
        // kaynağa arka arkaya istek atıyordu.
        DailyRefresh.schedule(context)
        DailyRefresh.runIfNeeded(context)
    }

    /** Yalnızca vakit bildirim alarmlarını yeniden kurar. */
    fun reschedulePrayerAlarms(context: Context) {
        val snapshot = PrayerStore.read(context)
        cancelAllPrayerAlarms(context)
        if (!snapshot.hasData || !snapshot.notificationsEnabled) return

        val schedule = PrayerSchedule(snapshot)
        // Aynı vakit birden çok günde listede olabilir; en yakını yeter.
        val upcoming = schedule.upcomingAlarms().distinctBy { it.index }
        for (entry in upcoming) {
            scheduleExact(
                context = context,
                triggerAtMillis = schedule.toDeviceMillis(entry.atMillis),
                requestCode = prayerRequestCode(entry.index),
                intent = Intent(context, PrayerAlarmReceiver::class.java).apply {
                    action = ACTION_PRAYER
                    putExtra(EXTRA_PRAYER_INDEX, entry.index)
                }
            )
        }
    }

    /**
     * Günlük veri yenilemesi.
     *
     * Tam zamanında olması gerekmiyor (gece 03:00 civarı yeter), bu yüzden
     * `setAndAllowWhileIdle` kullanılıyor — sistem uygun bir ana kaydırabilir,
     * pil açısından da doğrusu bu.
     */
    fun scheduleDailyRefresh(context: Context, triggerAtMillis: Long) {
        val manager = alarmManager(context) ?: return
        val pending = pendingIntent(
            context, REQUEST_DAILY,
            Intent(context, PrayerAlarmReceiver::class.java)
                .setAction(ACTION_DAILY_REFRESH)
        )
        manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pending)
    }

    /** Sıradaki vakit girdiğinde kalıcı bildirimin kendini yenilemesi için. */
    fun scheduleOngoingRefresh(context: Context, triggerAtMillis: Long) {
        // Vakit tam girdiği an değil, bir saniye sonrası — sıradaki vakit
        // hesabı yeni vakti "geçmiş" saysın diye.
        scheduleExact(
            context = context,
            triggerAtMillis = triggerAtMillis + 1_000L,
            requestCode = REQUEST_ONGOING,
            intent = Intent(context, PrayerAlarmReceiver::class.java).apply {
                action = ACTION_REFRESH_ONGOING
            }
        )
    }

    fun cancelAll(context: Context) {
        cancelAllPrayerAlarms(context)
        alarmManager(context)?.cancel(
            pendingIntent(
                context, REQUEST_ONGOING,
                Intent(context, PrayerAlarmReceiver::class.java)
                    .apply { action = ACTION_REFRESH_ONGOING }
            )
        )
    }

    private fun cancelAllPrayerAlarms(context: Context) {
        val manager = alarmManager(context) ?: return
        for (index in 0 until PrayerStore.PRAYER_COUNT) {
            manager.cancel(
                pendingIntent(
                    context, prayerRequestCode(index),
                    Intent(context, PrayerAlarmReceiver::class.java).apply {
                        action = ACTION_PRAYER
                        putExtra(EXTRA_PRAYER_INDEX, index)
                    }
                )
            )
        }
    }

    private fun scheduleExact(
        context: Context,
        triggerAtMillis: Long,
        requestCode: Int,
        intent: Intent
    ) {
        val manager = alarmManager(context) ?: return
        if (triggerAtMillis <= System.currentTimeMillis()) return

        val pending = pendingIntent(context, requestCode, intent)
        try {
            if (canScheduleExact(manager)) {
                manager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP, triggerAtMillis, pending
                )
            } else {
                // İzin yoksa yaklaşık alarm: birkaç dakika sapabilir.
                manager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP, triggerAtMillis, pending
                )
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "Alarm kurulamadı, yaklaşık alarma düşülüyor", e)
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pending)
        }
    }

    fun canScheduleExact(manager: AlarmManager): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S || manager.canScheduleExactAlarms()

    fun canScheduleExact(context: Context): Boolean =
        alarmManager(context)?.let(::canScheduleExact) ?: false

    private fun alarmManager(context: Context): AlarmManager? =
        context.getSystemService(AlarmManager::class.java)

    private fun pendingIntent(context: Context, requestCode: Int, intent: Intent) =
        PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
}
