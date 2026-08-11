import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../core/calendar_source.dart';
import '../core/prayer.dart';
import '../domain/next_prayer.dart';
import 'models/holy_day.dart';
import 'models/prayer_day.dart';
import 'sources/fazilet_source.dart';
import 'sources/prayer_source.dart';
import 'sources/turktakvim_source.dart';

/// Seçili takvim kaynağı belirli bir târihin vakitlerini veremiyor.
class MonthDownloadUnsupportedException implements Exception {
  MonthDownloadUnsupportedException(this.source);
  final CalendarSource source;

  @override
  String toString() =>
      '${source.displayName} yalnızca dün/bugün/yarını veriyor; '
      'aylık indirme yapılamaz.';
}

/// Bir aylık indirmenin ilerlemesi.
class MonthDownloadProgress {
  const MonthDownloadProgress({
    required this.done,
    required this.total,
    this.failed = 0,
  });

  final int done;
  final int total;
  final int failed;

  double get fraction => total == 0 ? 0 : done / total;
  bool get isComplete => done >= total;
}

/// Vakitlerin kalıcı deposu.
///
/// Uygulama önce yerel veritabanına bakar; orada yoksa ve internet varsa
/// turktakvim'den çeker ve saklar. Bir kere indirilmiş gün bir daha
/// istenmez — hem çevrimdışı çalışsın hem de kaynağa yük binmesin diye.
class PrayerRepository {
  PrayerRepository({Map<CalendarSource, PrayerSource>? sources, Database? database})
      : _sources = sources ??
            {
              CalendarSource.turktakvim: TurktakvimSource(),
              CalendarSource.fazilet: FaziletSource(),
            },
        _db = database;

  final Map<CalendarSource, PrayerSource> _sources;
  Database? _db;

  /// Kaç günlük geçmiş saklanacağı. Kullanıcı yer kaplamasın diye bir aylık
  /// geçmişin yeterli olduğunu söyledi; daha eskisi her açılışta silinir.
  static const int retentionDays = 31;

  PrayerSource _sourceFor(CalendarSource source) =>
      _sources[source] ?? _sources.values.first;

  static const _table = 'prayer_days';
  static const _holyTable = 'holy_days';
  static const _dbName = 'vakitler.db';

  Future<Database> get _database async =>
      _db ??= await openDatabase(
        p.join(await getDatabasesPath(), _dbName),
        version: 2,
        onCreate: (db, _) async {
          final columns =
              Prayer.values.map((p) => 't${p.index} TEXT').join(', ');
          await db.execute('''
            CREATE TABLE $_table (
              city_id INTEGER NOT NULL,
              date    TEXT    NOT NULL,
              hijri   TEXT,
              $columns,
              PRIMARY KEY (city_id, date)
            )
          ''');
          await db.execute(_createHolyTable);
        },
        onUpgrade: (db, from, to) async {
          if (from < 2) await db.execute(_createHolyTable);
        },
      );

  static const _createHolyTable = '''
    CREATE TABLE $_holyTable (
      date  TEXT PRIMARY KEY,
      hijri TEXT,
      name  TEXT
    )
  ''';

  /// Yerel veritabanındaki gün; yoksa `null`. Ağa çıkmaz.
  Future<PrayerDay?> cached(int cityId, DateTime date) async {
    final db = await _database;
    final rows = await db.query(
      _table,
      where: 'city_id = ? AND date = ?',
      whereArgs: [cityId, PrayerDay.dateKey(date)],
      limit: 1,
    );
    return rows.isEmpty ? null : PrayerDay.fromDbRow(rows.first);
  }

  /// Günü döndürür: önce önbellek, yoksa ağdan çekip saklar.
  Future<PrayerDay?> day(
    CalendarSource source,
    int cityId,
    DateTime date,
  ) async {
    final local = await cached(cityId, date);
    if (local != null) return local;

    final fetched = await _sourceFor(source).fetch(cityId: cityId, date: date);
    if (fetched.isEmpty) return null;
    await _store(fetched.map((r) => r.day).toList());

    // Fazilet üç gün birden döndüğü için istenen günü aralarından seçiyoruz;
    // istenen gün gelmediyse (ör. gelecek bir târih) null döner.
    final key = PrayerDay.dateKey(date);
    for (final result in fetched) {
      if (PrayerDay.dateKey(result.day.date) == key) return result.day;
    }
    return null;
  }

  /// Bugünü ağdan tazeler; şehrin saat dilimi farkını da öğrenir.
  ///
  /// Kaynak birden fazla gün döndürüyorsa (Fazilet dün/bugün/yarın veriyor)
  /// hepsi saklanır — kullanıcı her uygulamayı açtığında üç gün tazelenmiş
  /// olur, böylece Fazilet'te de yarının vakitleri elde bulunur.
  Future<({PrayerDay day, String cityName, String region, Duration offset})?>
      refreshToday(CalendarSource source, int cityId) async {
    final now = DateTime.now();
    final fetched = await _sourceFor(source).fetch(cityId: cityId, date: now);
    if (fetched.isEmpty) return null;

    await _store(fetched.map((r) => r.day).toList());

    final todayKey = PrayerDay.dateKey(now);
    final result = fetched.firstWhere(
      (r) => PrayerDay.dateKey(r.day.date) == todayKey,
      orElse: () => fetched.first,
    );

    return (
      day: result.day,
      cityName: result.cityName,
      region: result.region,
      offset: NextPrayerCalculator.cityOffset(
        cityLocalNow: result.cityLocalNow,
        deviceNow: now,
      ),
    );
  }

  /// [month] ayının tamamını indirir (o ayın gün sayısı kadar istek).
  ///
  /// Zaten önbellekte olan günler atlanır. [onProgress] her adımda çağrılır;
  /// tek tek hatalar indirmeyi durdurmaz, sonunda [MonthDownloadProgress.failed]
  /// ile bildirilir.
  Future<MonthDownloadProgress> downloadMonth(
    CalendarSource source,
    int cityId,
    DateTime month, {
    void Function(MonthDownloadProgress)? onProgress,
    Duration gap = const Duration(milliseconds: 150),
  }) async {
    if (!source.supportsArbitraryDate) {
      // Fazilet yalnızca dün/bugün/yarını veriyor; aylık indirme yapılamaz.
      throw MonthDownloadUnsupportedException(source);
    }

    final first = DateTime(month.year, month.month, 1);
    final dayCount = DateTime(month.year, month.month + 1, 0).day;
    final api = _sourceFor(source);

    var done = 0;
    var failed = 0;
    final pending = <PrayerDay>[];

    for (var i = 0; i < dayCount; i++) {
      final date = DateTime(first.year, first.month, first.day + i);
      if (await cached(cityId, date) == null) {
        try {
          final results = await api.fetch(cityId: cityId, date: date);
          pending.addAll(results.map((r) => r.day));
        } on CityNotSupportedException {
          rethrow; // bu şehir için hiçbir gün gelmeyecek, devam etmenin anlamı yok
        } catch (_) {
          failed++;
        }
        // Kaynağa saygı: istekleri arka arkaya yığmıyoruz.
        if (gap > Duration.zero) await Future<void>.delayed(gap);
      }
      done++;
      onProgress?.call(
          MonthDownloadProgress(done: done, total: dayCount, failed: failed));
    }

    if (pending.isNotEmpty) await _store(pending);
    return MonthDownloadProgress(
        done: done, total: dayCount, failed: failed);
  }

  /// Bir ayın önbellekteki günleri (tarih sırasına göre).
  Future<List<PrayerDay>> monthFromCache(int cityId, DateTime month) async {
    final db = await _database;
    final prefix =
        '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}-';
    final rows = await db.query(
      _table,
      where: 'city_id = ? AND date LIKE ?',
      whereArgs: [cityId, '$prefix%'],
      orderBy: 'date ASC',
    );
    return rows.map(PrayerDay.fromDbRow).toList();
  }

  /// [from] târihinden itibaren önbellekteki günler, târih sırasıyla.
  ///
  /// Bildirim ve widget'lara yazılacak pencereyi hazırlar; elde ne kadar veri
  /// varsa o kadar gün yazılır ki uygulama açılmadan da çalışsınlar.
  Future<List<PrayerDay>> upcomingFromCache(
    int cityId,
    DateTime from, {
    int limit = 40,
  }) async {
    final db = await _database;
    final rows = await db.query(
      _table,
      where: 'city_id = ? AND date >= ?',
      whereArgs: [cityId, PrayerDay.dateKey(from)],
      orderBy: 'date ASC',
      limit: limit,
    );
    return rows.map(PrayerDay.fromDbRow).toList();
  }

  /// Bir ayın kaç gününün indirilmiş olduğu.
  Future<int> cachedDayCount(int cityId, DateTime month) async =>
      (await monthFromCache(cityId, month)).length;

  /// Bir ayın tamamı önbellekte mi.
  Future<bool> isMonthComplete(int cityId, DateTime month) async {
    final expected = DateTime(month.year, month.month + 1, 0).day;
    return await cachedDayCount(cityId, month) >= expected;
  }

  /// Ay bitmeden gelecek ayı sessizce indirir.
  ///
  /// Ay sonuna [thresholdDays] gün veya daha az kaldığında devreye girer;
  /// böylece ay değiştiğinde kullanıcı internetsiz olsa bile takvim
  /// kesintiye uğramaz. Başarısız olursa sessizce vazgeçer — bu bir arka
  /// plan kolaylığı, hata gösterilecek bir işlem değil.
  ///
  /// İndirme yapıldıysa (ya da gerek yoksa) `true` döner.
  Future<bool> ensureNextMonth(
    CalendarSource source,
    int cityId, {
    DateTime? now,
    int thresholdDays = 10,
  }) async {
    // Fazilet ileriye dönük veri vermiyor; orada yapacak bir şey yok.
    if (!source.supportsArbitraryDate) return true;

    final today = now ?? DateTime.now();
    final lastDay = DateTime(today.year, today.month + 1, 0).day;
    if (lastDay - today.day > thresholdDays) return true;

    final nextMonth = DateTime(today.year, today.month + 1);
    if (await isMonthComplete(cityId, nextMonth)) return true;

    try {
      final result = await downloadMonth(source, cityId, nextMonth);
      return result.failed == 0;
    } catch (_) {
      return false;
    }
  }

  /// Sıradaki vakit için gereken üç günü (dün/bugün/yarın) önbellekten alır.
  Future<({PrayerDay? yesterday, PrayerDay? today, PrayerDay? tomorrow})>
      window(int cityId, DateTime date) async {
    final base = DateTime(date.year, date.month, date.day);
    return (
      yesterday: await cached(cityId, base.subtract(const Duration(days: 1))),
      today: await cached(cityId, base),
      tomorrow: await cached(cityId, base.add(const Duration(days: 1))),
    );
  }

  /// Seçili şehir dışındaki eski kayıtları temizler.
  Future<void> pruneOtherCities(int keepCityId) async {
    final db = await _database;
    await db.delete(_table, where: 'city_id != ?', whereArgs: [keepCityId]);
  }

  /// [retentionDays] günden eski kayıtları siler.
  ///
  /// Geçmiş vakitler yalnızca "içinde bulunulan vakit" hesabı için gerekli;
  /// aylardan eskisini tutmak yer kaplamaktan başka işe yaramıyor.
  Future<int> pruneOldDays({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final cutoff = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: retentionDays));
    final db = await _database;
    return db.delete(
      _table,
      where: 'date < ?',
      whereArgs: [PrayerDay.dateKey(cutoff)],
    );
  }

  /// Takvim kaynağı değiştiğinde önceki kaynağın indirdiği bütün vakitleri
  /// siler — iki takvim aynı vakti farklı hesapladığı için karışmamalı.
  Future<void> clearAllDays() async {
    final db = await _database;
    await db.delete(_table);
  }

  // --- mübârek günler ---

  /// Saklanmış mübârek günler (verilen yıla âit), târih sırasına göre.
  Future<List<HolyDay>> holyDays(int year) async {
    final db = await _database;
    final rows = await db.query(
      _holyTable,
      where: 'date LIKE ?',
      whereArgs: ['$year-%'],
      orderBy: 'date ASC',
    );
    return rows.map(HolyDay.fromDbRow).toList();
  }

  Future<void> storeHolyDays(List<HolyDay> days) async {
    if (days.isEmpty) return;
    final db = await _database;
    final batch = db.batch();
    for (final day in days) {
      batch.insert(_holyTable, day.toDbRow(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> _store(List<PrayerDay> days) async {
    final db = await _database;
    final batch = db.batch();
    for (final day in days) {
      batch.insert(_table, day.toDbRow(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
    for (final source in _sources.values) {
      source.close();
    }
  }
}
