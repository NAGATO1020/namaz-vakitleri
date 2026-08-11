import 'prayer.dart';

/// Vakitlerin alınacağı takvim.
///
/// İki kaynak aynı vakitleri farklı usûllerle hesaplıyor ve farklı sayıda
/// vakit veriyor; hangisinin kullanılacağı ayarlardan seçilir.
enum CalendarSource {
  /// Türkiye Takvimi — 18 vakit, istenen târih için veri verir.
  turktakvim(
    id: 'turktakvim',
    displayName: 'Türkiye Takvimi',
    homepage: 'https://turktakvim.com',
    cityAsset: 'assets/cities.tsv.gz',
  ),

  /// Fazilet Takvimi — 8 vakit, yalnızca dün/bugün/yarın.
  fazilet(
    id: 'fazilet',
    displayName: 'Fazilet Takvimi',
    homepage: 'https://fazilettakvimi.com',
    cityAsset: 'assets/fazilet_cities.tsv.gz',
  );

  const CalendarSource({
    required this.id,
    required this.displayName,
    required this.homepage,
    required this.cityAsset,
  });

  /// Ayarlarda saklanan değer.
  final String id;
  final String displayName;
  final String homepage;

  /// Şehir listesinin gömülü olduğu varlık dosyası.
  final String cityAsset;

  /// Bu kaynağın verdiği vakitler. Vermediği vakitler ne ana ekranda ne de
  /// bildirimde görünür — olmayan bir vakti boş göstermek yanıltıcı olurdu.
  Set<Prayer> get supportedPrayers => switch (this) {
        CalendarSource.turktakvim => Prayer.values.toSet(),
        CalendarSource.fazilet => const {
            Prayer.imsak,
            Prayer.sabah,
            Prayer.gunes,
            Prayer.israk,
            Prayer.ogle,
            Prayer.ikindi,
            Prayer.aksam,
            Prayer.yatsi,
          },
      };

  /// İstenen bir târihin vakitleri çekilebiliyor mu.
  ///
  /// Fazilet yalnızca dün/bugün/yarını veriyor; bu yüzden orada "bir aylık
  /// indirme" yapılamaz, uygulama her açılışta üç günü tazeler.
  bool get supportsArbitraryDate => this == CalendarSource.turktakvim;

  /// Bir istekte kaç günlük veri döndüğü.
  int get daysPerFetch => this == CalendarSource.fazilet ? 3 : 1;

  /// Mübârek günler yalnızca turktakvim'de var; Fazilet böyle bir liste
  /// yayınlamıyor. Kaynak Fazilet olsa da mübârek günleri turktakvim'den
  /// göstermek karışıklık yaratacağı için gizleniyor.
  bool get hasHolyDays => this == CalendarSource.turktakvim;

  static CalendarSource fromId(String? id) => values.firstWhere(
        (s) => s.id == id,
        orElse: () => CalendarSource.turktakvim,
      );
}
