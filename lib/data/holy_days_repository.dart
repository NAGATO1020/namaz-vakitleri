import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models/holy_day.dart';
import 'turktakvim_api.dart';

/// Mübârek günleri turktakvim'den alır ve saklar.
///
/// Kaynak: `https://turktakvim.com/yillikhicri.php` — "Senelik Hicrî Kamerî
/// Târîhler" sayfası. Tek istekte bütün yılın milâdî↔hicrî eşlemesi ve
/// "Mubârek Günler" sütunu geliyor; uygulama hiçbir günü kendisi hesaplamıyor.
///
/// Sayfa yıl parametresi kabul etmiyor, daima **içinde bulunulan yılı**
/// döndürüyor. Bu yüzden yılda bir kez çekilip saklanır; yıl değişince
/// kendiliğinden tazelenir.
class HolyDaysRepository {
  HolyDaysRepository({http.Client? client})
      : _client = client ?? http.Client();

  static const String url = 'https://turktakvim.com/yillikhicri.php';

  final http.Client _client;

  List<HolyDay>? _cached;
  int? _cachedYear;
  Future<List<HolyDay>>? _inFlight;

  /// Verilen yıla âit mübârek günler. Önbellekte yoksa ağdan çeker.
  /// Ağ yoksa ve önbellek de boşsa boş liste döner — uygulama çalışmaya
  /// devam eder, sadece mübârek gün gösterilmez.
  Future<List<HolyDay>> forYear(int year, {List<HolyDay>? stored}) async {
    if (_cachedYear == year && _cached != null) return _cached!;

    if (stored != null && stored.isNotEmpty && stored.first.date.year == year) {
      _cachedYear = year;
      return _cached = stored;
    }

    return _inFlight ??= () async {
      try {
        final fetched = await _fetch();
        if (fetched.isNotEmpty && fetched.first.date.year == year) {
          _cachedYear = year;
          _cached = fetched;
          return fetched;
        }
        // Site başka bir yıl döndürdüyse (yıl dönümü çevresi) zorlamayalım.
        return fetched;
      } catch (e) {
        debugPrint('Mübârek günler alınamadı: $e');
        return const <HolyDay>[];
      } finally {
        _inFlight = null;
      }
    }();
  }

  Future<List<HolyDay>> _fetch() async {
    final response = await _client.get(
      Uri.parse(url),
      headers: const {'User-Agent': TurktakvimApi.userAgent},
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw TurktakvimNetworkException(
          'Mübârek günler sayfası ${response.statusCode} döndü');
    }
    return parse(utf8.decode(response.bodyBytes, allowMalformed: true));
  }

  /// Sayfadaki tabloyu ayrıştırır.
  ///
  /// Satır biçimi:
  /// ```html
  /// <tr class="active"><td>15-01-2026</td><td>26  RECEB  1447</td><td>Mi'râc Kandili Gecesi</td></tr>
  /// ```
  /// Üçüncü hücresi boş olan satırlar sıradan günlerdir, atlanır.
  @visibleForTesting
  static List<HolyDay> parse(String html) {
    final rows = RegExp(
      r'<tr[^>]*>\s*<td[^>]*>\s*(\d{2})-(\d{2})-(\d{4})\s*</td>\s*'
      r'<td[^>]*>(.*?)</td>\s*<td[^>]*>(.*?)</td>',
      dotAll: true,
    ).allMatches(html);

    final out = <HolyDay>[];
    for (final row in rows) {
      final name = _clean(row.group(5)!);
      if (name.isEmpty) continue;
      out.add(HolyDay(
        date: DateTime(
          int.parse(row.group(3)!),
          int.parse(row.group(2)!),
          int.parse(row.group(1)!),
        ),
        hijri: _clean(row.group(4)!),
        nameTr: name,
      ));
    }
    return out;
  }

  static String _clean(String value) => _decodeEntities(
        value.replaceAll(RegExp(r'<[^>]+>'), ''),
      ).replaceAll(RegExp(r'\s+'), ' ').trim();

  /// HTML varlıklarını çözer.
  ///
  /// Sayfa bugün harfleri doğrudan UTF-8 yazıyor, ama aynı sitenin başka
  /// sayfaları `&acirc;` gibi varlıklar kullanıyor; ileride burada da
  /// çıkarsa ad bozulmasın diye çözülüyor.
  static String _decodeEntities(String input) {
    if (!input.contains('&')) return input;
    return input.replaceAllMapped(
      RegExp(r'&(#x?[0-9a-fA-F]+|[a-zA-Z]+);'),
      (match) {
        final body = match.group(1)!;
        if (body.startsWith('#')) {
          final hex = body.startsWith('#x') || body.startsWith('#X');
          final digits = body.substring(hex ? 2 : 1);
          final code = int.tryParse(digits, radix: hex ? 16 : 10);
          return code == null ? match.group(0)! : String.fromCharCode(code);
        }
        return _named[body] ?? match.group(0)!;
      },
    );
  }

  static const Map<String, String> _named = {
    'nbsp': ' ',
    'amp': '&',
    'lt': '<',
    'gt': '>',
    'quot': '"',
    'apos': "'",
    'acirc': 'â',
    'Acirc': 'Â',
    'icirc': 'î',
    'Icirc': 'Î',
    'ucirc': 'û',
    'Ucirc': 'Û',
    'ecirc': 'ê',
    'Ecirc': 'Ê',
    'ocirc': 'ô',
    'Ocirc': 'Ô',
    'uuml': 'ü',
    'Uuml': 'Ü',
    'ouml': 'ö',
    'Ouml': 'Ö',
    'ccedil': 'ç',
    'Ccedil': 'Ç',
    'scaron': 'š',
    'ntilde': 'ñ',
  };

  void close() => _client.close();
}

/// Bir mübârek gün listesinde gezinmek için kısayollar.
extension HolyDayLookup on List<HolyDay> {
  /// Verilen güne düşen mübârek gün (yoksa null).
  HolyDay? on(DateTime day) {
    for (final holy in this) {
      if (holy.date.year == day.year &&
          holy.date.month == day.month &&
          holy.date.day == day.day) {
        return holy;
      }
    }
    return null;
  }

  /// Bugünden sonraki ilk [count] mübârek gün.
  List<HolyDay> upcoming(DateTime from, {int count = 5}) {
    final start = DateTime(from.year, from.month, from.day);
    return where((h) => !h.date.isBefore(start)).take(count).toList();
  }
}
