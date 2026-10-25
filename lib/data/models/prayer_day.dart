import '../../core/prayer.dart';

/// Bir şehrin bir günlük vakit takımı.
///
/// Saatler daima **şehrin yerel saatiyle** tutulur (API böyle veriyor).
/// Cihazın saat dilimi farklıysa geri sayım ve alarmlar
/// [PrayerFetchResult.cityLocalNow] üzerinden hesaplanan offset ile düzeltilir.
class PrayerDay {
  PrayerDay({
    required this.cityId,
    required this.date,
    required this.times,
    required this.hijriDate,
  });

  final int cityId;

  /// Vakitlerin âit olduğu takvim günü (saat bileşeni yok).
  final DateTime date;

  /// [Prayer.index] ile indislenmiş "HH:mm" dizisi. Hesaplanamayan
  /// vakitler için `null`.
  final List<String?> times;

  /// "28 SAFER 1448" gibi normalize edilmiş hicrî târih.
  final String hijriDate;

  String? timeOf(Prayer p) => times[p.index];

  /// Vaktin şehir yerel saatiyle tam zamanı.
  ///
  /// Kronolojik zincirdeki (bkz. [Prayer.isInChronologicalChain]) vakitler
  /// sırayla ilerler; bir vakit kendinden öncekinden küçükse gece yarısını
  /// geçmiş demektir ve ertesi güne taşınır — Gece Yarısı Vakti, Teheccüd ve
  /// Seher tipik olarak böyledir. Kıble Sâati zincire girmez, günün içindedir.
  DateTime? dateTimeOf(Prayer p) => _resolved[p.index];

  late final List<DateTime?> _resolved = _resolve();

  List<DateTime?> _resolve() {
    final out = List<DateTime?>.filled(Prayer.values.length, null);
    var dayOffset = 0;
    var previousMinutes = -1;

    for (final p in Prayer.values) {
      final raw = times[p.index];
      if (raw == null) continue;
      final minutes = _toMinutes(raw);
      if (minutes == null) continue;

      if (!p.isInChronologicalChain) {
        // Kıble Sâati: her zaman günün kendi içinde.
        out[p.index] = _at(0, minutes);
        continue;
      }

      if (previousMinutes >= 0 && minutes < previousMinutes) dayOffset++;
      previousMinutes = minutes;
      out[p.index] = _at(dayOffset, minutes);
    }
    return out;
  }

  /// Vakti takvim alanlarından kurar: gün + "HH:mm".
  ///
  /// `date.add(Duration(...))` **kullanılmıyor**: `Duration` mutlak süredir,
  /// yaz saati biten gün 25 saat sürdüğü için gece yarısına 828 dakika eklemek
  /// 13:48'i değil 12:48'i veriyordu — bütün vakitler bir saat erkene kayıyor
  /// ve "vakit girdi" bildirimi bir saat önce çıkıyordu. Alanlardan kurulan
  /// `DateTime` duvar saatidir; Dart geçişi kendisi çözer.
  DateTime _at(int dayOffset, int minutes) => DateTime(
        date.year,
        date.month,
        date.day + dayOffset,
        minutes ~/ 60,
        minutes % 60,
      );

  static int? _toMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  /// Hiçbir vakit hesaplanamamışsa (aşırı kuzey enlemler — API `VY` döner).
  bool get isUnavailable => times.every((t) => t == null);

  Map<String, Object?> toDbRow() => <String, Object?>{
        'city_id': cityId,
        'date': _dateKey(date),
        'hijri': hijriDate,
        for (final p in Prayer.values) 't${p.index}': times[p.index],
      };

  static PrayerDay fromDbRow(Map<String, Object?> row) => PrayerDay(
        cityId: row['city_id']! as int,
        date: DateTime.parse(row['date']! as String),
        hijriDate: (row['hijri'] as String?) ?? '',
        times: [
          for (final p in Prayer.values) row['t${p.index}'] as String?,
        ],
      );

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String dateKey(DateTime d) => _dateKey(d);
}

/// API'den dönen bir günlük yanıtın tamamı — vakitlerin yanında şehir
/// künyesi ve şehrin o andaki yerel saati de gelir.
class PrayerFetchResult {
  const PrayerFetchResult({
    required this.day,
    required this.cityName,
    required this.region,
    required this.latitude,
    required this.longitude,
    required this.cityLocalNow,
  });

  final PrayerDay day;
  final String cityName;
  final String region;
  final double latitude;
  final double longitude;

  /// Şehrin yanıt ânındaki yerel saati. Cihaz saatiyle farkı, şehrin saat
  /// dilimi offset'ini verir.
  final DateTime cityLocalNow;

  String get displayName =>
      region.isEmpty || region == cityName ? cityName : '$cityName - $region';
}
