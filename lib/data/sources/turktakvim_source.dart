import '../../core/calendar_source.dart';
import '../models/prayer_day.dart';
import '../turktakvim_api.dart';
import 'prayer_source.dart';

/// Türkiye Takvimi (turktakvim.com) kaynağı.
///
/// 18 vaktin hepsini verir ve istenen târihin vakitleri çekilebilir; bu
/// yüzden bir aylık indirme yalnızca bu kaynakta mümkündür.
class TurktakvimSource implements PrayerSource {
  TurktakvimSource({TurktakvimApi? api}) : _api = api ?? TurktakvimApi();

  final TurktakvimApi _api;

  @override
  CalendarSource get source => CalendarSource.turktakvim;

  @override
  Future<List<PrayerFetchResult>> fetch({
    required int cityId,
    DateTime? date,
  }) async =>
      [await _api.fetchDay(cityId: cityId, date: date)];

  @override
  void close() => _api.close();
}
