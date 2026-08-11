import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../core/calendar_source.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'models/city.dart';

/// turktakvim'in 234 ülke / 122.000+ şehirlik listesi.
///
/// Liste `assets/cities.tsv.gz` olarak uygulamaya gömülüdür; arama tamamen
/// çevrimdışı çalışır. Dosya biçimi:
///
/// ```
/// #Afganistan
/// 127079<TAB>Ab Band-Badakhshan
/// #Almanya
/// 12345<TAB>Berlin-Berlin
/// ```
class CityRepository {
  CityRepository();

  static const int defaultCityId = 64814; // Schönberg - Fribourg / İsviçre

  /// Her takvim kaynağının kendi şehir listesi var; kimlikler birbirine
  /// uymadığı için ayrı ayrı yüklenip ayrı ayrı saklanır.
  final Map<CalendarSource, _CityIndex> _indexes = {};
  final Map<CalendarSource, Future<_CityIndex>> _loading = {};

  /// Aramaların hangi kaynağın listesinde yapılacağı.
  CalendarSource source = CalendarSource.turktakvim;

  CalendarSource get _current => source;

  Future<void> ensureLoaded([CalendarSource? source]) =>
      _load(source ?? _current);

  Future<_CityIndex> _load(CalendarSource source) {
    final existing = _indexes[source];
    if (existing != null) return Future.value(existing);
    return _loading[source] ??= () async {
      final bytes = await rootBundle.load(source.cityAsset);
      final index = await compute(_parseIndex, bytes.buffer.asUint8List());
      _indexes[source] = index;
      _loading.remove(source);
      return index;
    }();
  }

  /// Toplam şehir sayısı (liste yüklendikten sonra).
  int get cityCount => _indexes[_current]?.ids.length ?? 0;

  Future<City?> byId(int id) async {
    final index = await _load(_current);
    final i = index.positionOf(id);
    return i == null ? null : index.cityAt(i);
  }

  /// [query] ile eşleşen şehirleri döndürür.
  ///
  /// Arama Türkçe karakterlere ve büyük/küçük harfe duyarsızdır: "istanbul",
  /// "İSTANBUL" ve "ıstanbul" aynı sonucu verir. Adın başında eşleşenler
  /// öne alınır.
  Future<List<City>> search(String query, {int limit = 60}) async {
    final index = await _load(_current);
    final q = normalizeForSearch(query.trim());
    if (q.isEmpty) return const [];

    final starts = <int>[];
    final contains = <int>[];
    for (var i = 0; i < index.normalized.length; i++) {
      final name = index.normalized[i];
      if (name.startsWith(q)) {
        starts.add(i);
        if (starts.length >= limit) break;
      } else if (contains.length < limit && name.contains(q)) {
        contains.add(i);
      }
    }

    final picked = [...starts, ...contains].take(limit);
    return [for (final i in picked) index.cityAt(i)];
  }

  /// Ülkelere göre gruplanmış tam liste — "ülke listesi" ekranı için.
  Future<List<String>> countries() async => (await _load(_current)).countries;

  Future<List<City>> citiesOfCountry(String country) async {
    final index = await _load(_current);
    final ci = index.countries.indexOf(country);
    if (ci < 0) return const [];
    return [
      for (var i = 0; i < index.countryOf.length; i++)
        if (index.countryOf[i] == ci) index.cityAt(i),
    ];
  }
}

/// Bellek dostu ayrıştırılmış liste: nesne başına `City` yaratmak yerine
/// paralel diziler tutulur, `City` yalnızca istendiğinde üretilir.
class _CityIndex {
  _CityIndex({
    required this.ids,
    required this.names,
    required this.normalized,
    required this.countryOf,
    required this.countries,
  });

  final Int32List ids;
  final List<String> names;
  final List<String> normalized;
  final Uint16List countryOf;
  final List<String> countries;

  int? positionOf(int id) {
    for (var i = 0; i < ids.length; i++) {
      if (ids[i] == id) return i;
    }
    return null;
  }

  City cityAt(int i) => City(
        id: ids[i],
        name: names[i],
        country: countries[countryOf[i]],
      );
}

/// Ayrı bir isolate'te çalışır — 122.000 satırın ayrıştırılması ve
/// normalize edilmesi arayüzü kilitlemesin.
_CityIndex _parseIndex(Uint8List gzipped) {
  final text = utf8.decode(gzip.decode(gzipped));
  final lines = const LineSplitter().convert(text);

  final ids = <int>[];
  final names = <String>[];
  final normalized = <String>[];
  final countryOf = <int>[];
  final countries = <String>[];

  var current = -1;
  for (final line in lines) {
    if (line.isEmpty) continue;
    if (line.codeUnitAt(0) == 0x23 /* # */) {
      countries.add(line.substring(1));
      current = countries.length - 1;
      continue;
    }
    final tab = line.indexOf('\t');
    if (tab <= 0 || current < 0) continue;
    final id = int.tryParse(line.substring(0, tab));
    if (id == null) continue;
    final name = line.substring(tab + 1);
    ids.add(id);
    names.add(name);
    normalized.add(normalizeForSearch(name));
    countryOf.add(current);
  }

  return _CityIndex(
    ids: Int32List.fromList(ids),
    names: names,
    normalized: normalized,
    countryOf: Uint16List.fromList(countryOf),
    countries: countries,
  );
}
