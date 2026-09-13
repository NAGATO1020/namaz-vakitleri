package com.tunahan.namaz_vakitleri

import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar

/** Kalıcı bildirimin ne göstereceği kararı. */
class OngoingContentTest {

    private val times = listOf(
        "03:59", "04:19", "06:17", "07:11", "12:27", "13:25", "13:48", "17:45",
        "18:49", "20:12", "20:56", "22:00", "22:55", "23:12", "00:28", "01:39",
        "02:50", "11:06"
    )

    private fun snapshot(
        days: List<String> = listOf("2026-08-11", "2026-08-12"),
        persistentEnabled: Boolean = true
    ) = PrayerStore.Snapshot(
        cityDisplay = "Schönberg - Fribourg",
        sourceId = "turktakvim",
        cityId = 64814,
        days = days.map { PrayerStore.Day(date = it, times = times, hijri = "") },
        visible = setOf(0, 1, 2, 3, 6, 7, 10, 12, 17),
        notify = setOf(1, 6, 7, 10, 12),
        offsetMinutes = 0,
        language = "tr",
        persistentEnabled = persistentEnabled,
        notificationsEnabled = true,
        showSeconds = true,
        namesTr = List(18) { "vakit$it" },
        namesEn = List(18) { "prayer$it" }
    )

    private fun millisAt(month: Int, day: Int, hour: Int, minute: Int): Long =
        Calendar.getInstance().apply {
            clear()
            set(2026, month - 1, day, hour, minute, 0)
        }.timeInMillis

    @Test
    fun `vakit varsa geri sayim gosterilir`() {
        val content = OngoingContent.decide(snapshot(), millisAt(8, 11, 14, 30))
        assertTrue(content is OngoingContent.Countdown)
        assertEquals(7, (content as OngoingContent.Countdown).upcoming.next.index)
    }

    @Test
    fun `kullanici kapattiysa bildirim gizlenir`() {
        assertSame(
            OngoingContent.Hidden,
            OngoingContent.decide(snapshot(persistentEnabled = false), millisAt(8, 11, 14, 30))
        )
    }

    @Test
    fun `hic veri yoksa bildirim gizlenir`() {
        assertSame(
            OngoingContent.Hidden,
            OngoingContent.decide(snapshot(days = emptyList()), millisAt(8, 11, 14, 30))
        )
    }

    @Test
    fun `veri bitince bildirim kaybolmaz yenileme ister`() {
        // Eskiden bu durumda bildirim siliniyordu.
        assertSame(
            OngoingContent.Stale,
            OngoingContent.decide(snapshot(), millisAt(8, 14, 9, 0))
        )
    }
}
