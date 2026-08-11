import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_vakitleri/data/update_service.dart';

AppRelease release(String versionName, {int versionCode = 1}) => AppRelease(
      versionCode: versionCode,
      versionName: versionName,
      apkUrl: 'https://example.invalid/app.apk',
    );

void main() {
  group('sürüm karşılaştırma', () {
    test('büyük sürüm yeni sayılır', () {
      expect(UpdateService.compareVersions('1.2.0', '1.1.0'), 1);
      expect(UpdateService.compareVersions('2.0.0', '1.9.9'), 1);
      expect(UpdateService.compareVersions('1.0.1', '1.0.0'), 1);
    });

    test('küçük ve eşit sürümler', () {
      expect(UpdateService.compareVersions('1.1.0', '1.2.0'), -1);
      expect(UpdateService.compareVersions('1.2.0', '1.2.0'), 0);
    });

    test('sayısal karşılaştırma, metin değil', () {
      // Metin olarak "1.10.0" < "1.9.0" olurdu; sayı olarak büyük.
      expect(UpdateService.compareVersions('1.10.0', '1.9.0'), 1);
      expect(UpdateService.compareVersions('1.2.10', '1.2.9'), 1);
    });

    test('eksik parçalar sıfır sayılır', () {
      expect(UpdateService.compareVersions('1.2', '1.2.0'), 0);
      expect(UpdateService.compareVersions('1.2.1', '1.2'), 1);
    });

    test('yapı numarası eki karşılaştırmayı bozmaz', () {
      expect(UpdateService.compareVersions('1.2.0+5', '1.2.0+3'), 1);
      expect(UpdateService.compareVersions('1.3.0+1', '1.2.0+99'), 1);
    });
  });

  group('güncelleme var mı', () {
    test('yeni sürüm bildirilir', () {
      expect(UpdateService.isNewer(release('1.2.0'), currentName: '1.1.0'),
          isTrue);
    });

    test('aynı sürüm bildirilmez', () {
      expect(UpdateService.isNewer(release('1.2.0'), currentName: '1.2.0'),
          isFalse);
    });

    test('eski sürüm bildirilmez', () {
      expect(UpdateService.isNewer(release('1.1.0'), currentName: '1.2.0'),
          isFalse);
    });

    test('versionCode mimari ofseti karşılaştırmayı etkilemez', () {
      // --split-per-abi ile arm64 APK'sının versionCode'u 2000 artıyor.
      // Manifestteki 3 ile telefondaki 2002 kıyaslanınca güncelleme
      // görünmüyordu; artık sürüm adına bakılıyor.
      final yeni = release('1.2.0', versionCode: 3);
      expect(UpdateService.isNewer(yeni, currentName: '1.1.0'), isTrue);
    });
  });

  group('manifest çözümleme', () {
    test('eksik alanlar reddedilir', () {
      expect(AppRelease.fromJson({'versionName': '1.0.0'}), isNull);
      expect(AppRelease.fromJson({'versionCode': 2}), isNull);
      expect(
        AppRelease.fromJson(
            {'versionCode': 2, 'versionName': '1.0.0', 'apkUrl': ''}),
        isNull,
      );
    });

    test('geçerli manifest okunur', () {
      final parsed = AppRelease.fromJson({
        'versionCode': 3,
        'versionName': '1.2.0',
        'apkUrl': 'https://example.invalid/a.apk',
        'notes': 'not',
        'mandatory': true,
      })!;
      expect(parsed.versionName, '1.2.0');
      expect(parsed.mandatory, isTrue);
      expect(parsed.notes, 'not');
    });
  });
}
