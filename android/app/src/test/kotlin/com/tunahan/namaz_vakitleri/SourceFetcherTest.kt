package com.tunahan.namaz_vakitleri

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Arka plan indirmesinin ayrıştırıcıları.
 *
 * Bu kod Flutter uyandırılmadan çalıştığı için Dart tarafındaki ayrıştırıcıların
 * ikizi; ikisi ayrışmasın diye **aynı gerçek yanıtlarla** test ediliyor
 * (`test/fazilet_source_test.dart` ve `test/turktakvim_parser_test.dart`).
 */
class SourceFetcherTest {

    /** fazilettakvimi.com/api/cms/daily?districtId=31 — gerçek yanıt (kısaltıldı). */
    private val faziletIstanbul = """
    {"success":true,"bolge_adi":"İstanbul","bolge_saatdilimi":"Europe/Istanbul",
    "takvimler":[
     {"tarih":"2026-08-11","hicri_tarih":"28 Safer 1448"},
     {"tarih":"2026-08-12","hicri_tarih":"29 Safer 1448"}],
    "vakitler":[
     {"tarih":"2026-08-11","imsak":[{"tarih":"2026-08-11T01:05:00Z"}],
      "israk":[],"sabah":[{"tarih":"2026-08-11T01:25:00Z"}],
      "gunes":[{"tarih":"2026-08-11T03:01:00Z"}],
      "ogle":[{"tarih":"2026-08-11T10:19:00Z"}],
      "ikindi":[{"tarih":"2026-08-11T14:11:00Z"}],
      "aksam":[{"tarih":"2026-08-11T17:17:00Z"}],
      "yatsi":[{"tarih":"2026-08-11T18:58:00Z"}]},
     {"tarih":"2026-08-12","imsak":[{"tarih":"2026-08-12T01:07:00Z"}],
      "israk":[{"tarih":"2026-08-12T03:52:00Z"}],
      "sabah":[{"tarih":"2026-08-12T01:27:00Z"}],
      "gunes":[{"tarih":"2026-08-12T03:02:00Z"}],
      "ogle":[{"tarih":"2026-08-12T10:19:00Z"}],
      "ikindi":[{"tarih":"2026-08-12T14:10:00Z"}],
      "aksam":[{"tarih":"2026-08-12T17:16:00Z"}],
      "yatsi":[{"tarih":"2026-08-12T18:56:00Z"}]}]}
    """.trimIndent()

    /** gadget.turktakvim.com/gadget.php?pg=1&sid=64814 — gerçek yanıt. */
    private val turktakvimSchonberg =
        "Schönberg;46;48;N;7;11;E;03:59;04:19;06:17;07:11;12:27;13:25;13:48;" +
            "17:45;18:49;20:12;20:56;22:00;22:55;23:12;00:28;01:39;02:50;11:06;" +
            "11/08/2026 11:25:00 ;28  SAFER  1448 ;Fribourg"

    @Test
    fun `fazilet UTC saatleri sehrin saatine cevirir`() {
        val days = SourceFetcher.parseFazilet(faziletIstanbul)
        assertEquals(2, days.size)

        val today = days.first { it.date == "2026-08-11" }
        // 01:05Z + Europe/Istanbul (UTC+3) = 04:05
        assertEquals("04:05", today.times[0])  // İmsâk
        assertEquals("04:25", today.times[1])  // Sabâh
        assertEquals("06:01", today.times[2])  // Güneş
        assertEquals("13:19", today.times[6])  // Öğle
        assertEquals("17:11", today.times[7])  // İkindi
        assertEquals("20:17", today.times[10]) // Akşam
        assertEquals("21:58", today.times[12]) // Yatsı
    }

    @Test
    fun `fazilet bos gelen vakti atlar`() {
        val days = SourceFetcher.parseFazilet(faziletIstanbul)
        assertNull(days.first { it.date == "2026-08-11" }.times[3])   // İşrak boş
        assertEquals("06:52", days.first { it.date == "2026-08-12" }.times[3])
    }

    @Test
    fun `fazilet vermedigi vakitleri bos birakir`() {
        val today = SourceFetcher.parseFazilet(faziletIstanbul).first()
        for (index in listOf(4, 5, 8, 9, 11, 13, 14, 15, 16, 17)) {
            assertNull("index $index boş olmalı", today.times[index])
        }
    }

    @Test
    fun `fazilet hicri tarihi eslestirir`() {
        val days = SourceFetcher.parseFazilet(faziletIstanbul)
        assertEquals("28 Safer 1448", days.first { it.date == "2026-08-11" }.hijri)
    }

    @Test
    fun `fazilet basarisiz yaniti bos doner`() {
        assertTrue(SourceFetcher.parseFazilet("""{"success":false}""").isEmpty())
    }

    @Test
    fun `turktakvim 18 vakti dogru siraya koyar`() {
        val day = SourceFetcher.parseTurktakvim(turktakvimSchonberg, "2026-08-11")!!
        assertEquals("2026-08-11", day.date)
        assertEquals("03:59", day.times[0])
        assertEquals("13:48", day.times[6])
        assertEquals("22:55", day.times[12])
        assertEquals("02:50", day.times[16]) // Seher
        assertEquals("11:06", day.times[17]) // Kıble Sâati
        assertEquals("28 SAFER 1448", day.hijri)
    }

    @Test
    fun `turktakvim VY yanitini reddeder`() {
        val vy = "Longyearbyen;78;13;N;15;38;E;VY;11/08/2026 11:25:00 ;28 SAFER 1448 ;Spitsbergen"
        assertNull(SourceFetcher.parseTurktakvim(vy, "2026-08-11"))
    }

    @Test
    fun `turktakvim eksik yaniti reddeder`() {
        assertNull(SourceFetcher.parseTurktakvim("bir;iki;uc", "2026-08-11"))
        assertNull(SourceFetcher.parseTurktakvim("", "2026-08-11"))
    }

    @Test
    fun `gunler birlestirilirken yenisi eskisinin yerini alir`() {
        val eski = listOf(
            PrayerStore.Day("2026-08-11", PrayerStore.parseTimes("03:59"), "28 SAFER"),
            PrayerStore.Day("2026-08-12", PrayerStore.parseTimes("04:01"), "29 SAFER")
        )
        val encoded = PrayerStore.encodeDays(eski)
        val parsed = PrayerStore.parseDays(encoded)

        assertEquals(2, parsed.size)
        assertEquals("03:59", parsed[0].times[0])
        assertEquals("28 SAFER", parsed[0].hijri)
    }

    @Test
    fun `gun kodlama gidis donusu bozulmaz`() {
        val original = PrayerStore.Day(
            date = "2026-08-11",
            times = PrayerStore.parseTimes(
                "03:59,04:19,06:17,07:11,12:27,13:25,13:48,17:45,18:49,20:12," +
                    "20:56,22:00,22:55,23:12,00:28,01:39,02:50,11:06"
            ),
            hijri = "28 SAFER 1448"
        )
        val restored = PrayerStore.parseDays(PrayerStore.encodeDays(listOf(original))).single()
        assertEquals(original.date, restored.date)
        assertEquals(original.hijri, restored.hijri)
        assertEquals(original.times, restored.times)
    }
}
