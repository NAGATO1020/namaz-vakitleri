package com.tunahan.namaz_vakitleri

import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant
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
     * Seçili kaynaktan günleri çeker. Hata durumunda boş liste döner —
     * arka plan yenilemesi sessizce başarısız olmalı.
     */
    fun fetch(snapshot: PrayerStore.Snapshot, deviceNow: Long = System.currentTimeMillis()):
        List<PrayerStore.Day> {
        if (snapshot.cityId <= 0) return emptyList()
        return try {
            when (snapshot.sourceId) {
                "fazilet" -> fetchFazilet(snapshot.cityId)
                else -> fetchTurktakvim(snapshot.cityId, deviceNow)
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    // --- Fazilet Takvimi ---

    /**
     * `api/cms/daily` dün/bugün/yarını verir. Saatler UTC'dir; şehrin IANA
     * saat dilimiyle (`bolge_saatdilimi`) yerel saate çevrilir.
     */
    internal fun fetchFazilet(cityId: Int): List<PrayerStore.Day> {
        val body = get(
            "https://fazilettakvimi.com/api/cms/daily?districtId=$cityId&lang=1"
        ) ?: return emptyList()
        return parseFazilet(body)
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
        List<PrayerStore.Day> {
        val out = ArrayList<PrayerStore.Day>(dayCount)
        for (offset in 0 until dayCount) {
            val date = PrayerSchedule.dateKeyOf(deviceNow + offset * 86_400_000L)
            val body = get(
                "https://gadget.turktakvim.com/gadget.php" +
                    "?pg=1&sid=$cityId&cityID=$cityId&tarih=$date"
            ) ?: continue
            parseTurktakvim(body, date)?.let(out::add)
            // Kaynağa yük bindirmemek için nefes payı.
            Thread.sleep(200)
        }
        return out
    }

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
