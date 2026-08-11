import '../core/prayer.dart';
import 'models/prayer_day.dart';

/// `gadget.php?pg=1` yanıtını ayrıştırır.
///
/// Yanıt tek satırdır, alanlar `;` ile ayrılmıştır:
///
/// ```
/// Schönberg;46;48;N;7;11;E;03:59;04:19;...;11:06;11/08/2026 11:25:00 ;28  SAFER  1448 ;Fribourg
/// │         └── enlem ──┘ └── boylam ┘ └── 18 vakit (7..24) ──┘ │             │        └ il
/// └ şehir                                                       │             └ hicrî târih
///                                          şehrin o andaki yerel saati ┘
/// ```
///
/// Aşırı kuzey enlemlerde vakitler hesaplanamaz; o durumda 7. alan `VY` olur ve
/// sonraki alanlar bir kayar (gadget.js'teki `veri_ayir[7] == "VY"` dalı).
class TurktakvimParseException implements Exception {
  TurktakvimParseException(this.message, [this.raw]);
  final String message;
  final String? raw;

  @override
  String toString() =>
      'TurktakvimParseException: $message${raw == null ? '' : '\n  yanıt: $raw'}';
}

class TurktakvimParser {
  /// [raw] yanıtını, vakitlerin âit olduğu [date] ile birlikte çözer.
  static PrayerFetchResult parse({
    required String raw,
    required int cityId,
    required DateTime date,
  }) {
    final line = raw.trim();
    if (line.isEmpty) {
      throw TurktakvimParseException('Boş yanıt');
    }
    final f = line.split(';');
    if (f.length < 9) {
      throw TurktakvimParseException('Beklenenden az alan (${f.length})', line);
    }

    final cityName = f[0].trim();
    final unavailable = f[7].trim().toUpperCase() == 'VY';

    // VY yanıtında vakit alanları düşer ve kalan alanların yeri kayar; hangi
    // indise kaydığı sürümden sürüme değiştiği için (gadget.js iki farklı yer
    // okuyor) alanları biçimlerinden tanıyoruz.
    final String localNowRaw;
    final String hijriRaw;
    final String region;
    if (unavailable) {
      localNowRaw = f.firstWhere(_looksLikeDateTime, orElse: () => '');
      hijriRaw = f.firstWhere(_looksLikeHijri, orElse: () => '');
      region = f.last.trim();
    } else {
      localNowRaw = f.length > 25 ? f[25] : '';
      hijriRaw = f.length > 26 ? f[26] : '';
      region = f.length > 27 ? f[27] : '';
    }

    final times = List<String?>.filled(Prayer.values.length, null);
    if (!unavailable) {
      if (f.length < 25) {
        throw TurktakvimParseException(
            'Vakit alanları eksik (${f.length})', line);
      }
      for (final p in Prayer.values) {
        times[p.index] = _cleanTime(f[p.apiIndex]);
      }
    }

    final day = PrayerDay(
      cityId: cityId,
      date: DateTime(date.year, date.month, date.day),
      times: times,
      hijriDate: _cleanHijri(hijriRaw),
    );

    return PrayerFetchResult(
      day: day,
      cityName: cityName,
      region: region.trim(),
      latitude: _coordinate(f[1], f[2], f[3]),
      longitude: _coordinate(f[4], f[5], f[6]),
      cityLocalNow: _parseCityLocalNow(localNowRaw) ?? DateTime.now(),
    );
  }

  /// "03:59" → "03:59"; boş/bozuk değerler → null.
  static String? _cleanTime(String value) {
    final v = value.trim();
    if (v.length != 5 || v[2] != ':') return null;
    final h = int.tryParse(v.substring(0, 2));
    final m = int.tryParse(v.substring(3));
    if (h == null || m == null || h > 23 || m > 59) return null;
    return v;
  }

  /// "28  SAFER  1448 " → "28 SAFER 1448"
  static String _cleanHijri(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');

  static final RegExp _dateTimeRe = RegExp(r'(\d{1,2})[/.](\d{1,2})[/.](\d{4})\s+'
      r'(\d{1,2}):(\d{2})(?::(\d{2}))?');

  /// "28  SAFER  1448" gibi görünen alan.
  static final RegExp _hijriRe = RegExp(r'^\s*\d{1,2}\s+\D{3,}\s+\d{4}\s*$');

  static bool _looksLikeDateTime(String v) => _dateTimeRe.hasMatch(v);

  static bool _looksLikeHijri(String v) => _hijriRe.hasMatch(v);

  /// "11/08/2026 11:25:00 " → DateTime(2026, 8, 11, 11, 25, 0)
  static DateTime? _parseCityLocalNow(String value) {
    final m = _dateTimeRe.firstMatch(value.trim());
    if (m == null) return null;
    return DateTime(
      int.parse(m.group(3)!),
      int.parse(m.group(2)!),
      int.parse(m.group(1)!),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
      int.parse(m.group(6) ?? '0'),
    );
  }

  /// Derece + dakika + yön → ondalık derece. Güney/Batı negatif.
  static double _coordinate(String deg, String min, String dir) {
    final d = double.tryParse(deg.trim()) ?? 0;
    final m = double.tryParse(min.trim()) ?? 0;
    final value = d + m / 60.0;
    final sign = const {'S', 'W', 'G', 'B'}.contains(dir.trim().toUpperCase())
        ? -1
        : 1;
    return value * sign;
  }
}
