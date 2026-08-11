package com.tunahan.namaz_vakitleri

import android.content.Context
import android.content.SharedPreferences

/**
 * Flutter tarafının `home_widget` üzerinden yazdığı veriyi okur/yazar.
 *
 * Widget'lar ve kalıcı bildirim Flutter'ı hiç uyandırmadan çalışsın diye
 * bütün hesaplama (sıradaki vakit, geri sayım) native tarafta yapılır;
 * buradan yalnızca ham vakitler ve ayarlar alınır.
 *
 * Anahtarlar `lib/platform/widget_bridge.dart` ile birebir aynıdır.
 */
object PrayerStore {

    /**
     * `home_widget` verileri bu dosyaya, anahtarları **olduğu gibi** (önek
     * eklemeden) yazar — bkz. HomeWidgetPlugin.kt'deki `prefs.putString(id, data)`.
     */
    private const val PREFS = "HomeWidgetPreferences"

    const val PRAYER_COUNT = 18

    /** Kıble Sâati kronolojik zincire girmez (Prayer.kibleSaati). */
    const val QIBLA_INDEX = 17

    /** Bir günün vakitleri. */
    data class Day(
        /** "yyyy-MM-dd" */
        val date: String,
        /** 18 elemanlı; hesaplanamayan vakitler null. */
        val times: List<String?>,
        val hijri: String
    ) {
        val hasTimes: Boolean get() = times.any { it != null }
    }

    data class Snapshot(
        val cityDisplay: String,
        /** Vakitlerin çekileceği takvim: "turktakvim" veya "fazilet". */
        val sourceId: String,
        val cityId: Int,
        /**
         * Elde bulunan bütün günler, târihe göre sıralı.
         *
         * Eskiden yalnızca bugün ve yarın yazılıyordu; uygulama iki gün
         * açılmayınca bildirim susuyordu. Artık önbellekteki günler
         * yazıldığı için bildirim internetsiz de günlerce çalışır.
         */
        val days: List<Day>,
        val visible: Set<Int>,
        val notify: Set<Int>,
        val offsetMinutes: Long,
        val language: String,
        val persistentEnabled: Boolean,
        val notificationsEnabled: Boolean,
        val showSeconds: Boolean,
        private val namesTr: List<String>,
        private val namesEn: List<String>
    ) {
        val hasData: Boolean get() = days.any { it.hasTimes }

        fun nameOf(index: Int): String {
            val names = if (language == "en") namesEn else namesTr
            return names.getOrNull(index) ?: ""
        }

        fun dayOn(date: String): Day? = days.firstOrNull { it.date == date }

        /** Verilen günden sonraki ilk gün (varsa). */
        fun dayAfter(date: String): Day? =
            days.firstOrNull { it.date > date }

        /** En son elde bulunan gün — verinin ne kadar ileriye yettiğini gösterir. */
        val lastDate: String? get() = days.lastOrNull()?.date
    }

    fun read(context: Context): Snapshot {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return Snapshot(
            cityDisplay = prefs.string("city_display"),
            sourceId = prefs.string("source").ifEmpty { "turktakvim" },
            cityId = prefs.string("city_id").toIntOrNull() ?: 0,
            days = parseDays(prefs.string("days")),
            visible = parseIndices(prefs.string("visible_prayers")),
            notify = parseIndices(prefs.string("notify_prayers")),
            offsetMinutes = prefs.string("city_offset_minutes").toLongOrNull() ?: 0L,
            language = prefs.string("language"),
            persistentEnabled = prefs.bool("persistent_enabled", true),
            notificationsEnabled = prefs.bool("notifications_enabled", true),
            showSeconds = prefs.bool("show_seconds", true),
            namesTr = prefs.string("prayer_names_tr").split("|"),
            namesEn = prefs.string("prayer_names_en").split("|")
        )
    }

    /**
     * Arka planda çekilen günleri elde olanlarla birleştirip yazar.
     *
     * Aynı târih iki kez gelirse yenisi eskisinin yerini alır; böylece
     * kaynak vakitlerini düzeltirse düzeltme yansır.
     */
    fun mergeDays(context: Context, fetched: List<Day>) {
        if (fetched.isEmpty()) return
        val existing = read(context).days
        val byDate = LinkedHashMap<String, Day>()
        existing.forEach { byDate[it.date] = it }
        fetched.forEach { byDate[it.date] = it }

        val merged = byDate.values.sortedBy { it.date }.takeLast(MAX_DAYS)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString("days", encodeDays(merged))
            .apply()
    }

    private const val MAX_DAYS = 40

    /**
     * `yyyy-MM-dd<TAB>03:59,04:19,…<TAB>28 SAFER 1448` satırları.
     * Aynı biçimi Dart'ta `WidgetBridge.encodeDays` üretiyor.
     */
    fun parseDays(raw: String): List<Day> {
        if (raw.isEmpty()) return emptyList()
        return raw.split("\n").mapNotNull { line ->
            if (line.isBlank()) return@mapNotNull null
            val parts = line.split("\t")
            if (parts.size < 2) return@mapNotNull null
            val date = parts[0].trim()
            if (date.length != 10) return@mapNotNull null
            Day(
                date = date,
                times = parseTimes(parts[1]),
                hijri = parts.getOrNull(2)?.trim().orEmpty()
            )
        }.sortedBy { it.date }
    }

    fun encodeDays(days: List<Day>): String = days.joinToString("\n") { day ->
        val times = (0 until PRAYER_COUNT).joinToString(",") {
            day.times.getOrNull(it).orEmpty()
        }
        "${day.date}\t$times\t${day.hijri}"
    }

    private fun SharedPreferences.string(key: String): String =
        runCatching { getString(key, "") }.getOrNull() ?: ""

    private fun SharedPreferences.bool(key: String, fallback: Boolean): Boolean =
        if (contains(key)) getBoolean(key, fallback) else fallback

    /** "03:59,04:19,,13:48…" → 18 elemanlı liste. */
    fun parseTimes(raw: String): List<String?> {
        if (raw.isEmpty()) return List(PRAYER_COUNT) { null }
        val parts = raw.split(",")
        return List(PRAYER_COUNT) { i ->
            parts.getOrNull(i)?.takeIf { it.length == 5 && it[2] == ':' }
        }
    }

    /** "0,1,2,6" → {0,1,2,6} */
    private fun parseIndices(raw: String): Set<Int> =
        if (raw.isEmpty()) emptySet()
        else raw.split(",").mapNotNull { it.trim().toIntOrNull() }.toSet()
}
