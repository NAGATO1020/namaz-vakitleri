import 'package:flutter/material.dart';

import '../../core/calendar_source.dart';
import '../../core/prayer.dart';

/// Uygulamanın bütün kullanıcı tercihleri.
@immutable
class AppSettings {
  const AppSettings({
    this.source = CalendarSource.turktakvim,
    this.cityId = defaultCityId,
    this.cityName = 'Schönberg',
    this.cityRegion = 'Fribourg',
    this.cityOffsetMinutes = 0,
    this.themeMode = ThemeMode.system,
    this.languageCode,
    this.visiblePrayers = const {},
    this.notifyPrayers = const {},
    this.persistentNotification = true,
    this.notificationsEnabled = true,
    this.showSecondsInCountdown = true,
  });

  static const int defaultCityId = 64814; // Schönberg - Fribourg / İsviçre

  /// Vakitlerin alındığı takvim. Değiştiğinde şehir de sıfırlanır —
  /// iki kaynağın şehir kimlikleri birbirine uymuyor.
  final CalendarSource source;

  final int cityId;
  final String cityName;
  final String cityRegion;

  /// Şehrin yerel saati ile cihaz saati arasındaki fark (dakika).
  /// Vakitler şehrin saatiyle geldiği için geri sayım bununla düzeltilir.
  final int cityOffsetMinutes;

  final ThemeMode themeMode;

  /// `null` → cihazın dili. Aksi hâlde 'tr' veya 'en'.
  final String? languageCode;

  /// Ana ekranda ve widget'larda gösterilen vakitler.
  final Set<Prayer> visiblePrayers;

  /// Vakit girince bildirim gönderilecek vakitler.
  final Set<Prayer> notifyPrayers;

  /// Bildirim çubuğunda geri sayımlı kalıcı bildirim.
  final bool persistentNotification;

  /// Vakit bildirimlerinin ana anahtarı.
  final bool notificationsEnabled;

  final bool showSecondsInCountdown;

  Duration get cityOffset => Duration(minutes: cityOffsetMinutes);

  String get cityDisplayName =>
      cityRegion.isEmpty || cityRegion == cityName
          ? cityName
          : '$cityName - $cityRegion';

  /// İlk kurulumda kullanılan varsayılanlar: ekran görüntüsündeki işâretli
  /// vakitler görünür, bildirim beş farz vakit için açık.
  static AppSettings initial() => AppSettings(
        visiblePrayers: {
          for (final p in Prayer.values)
            if (p.visibleByDefault) p,
        },
        notifyPrayers: {
          for (final p in Prayer.values)
            if (p.isFard) p,
        },
      );

  /// Bu kaynağın verdiği vakitlerle sınırlanmış görünür vakit kümesi.
  /// Kaynak bir vakti hiç vermiyorsa listede boş satır olarak durmasın.
  Set<Prayer> get effectiveVisiblePrayers =>
      visiblePrayers.intersection(source.supportedPrayers);

  Set<Prayer> get effectiveNotifyPrayers =>
      notifyPrayers.intersection(source.supportedPrayers);

  AppSettings copyWith({
    CalendarSource? source,
    int? cityId,
    String? cityName,
    String? cityRegion,
    int? cityOffsetMinutes,
    ThemeMode? themeMode,
    String? languageCode,
    bool clearLanguage = false,
    Set<Prayer>? visiblePrayers,
    Set<Prayer>? notifyPrayers,
    bool? persistentNotification,
    bool? notificationsEnabled,
    bool? showSecondsInCountdown,
  }) =>
      AppSettings(
        source: source ?? this.source,
        cityId: cityId ?? this.cityId,
        cityName: cityName ?? this.cityName,
        cityRegion: cityRegion ?? this.cityRegion,
        cityOffsetMinutes: cityOffsetMinutes ?? this.cityOffsetMinutes,
        themeMode: themeMode ?? this.themeMode,
        languageCode: clearLanguage ? null : (languageCode ?? this.languageCode),
        visiblePrayers: visiblePrayers ?? this.visiblePrayers,
        notifyPrayers: notifyPrayers ?? this.notifyPrayers,
        persistentNotification:
            persistentNotification ?? this.persistentNotification,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        showSecondsInCountdown:
            showSecondsInCountdown ?? this.showSecondsInCountdown,
      );

  // --- kalıcı depolama ---

  static const _kCityId = 'city_id';
  static const _kCityName = 'city_name';
  static const _kCityRegion = 'city_region';
  static const _kCityOffset = 'city_offset_minutes';
  static const _kThemeMode = 'theme_mode';
  static const _kLanguage = 'language_code';
  static const _kVisible = 'visible_prayers';
  static const _kNotify = 'notify_prayers';
  static const _kPersistent = 'persistent_notification';
  static const _kNotifications = 'notifications_enabled';
  static const _kSeconds = 'show_seconds';
  static const _kSource = 'calendar_source';

  Map<String, Object> toPrefs() {
    final map = <String, Object>{
      _kSource: source.id,
      _kCityId: cityId,
      _kCityName: cityName,
      _kCityRegion: cityRegion,
      _kCityOffset: cityOffsetMinutes,
      _kThemeMode: themeMode.name,
      _kVisible: _encode(visiblePrayers),
      _kNotify: _encode(notifyPrayers),
      _kPersistent: persistentNotification,
      _kNotifications: notificationsEnabled,
      _kSeconds: showSecondsInCountdown,
    };
    final code = languageCode;
    if (code != null) map[_kLanguage] = code;
    return map;
  }

  static AppSettings fromPrefs(Map<String, Object?> prefs) {
    if (!prefs.containsKey(_kCityId)) return AppSettings.initial();
    final fallback = AppSettings.initial();
    return AppSettings(
      source: CalendarSource.fromId(prefs[_kSource] as String?),
      cityId: prefs[_kCityId] as int? ?? fallback.cityId,
      cityName: prefs[_kCityName] as String? ?? fallback.cityName,
      cityRegion: prefs[_kCityRegion] as String? ?? fallback.cityRegion,
      cityOffsetMinutes: prefs[_kCityOffset] as int? ?? 0,
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == prefs[_kThemeMode],
        orElse: () => ThemeMode.system,
      ),
      languageCode: prefs[_kLanguage] as String?,
      visiblePrayers: _decode(prefs[_kVisible]) ?? fallback.visiblePrayers,
      notifyPrayers: _decode(prefs[_kNotify]) ?? fallback.notifyPrayers,
      persistentNotification: prefs[_kPersistent] as bool? ?? true,
      notificationsEnabled: prefs[_kNotifications] as bool? ?? true,
      showSecondsInCountdown: prefs[_kSeconds] as bool? ?? true,
    );
  }

  /// Vakit kümesini "0,1,2,6" gibi bir dizgeye çevirir — native taraf
  /// (widget ve bildirim servisi) da bu biçimi okur.
  static String _encode(Set<Prayer> prayers) {
    final ordered = Prayer.values.where(prayers.contains).map((p) => p.index);
    return ordered.join(',');
  }

  static Set<Prayer>? _decode(Object? raw) {
    if (raw is! String) return null;
    if (raw.isEmpty) return <Prayer>{};
    final out = <Prayer>{};
    for (final part in raw.split(',')) {
      final i = int.tryParse(part);
      if (i != null && i >= 0 && i < Prayer.values.length) {
        out.add(Prayer.values[i]);
      }
    }
    return out;
  }

  static String encodePrayers(Set<Prayer> prayers) => _encode(prayers);
}
