import '../core/prayer.dart';
import '../data/models/prayer_day.dart';

/// İçinde bulunulan ve sıradaki vakit.
class NextPrayerInfo {
  const NextPrayerInfo({
    required this.next,
    required this.nextAt,
    required this.remaining,
    this.current,
    this.currentAt,
  });

  /// Sıradaki vakit.
  final Prayer next;

  /// Sıradaki vaktin **şehir yerel saatiyle** zamanı.
  final DateTime nextAt;

  /// Sıradaki vakte kalan süre.
  final Duration remaining;

  /// Hâlen içinde bulunulan vakit (varsa).
  final Prayer? current;

  /// İçinde bulunulan vaktin başlangıcı.
  final DateTime? currentAt;

  /// İki vakit arasında ne kadar ilerlendiği (0..1) — halka göstergesi için.
  double get progress {
    if (currentAt == null) return 0;
    final total = nextAt.difference(currentAt!).inSeconds;
    if (total <= 0) return 0;
    final done = total - remaining.inSeconds;
    return (done / total).clamp(0.0, 1.0);
  }
}

class NextPrayerCalculator {
  /// Şehrin saat dilimi ile cihazın saati arasındaki fark.
  ///
  /// API her yanıtta şehrin o andaki yerel saatini verir; cihaz saatiyle farkı
  /// almak şehrin offset'ini verir. Ağ gecikmesinden gelen saniyelik gürültüyü
  /// atmak için en yakın 15 dakikaya yuvarlanır — dünyadaki bütün saat dilimi
  /// offset'leri 15 dakikanın katıdır.
  static Duration cityOffset({
    required DateTime cityLocalNow,
    required DateTime deviceNow,
  }) {
    final diff = cityLocalNow.difference(deviceNow).inSeconds;
    const quarter = 15 * 60;
    final rounded = (diff / quarter).round() * quarter;
    return Duration(seconds: rounded);
  }

  /// Cihaz saatini şehrin yerel saatine çevirir.
  static DateTime toCityTime(DateTime deviceNow, Duration offset) =>
      deviceNow.add(offset);

  /// [candidates] arasından sıradaki vakti bulur.
  ///
  /// [yesterday] ve [tomorrow] verildiğinde gece yarısı çevresindeki geçişler
  /// de doğru çalışır: bir günün Gece Yarısı / Teheccüd / Seher vakitleri
  /// takvim olarak ertesi güne düşer, sabahın erken saatlerinde "içinde
  /// bulunulan vakit" bir önceki günün satırından gelir.
  ///
  /// Hiçbir aday bulunamazsa `null` döner (veri yok ya da hepsi geçmişte).
  static NextPrayerInfo? compute({
    required DateTime cityNow,
    required PrayerDay today,
    PrayerDay? yesterday,
    PrayerDay? tomorrow,
    Set<Prayer>? candidates,
  }) {
    final wanted = (candidates ?? Prayer.values.toSet())
        .where((p) => p.isInChronologicalChain)
        .toSet();
    if (wanted.isEmpty) return null;

    final entries = <(Prayer, DateTime)>[];
    final seen = <String>{};
    for (final day in [yesterday, today, tomorrow]) {
      if (day == null) continue;
      for (final p in wanted) {
        final at = day.dateTimeOf(p);
        if (at == null) continue;
        if (seen.add('${p.index}@${at.millisecondsSinceEpoch}')) {
          entries.add((p, at));
        }
      }
    }
    if (entries.isEmpty) return null;

    entries.sort((a, b) => a.$2.compareTo(b.$2));

    (Prayer, DateTime)? current;
    (Prayer, DateTime)? next;
    for (final e in entries) {
      if (e.$2.isAfter(cityNow)) {
        next = e;
        break;
      }
      current = e;
    }
    if (next == null) return null;

    return NextPrayerInfo(
      next: next.$1,
      nextAt: next.$2,
      remaining: next.$2.difference(cityNow),
      current: current?.$1,
      currentAt: current?.$2,
    );
  }

  /// "05:23:11" / "23:11" biçiminde geri sayım metni.
  ///
  /// Kalan süre **yukarı** yuvarlanır: 9,4 sn "10" değil "10" saniye kala
  /// değil — 9,4 sn kaldıysa ekranda 10 yazar ve tam 1 saniye boyunca öyle
  /// kalır. Aşağı yuvarlansaydı (varsayılan davranış) örnekleme anına göre
  /// aynı sayı iki kez görünüp sonra bir sayı atlanıyordu; sayaç donup
  /// zıplıyor gibi duruyordu.
  static String formatCountdown(Duration d, {bool withSeconds = true}) {
    final total = d.isNegative
        ? Duration.zero
        : Duration(milliseconds: (d.inMilliseconds / 1000).ceil() * 1000);
    final h = total.inHours;
    final m = total.inMinutes.remainder(60);
    final s = total.inSeconds.remainder(60);
    final mm = m.toString().padLeft(2, '0');
    if (!withSeconds) {
      return h > 0 ? '$h:$mm' : '$mm dk';
    }
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }
}
