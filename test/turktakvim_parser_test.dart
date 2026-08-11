import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/core/prayer.dart';
import 'package:namaz_vakitleri/data/models/prayer_day.dart';
import 'package:namaz_vakitleri/data/turktakvim_parser.dart';

String _fixture(String name) =>
    File('test/fixtures/$name').readAsStringSync();

void main() {
  group('TurktakvimParser', () {
    test('18 vaktin hepsi doğru alana düşer', () {
      final result = TurktakvimParser.parse(
        raw: _fixture('gadget_64814_2026-08-11.txt'),
        cityId: 64814,
        date: DateTime(2026, 8, 11),
      );

      expect(result.cityName, 'Schönberg');
      expect(result.region, 'Fribourg');
      expect(result.displayName, 'Schönberg - Fribourg');
      expect(result.day.hijriDate, '28 SAFER 1448');

      // Kullanıcının ekran görüntüsündeki değerlerle birebir.
      const expected = {
        Prayer.imsak: '03:59',
        Prayer.sabah: '04:19',
        Prayer.gunes: '06:17',
        Prayer.israk: '07:11',
        Prayer.dahveiKubra: '12:27',
        Prayer.kerahet: '13:25',
        Prayer.ogle: '13:48',
        Prayer.ikindi: '17:45',
        Prayer.asriSani: '18:49',
        Prayer.isfirariSems: '20:12',
        Prayer.aksam: '20:56',
        Prayer.istibakiNucum: '22:00',
        Prayer.yatsi: '22:55',
        Prayer.isaiSani: '23:12',
        Prayer.geceYarisi: '00:28',
        Prayer.teheccud: '01:39',
        Prayer.seher: '02:50',
        Prayer.kibleSaati: '11:06',
      };
      expected.forEach((prayer, time) {
        expect(result.day.timeOf(prayer), time, reason: prayer.nameTr);
      });
    });

    test('koordinat derece+dakikadan ondalığa çevrilir', () {
      final result = TurktakvimParser.parse(
        raw: _fixture('gadget_64814_2026-08-11.txt'),
        cityId: 64814,
        date: DateTime(2026, 8, 11),
      );
      expect(result.latitude, closeTo(46 + 48 / 60, 1e-9));
      expect(result.longitude, closeTo(7 + 11 / 60, 1e-9));
    });

    test('şehrin yerel saati okunur (saat dilimi farkı için gerekli)', () {
      final result = TurktakvimParser.parse(
        raw: _fixture('gadget_64814_2026-08-11.txt'),
        cityId: 64814,
        date: DateTime(2026, 8, 11),
      );
      expect(result.cityLocalNow, DateTime(2026, 8, 11, 11, 25, 0));
    });

    test('istenen târih yanıttaki "şimdi"den bağımsızdır', () {
      // Sunucu 25. alanda daima o anki saati döner; vakitler ise istenen güne
      // âittir. Ay indirirken bu ikisi karışmamalı.
      final result = TurktakvimParser.parse(
        raw: _fixture('gadget_64814_2026-08-20.txt'),
        cityId: 64814,
        date: DateTime(2026, 8, 20),
      );
      expect(result.day.date, DateTime(2026, 8, 20));
      expect(result.cityLocalNow.day, 11); // yanıttaki "şimdi" hâlâ 11 Ağustos
      expect(result.day.timeOf(Prayer.imsak), '04:19');
      expect(result.day.hijriDate, "7 REBÎ'UL-EVVEL 1448");
    });

    test('güney/batı yarımküre koordinatları negatif olur', () {
      final result = TurktakvimParser.parse(
        raw: 'Sydney;33;52;S;151;12;E;05:30;05:50;06:20;07:00;11:00;11:30;'
            '12:00;15:00;16:00;17:00;17:30;18:00;18:45;19:00;00:00;01:00;'
            '02:00;10:00;11/08/2026 21:25:00 ;28  SAFER  1448 ;New South Wales',
        cityId: 1,
        date: DateTime(2026, 8, 11),
      );
      expect(result.latitude, closeTo(-(33 + 52 / 60), 1e-9));
      expect(result.longitude, closeTo(151 + 12 / 60, 1e-9));
    });

    test('boş yanıt hata verir', () {
      expect(
        () => TurktakvimParser.parse(
            raw: '   ', cityId: 1, date: DateTime(2026, 1, 1)),
        throwsA(isA<TurktakvimParseException>()),
      );
    });

    test('VY yanıtı vakitsiz gün üretir', () {
      // Sentetik: canlı servis kutup şehirlerinde bugün HTTP 500 dönüyor,
      // ama gadget.js'te hâlâ "VY" dalı var. Parser ikisini de karşılamalı.
      final result = TurktakvimParser.parse(
        raw: 'Longyearbyen;78;13;N;15;38;E;VY;11/08/2026 11:25:00 ;'
            '28  SAFER  1448 ;Spitsbergen',
        cityId: 61860,
        date: DateTime(2026, 8, 11),
      );
      expect(result.day.isUnavailable, isTrue);
      expect(result.cityLocalNow, DateTime(2026, 8, 11, 11, 25, 0));
      expect(result.day.hijriDate, '28 SAFER 1448');
      expect(result.region, 'Spitsbergen');
    });
  });

  group('PrayerDay.dateTimeOf', () {
    final day = TurktakvimParser.parse(
      raw: _fixture('gadget_64814_2026-08-11.txt'),
      cityId: 64814,
      date: DateTime(2026, 8, 11),
    ).day;

    test('gündüz vakitleri kendi günündedir', () {
      expect(day.dateTimeOf(Prayer.imsak), DateTime(2026, 8, 11, 3, 59));
      expect(day.dateTimeOf(Prayer.yatsi), DateTime(2026, 8, 11, 22, 55));
      expect(day.dateTimeOf(Prayer.isaiSani), DateTime(2026, 8, 11, 23, 12));
    });

    test('gece yarısını geçen vakitler ertesi güne taşınır', () {
      // 00:28, 01:39, 02:50 → 12 Ağustos'un erken saatleri
      expect(day.dateTimeOf(Prayer.geceYarisi), DateTime(2026, 8, 12, 0, 28));
      expect(day.dateTimeOf(Prayer.teheccud), DateTime(2026, 8, 12, 1, 39));
      expect(day.dateTimeOf(Prayer.seher), DateTime(2026, 8, 12, 2, 50));
    });

    test('Kıble Sâati zincire girmez, günün içinde kalır', () {
      // 11:06, kendinden önceki İşâ-i Sânî'den (23:12) küçük olmasına rağmen
      // ertesi güne kaymamalı.
      expect(day.dateTimeOf(Prayer.kibleSaati), DateTime(2026, 8, 11, 11, 6));
    });

    test('zincirdeki vakitler kronolojik sıradadır', () {
      DateTime? previous;
      for (final p in Prayer.chain) {
        final at = day.dateTimeOf(p);
        expect(at, isNotNull, reason: p.nameTr);
        if (previous != null) {
          expect(at!.isAfter(previous), isTrue,
              reason: '${p.nameTr} ($at) öncekinden sonra gelmeli ($previous)');
        }
        previous = at;
      }
    });
  });

  group('veritabanı gidiş-dönüşü', () {
    test('toDbRow/fromDbRow vakitleri korur', () {
      final original = TurktakvimParser.parse(
        raw: _fixture('gadget_64814_2026-08-11.txt'),
        cityId: 64814,
        date: DateTime(2026, 8, 11),
      ).day;

      final restored = PrayerDay.fromDbRow(original.toDbRow());

      for (final p in Prayer.values) {
        expect(restored.timeOf(p), original.timeOf(p), reason: p.nameTr);
      }
      expect(restored.date, original.date);
      expect(restored.cityId, original.cityId);
      expect(restored.hijriDate, original.hijriDate);
    });
  });
}
