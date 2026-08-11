/// turktakvim.com gadget API'sinin döndüğü 18 vakit.
///
/// `apiIndex`, `gadget.php?pg=1` yanıtındaki `;` ile ayrılmış alanın sırasıdır.
/// 7..23 arası vakitler kronolojik bir zincir oluşturur (gece yarısını geçenler
/// dâhil); 24 (Kıble Sâati) bu zincirin dışında, günün içinde duran bir andır.
enum Prayer {
  imsak(7, 'İmsâk', 'Imsak'),
  sabah(8, 'Sabâh', 'Fajr'),
  gunes(9, 'Güneş', 'Sunrise'),
  israk(10, 'İşrak', 'Ishraq'),
  dahveiKubra(11, 'Dahve-i Kübrâ', 'Dahwa-i Kubra'),
  kerahet(12, 'Kerâhet', 'Karahat'),
  ogle(13, 'Öğle', 'Dhuhr'),
  ikindi(14, 'İkindi', 'Asr'),
  asriSani(15, 'Asr-ı Sânî', 'Asr Thani'),
  isfirariSems(16, 'İsfirâr-ı Şems', 'Isfirar-i Shams'),
  aksam(17, 'Akşam', 'Maghrib'),
  istibakiNucum(18, 'İştibâk-i Nücûm', 'Ishtibak-i Nujum'),
  yatsi(19, 'Yatsı', 'Isha'),
  isaiSani(20, 'İşâ-i Sânî', 'Isha Thani'),
  geceYarisi(21, 'Gece Yarısı Vakti', 'Midnight'),
  teheccud(22, 'Teheccüd', 'Tahajjud'),
  seher(23, 'Seher', 'Sahar'),
  kibleSaati(24, 'Kıble Sâati', 'Qibla Hour');

  const Prayer(this.apiIndex, this.nameTr, this.nameEn);

  /// gadget.php yanıtındaki alan sırası.
  final int apiIndex;
  final String nameTr;
  final String nameEn;

  String localizedName(String languageCode) =>
      languageCode == 'en' ? nameEn : nameTr;

  /// Kıble Sâati kronolojik zincirin parçası değildir; sıradaki vakit
  /// hesabına ve gün geçişi mantığına katılmaz.
  bool get isInChronologicalChain => this != Prayer.kibleSaati;

  /// Beş farz namaz vakti — bildirimlerin varsayılanı.
  bool get isFard => const {
        Prayer.sabah,
        Prayer.ogle,
        Prayer.ikindi,
        Prayer.aksam,
        Prayer.yatsi,
      }.contains(this);

  /// Uygulama ilk açıldığında ana ekranda görünen vakitler.
  /// (Kullanıcının gönderdiği ekran görüntüsünde işâretli olanlar.)
  bool get visibleByDefault => const {
        Prayer.imsak,
        Prayer.sabah,
        Prayer.gunes,
        Prayer.israk,
        Prayer.ogle,
        Prayer.ikindi,
        Prayer.aksam,
        Prayer.yatsi,
        Prayer.kibleSaati,
      }.contains(this);

  /// Kronolojik zincirdeki vakitler, API sırasıyla.
  static List<Prayer> get chain =>
      Prayer.values.where((p) => p.isInChronologicalChain).toList();

  /// Kronolojik zincirdeki vakitler dışındaki tek vakit sayısı — iki sütunlu
  /// düzende sütun başına düşen vakit sayısını hesaplamak için.
  static int get halfCount => (Prayer.values.length + 1) ~/ 2;
}
