/// turktakvim'in "Senelik Hicrî Kamerî Târîhler" sayfasındaki bir mübârek gün.
///
/// İsimler siteden geldiği gibi korunur (ör. "Kadr Gecesi", "Fıtr Bayramı
/// Gecesi"); uygulama kendi başına bir gün hesaplamaz. Kandil geceleri de
/// sitede zaten bir önceki güne yazılıdır — akşam ezânıyla başladıkları için.
class HolyDay {
  const HolyDay({
    required this.date,
    required this.hijri,
    required this.nameTr,
  });

  /// Milâdî gün (saat bileşeni yok).
  final DateTime date;

  /// "26 RECEB 1447" gibi normalize edilmiş hicrî târih.
  final String hijri;

  /// Sitedeki Türkçe ad.
  final String nameTr;

  String localizedName(String languageCode) =>
      languageCode == 'en' ? (_englishName(nameTr) ?? nameTr) : nameTr;

  /// Türkçe adların İngilizce karşılıkları. Eşleşmeyen bir ad çıkarsa
  /// Türkçesi olduğu gibi gösterilir — yanlış çevirmektense aynen bırakmak
  /// daha doğru.
  static String? _englishName(String tr) {
    final numbered = RegExp(r'^(.*?)\s*(\d+)\.\s*Günü$').firstMatch(tr);
    if (numbered != null) {
      final base = numbered.group(1)!.trim();
      final day = numbered.group(2)!;
      if (base.startsWith('Ramezân') || base.startsWith('Ramazan')) {
        return 'Eid al-Fitr, day $day';
      }
      if (base.startsWith('Kurban')) return 'Eid al-Adha, day $day';
    }

    for (final entry in _map.entries) {
      if (tr.startsWith(entry.key)) return entry.value;
    }
    return null;
  }

  static const Map<String, String> _map = {
    "Mi'râc Kandili": 'Night of Mi‘raj',
    'Berât Kandili': 'Night of Bara’ah',
    'Regâib Kandili': 'Night of Ragha’ib (first Friday night of Rajab)',
    'Mevlid Kandili': 'Night of Mawlid',
    'Kadr Gecesi': 'Night of Qadr',
    'Ramezân-ı şerîf’in başlangıcı': 'Beginning of Ramadan',
    "Ramezân-ı şerîf'in başlangıcı": 'Beginning of Ramadan',
    'Fıtr Bayramı Gecesi': 'Eve of Eid al-Fitr',
    'Terviye Günü': 'Day of Tarwiyah',
    'Arefe Günü': 'Day of Arafah',
    'Hicrî Yılbaşı Gecesi': 'Eve of the Hijri New Year',
    'Hicrî Yılbaşı': 'Hijri New Year',
    'Aşûre Gecesi': 'Night of Ashura',
    'Aşûre Günü': 'Day of Ashura',
  };

  Map<String, Object?> toDbRow() => {
        'date': _key(date),
        'hijri': hijri,
        'name': nameTr,
      };

  static HolyDay fromDbRow(Map<String, Object?> row) => HolyDay(
        date: DateTime.parse(row['date']! as String),
        hijri: (row['hijri'] as String?) ?? '',
        nameTr: (row['name'] as String?) ?? '',
      );

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  String toString() => '${_key(date)} $nameTr';
}
