package com.tunahan.namaz_vakitleri

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

/** Bildirim kanalları ve ortak yardımcılar. */
object Notifications {

    /// Kanal ayarları (kilit ekranı görünürlüğü gibi) bir kez oluşturulduktan
    /// sonra değiştirilemiyor; ayar değişince kimliği artırıp eskisini siliyoruz.
    const val CHANNEL_ONGOING = "ongoing_times_v3"
    const val CHANNEL_PRAYER = "prayer_alerts"

    private val OBSOLETE_CHANNELS = listOf("ongoing_times", "ongoing_times_v2")

    const val ID_ONGOING = 1001

    /** Vakit bildirimlerinin id'si: 2000 + vakit indeksi. */
    fun prayerNotificationId(prayerIndex: Int) = 2000 + prayerIndex

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        val turkish = PrayerStore.read(context).language != "en"

        // IMPORTANCE_LOW bildirimi "Sessiz" bölümüne düşürüyor; oradakiler
        // kilit ekranında gizleniyor. Ekran kapalıyken de görünsün diye
        // IMPORTANCE_DEFAULT kullanılıyor, ama sesi ve titreşimi kapatarak —
        // yani rahatsız etmeden, sadece görünür.
        //
        // Kanalın `lockscreenVisibility` alanı burada ayarlanamaz; Android
        // onu yalnızca sistemin değiştirmesine izin veriyor (uygulama
        // yazarsa -1000 olarak kalıyor). Kilit ekranı içeriğini bildirimin
        // kendi `setVisibility(VISIBILITY_PUBLIC)` çağrısı belirliyor.
        val ongoing = NotificationChannel(
            CHANNEL_ONGOING,
            if (turkish) "Kalıcı vakit bildirimi" else "Persistent prayer notification",
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = if (turkish) {
                "Bildirim çubuğundaki vakitler ve geri sayım"
            } else {
                "Times and countdown in the status bar"
            }
            setShowBadge(false)
            enableVibration(false)
            vibrationPattern = null
            setSound(null, null)
        }

        val alerts = NotificationChannel(
            CHANNEL_PRAYER,
            if (turkish) "Vakit bildirimleri" else "Prayer alerts",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = if (turkish) {
                "Namaz vakti girdiğinde bildirim"
            } else {
                "Notification when a prayer time begins"
            }
            enableVibration(true)
        }

        manager.createNotificationChannel(ongoing)
        manager.createNotificationChannel(alerts)

        // Ayarları değişmiş eski kanallar kalmasın.
        OBSOLETE_CHANNELS.forEach(manager::deleteNotificationChannel)
    }

    /** Bildirime dokununca uygulamayı açan intent. */
    fun openAppIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
