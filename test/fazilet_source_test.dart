import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/core/calendar_source.dart';
import 'package:namaz_vakitleri/core/prayer.dart';
import 'package:namaz_vakitleri/data/sources/fazilet_source.dart';
import 'package:namaz_vakitleri/data/sources/prayer_source.dart';

/// fazilettakvimi.com/api/cms/daily?districtId=31 yanıtından kısaltılmış,
/// yapısı birebir korunmuş gerçek veri (İstanbul, Ağustos 2026).
const _istanbul = '''
{"success":true,"bolge_adi":"İstanbul","bolge_saatdilimi":"Europe/Istanbul",
"form":{"ulke_id":1,"sehir_id":31,"ilce_id":null},
"takvimler":[
 {"tarih":"2026-08-10","hicri_tarih":"27 Safer 1448","rumi_tarih":"28 Temmuz 1442"},
 {"tarih":"2026-08-11","hicri_tarih":"28 Safer 1448","rumi_tarih":"29 Temmuz 1442"},
 {"tarih":"2026-08-12","hicri_tarih":"29 Safer 1448","rumi_tarih":"30 Temmuz 1442"}],
"vakitler":[
 {"tarih":"2026-08-10","imsak":[{"tarih":"2026-08-10T01:04:00Z","is_takdiri":false}],
  "israk":[],"sabah":[{"tarih":"2026-08-10T01:24:00Z","is_takdiri":false}],
  "gunes":[{"tarih":"2026-08-10T03:00:00Z","is_takdiri":false}],
  "ogle":[{"tarih":"2026-08-10T10:20:00Z","is_takdiri":false}],
  "ikindi":[{"tarih":"2026-08-10T14:12:00Z","is_takdiri":false}],
  "aksam":[{"tarih":"2026-08-10T17:18:00Z","is_takdiri":false}],
  "yatsi":[{"tarih":"2026-08-10T19:00:00Z","is_takdiri":false}]},
 {"tarih":"2026-08-11","imsak":[{"tarih":"2026-08-11T01:05:00Z","is_takdiri":false}],
  "israk":[],"sabah":[{"tarih":"2026-08-11T01:25:00Z","is_takdiri":false}],
  "gunes":[{"tarih":"2026-08-11T03:01:00Z","is_takdiri":false}],
  "ogle":[{"tarih":"2026-08-11T10:19:00Z","is_takdiri":false}],
  "ikindi":[{"tarih":"2026-08-11T14:11:00Z","is_takdiri":false}],
  "aksam":[{"tarih":"2026-08-11T17:17:00Z","is_takdiri":false}],
  "yatsi":[{"tarih":"2026-08-11T18:58:00Z","is_takdiri":false}]},
 {"tarih":"2026-08-12","imsak":[{"tarih":"2026-08-12T01:07:00Z","is_takdiri":false}],
  "israk":[{"tarih":"2026-08-12T03:52:00Z","is_takdiri":false}],
  "sabah":[{"tarih":"2026-08-12T01:27:00Z","is_takdiri":false}],
  "gunes":[{"tarih":"2026-08-12T03:02:00Z","is_takdiri":false}],
  "ogle":[{"tarih":"2026-08-12T10:19:00Z","is_takdiri":false}],
  "ikindi":[{"tarih":"2026-08-12T14:10:00Z","is_takdiri":false}],
  "aksam":[{"tarih":"2026-08-12T17:16:00Z","is_takdiri":false}],
  "yatsi":[{"tarih":"2026-08-12T18:56:00Z","is_takdiri":false}]}]}
''';

void main() {
  group('FaziletSource.parse', () {
    final days = FaziletSource.parse(raw: _istanbul, cityId: 31);

    test('üç gün birden döner', () {
      // Uç nokta dün/bugün/yarını veriyor; târih parametresi yok sayılıyor.
      expect(days.length, 3);
      expect(days.map((d) => d.day.date), [
        DateTime(2026, 8, 10),
        DateTime(2026, 8, 11),
        DateTime(2026, 8, 12),
      ]);
    });

    test('UTC saatler şehrin yerel saatine çevrilir', () {
      // 01:05Z + Europe/Istanbul (UTC+3) = 04:05
      final today = days[1].day;
      expect(today.timeOf(Prayer.imsak), '04:05');
      expect(today.timeOf(Prayer.sabah), '04:25');
      expect(today.timeOf(Prayer.gunes), '06:01');
      expect(today.timeOf(Prayer.ogle), '13:19');
      expect(today.timeOf(Prayer.ikindi), '17:11');
      expect(today.timeOf(Prayer.aksam), '20:17');
      expect(today.timeOf(Prayer.yatsi), '21:58');
    });

    test('boş dizi gelen vakit atlanır', () {
      // İstanbul'da İşrak ilk iki gün boş geliyor, üçüncü gün dolu.
      expect(days[1].day.timeOf(Prayer.israk), isNull);
      expect(days[2].day.timeOf(Prayer.israk), '06:52');
    });

    test('kaynağın vermediği vakitler boş kalır', () {
      final today = days[1].day;
      for (final prayer in [
        Prayer.dahveiKubra,
        Prayer.kerahet,
        Prayer.asriSani,
        Prayer.isfirariSems,
        Prayer.istibakiNucum,
        Prayer.isaiSani,
        Prayer.geceYarisi,
        Prayer.teheccud,
        Prayer.seher,
        Prayer.kibleSaati,
      ]) {
        expect(today.timeOf(prayer), isNull, reason: prayer.nameTr);
      }
    });

    test('şehir adı ve hicrî târih okunur', () {
      expect(days[1].cityName, 'İstanbul');
      expect(days[1].day.hijriDate, '28 Safer 1448');
    });

    test('gece yarısını geçen vakit yok, zincir düz ilerler', () {
      final today = days[1].day;
      expect(today.dateTimeOf(Prayer.imsak), DateTime(2026, 8, 11, 4, 5));
      expect(today.dateTimeOf(Prayer.yatsi), DateTime(2026, 8, 11, 21, 58));
    });

    test('bozuk yanıt hata verir', () {
      expect(
        () => FaziletSource.parse(raw: 'bu json değil', cityId: 31),
        throwsA(isA<PrayerNetworkException>()),
      );
    });

    test('success=false şehir desteklenmiyor demektir', () {
      expect(
        () => FaziletSource.parse(raw: '{"success":false}', cityId: 999),
        throwsA(isA<CityNotSupportedException>()),
      );
    });

    test('boş vakit listesi hata verir', () {
      expect(
        () => FaziletSource.parse(
            raw: '{"success":true,"vakitler":[]}', cityId: 31),
        throwsA(isA<CityNotSupportedException>()),
      );
    });
  });

  group('CalendarSource yetenekleri', () {
    test('Fazilet 8 vakit verir, turktakvim 18', () {
      expect(CalendarSource.fazilet.supportedPrayers.length, 8);
      expect(CalendarSource.turktakvim.supportedPrayers.length, 18);
    });

    test('yalnızca turktakvim istenen târihi verebilir', () {
      expect(CalendarSource.turktakvim.supportsArbitraryDate, isTrue);
      expect(CalendarSource.fazilet.supportsArbitraryDate, isFalse);
    });

    test('Kıble Sâati Fazilet\'te yok', () {
      expect(CalendarSource.fazilet.supportedPrayers.contains(Prayer.kibleSaati),
          isFalse);
    });

    test('bilinmeyen kimlik turktakvim\'e düşer', () {
      expect(CalendarSource.fromId('bilinmeyen'), CalendarSource.turktakvim);
      expect(CalendarSource.fromId(null), CalendarSource.turktakvim);
      expect(CalendarSource.fromId('fazilet'), CalendarSource.fazilet);
    });
  });
}
