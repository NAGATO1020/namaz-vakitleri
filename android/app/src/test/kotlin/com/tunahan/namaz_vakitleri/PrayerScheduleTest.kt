package com.tunahan.namaz_vakitleri

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar

/**
 * Native taraftaki sıradaki-vakit hesabının testleri.
 *
 * Kurallar Dart'taki `PrayerDay.dateTimeOf` / `NextPrayerCalculator` ile aynı
 * olmak zorunda; `test/next_prayer_test.dart` ile aynı senaryolar burada da
 * çalıştırılıyor ki iki taraf ayrışmasın.
 */
class PrayerScheduleTest {

    /** 11 Ağustos 2026, Schönberg — turktakvim'den gelen gerçek yanıt. */
    private val day11 = listOf(
        "03:59", "04:19", "06:17", "07:11", "12:27", "13:25", "13:48", "17:45",
        "18:49", "20:12", "20:56", "22:00", "22:55", "23:12", "00:28", "01:39",
        "02:50", "11:06"
    )

    /** Ana ekranda varsayılan görünen vakitler. */
    private val visibleByDefault = setOf(0, 1, 2, 3, 6, 7, 10, 12, 17)

    private fun day(date: String, times: List<String?> = day11) =
        PrayerStore.Day(date = date, times = times, hijri = "28 SAFER 1448")

    private fun snapshot(
        days: List<PrayerStore.Day> = listOf(day("2026-08-11"), day("2026-08-12")),
        visible: Set<Int> = visibleByDefault,
        notify: Set<Int> = setOf(1, 6, 7, 10, 12),
        offsetMinutes: Long = 0,
        sourceId: String = "turktakvim"
    ) = PrayerStore.Snapshot(
        cityDisplay = "Schönberg - Fribourg",
        sourceId = sourceId,
        cityId = 64814,
        days = days,
        visible = visible,
        notify = notify,
        offsetMinutes = offsetMinutes,
        language = "tr",
        persistentEnabled = true,
        notificationsEnabled = true,
        showSeconds = true,
        namesTr = List(18) { "vakit$it" },
        namesEn = List(18) { "prayer$it" }
    )

    private fun millisAt(year: Int, month: Int, day: Int, hour: Int, minute: Int): Long =
        Calendar.getInstance().apply {
            clear()
            set(year, month - 1, day, hour, minute, 0)
        }.timeInMillis

    @Test
    fun `gun ortasinda siradaki vakit ikindi`() {
        val upcoming = PrayerSchedule(snapshot()).next(millisAt(2026, 8, 11, 14, 30))!!
        assertEquals(6, upcoming.current?.index) // Öğle
        assertEquals(7, upcoming.next.index)     // İkindi
        assertEquals(millisAt(2026, 8, 11, 17, 45), upcoming.next.atMillis)
    }

    @Test
    fun `vaktin tam uzerinde o vakit icinde bulunulan sayilir`() {
        val upcoming = PrayerSchedule(snapshot()).next(millisAt(2026, 8, 11, 17, 45))!!
        assertEquals(7, upcoming.current?.index)
        assertEquals(10, upcoming.next.index)
    }

    @Test
    fun `gece gecisinde siradaki vakit ertesi gunun imsaki`() {
        val upcoming = PrayerSchedule(snapshot()).next(millisAt(2026, 8, 11, 23, 30))!!
        assertEquals(12, upcoming.current?.index) // Yatsı
        assertEquals(0, upcoming.next.index)      // İmsâk
        assertEquals(millisAt(2026, 8, 12, 3, 59), upcoming.next.atMillis)
    }

    @Test
    fun `gece yarisini gecen vakitler ertesi gune tasinir`() {
        val entries = PrayerSchedule(snapshot(days = listOf(day("2026-08-11")), visible = setOf(14, 15, 16)))
            .entries()
        assertEquals(millisAt(2026, 8, 12, 0, 28), entries[0].atMillis)
        assertEquals(millisAt(2026, 8, 12, 1, 39), entries[1].atMillis)
        assertEquals(millisAt(2026, 8, 12, 2, 50), entries[2].atMillis)
    }

    @Test
    fun `kible saati zincire girmez ve siradaki vakit olmaz`() {
        val schedule = PrayerSchedule(snapshot())
        val upcoming = schedule.next(millisAt(2026, 8, 11, 10, 0))!!
        assertEquals(6, upcoming.next.index) // Öğle

        val qibla = schedule.entries(indices = setOf(17)).first()
        assertEquals(millisAt(2026, 8, 11, 11, 6), qibla.atMillis)
    }

    @Test
    fun `sehir saat dilimi farki geri sayimi kaydirir`() {
        val schedule = PrayerSchedule(snapshot(offsetMinutes = -60))
        val upcoming = schedule.next(millisAt(2026, 8, 11, 15, 30))!!
        assertEquals(7, upcoming.next.index)
        assertEquals(
            (3 * 60 + 15) * 60_000L,
            schedule.remainingMillis(upcoming.next, millisAt(2026, 8, 11, 15, 30))
        )
    }

    @Test
    fun `alarm zamani cihaz saatine cevrilir`() {
        val schedule = PrayerSchedule(snapshot(offsetMinutes = -60))
        assertEquals(
            millisAt(2026, 8, 11, 18, 45),
            schedule.toDeviceMillis(millisAt(2026, 8, 11, 17, 45))
        )
    }

    @Test
    fun `bildirim alarmlari yalnizca secili ve gelecek vakitler icin`() {
        val alarms = PrayerSchedule(snapshot(notify = setOf(7, 10)))
            .upcomingAlarms(millisAt(2026, 8, 11, 14, 0))
            .distinctBy { it.index }
        assertEquals(setOf(7, 10), alarms.map { it.index }.toSet())
    }

    @Test
    fun `elde bir tek gun varsa gunun sonunda siradaki vakit kalmaz`() {
        val schedule = PrayerSchedule(snapshot(days = listOf(day("2026-08-11"))))
        assertNull(schedule.next(millisAt(2026, 8, 12, 4, 0)))
    }

    @Test
    fun `coklu gun verisiyle bildirim gunlerce calisir`() {
        // Uygulama bir hafta açılmasa da elde veri varsa bildirim susmamalı.
        val week = (11..18).map { day("2026-08-%02d".format(it)) }
        val schedule = PrayerSchedule(snapshot(days = week))

        val upcoming = schedule.next(millisAt(2026, 8, 17, 14, 30))
        assertNotNull("6 gün sonrası için de vakit bulunmalı", upcoming)
        assertEquals(7, upcoming!!.next.index)
        assertEquals(millisAt(2026, 8, 17, 17, 45), upcoming.next.atMillis)
    }

    @Test
    fun `bugunun satiri sehir saatine gore secilir`() {
        val schedule = PrayerSchedule(
            snapshot(days = listOf(day("2026-08-11"), day("2026-08-12")))
        )
        assertEquals("2026-08-12", schedule.today(millisAt(2026, 8, 12, 9, 0))?.date)
        assertEquals("2026-08-11", schedule.today(millisAt(2026, 8, 11, 9, 0))?.date)
    }

    @Test
    fun `bos veri hesaplama yapmaz`() {
        val empty = snapshot(days = emptyList())
        assertTrue(!empty.hasData)
        assertNull(PrayerSchedule(empty).next())
    }

    @Test
    fun `saat metni ayristirilir`() {
        assertEquals(828, PrayerSchedule.minutesOf("13:48"))
        assertEquals(0, PrayerSchedule.minutesOf("00:00"))
        assertNull(PrayerSchedule.minutesOf("25:00"))
        assertNull(PrayerSchedule.minutesOf("1348"))
        assertNull(PrayerSchedule.minutesOf(""))
    }

    @Test
    fun `tarih anahtari uretilir`() {
        assertEquals("2026-08-11", PrayerSchedule.dateKeyOf(millisAt(2026, 8, 11, 23, 59)))
        assertEquals("2026-01-05", PrayerSchedule.dateKeyOf(millisAt(2026, 1, 5, 0, 0)))
    }
}
