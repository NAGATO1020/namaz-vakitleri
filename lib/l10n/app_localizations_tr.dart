// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Namaz Vakitleri';

  @override
  String get nextPrayer => 'Sıradaki vakit';

  @override
  String get remainingTime => 'Kalan süre';

  @override
  String get currentPrayer => 'İçinde bulunulan vakit';

  @override
  String get today => 'Bugün';

  @override
  String get tomorrow => 'Yarın';

  @override
  String get settings => 'Ayarlar';

  @override
  String get close => 'Kapat';

  @override
  String get retry => 'Tekrar dene';

  @override
  String get cancel => 'Vazgeç';

  @override
  String get done => 'Tamam';

  @override
  String get theme => 'Tema';

  @override
  String get themeSystem => 'Sistem';

  @override
  String get themeLight => 'Açık';

  @override
  String get themeDark => 'Koyu';

  @override
  String get language => 'Dil';

  @override
  String get languageSystem => 'Sistem dili';

  @override
  String get languageTurkish => 'Türkçe';

  @override
  String get languageEnglish => 'English';

  @override
  String get location => 'Konum';

  @override
  String get changeCity => 'Şehri değiştir';

  @override
  String get citySearchTitle => 'Şehir ara';

  @override
  String get citySearchHint => 'Şehir adı yazınız';

  @override
  String get citySearchEmpty => 'Aramak için şehir adı yazın';

  @override
  String get citySearchNoResult => 'Sonuç bulunamadı';

  @override
  String cityCount(int count) {
    return '$count şehir';
  }

  @override
  String get visiblePrayersTitle => 'Görünen vakitler';

  @override
  String get visiblePrayersSubtitle =>
      'Ana ekranda ve widget\'larda hangi vakitler görünsün';

  @override
  String get selectAll => 'Hepsini seç';

  @override
  String get clearAll => 'Hiçbirini seçme';

  @override
  String get notificationsTitle => 'Bildirimler';

  @override
  String get prayerNotifications => 'Vakit bildirimleri';

  @override
  String get prayerNotificationsSubtitle =>
      'Seçilen vakit girdiğinde bildirim gönder';

  @override
  String get notifyPrayersTitle => 'Bildirim gönderilecek vakitler';

  @override
  String get persistentNotification => 'Kalıcı bildirim';

  @override
  String get persistentNotificationSubtitle =>
      'Bildirim çubuğunda vakitler ve geri sayım';

  @override
  String get showSeconds => 'Geri sayımda saniye göster';

  @override
  String get monthlyTitle => 'Aylık vakitler';

  @override
  String get downloadMonth => 'Bu ayı indir';

  @override
  String downloading(int done, int total) {
    return 'İndiriliyor… $done/$total';
  }

  @override
  String monthDownloaded(int count) {
    return '$count gün indirildi, telefonda saklanıyor';
  }

  @override
  String monthPartial(int failed) {
    return '$failed gün indirilemedi, tekrar deneyebilirsiniz';
  }

  @override
  String monthCached(int cached, int total) {
    return '$cached/$total gün telefonda mevcut';
  }

  @override
  String get previousMonth => 'Önceki ay';

  @override
  String get nextMonth => 'Sonraki ay';

  @override
  String get errorOffline =>
      'İnternet bağlantısı yok. Kayıtlı vakitler gösteriliyor.';

  @override
  String get errorNoData => 'Bu gün için kayıtlı vakit yok. Bağlanıp indirin.';

  @override
  String get errorCityNotSupported =>
      'Bu şehir için vakitler hesaplanamıyor. Güneşin ufkun altına inmediği enlemlerde vakitler tanımsızdır; lütfen yakın bir şehir seçin.';

  @override
  String errorGeneric(String message) {
    return 'Bir hata oldu: $message';
  }

  @override
  String get calendarSourceTitle => 'Takvim';

  @override
  String get calendarSourceSubtitle =>
      'Vakitler seçtiğiniz takvimden alınır. Takvimi değiştirince öncekinin indirdiği vakitler silinir.';

  @override
  String sourceFull(int count) {
    return '$count vakit · aylık indirme yapılabilir';
  }

  @override
  String sourceLimited(int count) {
    return '$count vakit · yalnızca dün, bugün ve yarın';
  }

  @override
  String sourceChangeTitle(String name) {
    return '$name kullanılsın mı?';
  }

  @override
  String get sourceChangeBody =>
      'Önceki takvimden indirilen bütün vakitler silinecek ve şehri yeniden seçmeniz gerekecek. İki takvimin şehir listeleri farklıdır.';

  @override
  String monthUnsupported(String name) {
    return '$name yalnızca dün, bugün ve yarının vakitlerini veriyor; aylık indirme yapılamaz. Uygulamayı her açtığınızda bu üç gün tazelenir.';
  }

  @override
  String get retentionNote =>
      'Bir aydan eski vakitler yer kaplamasın diye silinir.';

  @override
  String get holyDayToday => 'BUGÜN MÜBÂREK GÜN';

  @override
  String get holyDaysUpcoming => 'Yaklaşan mübârek günler';

  @override
  String get holyDaysTitle => 'Mübârek günler';

  @override
  String get holyDaysEmpty => 'Mübârek günler için internete bağlanın';

  @override
  String daysAway(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days gün sonra',
      one: 'yarın',
      zero: 'bugün',
    );
    return '$_temp0';
  }

  @override
  String updateAvailable(String version) {
    return '$version güncellemesi var';
  }

  @override
  String get updateNow => 'Güncelle';

  @override
  String get updateDownloading => 'İndiriliyor…';

  @override
  String updateDownloadingPercent(int percent) {
    return 'İndiriliyor… %$percent';
  }

  @override
  String get updateFailed => 'Güncelleme indirilemedi';

  @override
  String updateCurrentVersion(String version) {
    return 'Kurulu sürüm $version';
  }

  @override
  String get updateCheck => 'Güncellemeleri denetle';

  @override
  String get updateUpToDate => 'En son sürümü kullanıyorsunuz';

  @override
  String get autoNextMonth => 'Ay bitmeden gelecek ay otomatik iner';

  @override
  String get sourceTitle => 'Kaynak';

  @override
  String sourceNote(String name) {
    return 'Bütün vakitler $name tarafından hesaplanmaktadır.';
  }

  @override
  String openSource(String host) {
    return '$host adresini aç';
  }

  @override
  String get hijriDate => 'Hicrî';

  @override
  String get qiblaHourNote =>
      'Kıble Sâati\'nde güneşe dönen, kıbleye dönmüş olur.';

  @override
  String get permissionNotificationTitle => 'Bildirim izni gerekli';

  @override
  String get permissionNotificationBody =>
      'Vakit bildirimleri için bildirim iznine ihtiyaç var.';

  @override
  String get permissionExactAlarmTitle => 'Tam zamanlı alarm izni';

  @override
  String get permissionExactAlarmBody =>
      'Bildirimlerin vaktinde gelmesi için \'alarm ve hatırlatıcılar\' iznini vermeniz gerekir.';

  @override
  String get permissionBatteryTitle => 'Pil optimizasyonu';

  @override
  String get permissionBatteryBody =>
      'Telefon uygulamayı uykuya alırsa bildirimler gecikebilir. Pil optimizasyonundan muaf tutmanız önerilir.';

  @override
  String get grantPermission => 'İzin ver';

  @override
  String get later => 'Sonra';

  @override
  String get notificationChannelPrayerName => 'Vakit bildirimleri';

  @override
  String get notificationChannelPrayerDescription =>
      'Namaz vakti girdiğinde bildirim';

  @override
  String get notificationChannelOngoingName => 'Kalıcı vakit bildirimi';

  @override
  String get notificationChannelOngoingDescription =>
      'Bildirim çubuğundaki vakitler ve geri sayım';

  @override
  String notificationPrayerEntered(String prayer) {
    return '$prayer vakti girdi';
  }

  @override
  String get widgetNextPrayerName => 'Sıradaki vakit';

  @override
  String get widgetDailyTimesName => 'Günün vakitleri';

  @override
  String get widgetCompactName => 'Kompakt vakit';
}
