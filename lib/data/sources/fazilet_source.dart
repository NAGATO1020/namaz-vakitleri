import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../core/calendar_source.dart';
import '../../core/prayer.dart';
import '../models/prayer_day.dart';
import 'prayer_source.dart';

/// Fazilet Takvimi (fazilettakvimi.com) kaynağı.
///
/// Uç nokta:
/// ```
/// GET https://fazilettakvimi.com/api/cms/daily?districtId={cityId}&lang=1
/// ```
///
/// Yanıt **dün, bugün ve yarını** verir; belirli bir târih istenemez
/// (`date`/`tarih` parametreleri yok sayılıyor). Bu yüzden Fazilet'te
/// "bir aylık indirme" yapılamaz; uygulama her açılışta bu üç günü tazeler.
///
/// Vakitler **UTC** olarak gelir (`2026-08-11T01:05:00Z`); şehrin yerel
/// saatine çevirmek için yanıttaki IANA saat dilimi (`bolge_saatdilimi`,
/// ör. `Europe/Istanbul`) kullanılır.
///
/// Kaynak 8 vakit veriyor: İmsak, Sabah, Güneş, İşrak, Öğle, İkindi, Akşam,
/// Yatsı. Diğer on vakit (Dahve-i Kübrâ, Kerâhet, Asr-ı Sânî, İsfirâr-ı Şems,
/// İştibâk-i Nücûm, İşâ-i Sânî, Gece Yarısı, Teheccüd, Seher, Kıble Sâati)
/// bu takvimde yok.
class FaziletSource implements PrayerSource {
  FaziletSource({http.Client? client, this.timeout = const Duration(seconds: 20)})
      : _client = client ?? http.Client() {
    _ensureTimezones();
  }

  static const String base = 'https://fazilettakvimi.com/api/cms';

  static const String userAgent =
      'NamazVakitleri/1.0 (Android; fazilettakvimi.com verisi)';

  /// JSON anahtarı → uygulamadaki vakit.
  static const Map<String, Prayer> fieldToPrayer = {
    'imsak': Prayer.imsak,
    'sabah': Prayer.sabah,
    'gunes': Prayer.gunes,
    'israk': Prayer.israk,
    'ogle': Prayer.ogle,
    'ikindi': Prayer.ikindi,
    'aksam': Prayer.aksam,
    'yatsi': Prayer.yatsi,
  };

  final http.Client _client;
  final Duration timeout;

  static bool _timezonesReady = false;

  static void _ensureTimezones() {
    if (_timezonesReady) return;
    tzdata.initializeTimeZones();
    _timezonesReady = true;
  }

  @override
  CalendarSource get source => CalendarSource.fazilet;

  @override
  Future<List<PrayerFetchResult>> fetch({
    required int cityId,
    DateTime? date,
  }) async {
    // `date` bilerek yok sayılıyor: uç nokta her hâlükârda üç günü döndürüyor.
    final uri = Uri.parse('$base/daily').replace(queryParameters: {
      'districtId': '$cityId',
      'lang': '1',
    });

    final body = await _get(uri);
    return parse(raw: body, cityId: cityId);
  }

  /// Yanıtı çözer. Test edilebilmesi için ağdan ayrı tutuldu.
  static List<PrayerFetchResult> parse({
    required String raw,
    required int cityId,
  }) {
    _ensureTimezones();

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      throw PrayerNetworkException('Fazilet yanıtı çözülemedi: ${e.message}');
    }
    if (decoded is! Map<String, Object?>) {
      throw PrayerNetworkException('Fazilet yanıtı beklenen biçimde değil');
    }
    if (decoded['success'] == false) {
      throw CityNotSupportedException(cityId, 'sunucu success=false döndü');
    }

    final cityName = (decoded['bolge_adi'] as String? ?? '').trim();
    final zoneName = (decoded['bolge_saatdilimi'] as String? ?? '').trim();
    final location = _location(zoneName);

    final hijriByDate = <String, String>{
      for (final entry in (decoded['takvimler'] as List? ?? const []))
        if (entry is Map && entry['tarih'] is String)
          entry['tarih'] as String: (entry['hicri_tarih'] as String? ?? '').trim(),
    };

    final days = decoded['vakitler'] as List? ?? const [];
    if (days.isEmpty) {
      throw CityNotSupportedException(cityId, 'vakit listesi boş');
    }

    final now = DateTime.now();
    final results = <PrayerFetchResult>[];

    for (final entry in days) {
      if (entry is! Map) continue;
      final dateKey = entry['tarih'] as String?;
      if (dateKey == null) continue;
      final date = DateTime.tryParse(dateKey);
      if (date == null) continue;

      final times = List<String?>.filled(Prayer.values.length, null);
      var any = false;
      fieldToPrayer.forEach((field, prayer) {
        final local = _localTimeOf(entry[field], location);
        if (local != null) {
          times[prayer.index] = local;
          any = true;
        }
      });
      if (!any) continue;

      results.add(PrayerFetchResult(
        day: PrayerDay(
          cityId: cityId,
          date: DateTime(date.year, date.month, date.day),
          times: times,
          hijriDate: hijriByDate[dateKey] ?? '',
        ),
        cityName: cityName,
        region: '',
        latitude: 0,
        longitude: 0,
        cityLocalNow: _nowIn(location, now),
      ));
    }

    if (results.isEmpty) {
      throw CityNotSupportedException(cityId, 'hiçbir gün çözülemedi');
    }
    return results;
  }

  /// `[{"tarih":"2026-08-11T01:05:00Z","is_takdiri":false}]` → `"04:05"`
  ///
  /// Boş dizi gelen vakitler (bâzı şehirlerde İşrak) atlanır.
  static String? _localTimeOf(Object? value, tz.Location location) {
    if (value is! List || value.isEmpty) return null;
    final first = value.first;
    if (first is! Map) return null;
    final raw = first['tarih'];
    if (raw is! String) return null;

    final utc = DateTime.tryParse(raw);
    if (utc == null) return null;
    final local = tz.TZDateTime.from(utc.toUtc(), location);
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  static DateTime _nowIn(tz.Location location, DateTime deviceNow) {
    final local = tz.TZDateTime.from(deviceNow.toUtc(), location);
    return DateTime(local.year, local.month, local.day, local.hour,
        local.minute, local.second);
  }

  /// Bilinmeyen saat dilimi gelirse cihazınkine düşülür — vakitler yine
  /// gösterilir, sadece başka bir saat dilimindeyken kayma olabilir.
  static tz.Location _location(String name) {
    if (name.isEmpty) return tz.local;
    try {
      return tz.getLocation(name);
    } catch (_) {
      return tz.local;
    }
  }

  Future<String> _get(Uri uri) async {
    try {
      final response = await _client
          .get(uri, headers: const {
            'User-Agent': userAgent,
            'Accept': 'application/json',
          })
          .timeout(timeout);
      if (response.statusCode == 404) {
        throw CityNotSupportedException(0, 'şehir bulunamadı');
      }
      if (response.statusCode != 200) {
        throw PrayerNetworkException(
            'Fazilet sunucusu ${response.statusCode} döndü');
      }
      return utf8.decode(response.bodyBytes, allowMalformed: true);
    } on TimeoutException {
      throw PrayerNetworkException('Zaman aşımı: $uri');
    } on http.ClientException catch (e) {
      throw PrayerNetworkException('Bağlantı hatası: ${e.message}');
    }
  }

  @override
  void close() => _client.close();
}
