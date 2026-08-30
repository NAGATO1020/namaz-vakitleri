import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/calendar_source.dart';
import '../core/prayer.dart';
import '../data/city_repository.dart';
import '../data/holy_days_repository.dart';
import '../data/models/city.dart';
import '../data/models/holy_day.dart';
import '../data/models/prayer_day.dart';
import '../data/models/settings.dart';
import '../data/prayer_repository.dart';
import '../data/sources/prayer_source.dart';
import '../domain/next_prayer.dart';
import '../platform/service_bridge.dart';
import '../platform/widget_bridge.dart';

final cityRepositoryProvider =
    Provider<CityRepository>((ref) => CityRepository());

final prayerRepositoryProvider = Provider<PrayerRepository>((ref) {
  final repo = PrayerRepository();
  ref.onDispose(repo.close);
  return repo;
});

/// Geri sayımı canlı tutan sayaç.
///
/// Saniyede **iki kez** örnekleniyor. Saniyede bir örneklemek yetmiyordu:
/// `Stream.periodic` tam 1 sn'de bir tetiklenmediği için kalan süre bazen aynı
/// saniyede iki kez, bazen hiç örneklenmiyor; ekranda bir saniye donup sonra
/// iki saniye atlıyordu. İki kat sık örnekleme + yukarı yuvarlama (bkz.
/// `NextPrayerCalculator.formatCountdown`) sayacı düzgün akıtıyor.
final tickerProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(
    const Duration(milliseconds: 500),
    (_) => DateTime.now(),
  );
});

final holyDaysRepositoryProvider = Provider<HolyDaysRepository>((ref) {
  final repo = HolyDaysRepository();
  ref.onDispose(repo.close);
  return repo;
});

final homeControllerProvider =
    StateNotifierProvider<HomeController, HomeState>((ref) {
  final controller = HomeController(
    ref.watch(prayerRepositoryProvider),
    ref.watch(holyDaysRepositoryProvider),
    ref.watch(cityRepositoryProvider),
  );
  controller.load();
  return controller;
});

/// Ekranın o anki durumu — hangi vakitler yüklü, hata var mı.
@immutable
class HomeState {
  const HomeState({
    required this.settings,
    this.yesterday,
    this.today,
    this.tomorrow,
    this.loading = true,
    this.error,
    this.usingCache = false,
    this.holyDays = const [],
  });

  final AppSettings settings;
  final PrayerDay? yesterday;
  final PrayerDay? today;
  final PrayerDay? tomorrow;
  final bool loading;

  /// İçinde bulunulan yılın mübârek günleri (turktakvim'den).
  final List<HolyDay> holyDays;

  /// Kullanıcıya gösterilecek hata; veri varken de dolabilir (o zaman
  /// önbellekteki vakitler gösterilip hata bir şerit olarak belirir).
  final Object? error;

  /// Bugünün verisi ağdan değil, önbellekten geliyor.
  final bool usingCache;

  bool get hasData => today != null && !today!.isUnavailable;

  /// Şehrin saat dilimine göre "şimdi".
  DateTime cityNow([DateTime? deviceNow]) =>
      (deviceNow ?? DateTime.now()).add(settings.cityOffset);

  NextPrayerInfo? nextPrayer([DateTime? deviceNow]) {
    final day = today;
    if (day == null || day.isUnavailable) return null;
    return NextPrayerCalculator.compute(
      cityNow: cityNow(deviceNow),
      today: day,
      yesterday: yesterday,
      tomorrow: tomorrow,
      candidates: settings.effectiveVisiblePrayers,
    );
  }

  HomeState copyWith({
    AppSettings? settings,
    PrayerDay? yesterday,
    PrayerDay? today,
    PrayerDay? tomorrow,
    bool? loading,
    Object? error,
    bool clearError = false,
    bool? usingCache,
    List<HolyDay>? holyDays,
  }) =>
      HomeState(
        settings: settings ?? this.settings,
        yesterday: yesterday ?? this.yesterday,
        today: today ?? this.today,
        tomorrow: tomorrow ?? this.tomorrow,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        usingCache: usingCache ?? this.usingCache,
        holyDays: holyDays ?? this.holyDays,
      );

  /// Bugüne düşen mübârek gün (yoksa null).
  HolyDay? get todayHolyDay => holyDays.on(DateTime.now());

  /// Bugünden sonraki mübârek günler.
  List<HolyDay> upcomingHolyDays({int count = 4}) =>
      holyDays.upcoming(DateTime.now(), count: count);
}

class HomeController extends StateNotifier<HomeState> {
  HomeController(this._repository, this._holyDays, this._cities)
      : super(HomeState(settings: AppSettings.initial()));

  final PrayerRepository _repository;
  final HolyDaysRepository _holyDays;
  final CityRepository _cities;
  SharedPreferences? _prefs;

  /// Açılışta: ayarları oku, önbellekteki vakitleri göster, sonra ağdan tazele.
  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final settings = AppSettings.fromPrefs({
      for (final key in _prefs!.getKeys()) key: _prefs!.get(key),
    });
    state = state.copyWith(settings: settings);
    _cities.source = settings.source;

    await _loadFromCache(settings);
    if (settings.source.hasHolyDays) unawaited(_loadHolyDays());
    await refresh();
  }

  Future<void> _loadFromCache(AppSettings settings) async {
    final window = await _repository.window(settings.cityId, DateTime.now());
    state = state.copyWith(
      yesterday: window.yesterday,
      today: window.today,
      tomorrow: window.tomorrow,
      loading: window.today == null,
      usingCache: window.today != null,
    );
  }

  /// Bugünü ağdan tazeler; şehir künyesini ve saat dilimi farkını da günceller.
  Future<void> refresh() async {
    final settings = state.settings;
    if (settings.cityId <= 0) {
      // Kaynak yeni değişti, şehir henüz seçilmedi.
      state = state.copyWith(loading: false, clearError: true);
      return;
    }
    try {
      final fresh =
          await _repository.refreshToday(settings.source, settings.cityId);
      if (fresh == null) {
        state = state.copyWith(loading: false);
        return;
      }

      final updated = settings.copyWith(
        cityName: fresh.cityName,
        cityRegion: fresh.region,
        cityOffsetMinutes: fresh.offset.inMinutes,
      );
      await _persist(updated);

      // Yarını da sessizce çekelim ki gece geri sayımı kesilmesin.
      // (Fazilet zaten üç günü birden verdiği için orada bu bir daha
      // istek atmaz — yarın önbellekte olur.)
      unawaited(_ensureTomorrow(settings.source, settings.cityId));
      // Ay sonuna yaklaştıysak gelecek ayı da arka planda indirelim.
      unawaited(_prefetchNextMonth(settings.source, settings.cityId));
      // Bir aydan eski kayıtlar yer kaplamasın.
      unawaited(_repository.pruneOldDays());

      final window = await _repository.window(settings.cityId, DateTime.now());
      state = state.copyWith(
        settings: updated,
        yesterday: window.yesterday,
        today: fresh.day,
        tomorrow: window.tomorrow,
        loading: false,
        usingCache: false,
        clearError: true,
      );
    } on CityNotSupportedException catch (e) {
      state = state.copyWith(loading: false, error: e);
    } catch (e) {
      // Ağ yoksa önbellekteki veriyle devam; veri varsa hata sadece bir
      // şerit olarak görünür, ekran boş kalmaz.
      state = state.copyWith(
        loading: false,
        error: e,
        usingCache: state.today != null,
      );
    }
    await _pushToWidgets();
  }

  Future<void> _ensureTomorrow(CalendarSource source, int cityId) async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    try {
      final day = await _repository.day(source, cityId, tomorrow);
      if (day != null && mounted) state = state.copyWith(tomorrow: day);
    } catch (_) {
      // Yarın gelmezse sorun değil; bugünün vakitleri yeterli.
    }
  }

  /// Mübârek günleri yükler: önce veritabanından, yoksa turktakvim'den çekip
  /// saklar. Yıl değiştiğinde kendiliğinden tazelenir.
  Future<void> _loadHolyDays() async {
    final year = DateTime.now().year;
    final stored = await _repository.holyDays(year);
    if (stored.isNotEmpty && mounted) {
      state = state.copyWith(holyDays: stored);
    }

    final fetched = await _holyDays.forYear(year, stored: stored);
    if (fetched.isEmpty || identical(fetched, stored)) return;
    await _repository.storeHolyDays(fetched);
    if (mounted) state = state.copyWith(holyDays: fetched);
  }

  /// Ay sonuna yaklaşıldıysa gelecek ayı sessizce indirir; böylece ay
  /// değiştiğinde internet olmasa bile vakitler elde olur.
  Future<void> _prefetchNextMonth(CalendarSource source, int cityId) async {
    try {
      await _repository.ensureNextMonth(source, cityId);
    } catch (_) {
      // Arka plan kolaylığı — başarısızlığı kullanıcıya taşımıyoruz.
    }
  }

  // --- ayar değiştiricileri ---

  Future<void> setCity(City city) async {
    final updated = state.settings.copyWith(
      cityId: city.id,
      cityName: city.shortName,
      cityRegion: city.province,
      cityOffsetMinutes: 0,
    );
    await _persist(updated);
    state = HomeState(
        settings: updated, loading: true, holyDays: state.holyDays);
    await _loadFromCache(updated);
    await refresh();
  }

  /// Takvim kaynağını değiştirir.
  ///
  /// Önceki kaynağın indirdiği bütün vakitler silinir: iki takvim aynı vakti
  /// farklı usûlle hesaplıyor, karışmaları yanlış vakit göstermeye yol açar.
  /// Şehir kimlikleri de uyuşmadığı için şehir seçimi sıfırlanır ve kullanıcı
  /// yeni kaynağın listesinden şehrini seçer.
  Future<void> setSource(CalendarSource source) async {
    if (source == state.settings.source) return;

    await _repository.clearAllDays();

    final updated = state.settings.copyWith(
      source: source,
      cityId: 0,
      cityName: '',
      cityRegion: '',
      cityOffsetMinutes: 0,
    );
    await _persist(updated);
    _cities.source = source;

    state = HomeState(
      settings: updated,
      loading: false,
      holyDays: source.hasHolyDays ? state.holyDays : const [],
    );
  }

  /// Kaynak değiştikten sonra şehir seçilmemiş durumu.
  bool get needsCity => state.settings.cityId <= 0;

  Future<void> setThemeMode(ThemeMode mode) =>
      _persist(state.settings.copyWith(themeMode: mode));

  Future<void> setLanguage(String? code) => _persist(
      state.settings.copyWith(languageCode: code, clearLanguage: code == null));

  Future<void> toggleVisible(Prayer prayer) {
    final next = {...state.settings.visiblePrayers};
    next.contains(prayer) ? next.remove(prayer) : next.add(prayer);
    return _persist(state.settings.copyWith(visiblePrayers: next));
  }

  Future<void> setVisible(Set<Prayer> prayers) =>
      _persist(state.settings.copyWith(visiblePrayers: prayers));

  Future<void> toggleNotify(Prayer prayer) {
    final next = {...state.settings.notifyPrayers};
    next.contains(prayer) ? next.remove(prayer) : next.add(prayer);
    return _persist(state.settings.copyWith(notifyPrayers: next));
  }

  Future<void> setNotificationsEnabled(bool value) =>
      _persist(state.settings.copyWith(notificationsEnabled: value));

  Future<void> setPersistentNotification(bool value) =>
      _persist(state.settings.copyWith(persistentNotification: value));

  Future<void> setShowSeconds(bool value) =>
      _persist(state.settings.copyWith(showSecondsInCountdown: value));

  Future<void> _persist(AppSettings settings) async {
    state = state.copyWith(settings: settings);
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    for (final entry in settings.toPrefs().entries) {
      final value = entry.value;
      if (value is int) await prefs.setInt(entry.key, value);
      if (value is bool) await prefs.setBool(entry.key, value);
      if (value is String) await prefs.setString(entry.key, value);
    }
    await _pushToWidgets();
  }

  /// Widget'lar ve kalıcı bildirim aynı veriyi native taraftan okur.
  ///
  /// Önce veriyi yayınlar, sonra native tarafa "alarmları ve bildirimi
  /// yeniden kur" der — sıra önemli, aksi hâlde eski veriyle kurulur.
  Future<void> _pushToWidgets() async {
    if (state.today == null) return;
    // Elde ne varsa yazıyoruz: uygulama günlerce açılmasa da bildirim
    // önbellekteki günlerle çalışmaya devam etsin.
    final days = await _repository.upcomingFromCache(
      state.settings.cityId,
      DateTime.now().subtract(const Duration(days: 1)),
      limit: WidgetBridge.publishedDayCount,
    );
    await WidgetBridge.publish(
      settings: state.settings,
      days: days.isEmpty ? [state.today!] : days,
    );
    if (state.settings.notificationsEnabled ||
        state.settings.persistentNotification) {
      await ServiceBridge.syncSchedule();
    } else {
      await ServiceBridge.cancelAll();
    }
  }
}
