package com.tunahan.namaz_vakitleri

import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter

/**
 * Vakitleri **Flutter'ı uyandırmadan** çeker.
 *
 * Uygulama günlerce açılmasa da bildirim ve widget'lar çalışsın diye günlük
 * arka plan yenilemesi burada yapılır. Ayrıştırma mantığı Dart tarafındaki
 * `TurktakvimParser` ve `FaziletSource` ile aynı kuralları uygular; ikisi
 * ayrışmasın diye her ikisinin de birim testleri var.
 *
 * Not: `java.time` API'leri core library desugaring ile eski Android
 * sürümlerinde de çalışıyor (bkz. `build.gradle.kts`).
 */
object SourceFetcher {

    private const val TIMEOUT_MS = 20_000

    private const val USER_AGENT =
        "NamazVakitleri/1.1 (Android; arka plan yenilemesi)"

    /** Fazilet'in JSON alan adları → uygulamadaki vakit sırası. */
    private val FAZILET_FIELDS = listOf(
        "imsak" to 0, "sabah" to 1, "gunes" to 2, "israk" to 3,
        "ogle" to 6, "ikindi" to 7, "aksam" to 10, "yatsi" to 12
    )

    /**
     * Bir yenilemenin sonucu: günler ve şehrin cihazla arasındaki saat farkı.
     *
     * Fark da her yenilemede tâzeleniyor, çünkü **sâbit değil**: yaz saati
     * uygulaması ülkeden ülkeye değişiyor. Türkiye 2016'dan beri saatini hiç
     * değiştirmiyor, Avrupa yılda iki kez değiştiriyor. Şehir cihazdan başka
     * bir ülkedeyse, taraflardan biri saatini değiştirdiği anda kayıtlı fark
     * bir saat yanlışa düşüyor ve uygulama açılana kadar öyle kalıyordu.
     */
    data class Fetched(
        val days: List<PrayerStore.Day>,
        /** Çözülemediyse `null`; o zaman kayıtlı fark korunur. */
        val offsetMinutes: Long?
    )

    /**
     * Seçili kaynaktan günleri çeker. Hata durumunda boş sonuç döner —
     * arka plan yenilemesi sessizce başarısız olmalı.
     */
    fun fetch(snapshot: PrayerStore.Snapshot, deviceNow: Long = System.currentTimeMillis()):
        Fetched {
        if (snapshot.cityId <= 0) return Fetched(emptyList(), null)
        return try {
            when (snapshot.sourceId) {
                "fazilet" -> fetchFaziletWithOffset(snapshot.cityId, deviceNow)
                else -> fetchTurktakvimWithOffset(snapshot.cityId, deviceNow)
            }
        } catch (_: Exception) {
            Fetched(emptyList(), null)
        }
    }

    /**
     * Şehrin yerel saati ile cihazınki arasındaki fark, dakika olarak.
     *
     * Ağ gecikmesinden gelen saniyelik gürültüyü atmak için en yakın 15
     * dakikaya yuvarlanır; dünyadaki bütün saat dilimi farkları 15'in
     * katıdır. Dart'taki `NextPrayerCalculator.cityOffset` ile aynı kural.
     */
    internal fun roundedOffsetMinutes(cityNowMillis: Long, deviceNow: Long): Long {
        val diffMinutes = (cityNowMillis - deviceNow).toDouble() / 60_000.0
        return Math.round(diffMinutes / 15.0) * 15L
    }

    // --- Fazilet Takvimi ---

    /**
     * `api/cms/daily` dün/bugün/yarını verir. Saatler UTC'dir; şehrin IANA
     * saat dilimiyle (`bolge_saatdilimi`) yerel saate çevrilir.
     */
    internal fun fetchFazilet(cityId: Int): List<PrayerStore.Day> =
        fetchFaziletWithOffset(cityId, System.currentTimeMillis()).days

    private fun fetchFaziletWithOffset(cityId: Int, deviceNow: Long): Fetched {
        val body = get(
            "https://fazilettakvimi.com/api/cms/daily?districtId=$cityId&lang=1"
        ) ?: return Fetched(emptyList(), null)
        return Fetched(parseFazilet(body), faziletOffsetMinutes(body, deviceNow))
    }

    /**
     * Fazilet yanıtındaki IANA saat diliminden farkı **hesaplar**.
     *
     * Burada tahmin yok: `Europe/Istanbul` gibi bir bölge adı verildiği için
     * o ülkenin o târihteki yaz saati kuralı da biliniyor. Cihazın kendi
     * bölgesiyle farkı her yenilemede yeniden çıkarılıyor.
     */
    internal fun faziletOffsetMinutes(body: String, deviceNow: Long): Long? {
        val zoneName = runCatching { JSONObject(body).optString("bolge_saatdilimi") }
            .getOrNull()?.trim().orEmpty()
        if (zoneName.isEmpty()) return null
        val zone = runCatching { ZoneId.of(zoneName) }.getOrNull() ?: return null

        val instant = Instant.ofEpochMilli(deviceNow)
        val cityOffset = zone.rules.getOffset(instant).totalSeconds
        val deviceOffset = ZoneId.systemDefault().rules.getOffset(instant).totalSeconds
        return (cityOffset - deviceOffset) / 60L
    }

    internal fun parseFazilet(body: String): List<PrayerStore.Day> {
        val root = JSONObject(body)
        if (root.optBoolean("success", true).not()) return emptyList()

        val zone = runCatching { ZoneId.of(root.optString("bolge_saatdilimi")) }
            .getOrElse { ZoneId.systemDefault() }

        val hijriByDate = HashMap<String, String>()
        root.optJSONArray("takvimler")?.let { list ->
            for (i in 0 until list.length()) {
                val item = list.optJSONObject(i) ?: continue
                hijriByDate[item.optString("tarih")] = item.optString("hicri_tarih").trim()
            }
        }

        val days = root.optJSONArray("vakitler") ?: return emptyList()
        val out = ArrayList<PrayerStore.Day>(days.length())

        for (i in 0 until days.length()) {
            val entry = days.optJSONObject(i) ?: continue
            val date = entry.optString("tarih").takeIf { it.length == 10 } ?: continue

            val times = arrayOfNulls<String>(PrayerStore.PRAYER_COUNT)
            var any = false
            for ((field, index) in FAZILET_FIELDS) {
                val local = localTimeOf(entry.optJSONArray(field), zone)
                if (local != null) {
                    times[index] = local
                    any = true
                }
            }
            if (!any) continue

            out.add(
                PrayerStore.Day(
                    date = date,
                    times = times.toList(),
                    hijri = hijriByDate[date].orEmpty()
                )
            )
        }
        return out
    }

    /** `[{"tarih":"2026-08-11T01:05:00Z"}]` → `"04:05"` */
    private fun localTimeOf(array: org.json.JSONArray?, zone: ZoneId): String? {
        val first = array?.optJSONObject(0) ?: return null
        val raw = first.optString("tarih").takeIf { it.isNotEmpty() } ?: return null
        return runCatching {
            ZonedDateTime.ofInstant(Instant.parse(raw), zone)
                .format(DateTimeFormatter.ofPattern("HH:mm"))
        }.getOrNull()
    }

    // --- Türkiye Takvimi ---

    /**
     * `gadget.php` tek bir günü verir, o yüzden bugünden başlayarak birkaç gün
     * çekilir. Uygulama zaten aylık indirme yapabildiği için burada amaç sadece
     * elde veri kalmadığında boşluğu kapatmak.
     */
    internal fun fetchTurktakvim(cityId: Int, deviceNow: Long, dayCount: Int = 3):
        List<PrayerStore.Day> = fetchTurktakvimWithOffset(cityId, deviceNow, dayCount).days

    private fun fetchTurktakvimWithOffset(
        cityId: Int,
        deviceNow: Long,
        dayCount: Int = 3
    ): Fetched {
        val out = ArrayList<PrayerStore.Day>(dayCount)
        var offsetMinutes: Long? = null
        for (offset in 0 until dayCount) {
            val date = PrayerSchedule.dateKeyOf(deviceNow + offset * 86_400_000L)
            val body = get(
                "https://gadget.turktakvim.com/gadget.php" +
                    "?pg=1&sid=$cityId&cityID=$cityId&tarih=$date"
            ) ?: continue
            parseTurktakvim(body, date)?.let(out::add)
            // Fark yalnızca ilk yanıttan alınır; sonraki istekler aynı ânı vermez.
            if (offsetMinutes == null) {
                offsetMinutes = turktakvimOffsetMinutes(body, deviceNow)
            }
            // Kaynağa yük bindirmemek için nefes payı.
            Thread.sleep(200)
        }
        return Fetched(out, offsetMinutes)
    }

    /**
     * turktakvim yanıtındaki "şehrin o andaki yerel saati" alanından farkı
     * çıkarır. (Fazilet'in aksine bölge adı vermiyor, yalnızca saati veriyor.)
     */
    internal fun turktakvimOffsetMinutes(body: String, deviceNow: Long): Long? {
        val raw = body.trim().split(";")
            .map { it.trim() }
            .firstOrNull { LOCAL_NOW.matches(it) } ?: return null
        val local = runCatching { LocalDateTime.parse(raw, LOCAL_NOW_FORMAT) }
            .getOrNull() ?: return null

        // Şehrin duvar saati, cihazın bölgesindeymiş gibi ânâ çevrilir; aradaki
        // fark saat dilimi farkını verir (Dart tarafı da böyle yapıyor).
        val asDevice = local.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
        val minutes = roundedOffsetMinutes(asDevice, deviceNow)
        // 26 saati aşan bir fark saat dilimi değil, bozuk veridir.
        return if (minutes in -26 * 60L..26 * 60L) minutes else null
    }

    /** "11/08/2026 11:25:00" */
    private val LOCAL_NOW = Regex("""\d{2}/\d{2}/\d{4} \d{2}:\d{2}:\d{2}""")

    private val LOCAL_NOW_FORMAT: DateTimeFormatter =
        DateTimeFormatter.ofPattern("dd/MM/uuuu HH:mm:ss")

    /**
     * `Schönberg;46;48;N;7;11;E;03:59;…;11:06;11/08/2026 11:25:00 ;28 SAFER 1448 ;Fribourg`
     *
     * Alan 7..24 vakitler, 26 hicrî târih. Kutup şehirlerinde 7. alan `VY`
     * gelir; o zaman vakit yoktur.
     */
    internal fun parseTurktakvim(body: String, date: String): PrayerStore.Day? {
        val fields = body.trim().split(";")
        if (fields.size < 25) return null
        if (fields[7].trim().equals("VY", ignoreCase = true)) return null

        val times = arrayOfNulls<String>(PrayerStore.PRAYER_COUNT)
        var any = false
        for (index in 0 until PrayerStore.PRAYER_COUNT) {
            val raw = fields.getOrNull(index + 7)?.trim() ?: continue
            if (raw.length == 5 && raw[2] == ':' && PrayerSchedule.minutesOf(raw) != null) {
                times[index] = raw
                any = true
            }
        }
        if (!any) return null

        val hijri = fields.getOrNull(26)?.trim()?.replace(Regex("\\s+"), " ").orEmpty()
        return PrayerStore.Day(date = date, times = times.toList(), hijri = hijri)
    }

    // --- ortak ---

    private fun get(url: String): String? {
        var connection: HttpURLConnection? = null
        return try {
            connection = (URL(url).openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = TIMEOUT_MS
                readTimeout = TIMEOUT_MS
                setRequestProperty("User-Agent", USER_AGENT)
                setRequestProperty("Accept", "application/json, text/plain, */*")
            }
            if (connection.responseCode != 200) return null
            connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
        } catch (_: Exception) {
            null
        } finally {
            connection?.disconnect()
        }
    }
}
