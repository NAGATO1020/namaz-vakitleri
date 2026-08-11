/// turktakvim şehir listesindeki bir kayıt.
///
/// [id], API'nin `cityID` değeridir. [name] "Şehir-İl" biçiminde gelir
/// (ör. `Schönberg-Fribourg`, `İstanbul-İstanbul`).
class City {
  const City({
    required this.id,
    required this.name,
    required this.country,
  });

  final int id;
  final String name;
  final String country;

  /// "Şehir-İl" biçimindeki adın şehir kısmı.
  String get shortName {
    final i = name.lastIndexOf('-');
    return i <= 0 ? name : name.substring(0, i);
  }

  /// "Şehir-İl" biçimindeki adın il/bölge kısmı; yoksa boş.
  String get province {
    final i = name.lastIndexOf('-');
    return i <= 0 ? '' : name.substring(i + 1);
  }

  @override
  bool operator ==(Object other) => other is City && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'City($id, $name, $country)';
}

/// Türkçe'ye duyarlı, aksan/büyük-küçük harf farkını yok sayan arama anahtarı.
///
/// "Istanbul", "istanbul", "İSTANBUL" ve "ıstanbul" hepsi aynı anahtara düşer;
/// böylece klavyeden Türkçe karakter yazmayan kullanıcı da şehri bulabilir.
String normalizeForSearch(String input) {
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    buffer.write(_foldMap[rune] ?? String.fromCharCode(rune));
  }
  return buffer.toString();
}

const Map<int, String> _foldMap = {
  0x131: 'i', // ı
  0x69: 'i', // i
  0x130: 'i', // İ  (toLowerCase sonrası 'i̇' olabilir, yine de kapsıyoruz)
  0x307: '', // combining dot above (İ.toLowerCase() bunu üretir)
  0x15F: 's', // ş
  0x11F: 'g', // ğ
  0xFC: 'u', // ü
  0xF6: 'o', // ö
  0xE7: 'c', // ç
  0xE2: 'a', // â
  0xEE: 'i', // î
  0xFB: 'u', // û
  0xE1: 'a', // á
  0xE0: 'a', // à
  0xE4: 'a', // ä
  0xE9: 'e', // é
  0xE8: 'e', // è
  0xEA: 'e', // ê
  0xEB: 'e', // ë
  0xED: 'i', // í
  0xEF: 'i', // ï
  0xF3: 'o', // ó
  0xF2: 'o', // ò
  0xF4: 'o', // ô
  0xF5: 'o', // õ
  0xFA: 'u', // ú
  0xF9: 'u', // ù
  0xF1: 'n', // ñ
  0xE5: 'a', // å
  0xF8: 'o', // ø
  0xE6: 'ae', // æ
  0xDF: 'ss', // ß
};
