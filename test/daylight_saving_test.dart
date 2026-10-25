import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/core/prayer.dart';
import 'package:namaz_vakitleri/data/models/prayer_day.dart';

/// Yaz saati geçişleri.
///
/// Saatlerin geri alındığı gün 25 saat sürer. Vakitler gün başına `Duration`
/// eklenerek kurulurken hepsi bir saat erkene kayıyordu: ekranda 13:48 yazan
/// Öğle, geri sayım ve bildirim açısından 12:48 sayılıyordu.
///
/// Dart'ta testler makinenin saat dilimiyle çalışır ve bu zorlanamaz; bu
/// yüzden asıl iddia saat diliminden bağımsız kurulmuştur: çözülen vaktin
/// duvar saati, takvimden gelen "HH:mm" ile aynı olmak zorundadır. Yaz saati
/// uygulayan her makinede geçiş günleri bu iddiayı düşürür.
void main() {
  const times = [
    '03:59', '04:19', '06:17', '07:11', '12:27', '13:25', '13:48', '17:45',
    '18:49', '20:12', '20:56', '22:00', '22:55', '23:12', '00:28', '01:39',
    '02:50', '11:06',
  ];

  PrayerDay dayOn(DateTime date) => PrayerDay(
        cityId: 64814,
        date: date,
        times: times,
        hijriDate: '',
      );

  String clockOf(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  group('yaz saati geçişi', () {
    test('saat geri alınan günde vakitler kaymaz', () {
      final day = dayOn(DateTime(2026, 10, 25));
      final ogle = day.dateTimeOf(Prayer.values[6])!;
      expect(clockOf(ogle), '13:48');
      expect(ogle.day, 25);
    });

    test('saat ileri alınan günde vakitler kaymaz', () {
      final day = dayOn(DateTime(2026, 3, 29));
      expect(clockOf(day.dateTimeOf(Prayer.values[6])!), '13:48');
    });

    test('gece yarısını geçen vakit ertesi güne düşer', () {
      final day = dayOn(DateTime(2026, 10, 25));
      final seher = day.dateTimeOf(Prayer.values[16])!;
      expect(clockOf(seher), '02:50');
      expect(seher.day, 26);
    });

    test('yılın her gününde duvar saati korunur', () {
      // Geçiş günleri hangi güne denk gelirse gelsin yakalansın.
      //
      // İddiâ: çözülen ân, kendi takvim gününde o duvar saatinin tâ kendisi.
      // Saatlerin ileri alındığı gece atlanan bir vakit (ör. 02:50) hiç
      // yaşanmaz; Dart onu geçişin sonuna taşır ve iki taraf da aynı taşımayı
      // yaptığı için eşitlik bozulmaz. Eski hatâda ise vakitler gün başına
      // `Duration` eklenerek kuruluyor, geçiş günlerinde bir saat **geriye**
      // kayıyordu — bu iddia onu düşürür.
      for (var i = 0; i < 365; i++) {
        final date = DateTime(2026, 1, 1).add(Duration(days: i));
        final day = dayOn(DateTime(date.year, date.month, date.day));
        for (final p in Prayer.values) {
          final at = day.dateTimeOf(p);
          if (at == null) continue;
          final raw = times[p.index];
          final duvarSaati = DateTime(
            at.year,
            at.month,
            at.day,
            int.parse(raw.substring(0, 2)),
            int.parse(raw.substring(3)),
          );
          expect(
            at,
            duvarSaati,
            reason: '${day.date} tarihinde ${p.name}: ${clockOf(at)} '
                '(takvimde $raw)',
          );
        }
      }
    });
  });
}
