import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../core/prayer.dart';
import '../data/models/prayer_day.dart';
import '../data/models/settings.dart';

/// Flutter tarafındaki veriyi native tarafa (widget'lar ve kalıcı bildirim
/// servisi) aktarır.
///
/// Native taraf sıradaki vakti ve geri sayımı **kendisi** hesaplar; böylece
/// bildirim her dakika Flutter'ı uyandırmadan güncellenebilir. Bunun için
/// gereken her şey buradan yazılır.
class WidgetBridge {
  const WidgetBridge._();

  /// Android'de `home_widget`'ın kullandığı SharedPreferences dosyası;
  /// Kotlin tarafı da aynı dosyayı okur.
  static const String androidAppGroup = 'HomeWidgetPreferences';

  /// iOS'ta widget uzantısıyla paylaşılan App Group.
  static const String iosAppGroup = 'group.com.tunahan.namazvakitleri';

  static const _providers = <String>[
    'NextPrayerWidgetProvider',
    'DailyTimesWidgetProvider',
    'CompactWidgetProvider',
  ];

  static bool _initialised = false;

  static Future<void> ensureInitialised() async {
    if (_initialised) return;
    await HomeWidget.setAppGroupId(iosAppGroup);
    _initialised = true;
  }

  /// Önbellekten kaç günlük veri native tarafa yazılacağı.
  ///
  /// Yalnızca bugün+yarın yazmak, uygulama iki gün açılmazsa bildirimin
  /// susmasına yol açıyordu. Elde ne varsa (turktakvim'de bir aylık indirme
  /// yapıldıysa bir ay) yazınca bildirim internetsiz de haftalarca doğru
  /// çalışıyor.
  static const int publishedDayCount = 40;

  /// Vakitleri ve ilgili ayarları yayınlar.
  ///
  /// [days] dünden başlayarak elde bulunan günler olmalı; sıralı olması
  /// gerekmez, native taraf târihe göre seçiyor.
  static Future<void> publish({
    required AppSettings settings,
    required List<PrayerDay> days,
  }) async {
    if (days.isEmpty) return;
    try {
      await ensureInitialised();
      await Future.wait([
        HomeWidget.saveWidgetData('city_display', settings.cityDisplayName),
        HomeWidget.saveWidgetData('source', settings.source.id),
        HomeWidget.saveWidgetData('city_id', '${settings.cityId}'),
        // Native tarafın arka planda kendi başına veri çekebilmesi için.
        HomeWidget.saveWidgetData('days', encodeDays(days)),
        HomeWidget.saveWidgetData('visible_prayers',
            AppSettings.encodePrayers(settings.effectiveVisiblePrayers)),
        HomeWidget.saveWidgetData(
            'notify_prayers', AppSettings.encodePrayers(settings.effectiveNotifyPrayers)),
        // Sayılar platform kanalında Int/Long arasında gidip geldiği için
        // native tarafta belirsizlik olmasın diye metin olarak yazılıyor.
        HomeWidget.saveWidgetData(
            'city_offset_minutes', '${settings.cityOffsetMinutes}'),
        // Native taraf cihaz dilini kendisi çözemesin diye **etkin** dili
        // yazıyoruz: ayarda "sistem dili" seçiliyse cihazın dilini gönderiyoruz.
        // Aksi hâlde arayüz İngilizceyken bildirim Türkçe kalıyordu.
        HomeWidget.saveWidgetData('language', effectiveLanguage(settings)),
        HomeWidget.saveWidgetData(
            'persistent_enabled', settings.persistentNotification),
        HomeWidget.saveWidgetData(
            'notifications_enabled', settings.notificationsEnabled),
        HomeWidget.saveWidgetData(
            'show_seconds', settings.showSecondsInCountdown),
        HomeWidget.saveWidgetData('prayer_names_tr',
            Prayer.values.map((p) => p.nameTr).join('|')),
        HomeWidget.saveWidgetData('prayer_names_en',
            Prayer.values.map((p) => p.nameEn).join('|')),
      ]);
      await _refreshAll();
    } catch (e, s) {
      // Widget güncellemesi uygulamanın açılmasını engellememeli.
      debugPrint('WidgetBridge.publish başarısız: $e\n$s');
    }
  }

  static Future<void> _refreshAll() async {
    for (final provider in _providers) {
      await HomeWidget.updateWidget(
        name: provider,
        androidName: provider,
        iOSName: provider,
      );
    }
  }

  /// 18 vakti "03:59,04:19,…" biçiminde tek satıra çevirir; hesaplanamayan
  /// vakitler boş bırakılır.
  static String encodeTimes(PrayerDay day) =>
      Prayer.values.map((p) => day.timeOf(p) ?? '').join(',');

  /// Günleri native tarafın okuyacağı biçime çevirir; her satır:
  /// `YYYY-MM-DD<TAB>03:59,04:19,…<TAB>28 SAFER 1448`
  ///
  /// Aynı biçimi Kotlin'de `PrayerStore.parseDays` çözüyor.
  static String encodeDays(List<PrayerDay> days) {
    final sorted = [...days]..sort((a, b) => a.date.compareTo(b.date));
    return sorted
        .take(publishedDayCount)
        .map((d) =>
            '${PrayerDay.dateKey(d.date)}\t${encodeTimes(d)}\t${d.hijriDate}')
        .join('\n');
  }

  /// Arayüzün gerçekte kullandığı dil: ayarda seçili dil, yoksa cihazın dili.
  /// Desteklenmeyen bir cihaz dili Türkçeye düşer (uygulamanın varsayılanı).
  static String effectiveLanguage(AppSettings settings) {
    final chosen = settings.languageCode;
    if (chosen != null) return chosen;
    final device = PlatformDispatcher.instance.locale.languageCode;
    return device == 'en' ? 'en' : 'tr';
  }
}
