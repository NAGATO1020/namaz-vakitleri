package com.tunahan.namaz_vakitleri

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * Bildirim çubuğundaki kalıcı vakit bildirimi.
 *
 * Geri sayımı `Chronometer` yapar: sistem sayacı kendisi işletir, bu yüzden
 * arka planda hiçbir hesap yürütmeye gerek yoktur. Bildirim yalnızca vakit
 * değiştiğinde yeniden kurulur — bunu [AlarmScheduler] zamanlar.
 *
 * Bildirim, sistemin uygulamayı durdurduğunda silmemesi için
 * [OngoingService] üzerinden ön plan bildirimi olarak basılır; servis
 * başlatılamazsa sıradan bildirime düşülür.
 *
 * Açık/koyu tema uyumu `?android:attr/textColorPrimary` gibi tema
 * özniteliklerinden gelir; tek düzen iki temada da doğru görünür.
 */
object OngoingNotification {

    fun refresh(context: Context) {
        val snapshot = PrayerStore.read(context)
        when (val content = OngoingContent.decide(snapshot)) {
            OngoingContent.Hidden -> cancel(context)

            OngoingContent.Stale -> {
                val signature = "stale|${snapshot.language}"
                if (signature != storedSignature(context) || !isShowing(context)) {
                    publish(context, signature, buildStale(context, snapshot))
                }
                // Elde gelecek vakit kalmadı: günlük alarmı beklemeden veri
                // çekmeyi dene. `runIfNeeded` kendi içinde 6 saatlik fren
                // uyguladığı için kaynağa arka arkaya istek gitmez.
                DailyRefresh.runIfNeeded(context)
            }

            is OngoingContent.Countdown -> showCountdown(
                context, snapshot, content.schedule, content.upcoming
            )
        }
    }

    private fun showCountdown(
        context: Context,
        snapshot: PrayerStore.Snapshot,
        schedule: PrayerSchedule,
        upcoming: PrayerSchedule.Upcoming
    ) {
        val next = upcoming.next
        val nextDeviceMillis = schedule.toDeviceMillis(next.atMillis)

        // Geri sayım `Chronometer` ile gösteriliyor ve tabanı monoton saatle
        // (`elapsedRealtime`) kuruluyor; kalan süre ise duvar saatinden
        // hesaplanıyor. İki saat NTP düzeltmeleriyle birbirinden kayıyor, bu
        // yüzden bildirim her yeniden basıldığında sayaç sıfırlanıp kayma
        // kadar zıplıyordu — bazen geriye. İçerik değişmediyse ve bildirim
        // hâlâ duruyorsa yeniden basmıyoruz.
        val signature = signatureOf(snapshot, next, upcoming.current)
        if (signature == storedSignature(context) && isShowing(context)) {
            // Bildirim duruyor ama servisin dışında kalmış olabilir (ör. önceki
            // sürümden ya da servis başlatılamadığı bir andan). Fırsat varken
            // servise al ki sistem onu silemesin.
            if (!OngoingService.isRunning) OngoingService.tryStart(context)
            AlarmScheduler.scheduleOngoingRefresh(context, nextDeviceMillis)
            return
        }

        publish(
            context, signature,
            buildCountdown(context, snapshot, schedule, upcoming)
        )

        // Sıradaki vakit girdiğinde bildirim kendini yenilesin.
        AlarmScheduler.scheduleOngoingRefresh(context, nextDeviceMillis)
    }

    /**
     * O anki içerikle bildirimi kurar; gösterilecek bir şey yoksa `null`.
     * Yan etkisi yok — [OngoingService] başlarken bunu kullanır.
     */
    fun build(context: Context): Notification? {
        val snapshot = PrayerStore.read(context)
        return when (val content = OngoingContent.decide(snapshot)) {
            OngoingContent.Hidden -> null
            OngoingContent.Stale -> buildStale(context, snapshot)
            is OngoingContent.Countdown ->
                buildCountdown(context, snapshot, content.schedule, content.upcoming)
        }
    }

    /**
     * Servisin, gösterecek bir şey kalmadığında bile `startForeground`
     * çağırabilmesi için içeriksiz bildirim. Hemen ardından kaldırılır.
     */
    fun placeholder(context: Context): Notification =
        baseBuilder(context)
            .setContentTitle(context.getString(R.string.app_name))
            .build()

    fun cancel(context: Context) {
        OngoingService.stop(context)
        context.getSystemService(NotificationManager::class.java)
            ?.cancel(Notifications.ID_ONGOING)
        storeSignature(context, "")
    }

    /**
     * Bildirimi basar: servis ayaktaysa onun bildirimini günceller, değilse
     * servisi başlatmayı dener (servis bildirimi kendisi basar), o da olmazsa
     * sıradan bildirim olarak basar.
     */
    private fun publish(context: Context, signature: String, notification: Notification) {
        storeSignature(context, signature)

        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) {
            // İzin yokken servisi ayakta tutmanın anlamı yok; bildirim görünmez.
            OngoingService.stop(context)
            return
        }

        // Servis ayaktayken aynı kimlikle `notify` ön plan bildirimini günceller.
        if (OngoingService.isRunning || !OngoingService.tryStart(context)) {
            notifyPlain(context, notification)
        }
    }

    fun notifyPlain(context: Context, notification: Notification) {
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) return
        try {
            NotificationManagerCompat.from(context)
                .notify(Notifications.ID_ONGOING, notification)
        } catch (_: SecurityException) {
            // Bildirim izni yoksa sessizce vazgeç; izni uygulama içinde isteriz.
        }
    }

    /** Kalıcı bildirimin her türünde ortak ayarlar. */
    private fun baseBuilder(context: Context): NotificationCompat.Builder {
        Notifications.ensureChannels(context)
        return NotificationCompat.Builder(context, Notifications.CHANNEL_ONGOING)
            .setSmallIcon(R.drawable.ic_stat_crescent)
            .setContentIntent(Notifications.openAppIntent(context))
            .setOngoing(true)
            .setShowWhen(false)
            // Her yeniden basılışta ses/titreşim tetiklenmesin.
            //
            // `setSilent(true)` **kullanılmıyor**: o çağrı bildirimi
            // GROUP_KEY_SILENT'e koyup "Sessiz" bölümüne düşürüyor, orası da
            // kilit ekranında gizleniyor. Sessizliği zaten kanal sağlıyor
            // (sesi ve titreşimi kapalı IMPORTANCE_DEFAULT).
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            // Ekran kilitliyken de içeriğiyle görünsün.
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            // Android 12+ ön plan bildirimlerini 10 saniyeye kadar geciktiriyor.
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            // Android 13'ten beri kalıcı ve ön plan bildirimleri de kaydırılıp
            // atılabiliyor. Atılırsa bunu yakalayıp hemen geri koyuyoruz.
            .setDeleteIntent(dismissIntent(context))
    }

    private fun buildCountdown(
        context: Context,
        snapshot: PrayerStore.Snapshot,
        schedule: PrayerSchedule,
        upcoming: PrayerSchedule.Upcoming
    ): Notification {
        val next = upcoming.next
        val current = upcoming.current
        return baseBuilder(context)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setCustomContentView(
                buildViews(context, snapshot, schedule, next, current, expanded = false)
            )
            .setCustomBigContentView(
                buildViews(context, snapshot, schedule, next, current, expanded = true)
            )
            .build()
    }

    /** Elde gelecek vakit kalmadığında gösterilen bildirim. */
    private fun buildStale(context: Context, snapshot: PrayerStore.Snapshot): Notification {
        val english = snapshot.language == "en"
        return baseBuilder(context)
            .setContentTitle(
                if (english) "Prayer times need refreshing" else "Vakitlerin yenilenmesi gerekiyor"
            )
            .setContentText(
                if (english) "Open the app to download current times"
                else "Güncel vakitleri indirmek için uygulamayı açın"
            )
            .build()
    }

    // --- gereksiz yeniden basmayı önleyen imza ---

    private const val PREFS_STATE = "OngoingNotificationState"
    private const val KEY_SIGNATURE = "signature"

    /**
     * Bildirimin görünen içeriğini özetler. Yalnızca bu değişince yeniden
     * basılır; aksi hâlde `Chronometer` sıfırlanıp geri sayım zıplıyor.
     */
    private fun signatureOf(
        snapshot: PrayerStore.Snapshot,
        next: PrayerSchedule.Entry,
        current: PrayerSchedule.Entry?
    ): String = buildString {
        append(next.index).append('@').append(next.atMillis)
        append('|').append(current?.index).append('@').append(current?.atMillis)
        append('|').append(snapshot.language)
        append('|').append(snapshot.cityDisplay)
        append('|').append(snapshot.visible.sorted().joinToString(","))
        append('|').append(snapshot.notify.sorted().joinToString(","))
    }

    private fun storedSignature(context: Context): String =
        context.getSharedPreferences(PREFS_STATE, Context.MODE_PRIVATE)
            .getString(KEY_SIGNATURE, "") ?: ""

    private fun storeSignature(context: Context, signature: String) {
        context.getSharedPreferences(PREFS_STATE, Context.MODE_PRIVATE)
            .edit().putString(KEY_SIGNATURE, signature).apply()
    }

    /**
     * Bildirim şu an gerçekten duruyor mu.
     *
     * Sistem ya da üretici pil yönetimi uygulamayı öldürdüğünde bildirim
     * siliniyor ama `deleteIntent` tetiklenmiyor; imza aynı kalsa bile
     * bildirim yoksa yeniden basmamız gerekiyor.
     */
    private fun isShowing(context: Context): Boolean {
        val manager = context.getSystemService(NotificationManager::class.java)
            ?: return false
        return runCatching {
            manager.activeNotifications.any { it.id == Notifications.ID_ONGOING }
        }.getOrDefault(false)
    }

    /// Bildirim kaydırılıp atıldığında sistemin tetiklediği intent.
    private fun dismissIntent(context: Context): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            REQUEST_DISMISSED,
            Intent(context, PrayerAlarmReceiver::class.java)
                .setAction(AlarmScheduler.ACTION_ONGOING_DISMISSED),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

    private const val REQUEST_DISMISSED = 920_000

    private fun buildViews(
        context: Context,
        snapshot: PrayerStore.Snapshot,
        schedule: PrayerSchedule,
        next: PrayerSchedule.Entry,
        current: PrayerSchedule.Entry?,
        expanded: Boolean
    ): RemoteViews {
        val layout = if (expanded) {
            R.layout.notification_ongoing_expanded
        } else {
            R.layout.notification_ongoing
        }
        val views = RemoteViews(context.packageName, layout)

        views.setTextViewText(R.id.next_name, snapshot.nameOf(next.index))
        views.setTextViewText(R.id.next_time, PrayerSchedule.formatClock(next.atMillis))
        views.setTextViewText(R.id.city, snapshot.cityDisplay)

        // Chronometer: hedefe kadar geri sayar, sistem kendi günceller.
        val remaining = schedule.remainingMillis(next)
        views.setChronometer(
            R.id.countdown,
            SystemClock.elapsedRealtime() + remaining,
            null,
            true
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            views.setChronometerCountDown(R.id.countdown, true)
        }

        if (expanded) {
            views.setTextViewText(R.id.hijri, schedule.today()?.hijri.orEmpty())
            views.setTextViewText(
                R.id.current_name,
                current?.let { snapshot.nameOf(it.index) } ?: ""
            )
            fillTimesTable(context, views, snapshot, schedule, next)
        }

        return views
    }

    /** Genişletilmiş görünümde günün seçili vakitlerini alt alta dizer. */
    private fun fillTimesTable(
        context: Context,
        views: RemoteViews,
        snapshot: PrayerStore.Snapshot,
        schedule: PrayerSchedule,
        next: PrayerSchedule.Entry
    ) {
        views.removeAllViews(R.id.times_container)
        val cityNow = schedule.cityNow()

        // Yalnızca bugünün satırındaki vakitler; sonraki günlerinkiler
        // tekrar etmesin. (Artık elde günlerce veri olabiliyor.)
        val todayEntries = schedule.entries()
            .filter { it.atMillis in (cityNow - DAY_MILLIS)..(cityNow + DAY_MILLIS) }
            .distinctBy { it.index }

        for (entry in todayEntries) {
            val isNext = entry.index == next.index && entry.atMillis == next.atMillis
            val past = !isNext && entry.atMillis < cityNow
            // Geçmiş vakitler için ayrı düzen: rengi düzenden (tema
            // özniteliğinden) almak açık/koyu temada da doğru sonuç veriyor.
            val row = RemoteViews(
                context.packageName,
                if (past) R.layout.notification_time_row_past
                else R.layout.notification_time_row
            )
            row.setTextViewText(R.id.row_name, snapshot.nameOf(entry.index))
            row.setTextViewText(R.id.row_time, PrayerSchedule.formatClock(entry.atMillis))
            row.setViewVisibility(R.id.row_marker, if (isNext) View.VISIBLE else View.INVISIBLE)
            views.addView(R.id.times_container, row)
        }
    }

    private const val DAY_MILLIS = 24L * 60 * 60 * 1000
}
