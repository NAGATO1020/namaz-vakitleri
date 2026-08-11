import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/core/prayer.dart';
import 'package:namaz_vakitleri/data/models/prayer_day.dart';
import 'package:namaz_vakitleri/data/turktakvim_parser.dart';
import 'package:namaz_vakitleri/domain/next_prayer.dart';

PrayerDay _day(String fixture, DateTime date) => TurktakvimParser.parse(
      raw: File('test/fixtures/$fixture').readAsStringSync(),
      cityId: 64814,
      date: date,
    ).day;

/// Aynı vakitleri istenen güne kopyalar — komşu günleri üretmek için.
PrayerDay _shift(PrayerDay source, int days) => PrayerDay(
      cityId: source.cityId,
      date: source.date.add(Duration(days: days)),
      times: source.times,
      hijriDate: source.hijriDate,
    );

void main() {
  // 11 Ağustos 2026, Schönberg:
  // İmsâk 03:59 · Sabâh 04:19 · Güneş 06:17 · İşrak 07:11 · Öğle 13:48
  // İkindi 17:45 · Akşam 20:56 · Yatsı 22:55 · (ertesi gün) Seher 02:50
  final today = _day('gadget_64814_2026-08-11.txt', DateTime(2026, 8, 11));
  final yesterday = _shift(today, -1);
  final tomorrow = _shift(today, 1);

  final visible =
      Prayer.values.where((p) => p.visibleByDefault).toSet();

  group('NextPrayerCalculator.compute', () {
    test('gün ortasında sıradaki vakti ve içinde bulunulanı bulur', () {
      final info = NextPrayerCalculator.compute(
        cityNow: DateTime(2026, 8, 11, 14, 30),
        today: today,
        yesterday: yesterday,
        tomorrow: tomorrow,
        candidates: visible,
      )!;
      expect(info.current, Prayer.ogle); // 13:48
      expect(info.next, Prayer.ikindi); // 17:45
      expect(info.nextAt, DateTime(2026, 8, 11, 17, 45));
      expect(info.remaining, const Duration(hours: 3, minutes: 15));
    });

    test('vaktin tam üzerinde o vakit "içinde bulunulan" sayılır', () {
      final info = NextPrayerCalculator.compute(
        cityNow: DateTime(2026, 8, 11, 17, 45),
        today: today,
        yesterday: yesterday,
        tomorrow: tomorrow,
        candidates: visible,
      )!;
      expect(info.current, Prayer.ikindi);
      expect(info.next, Prayer.aksam);
    });

    test('Yatsı ile ertesi gün İmsâk arasında gece geçişi doğru', () {
      // 23:30 — Yatsı (22:55) girmiş, sıradaki ertesi günün İmsâk'i (03:59).
      final info = NextPrayerCalculator.compute(
        cityNow: DateTime(2026, 8, 11, 23, 30),
        today: today,
        yesterday: yesterday,
        tomorrow: tomorrow,
        candidates: visible,
      )!;
      expect(info.current, Prayer.yatsi);
      expect(info.next, Prayer.imsak);
      expect(info.nextAt, DateTime(2026, 8, 12, 3, 59));
      expect(info.remaining, const Duration(hours: 4, minutes: 29));
    });

    test('gece yarısından sonra hâlâ önceki günün Yatsı vaktindeyiz', () {
      // 01:30 — bugünün İmsâk'i henüz gelmedi; içinde bulunulan vakit dünün
      // satırından gelen Yatsı.
      final info = NextPrayerCalculator.compute(
        cityNow: DateTime(2026, 8, 11, 1, 30),
        today: today,
        yesterday: yesterday,
        tomorrow: tomorrow,
        candidates: visible,
      )!;
      expect(info.current, Prayer.yatsi);
      expect(info.next, Prayer.imsak);
      expect(info.nextAt, DateTime(2026, 8, 11, 3, 59));
    });

    test('gece vakitleri seçiliyse Teheccüd/Seher de sıraya girer', () {
      final withNightPrayers = {...visible, Prayer.teheccud, Prayer.seher};
      final info = NextPrayerCalculator.compute(
        cityNow: DateTime(2026, 8, 12, 1, 0),
        today: today,
        yesterday: yesterday,
        tomorrow: tomorrow,
        candidates: withNightPrayers,
      )!;
      // 11 Ağustos satırındaki Teheccüd 01:39 → 12 Ağustos 01:39
      expect(info.next, Prayer.teheccud);
      expect(info.nextAt, DateTime(2026, 8, 12, 1, 39));
    });

    test('Kıble Sâati sıradaki vakit olarak seçilmez', () {
      // 10:00'da Kıble Sâati (11:06) en yakın an olsa da zincire girmediği
      // için sıradaki vakit İşrak sonrası Öğle olmalı.
      final info = NextPrayerCalculator.compute(
        cityNow: DateTime(2026, 8, 11, 10, 0),
        today: today,
        yesterday: yesterday,
        tomorrow: tomorrow,
        candidates: visible,
      )!;
      expect(info.next, Prayer.ogle);
      expect(info.next, isNot(Prayer.kibleSaati));
    });

    test('komşu günler yoksa da bugünün içinde çalışır', () {
      final info = NextPrayerCalculator.compute(
        cityNow: DateTime(2026, 8, 11, 5, 0),
        today: today,
        candidates: visible,
      )!;
      expect(info.current, Prayer.sabah);
      expect(info.next, Prayer.gunes);
    });

    test('yarının verisi yoksa günün son vaktinden sonra null döner', () {
      final info = NextPrayerCalculator.compute(
        cityNow: DateTime(2026, 8, 11, 23, 30),
        today: today,
        candidates: visible,
      );
      expect(info, isNull);
    });

    test('ilerleme oranı iki vakit arasını doğru ölçer', () {
      // Öğle 13:48 → İkindi 17:45 = 237 dk. 13:48 + 118,5 dk ≈ %50
      final info = NextPrayerCalculator.compute(
        cityNow: DateTime(2026, 8, 11, 15, 46, 30),
        today: today,
        tomorrow: tomorrow,
        candidates: visible,
      )!;
      expect(info.progress, closeTo(0.5, 0.01));
    });
  });

  group('saat dilimi farkı', () {
    test('şehir cihazdan ileriyse offset pozitif ve 15 dk katı', () {
      // Cihaz Türkiye'de (12:25), şehir İsviçre'de (11:25) → -1 saat.
      final offset = NextPrayerCalculator.cityOffset(
        cityLocalNow: DateTime(2026, 8, 11, 11, 25, 0),
        deviceNow: DateTime(2026, 8, 11, 12, 25, 3), // 3 sn ağ gecikmesi
      );
      expect(offset, const Duration(hours: -1));
    });

    test('yarım saatlik saat dilimleri korunur', () {
      // Hindistan: +5:30. Cihaz UTC'de olsun.
      final offset = NextPrayerCalculator.cityOffset(
        cityLocalNow: DateTime(2026, 8, 11, 17, 55, 12),
        deviceNow: DateTime(2026, 8, 11, 12, 25, 0),
      );
      expect(offset, const Duration(hours: 5, minutes: 30));
    });

    test('45 dakikalık saat dilimi (Nepal) korunur', () {
      final offset = NextPrayerCalculator.cityOffset(
        cityLocalNow: DateTime(2026, 8, 11, 18, 10, 40),
        deviceNow: DateTime(2026, 8, 11, 12, 25, 0),
      );
      expect(offset, const Duration(hours: 5, minutes: 45));
    });

    test('aynı saat dilimi sıfır offset verir', () {
      final offset = NextPrayerCalculator.cityOffset(
        cityLocalNow: DateTime(2026, 8, 11, 12, 25, 8),
        deviceNow: DateTime(2026, 8, 11, 12, 25, 0),
      );
      expect(offset, Duration.zero);
    });
  });

  group('geri sayım biçimi', () {
    test('saat varsa s:dd:ss, yoksa dd:ss', () {
      expect(
        NextPrayerCalculator.formatCountdown(
            const Duration(hours: 3, minutes: 15, seconds: 4)),
        '3:15:04',
      );
      expect(
        NextPrayerCalculator.formatCountdown(
            const Duration(minutes: 7, seconds: 9)),
        '07:09',
      );
    });

    test('saniyesiz biçim bildirim çubuğu için kısadır', () {
      expect(
        NextPrayerCalculator.formatCountdown(
            const Duration(hours: 2, minutes: 5),
            withSeconds: false),
        '2:05',
      );
      expect(
        NextPrayerCalculator.formatCountdown(const Duration(minutes: 42),
            withSeconds: false),
        '42 dk',
      );
    });

    test('negatif süre sıfıra kırpılır', () {
      expect(
        NextPrayerCalculator.formatCountdown(const Duration(seconds: -30)),
        '00:00',
      );
    });
  });
}
