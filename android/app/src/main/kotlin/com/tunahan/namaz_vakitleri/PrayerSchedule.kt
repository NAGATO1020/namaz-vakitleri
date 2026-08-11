package com.tunahan.namaz_vakitleri

import java.util.Calendar
import java.util.Locale

/**
 * Vakitleri gerçek zamana oturtur ve sıradaki vakti bulur.
 *
 * Dart tarafındaki `PrayerDay.dateTimeOf` ve `NextPrayerCalculator` ile aynı
 * kuralları uygular:
 *
 *  - 0..16 arası vakitler kronolojik bir zincirdir; bir vakit kendinden
 *    öncekinden küçükse gece yarısını geçmiştir ve ertesi güne taşınır
 *    (Gece Yarısı, Teheccüd, Seher tipik olarak böyledir).
 *  - Kıble Sâati (17) zincire girmez, sıradaki vakit olarak seçilmez.
 *  - Saatler şehrin yerel saatiyledir; cihaz saatiyle farkı `offsetMinutes`
 *    kapatır.
 *
 * Elde birden çok gün varsa hepsi zaman çizgisine dizilir; böylece uygulama
 * günlerce açılmasa da bildirim doğru vakti gösterir.
 */
class PrayerSchedule(private val snapshot: PrayerStore.Snapshot) {

    data class Entry(val index: Int, val atMillis: Long)

    /** Sıradaki vakit ve varsa o an içinde bulunulan vakit. */
    data class Upcoming(val next: Entry, val current: Entry?)

    /** Cihaz saatinin şehrin saatine karşılık gelen ânı. */
    fun cityNow(deviceNow: Long = System.currentTimeMillis()): Long =
        deviceNow + snapshot.offsetMinutes * 60_000L

    /**
     * Elde bulunan bütün günlerin vakitleri, zaman sırasına dizilmiş.
     *
     * Gün başlangıçları `Calendar` ile hesaplanır; yaz saati geçişlerinde
     * 24 saat eklemek yanlış sonuç verirdi.
     */
    fun entries(onlyVisible: Boolean = true, indices: Set<Int>? = null): List<Entry> {
        val wanted = indices
            ?: if (onlyVisible) snapshot.visible else (0 until PrayerStore.PRAYER_COUNT).toSet()

        val out = ArrayList<Entry>(snapshot.days.size * PrayerStore.PRAYER_COUNT)
        for (day in snapshot.days) {
            val anchor = midnightOf(day.date) ?: continue
            appendDay(out, day.times, anchor, wanted)
        }
        out.sortBy { it.atMillis }
        return out
    }

    /**
     * Sıradaki vakit ve o an içinde bulunulan vakit.
     *
     * Kıble Sâati listede görünse de sıraya girmez: bir namaz vakti değil,
     * günün içinde duran bir andır.
     *
     * Veri yoksa ya da elde gelecek vakit kalmadıysa `null`.
     */
    fun next(deviceNow: Long = System.currentTimeMillis()): Upcoming? {
        val now = cityNow(deviceNow)
        var current: Entry? = null
        for (entry in entries()) {
            if (entry.index == PrayerStore.QIBLA_INDEX) continue
            if (entry.atMillis > now) return Upcoming(entry, current)
            current = entry
        }
        return null
    }

    /** Sıradaki vakte kalan süre (milisaniye). */
    fun remainingMillis(next: Entry, deviceNow: Long = System.currentTimeMillis()): Long =
        (next.atMillis - cityNow(deviceNow)).coerceAtLeast(0L)

    /** Bildirim gönderilecek, henüz gelmemiş vakitler. */
    fun upcomingAlarms(deviceNow: Long = System.currentTimeMillis()): List<Entry> {
        if (!snapshot.notificationsEnabled || snapshot.notify.isEmpty()) return emptyList()
        val now = cityNow(deviceNow)
        // Kıble Sâati için bildirim kurulmaz — namaz vakti değil.
        val wanted = snapshot.notify - PrayerStore.QIBLA_INDEX
        if (wanted.isEmpty()) return emptyList()
        return entries(indices = wanted).filter { it.atMillis > now }
    }

    /**
     * Şehir saatiyle verilen ânın, alarm kurulacak **cihaz** saatindeki karşılığı.
     * Vakitler şehrin saatiyle tutulduğu için alarmlar bu dönüşümle kurulur.
     */
    fun toDeviceMillis(cityMillis: Long): Long =
        cityMillis - snapshot.offsetMinutes * 60_000L

    /** Bugünün (şehir saatiyle) vakitleri — bildirimdeki liste için. */
    fun today(deviceNow: Long = System.currentTimeMillis()): PrayerStore.Day? {
        val key = dateKeyOf(cityNow(deviceNow))
        return snapshot.dayOn(key) ?: snapshot.days.lastOrNull { it.date <= key }
    }

    private fun appendDay(
        out: MutableList<Entry>,
        times: List<String?>,
        anchorMidnight: Long,
        wanted: Set<Int>
    ) {
        var dayOffset = 0
        var previousMinutes = -1

        for (index in 0 until PrayerStore.PRAYER_COUNT) {
            val minutes = times.getOrNull(index)?.let(::minutesOf) ?: continue

            if (index == PrayerStore.QIBLA_INDEX) {
                // Zincire girmez; günün kendi içinde kalır ve sıraya sokulmaz.
                if (index in wanted) {
                    out.add(Entry(index, atMillis(anchorMidnight, 0, minutes)))
                }
                continue
            }

            if (previousMinutes >= 0 && minutes < previousMinutes) dayOffset++
            previousMinutes = minutes

            if (index in wanted) {
                out.add(Entry(index, atMillis(anchorMidnight, dayOffset, minutes)))
            }
        }
    }

    private fun atMillis(anchorMidnight: Long, dayOffset: Int, minutes: Int): Long =
        Calendar.getInstance().apply {
            timeInMillis = anchorMidnight
            if (dayOffset != 0) add(Calendar.DAY_OF_MONTH, dayOffset)
            add(Calendar.MINUTE, minutes)
        }.timeInMillis

    companion object {
        /** "13:48" → 828 */
        fun minutesOf(hhmm: String): Int? {
            if (hhmm.length != 5 || hhmm[2] != ':') return null
            val h = hhmm.substring(0, 2).toIntOrNull() ?: return null
            val m = hhmm.substring(3).toIntOrNull() ?: return null
            if (h > 23 || m > 59) return null
            return h * 60 + m
        }

        /** "2026-08-11" → o günün 00:00'ı (cihazın saat diliminde). */
        fun midnightOf(date: String): Long? {
            val parts = date.split("-")
            if (parts.size != 3) return null
            val year = parts[0].toIntOrNull() ?: return null
            val month = parts[1].toIntOrNull() ?: return null
            val day = parts[2].toIntOrNull() ?: return null
            return Calendar.getInstance().apply {
                clear()
                set(year, month - 1, day, 0, 0, 0)
            }.timeInMillis
        }

        /** Milisaniyeyi "yyyy-MM-dd" olarak yazar. */
        fun dateKeyOf(millis: Long): String {
            val c = Calendar.getInstance().apply { timeInMillis = millis }
            return String.format(
                Locale.ROOT, "%04d-%02d-%02d",
                c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH)
            )
        }

        /** Milisaniyeyi "HH:mm" olarak yazar. */
        fun formatClock(millis: Long): String {
            val c = Calendar.getInstance().apply { timeInMillis = millis }
            return String.format(
                Locale.ROOT, "%02d:%02d",
                c.get(Calendar.HOUR_OF_DAY), c.get(Calendar.MINUTE)
            )
        }
    }
}
