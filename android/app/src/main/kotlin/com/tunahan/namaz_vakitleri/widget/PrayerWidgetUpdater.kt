package com.tunahan.namaz_vakitleri

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context

/** Üç widget'ı da tek noktadan yeniler. */
object PrayerWidgetUpdater {

    private val providers = listOf(
        NextPrayerWidgetProvider::class.java,
        DailyTimesWidgetProvider::class.java,
        CompactWidgetProvider::class.java
    )

    fun updateAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context) ?: return
        for (provider in providers) {
            val ids = manager.getAppWidgetIds(ComponentName(context, provider))
            if (ids.isEmpty()) continue
            when (provider) {
                NextPrayerWidgetProvider::class.java ->
                    NextPrayerWidgetProvider().onUpdate(context, manager, ids)
                DailyTimesWidgetProvider::class.java ->
                    DailyTimesWidgetProvider().onUpdate(context, manager, ids)
                CompactWidgetProvider::class.java ->
                    CompactWidgetProvider().onUpdate(context, manager, ids)
            }
        }
    }
}
