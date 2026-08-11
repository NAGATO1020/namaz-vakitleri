package com.tunahan.namaz_vakitleri

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.os.Build
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews

/**
 * Üç ana ekran widget'ının ortak iskeleti.
 *
 * Veri [PrayerStore]'dan okunur, sıradaki vakit [PrayerSchedule] ile bulunur.
 * Geri sayım `Chronometer` ile gösterilir; sistem sayacı kendisi işlettiği
 * için widget'ın sürekli yenilenmesi gerekmez.
 */
abstract class BasePrayerWidgetProvider : AppWidgetProvider() {

    protected abstract val layoutId: Int

    protected abstract fun render(
        context: Context,
        views: RemoteViews,
        snapshot: PrayerStore.Snapshot,
        schedule: PrayerSchedule,
        next: PrayerSchedule.Entry,
        current: PrayerSchedule.Entry?
    )

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val snapshot = PrayerStore.read(context)
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, layoutId)
            views.setOnClickPendingIntent(R.id.widget_root, Notifications.openAppIntent(context))

            if (!snapshot.hasData) {
                views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                views.setViewVisibility(R.id.widget_content, View.GONE)
            } else {
                val schedule = PrayerSchedule(snapshot)
                val upcoming = schedule.next()
                if (upcoming == null) {
                    views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_content, View.GONE)
                } else {
                    views.setViewVisibility(R.id.widget_empty, View.GONE)
                    views.setViewVisibility(R.id.widget_content, View.VISIBLE)
                    render(context, views, snapshot, schedule, upcoming.next, upcoming.current)
                }
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    /** Hedefe geri sayan sayaç kurar. */
    protected fun setCountdown(views: RemoteViews, viewId: Int, remainingMillis: Long) {
        views.setChronometer(
            viewId,
            SystemClock.elapsedRealtime() + remainingMillis,
            null,
            true
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            views.setChronometerCountDown(viewId, true)
        }
    }
}

/** 2×1 — sıradaki vaktin adı, saati ve geri sayım. */
class NextPrayerWidgetProvider : BasePrayerWidgetProvider() {
    override val layoutId = R.layout.widget_next_prayer

    override fun render(
        context: Context,
        views: RemoteViews,
        snapshot: PrayerStore.Snapshot,
        schedule: PrayerSchedule,
        next: PrayerSchedule.Entry,
        current: PrayerSchedule.Entry?
    ) {
        views.setTextViewText(R.id.next_name, snapshot.nameOf(next.index))
        views.setTextViewText(R.id.next_time, PrayerSchedule.formatClock(next.atMillis))
        views.setTextViewText(R.id.city, snapshot.cityDisplay)
        setCountdown(views, R.id.countdown, schedule.remainingMillis(next))
    }
}

/** 1×1 — yalnızca sıradaki vaktin saati. */
class CompactWidgetProvider : BasePrayerWidgetProvider() {
    override val layoutId = R.layout.widget_compact

    override fun render(
        context: Context,
        views: RemoteViews,
        snapshot: PrayerStore.Snapshot,
        schedule: PrayerSchedule,
        next: PrayerSchedule.Entry,
        current: PrayerSchedule.Entry?
    ) {
        views.setTextViewText(R.id.next_name, snapshot.nameOf(next.index))
        views.setTextViewText(R.id.next_time, PrayerSchedule.formatClock(next.atMillis))
    }
}

/** 4×2 — şehir, hicrî târih ve günün seçili vakitleri. */
class DailyTimesWidgetProvider : BasePrayerWidgetProvider() {
    override val layoutId = R.layout.widget_daily_times

    override fun render(
        context: Context,
        views: RemoteViews,
        snapshot: PrayerStore.Snapshot,
        schedule: PrayerSchedule,
        next: PrayerSchedule.Entry,
        current: PrayerSchedule.Entry?
    ) {
        views.setTextViewText(R.id.city, snapshot.cityDisplay)
        views.setTextViewText(R.id.hijri, schedule.today()?.hijri.orEmpty())
        views.setTextViewText(R.id.next_name, snapshot.nameOf(next.index))
        setCountdown(views, R.id.countdown, schedule.remainingMillis(next))

        views.removeAllViews(R.id.times_container)
        val cityNow = schedule.cityNow()
        val entries = schedule.entries()
            .filter { it.atMillis in (cityNow - DAY_MILLIS)..(cityNow + DAY_MILLIS) }
            .distinctBy { it.index }

        for (entry in entries) {
            val isNext = entry.index == next.index && entry.atMillis == next.atMillis
            val past = !isNext && entry.atMillis < cityNow
            // Geçmiş vakitler soluk görünsün diye ayrı bir satır düzeni
            // kullanılıyor: RemoteViews'ta View.setAlpha güvenilir değil,
            // renk ise düzenden gelince açık/koyu temada da doğru çıkıyor.
            val row = RemoteViews(
                context.packageName,
                if (past) R.layout.widget_time_row_past else R.layout.widget_time_row
            )
            row.setTextViewText(R.id.row_name, snapshot.nameOf(entry.index))
            row.setTextViewText(R.id.row_time, PrayerSchedule.formatClock(entry.atMillis))
            row.setViewVisibility(R.id.row_marker, if (isNext) View.VISIBLE else View.INVISIBLE)
            views.addView(R.id.times_container, row)
        }
    }

    private companion object {
        const val DAY_MILLIS = 24L * 60 * 60 * 1000
    }
}
