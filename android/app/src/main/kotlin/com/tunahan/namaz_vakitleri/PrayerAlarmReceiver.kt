package com.tunahan.namaz_vakitleri

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * Vakit girdiğinde bildirimi gösterir; ayrıca kalıcı bildirimi ve
 * widget'ları yeniler.
 */
class PrayerAlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            AlarmScheduler.ACTION_PRAYER -> {
                val index = intent.getIntExtra(AlarmScheduler.EXTRA_PRAYER_INDEX, -1)
                if (index >= 0) showPrayerNotification(context, index)
                // Bu vakit geçti; hem yarın için alarmı yeniden kur hem de
                // kalıcı bildirimi sıradaki vakte taşı.
                AlarmScheduler.rescheduleAll(context)
            }

            AlarmScheduler.ACTION_REFRESH_ONGOING -> {
                OngoingNotification.refresh(context)
                // Emniyet ağı tekrarlamıyor; bir sonrakini burada kuruyoruz.
                AlarmScheduler.scheduleHeartbeat(context)
                // Saat ya da yaz saati değiştiyse kurulu alarmlar yanlış âna
                // bakıyor olabilir; vakit alarmlarını yeniden kuruyoruz.
                AlarmScheduler.reschedulePrayerAlarms(context)
                // Veri bitmek üzereyse (Fazilet yalnızca üç gün veriyor) günlük
                // alarmı beklemeden dene; 6 saatlik fren kendi içinde.
                DailyRefresh.runIfNeeded(context)
            }

            // Kullanıcı kalıcı bildirimi kaydırıp attı — hemen geri koy.
            // Android 14'ten beri kalıcı bildirimler de atılabiliyor; kullanıcı
            // bunun kalıcı olmasını istediği için tekrar basıyoruz. Tamamen
            // kapatmak isteyen ayarlardan kapatabilir.
            AlarmScheduler.ACTION_ONGOING_DISMISSED -> {
                OngoingNotification.refresh(context)
            }

            // Günlük arka plan yenilemesi: ağ işi olduğu için alıcıyı
            // goAsync() ile açık tutuyoruz, iş bitince serbest bırakıyoruz.
            // Günlük alarm doğrudan `run` çağırır — bekleme kontrolü burada
            // gereksiz, zâten günde bir kez tetikleniyor.
            AlarmScheduler.ACTION_DAILY_REFRESH -> {
                val result = goAsync()
                DailyRefresh.run(context) { result.finish() }
                return
            }
        }
        PrayerWidgetUpdater.updateAll(context)
    }

    private fun showPrayerNotification(context: Context, index: Int) {
        val snapshot = PrayerStore.read(context)
        if (!snapshot.notificationsEnabled) return
        if (index !in snapshot.notify) return

        // Alarm gerçekten bu vakte mi denk geliyor? Saat geri alınınca (yaz
        // saati bitişi) önceden kurulmuş alarmlar bir saat erken çalıyor ve
        // vakit girmeden "vakit girdi" deniyordu. Denk gelmiyorsa bildirim
        // basılmaz; alarmlar `rescheduleAll` ile yeni saate göre kurulur.
        if (!PrayerSchedule(snapshot).isDue(index)) return

        Notifications.ensureChannels(context)

        val name = snapshot.nameOf(index)
        val title = if (snapshot.language == "en") "$name has begun" else "$name vakti girdi"

        val notification = NotificationCompat.Builder(context, Notifications.CHANNEL_PRAYER)
            .setSmallIcon(R.drawable.ic_stat_crescent)
            .setContentTitle(title)
            .setContentText(snapshot.cityDisplay)
            .setContentIntent(Notifications.openAppIntent(context))
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .build()

        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) return
        try {
            NotificationManagerCompat.from(context)
                .notify(Notifications.prayerNotificationId(index), notification)
        } catch (_: SecurityException) {
            // İzin verilmemiş; uygulama açıldığında izin isteniyor.
        }
    }
}
