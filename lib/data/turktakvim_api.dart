import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models/prayer_day.dart';
import 'sources/prayer_source.dart';
import 'turktakvim_parser.dart';

/// Geriye dönük uyumluluk: hatalar artık `sources/prayer_source.dart`
/// içindeki ortak sınıflarda toplanıyor, iki kaynak da aynılarını fırlatıyor.
typedef TurktakvimNetworkException = PrayerNetworkException;

/// turktakvim.com'un gadget servisine erişim.
///
/// Vakitlerin tamamı buradan gelir; uygulama hiçbir vakti kendisi hesaplamaz.
/// Kaynağa yük bindirmemek için çağıran taraf sonuçları kalıcı olarak
/// önbelleğe alır (bkz. `PrayerRepository`).
class TurktakvimApi {
  TurktakvimApi({http.Client? client, this.timeout = const Duration(seconds: 20)})
      : _client = client ?? http.Client();

  static const String base = 'https://gadget.turktakvim.com/gadget.php';

  /// Kaynak sitenin bizi tanıyabilmesi için açık bir kimlik.
  static const String userAgent =
      'NamazVakitleri/1.0 (Android; turktakvim.com verisi)';

  final http.Client _client;
  final Duration timeout;

  /// Bir günün 18 vaktini çeker. [date] verilmezse bugünü döner.
  Future<PrayerFetchResult> fetchDay({
    required int cityId,
    DateTime? date,
  }) async {
    final effectiveDate = date ?? DateTime.now();
    final uri = Uri.parse(base).replace(queryParameters: {
      'pg': '1',
      'sid': '$cityId',
      'cityID': '$cityId',
      'tarih': PrayerDay.dateKey(effectiveDate),
    });

    // Kutup bölgesindeki şehirlerde servis 500 döner; bunu ağ hatasından
    // ayırmak gerekiyor, çünkü tekrar denemenin faydası yok.
    final body = await _get(uri, onServerError: () => CityNotSupportedException(cityId));

    final result = TurktakvimParser.parse(
      raw: body,
      cityId: cityId,
      date: effectiveDate,
    );
    if (result.day.isUnavailable) throw CityNotSupportedException(cityId);
    return result;
  }

  /// Tüm şehir listesinin ham HTML'i (~15 MB, 122.000+ şehir).
  ///
  /// Uygulama çalışırken kullanılmaz — liste `assets/cities.tsv.gz` olarak
  /// gömülüdür. Bu metod yalnızca `tool/build_city_db.dart` içindir.
  Future<String> fetchCityListRaw() =>
      _get(Uri.parse('$base?pg=2'), timeout: const Duration(minutes: 3));

  Future<String> _get(
    Uri uri, {
    Duration? timeout,
    Exception Function()? onServerError,
  }) async {
    try {
      final response = await _client
          .get(uri, headers: const {'User-Agent': userAgent})
          .timeout(timeout ?? this.timeout);
      if (response.statusCode >= 500 && onServerError != null) {
        throw onServerError();
      }
      if (response.statusCode != 200) {
        throw TurktakvimNetworkException(
            'Sunucu ${response.statusCode} döndü: $uri');
      }
      // Sunucu charset başlığı göndermiyor; yanıt UTF-8.
      return utf8.decode(response.bodyBytes, allowMalformed: true);
    } on TimeoutException {
      throw TurktakvimNetworkException('Zaman aşımı: $uri');
    } on http.ClientException catch (e) {
      throw TurktakvimNetworkException('Bağlantı hatası: ${e.message}');
    }
  }

  void close() => _client.close();
}
