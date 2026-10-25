package com.tunahan.namaz_vakitleri

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.TimeZone

/**
 * Yaz saati geçişleri.
 *
 * 25 Ekim 2026'da saatler bir saat geri alındı; o gün 25 saat sürdü. Gece
 * yarısına dakika **ekleyerek** kurulan vakitler bir saat erkene kaydı ve
 * alarmlar vakit girmeden "vakit girdi" dedi. Varsayılan saat dilimi burada
 * sâbitleniyor ki test çalıştığı makineden bağımsız olsun.
 */
class DaylightSavingTest {

    private val zurich = ZoneId.of("Europe/Zurich")
    private lateinit var original: TimeZone

    @Before
    fun useZurich() {
        original = TimeZone.getDefault()
        TimeZone.setDefault(TimeZone.getTimeZone(zurich))
    }

    @After
    fun restore() {
        TimeZone.setDefault(original)
    }

    private val times = listOf(
        "03:59", "04:19", "06:17", "07:11", "12:27", "13:25", "13:48", "17:45",
        "18:49", "20:12", "20:56", "22:00", "22:55", "23:12", "00:28", "01:39",
        "02:50", "11:06"
    )

    private fun snapshot(vararg dates: String) = PrayerStore.Snapshot(
        cityDisplay = "Schönberg - Fribourg",
        sourceId = "turktakvim",
        cityId = 64814,
        days = dates.map { PrayerStore.Day(date = it, times = times, hijri = "") },
        visible = (0 until 18).toSet(),
        notify = setOf(1, 6, 7, 10, 12),
        offsetMinutes = 0,
        language = "tr",
        persistentEnabled = true,
        notificationsEnabled = true,
        showSeconds = true,
        namesTr = List(18) { "vakit$it" },
        namesEn = List(18) { "prayer$it" }
    )

    /** Duvar saatiyle verilen ânın gerçek epoch karşılığı. */
    private fun wallClock(date: String, hour: Int, minute: Int): Long {
        val d = date.split("-").map(String::toInt)
        return ZonedDateTime.of(d[0], d[1], d[2], hour, minute, 0, 0, zurich)
            .toInstant().toEpochMilli()
    }

    @Test
    fun `saat geri alinan gun vakitler kaymaz`() {
        val entries = PrayerSchedule(snapshot("2026-10-25")).entries()
        // Öğle (6) o gün 13:48'de; gece yarısına 828 dakika eklemek 12:48 verirdi.
        val ogle = entries.first { it.index == 6 }
        assertEquals(wallClock("2026-10-25", 13, 48), ogle.atMillis)
        assertEquals("13:48", PrayerSchedule.formatClock(ogle.atMillis))
    }

    @Test
    fun `saat ileri alinan gun vakitler kaymaz`() {
        // 29 Mart 2026: saatler ileri alındı, gün 23 saat sürdü.
        val ogle = PrayerSchedule(snapshot("2026-03-29")).entries().first { it.index == 6 }
        assertEquals(wallClock("2026-03-29", 13, 48), ogle.atMillis)
    }

    @Test
    fun `gece yarisini gecen vakit geciste de dogru gune duser`() {
        // Seher (16) 02:50 — 25 Ekim'in vakitleri olarak 26 Ekim'e düşer.
        val seher = PrayerSchedule(snapshot("2026-10-25")).entries().first { it.index == 16 }
        assertEquals(wallClock("2026-10-26", 2, 50), seher.atMillis)
    }

    @Test
    fun `bir saat erken calan alarm reddedilir`() {
        val schedule = PrayerSchedule(snapshot("2026-10-25"))
        // Saat geri alınmadan kurulmuş alarmın tetiklendiği an: 12:48.
        assertFalse(schedule.isDue(6, wallClock("2026-10-25", 12, 48)))
    }

    @Test
    fun `vaktinde calan alarm kabul edilir`() {
        val schedule = PrayerSchedule(snapshot("2026-10-25"))
        assertTrue(schedule.isDue(6, wallClock("2026-10-25", 13, 48)))
    }

    @Test
    fun `doze yuzunden geciken alarm kabul edilir`() {
        val schedule = PrayerSchedule(snapshot("2026-10-25"))
        assertTrue(schedule.isDue(6, wallClock("2026-10-25", 14, 20)))
    }

    @Test
    fun `cok gec kalan alarm reddedilir`() {
        val schedule = PrayerSchedule(snapshot("2026-10-25"))
        assertFalse(schedule.isDue(6, wallClock("2026-10-25", 16, 0)))
    }

    @Test
    fun `gecis gunu butun vakitler duvar saatinde kalir`() {
        val schedule = PrayerSchedule(snapshot("2026-10-25"))
        for ((index, raw) in times.withIndex()) {
            val entry = schedule.entries().firstOrNull { it.index == index } ?: continue
            assertEquals(
                "vakit $index kaymamalı",
                raw,
                PrayerSchedule.formatClock(entry.atMillis)
            )
        }
    }
}
