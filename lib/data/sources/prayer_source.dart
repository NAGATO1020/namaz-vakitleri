import '../../core/calendar_source.dart';
import '../models/prayer_day.dart';

/// Bir takvim kaynağından vakit çekmenin ortak arayüzü.
///
/// İki kaynak farklı davranıyor: turktakvim istenen târihin vakitlerini
/// verirken, Fazilet tek istekte dün/bugün/yarını döndürüp târih parametresini
/// yok sayıyor. Bu yüzden [fetch] her zaman **liste** döner — çağıran taraf
/// kaç gün geldiğini bilmek zorunda kalmaz.
abstract class PrayerSource {
  CalendarSource get source;

  /// [date] verilirse o günü (kaynak destekliyorsa) getirir; desteklemiyorsa
  /// elindeki günleri döndürür.
  Future<List<PrayerFetchResult>> fetch({
    required int cityId,
    DateTime? date,
  });

  void close();
}

/// Kaynak bu şehir için vakit üretemiyor.
class CityNotSupportedException implements Exception {
  CityNotSupportedException(this.cityId, [this.reason]);

  final int cityId;
  final String? reason;

  @override
  String toString() =>
      'CityNotSupportedException: $cityId için vakit hesaplanamıyor'
      '${reason == null ? '' : ' ($reason)'}';
}

/// Ağ katmanı hatası.
class PrayerNetworkException implements Exception {
  PrayerNetworkException(this.message);
  final String message;

  @override
  String toString() => 'PrayerNetworkException: $message';
}
