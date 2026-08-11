import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/data/holy_days_repository.dart';
import 'package:namaz_vakitleri/data/models/holy_day.dart';

/// turktakvim'in `yillikhicri.php` sayfasından alınmış gerçek satırlar.
const _html = '''
<table>
<tr class="normal"><td>14-01-2026</td><td>25  RECEB  1447</td><td></td></tr>
<tr class="active"><td>15-01-2026</td><td>26  RECEB  1447</td><td>Mi'râc Kandili Gecesi</td></tr>
<tr class="normal"><td>16-01-2026</td><td>27  RECEB  1447</td><td></td></tr>
<tr class="active"><td>02-02-2026</td><td>14  ŞA'BÂN  1447</td><td>Ber&acirc;t Kandili Gecesi</td></tr>
<tr class="active"><td>19-02-2026</td><td>1  RAMEZÂN  1447</td><td>Ramez&acirc;n-ı şer&icirc;f'in başlangıcı</td></tr>
<tr class="active"><td>16-03-2026</td><td>26  RAMEZÂN  1447</td><td>Kadr Gecesi</td></tr>
<tr class="active"><td>20-03-2026</td><td>1  ŞEVVÂL  1447</td><td>Ramezân-ı şerîf bayramının 1. Günü</td></tr>
<tr class="active"><td>27-05-2026</td><td>10  ZİL-HİCCE  1447</td><td>Kurban Bayramı 1. Günü</td></tr>
<tr class="active"><td>25-06-2026</td><td>10  MUHARREM  1448</td><td>Aşûre Günü</td></tr>
<tr class="active"><td>24-08-2026</td><td>11  REBÎ'UL-EVVEL  1448</td><td>Mevlid Kandili Gecesi</td></tr>
</table>
''';

void main() {
  group('HolyDaysRepository.parse', () {
    final days = HolyDaysRepository.parse(_html);

    test('yalnızca mübârek gün satırlarını alır', () {
      // 10 satırdan 3'ünün üçüncü hücresi boş; onlar atlanmalı.
      expect(days.length, 8);
    });

    test('târih ve ad doğru ayrıştırılır', () {
      expect(days.first.date, DateTime(2026, 1, 15));
      expect(days.first.nameTr, "Mi'râc Kandili Gecesi");
      expect(days.first.hijri, '26 RECEB 1447');
    });

    test('HTML varlıkları çözülür', () {
      final berat = days[1];
      expect(berat.nameTr, 'Berât Kandili Gecesi');
      final ramazan = days[2];
      expect(ramazan.nameTr, "Ramezân-ı şerîf'in başlangıcı");
    });

    test('kandil geceleri sitedeki günde kalır', () {
      // Mi'râc 27 Receb'de ama gece 26 Receb akşamı başlar; turktakvim bunu
      // zaten 26 Receb'e yazıyor, biz kaydırmıyoruz.
      expect(days.first.hijri, startsWith('26 RECEB'));
    });
  });

  group('HolyDay adlandırma', () {
    HolyDay named(String name) =>
        HolyDay(date: DateTime(2026, 1, 1), hijri: '', nameTr: name);

    test('Türkçe adlar siteden geldiği gibi kalır', () {
      expect(named('Kadr Gecesi').localizedName('tr'), 'Kadr Gecesi');
      expect(named('Terviye Günü').localizedName('tr'), 'Terviye Günü');
    });

    test('İngilizce karşılıkları var', () {
      expect(named('Kadr Gecesi').localizedName('en'), 'Night of Qadr');
      expect(named('Aşûre Günü').localizedName('en'), 'Day of Ashura');
      expect(named('Hicrî Yılbaşı').localizedName('en'), 'Hijri New Year');
    });

    test('numaralı bayram günleri İngilizceye çevrilir', () {
      expect(
        named('Ramezân-ı şerîf bayramının 2. Günü').localizedName('en'),
        'Eid al-Fitr, day 2',
      );
      expect(
        named('Kurban Bayramı 3. Günü').localizedName('en'),
        'Eid al-Adha, day 3',
      );
    });

    test('bilinmeyen ad Türkçe hâliyle kalır', () {
      // Site yeni bir gün eklerse yanlış çevirmektense aynen göstermek doğru.
      expect(named('Bilinmeyen Gün').localizedName('en'), 'Bilinmeyen Gün');
    });
  });

  group('HolyDayLookup', () {
    final days = HolyDaysRepository.parse(_html);

    test('belirli bir güne düşen mübârek günü bulur', () {
      expect(days.on(DateTime(2026, 1, 15))?.nameTr, "Mi'râc Kandili Gecesi");
      expect(days.on(DateTime(2026, 1, 16)), isNull);
    });

    test('yaklaşan günleri sırayla verir', () {
      final upcoming = days.upcoming(DateTime(2026, 3, 1), count: 2);
      expect(upcoming.map((d) => d.date), [
        DateTime(2026, 3, 16),
        DateTime(2026, 3, 20),
      ]);
    });

    test('geçmiş günler yaklaşanlara girmez', () {
      final upcoming = days.upcoming(DateTime(2026, 12, 31));
      expect(upcoming, isEmpty);
    });

    test('bugün mübârek günse yaklaşanların başında gelir', () {
      final upcoming = days.upcoming(DateTime(2026, 1, 15), count: 1);
      expect(upcoming.single.date, DateTime(2026, 1, 15));
    });
  });
}
