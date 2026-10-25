package com.tunahan.namaz_vakitleri

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.TimeZone

/**
 * Şehir ile cihaz arasındaki saat farkının tâzelenmesi.
 *
 * Fark sâbit değil: yaz saatini kimi ülke uyguluyor kimi uygulamıyor, uygulayan
 * ülkeler de aynı günde geçmiyor. Türkiye 2016'dan beri saatini hiç
 * değiştirmiyor, İsviçre yılda iki kez değiştiriyor — yâni İstanbul'u seçmiş
 * bir İsviçre telefonunda fark yazın 1 saat, kışın 2 saat. Kayıtlı farkın
 * eskimesi geri sayımı ve alarmları bir saat kaydırıyordu.
 */
class CityOffsetTest {

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

    private fun instantAt(month: Int, day: Int, hour: Int): Long =
        ZonedDateTime.of(2026, month, day, hour, 0, 0, 0, zurich).toInstant().toEpochMilli()

    private val faziletIstanbul =
        """{"success":true,"bolge_adi":"İstanbul","bolge_saatdilimi":"Europe/Istanbul"}"""

    private val turktakvimSchonberg =
        "Schönberg;46;48;N;7;11;E;03:59;04:19;06:17;07:11;12:27;13:25;13:48;" +
            "17:45;18:49;20:12;20:56;22:00;22:55;23:12;00:28;01:39;02:50;11:06;" +
            "11/08/2026 11:25:00 ;28  SAFER  1448 ;Fribourg"

    @Test
    fun `fazilet yazin istanbul farki bir saat`() {
        // Zürih UTC+2 (yaz saati), İstanbul UTC+3.
        assertEquals(
            60L,
            SourceFetcher.faziletOffsetMinutes(faziletIstanbul, instantAt(8, 11, 12))
        )
    }

    @Test
    fun `fazilet kisin istanbul farki iki saat`() {
        // Zürih UTC+1 (kış saati), İstanbul yine UTC+3 — fark değişti.
        assertEquals(
            120L,
            SourceFetcher.faziletOffsetMinutes(faziletIstanbul, instantAt(12, 11, 12))
        )
    }

    @Test
    fun `fazilet saat dilimi yoksa fark cozulmez`() {
        assertNull(SourceFetcher.faziletOffsetMinutes("""{"success":true}""", instantAt(8, 11, 12)))
        assertNull(SourceFetcher.faziletOffsetMinutes("bozuk", instantAt(8, 11, 12)))
    }

    @Test
    fun `turktakvim ayni saat diliminde fark sifir`() {
        // Yanıt "11/08/2026 11:25:00" diyor; cihaz da o an 11:25'te.
        assertEquals(
            0L,
            SourceFetcher.turktakvimOffsetMinutes(
                turktakvimSchonberg,
                ZonedDateTime.of(2026, 8, 11, 11, 25, 0, 0, zurich).toInstant().toEpochMilli()
            )
        )
    }

    @Test
    fun `turktakvim farkli saat diliminde fark cikarilir`() {
        // Cihaz 09:25'teyken şehir 11:25 diyorsa fark +2 saat.
        assertEquals(
            120L,
            SourceFetcher.turktakvimOffsetMinutes(
                turktakvimSchonberg,
                ZonedDateTime.of(2026, 8, 11, 9, 25, 0, 0, zurich).toInstant().toEpochMilli()
            )
        )
    }

    @Test
    fun `turktakvim ag gecikmesi farki bozmaz`() {
        // 40 saniyelik gecikme en yakın 15 dakikaya yuvarlanıp yutulur.
        assertEquals(
            0L,
            SourceFetcher.turktakvimOffsetMinutes(
                turktakvimSchonberg,
                ZonedDateTime.of(2026, 8, 11, 11, 24, 20, 0, zurich).toInstant().toEpochMilli()
            )
        )
    }

    @Test
    fun `turktakvim saat alani yoksa fark cozulmez`() {
        assertNull(SourceFetcher.turktakvimOffsetMinutes("bir;iki;uc", instantAt(8, 11, 12)))
    }

    @Test
    fun `sacma buyuklukteki fark reddedilir`() {
        // Bozuk veri saat dilimi diye kabul edilmemeli.
        assertNull(
            SourceFetcher.turktakvimOffsetMinutes(
                turktakvimSchonberg,
                ZonedDateTime.of(2026, 9, 11, 11, 25, 0, 0, zurich).toInstant().toEpochMilli()
            )
        )
    }

    @Test
    fun `yuvarlama en yakin ceyrek saate`() {
        assertEquals(0L, SourceFetcher.roundedOffsetMinutes(0L, 0L))
        assertEquals(60L, SourceFetcher.roundedOffsetMinutes(61 * 60_000L, 0L))
        assertEquals(-60L, SourceFetcher.roundedOffsetMinutes(0L, 59 * 60_000L))
        // Nepal UTC+5:45 gibi çeyreklik farklar korunur.
        assertEquals(345L, SourceFetcher.roundedOffsetMinutes(345 * 60_000L, 0L))
    }
}
