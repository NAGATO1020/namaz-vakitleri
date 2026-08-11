import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In tr, this message translates to:
  /// **'Namaz Vakitleri'**
  String get appTitle;

  /// No description provided for @nextPrayer.
  ///
  /// In tr, this message translates to:
  /// **'Sıradaki vakit'**
  String get nextPrayer;

  /// No description provided for @remainingTime.
  ///
  /// In tr, this message translates to:
  /// **'Kalan süre'**
  String get remainingTime;

  /// No description provided for @currentPrayer.
  ///
  /// In tr, this message translates to:
  /// **'İçinde bulunulan vakit'**
  String get currentPrayer;

  /// No description provided for @today.
  ///
  /// In tr, this message translates to:
  /// **'Bugün'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In tr, this message translates to:
  /// **'Yarın'**
  String get tomorrow;

  /// No description provided for @settings.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar'**
  String get settings;

  /// No description provided for @close.
  ///
  /// In tr, this message translates to:
  /// **'Kapat'**
  String get close;

  /// No description provided for @retry.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar dene'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get cancel;

  /// No description provided for @done.
  ///
  /// In tr, this message translates to:
  /// **'Tamam'**
  String get done;

  /// No description provided for @theme.
  ///
  /// In tr, this message translates to:
  /// **'Tema'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In tr, this message translates to:
  /// **'Sistem'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In tr, this message translates to:
  /// **'Açık'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In tr, this message translates to:
  /// **'Koyu'**
  String get themeDark;

  /// No description provided for @language.
  ///
  /// In tr, this message translates to:
  /// **'Dil'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In tr, this message translates to:
  /// **'Sistem dili'**
  String get languageSystem;

  /// No description provided for @languageTurkish.
  ///
  /// In tr, this message translates to:
  /// **'Türkçe'**
  String get languageTurkish;

  /// No description provided for @languageEnglish.
  ///
  /// In tr, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @location.
  ///
  /// In tr, this message translates to:
  /// **'Konum'**
  String get location;

  /// No description provided for @changeCity.
  ///
  /// In tr, this message translates to:
  /// **'Şehri değiştir'**
  String get changeCity;

  /// No description provided for @citySearchTitle.
  ///
  /// In tr, this message translates to:
  /// **'Şehir ara'**
  String get citySearchTitle;

  /// No description provided for @citySearchHint.
  ///
  /// In tr, this message translates to:
  /// **'Şehir adı yazınız'**
  String get citySearchHint;

  /// No description provided for @citySearchEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Aramak için şehir adı yazın'**
  String get citySearchEmpty;

  /// No description provided for @citySearchNoResult.
  ///
  /// In tr, this message translates to:
  /// **'Sonuç bulunamadı'**
  String get citySearchNoResult;

  /// No description provided for @cityCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} şehir'**
  String cityCount(int count);

  /// No description provided for @visiblePrayersTitle.
  ///
  /// In tr, this message translates to:
  /// **'Görünen vakitler'**
  String get visiblePrayersTitle;

  /// No description provided for @visiblePrayersSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Ana ekranda ve widget\'larda hangi vakitler görünsün'**
  String get visiblePrayersSubtitle;

  /// No description provided for @selectAll.
  ///
  /// In tr, this message translates to:
  /// **'Hepsini seç'**
  String get selectAll;

  /// No description provided for @clearAll.
  ///
  /// In tr, this message translates to:
  /// **'Hiçbirini seçme'**
  String get clearAll;

  /// No description provided for @notificationsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bildirimler'**
  String get notificationsTitle;

  /// No description provided for @prayerNotifications.
  ///
  /// In tr, this message translates to:
  /// **'Vakit bildirimleri'**
  String get prayerNotifications;

  /// No description provided for @prayerNotificationsSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Seçilen vakit girdiğinde bildirim gönder'**
  String get prayerNotificationsSubtitle;

  /// No description provided for @notifyPrayersTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bildirim gönderilecek vakitler'**
  String get notifyPrayersTitle;

  /// No description provided for @persistentNotification.
  ///
  /// In tr, this message translates to:
  /// **'Kalıcı bildirim'**
  String get persistentNotification;

  /// No description provided for @persistentNotificationSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Bildirim çubuğunda vakitler ve geri sayım'**
  String get persistentNotificationSubtitle;

  /// No description provided for @showSeconds.
  ///
  /// In tr, this message translates to:
  /// **'Geri sayımda saniye göster'**
  String get showSeconds;

  /// No description provided for @monthlyTitle.
  ///
  /// In tr, this message translates to:
  /// **'Aylık vakitler'**
  String get monthlyTitle;

  /// No description provided for @downloadMonth.
  ///
  /// In tr, this message translates to:
  /// **'Bu ayı indir'**
  String get downloadMonth;

  /// No description provided for @downloading.
  ///
  /// In tr, this message translates to:
  /// **'İndiriliyor… {done}/{total}'**
  String downloading(int done, int total);

  /// No description provided for @monthDownloaded.
  ///
  /// In tr, this message translates to:
  /// **'{count} gün indirildi, telefonda saklanıyor'**
  String monthDownloaded(int count);

  /// No description provided for @monthPartial.
  ///
  /// In tr, this message translates to:
  /// **'{failed} gün indirilemedi, tekrar deneyebilirsiniz'**
  String monthPartial(int failed);

  /// No description provided for @monthCached.
  ///
  /// In tr, this message translates to:
  /// **'{cached}/{total} gün telefonda mevcut'**
  String monthCached(int cached, int total);

  /// No description provided for @previousMonth.
  ///
  /// In tr, this message translates to:
  /// **'Önceki ay'**
  String get previousMonth;

  /// No description provided for @nextMonth.
  ///
  /// In tr, this message translates to:
  /// **'Sonraki ay'**
  String get nextMonth;

  /// No description provided for @errorOffline.
  ///
  /// In tr, this message translates to:
  /// **'İnternet bağlantısı yok. Kayıtlı vakitler gösteriliyor.'**
  String get errorOffline;

  /// No description provided for @errorNoData.
  ///
  /// In tr, this message translates to:
  /// **'Bu gün için kayıtlı vakit yok. Bağlanıp indirin.'**
  String get errorNoData;

  /// No description provided for @errorCityNotSupported.
  ///
  /// In tr, this message translates to:
  /// **'Bu şehir için vakitler hesaplanamıyor. Güneşin ufkun altına inmediği enlemlerde vakitler tanımsızdır; lütfen yakın bir şehir seçin.'**
  String get errorCityNotSupported;

  /// No description provided for @errorGeneric.
  ///
  /// In tr, this message translates to:
  /// **'Bir hata oldu: {message}'**
  String errorGeneric(String message);

  /// No description provided for @calendarSourceTitle.
  ///
  /// In tr, this message translates to:
  /// **'Takvim'**
  String get calendarSourceTitle;

  /// No description provided for @calendarSourceSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Vakitler seçtiğiniz takvimden alınır. Takvimi değiştirince öncekinin indirdiği vakitler silinir.'**
  String get calendarSourceSubtitle;

  /// No description provided for @sourceFull.
  ///
  /// In tr, this message translates to:
  /// **'{count} vakit · aylık indirme yapılabilir'**
  String sourceFull(int count);

  /// No description provided for @sourceLimited.
  ///
  /// In tr, this message translates to:
  /// **'{count} vakit · yalnızca dün, bugün ve yarın'**
  String sourceLimited(int count);

  /// No description provided for @sourceChangeTitle.
  ///
  /// In tr, this message translates to:
  /// **'{name} kullanılsın mı?'**
  String sourceChangeTitle(String name);

  /// No description provided for @sourceChangeBody.
  ///
  /// In tr, this message translates to:
  /// **'Önceki takvimden indirilen bütün vakitler silinecek ve şehri yeniden seçmeniz gerekecek. İki takvimin şehir listeleri farklıdır.'**
  String get sourceChangeBody;

  /// No description provided for @monthUnsupported.
  ///
  /// In tr, this message translates to:
  /// **'{name} yalnızca dün, bugün ve yarının vakitlerini veriyor; aylık indirme yapılamaz. Uygulamayı her açtığınızda bu üç gün tazelenir.'**
  String monthUnsupported(String name);

  /// No description provided for @retentionNote.
  ///
  /// In tr, this message translates to:
  /// **'Bir aydan eski vakitler yer kaplamasın diye silinir.'**
  String get retentionNote;

  /// No description provided for @holyDayToday.
  ///
  /// In tr, this message translates to:
  /// **'BUGÜN MÜBÂREK GÜN'**
  String get holyDayToday;

  /// No description provided for @holyDaysUpcoming.
  ///
  /// In tr, this message translates to:
  /// **'Yaklaşan mübârek günler'**
  String get holyDaysUpcoming;

  /// No description provided for @holyDaysTitle.
  ///
  /// In tr, this message translates to:
  /// **'Mübârek günler'**
  String get holyDaysTitle;

  /// No description provided for @holyDaysEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Mübârek günler için internete bağlanın'**
  String get holyDaysEmpty;

  /// No description provided for @daysAway.
  ///
  /// In tr, this message translates to:
  /// **'{days, plural, =0{bugün} =1{yarın} other{{days} gün sonra}}'**
  String daysAway(int days);

  /// No description provided for @updateAvailable.
  ///
  /// In tr, this message translates to:
  /// **'{version} güncellemesi var'**
  String updateAvailable(String version);

  /// No description provided for @updateNow.
  ///
  /// In tr, this message translates to:
  /// **'Güncelle'**
  String get updateNow;

  /// No description provided for @updateDownloading.
  ///
  /// In tr, this message translates to:
  /// **'İndiriliyor…'**
  String get updateDownloading;

  /// No description provided for @updateDownloadingPercent.
  ///
  /// In tr, this message translates to:
  /// **'İndiriliyor… %{percent}'**
  String updateDownloadingPercent(int percent);

  /// No description provided for @updateFailed.
  ///
  /// In tr, this message translates to:
  /// **'Güncelleme indirilemedi'**
  String get updateFailed;

  /// No description provided for @updateCurrentVersion.
  ///
  /// In tr, this message translates to:
  /// **'Kurulu sürüm {version}'**
  String updateCurrentVersion(String version);

  /// No description provided for @updateCheck.
  ///
  /// In tr, this message translates to:
  /// **'Güncellemeleri denetle'**
  String get updateCheck;

  /// No description provided for @updateUpToDate.
  ///
  /// In tr, this message translates to:
  /// **'En son sürümü kullanıyorsunuz'**
  String get updateUpToDate;

  /// No description provided for @autoNextMonth.
  ///
  /// In tr, this message translates to:
  /// **'Ay bitmeden gelecek ay otomatik iner'**
  String get autoNextMonth;

  /// No description provided for @sourceTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kaynak'**
  String get sourceTitle;

  /// No description provided for @sourceNote.
  ///
  /// In tr, this message translates to:
  /// **'Bütün vakitler {name} tarafından hesaplanmaktadır.'**
  String sourceNote(String name);

  /// No description provided for @openSource.
  ///
  /// In tr, this message translates to:
  /// **'{host} adresini aç'**
  String openSource(String host);

  /// No description provided for @hijriDate.
  ///
  /// In tr, this message translates to:
  /// **'Hicrî'**
  String get hijriDate;

  /// No description provided for @qiblaHourNote.
  ///
  /// In tr, this message translates to:
  /// **'Kıble Sâati\'nde güneşe dönen, kıbleye dönmüş olur.'**
  String get qiblaHourNote;

  /// No description provided for @permissionNotificationTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bildirim izni gerekli'**
  String get permissionNotificationTitle;

  /// No description provided for @permissionNotificationBody.
  ///
  /// In tr, this message translates to:
  /// **'Vakit bildirimleri için bildirim iznine ihtiyaç var.'**
  String get permissionNotificationBody;

  /// No description provided for @permissionExactAlarmTitle.
  ///
  /// In tr, this message translates to:
  /// **'Tam zamanlı alarm izni'**
  String get permissionExactAlarmTitle;

  /// No description provided for @permissionExactAlarmBody.
  ///
  /// In tr, this message translates to:
  /// **'Bildirimlerin vaktinde gelmesi için \'alarm ve hatırlatıcılar\' iznini vermeniz gerekir.'**
  String get permissionExactAlarmBody;

  /// No description provided for @permissionBatteryTitle.
  ///
  /// In tr, this message translates to:
  /// **'Pil optimizasyonu'**
  String get permissionBatteryTitle;

  /// No description provided for @permissionBatteryBody.
  ///
  /// In tr, this message translates to:
  /// **'Telefon uygulamayı uykuya alırsa bildirimler gecikebilir. Pil optimizasyonundan muaf tutmanız önerilir.'**
  String get permissionBatteryBody;

  /// No description provided for @grantPermission.
  ///
  /// In tr, this message translates to:
  /// **'İzin ver'**
  String get grantPermission;

  /// No description provided for @later.
  ///
  /// In tr, this message translates to:
  /// **'Sonra'**
  String get later;

  /// No description provided for @notificationChannelPrayerName.
  ///
  /// In tr, this message translates to:
  /// **'Vakit bildirimleri'**
  String get notificationChannelPrayerName;

  /// No description provided for @notificationChannelPrayerDescription.
  ///
  /// In tr, this message translates to:
  /// **'Namaz vakti girdiğinde bildirim'**
  String get notificationChannelPrayerDescription;

  /// No description provided for @notificationChannelOngoingName.
  ///
  /// In tr, this message translates to:
  /// **'Kalıcı vakit bildirimi'**
  String get notificationChannelOngoingName;

  /// No description provided for @notificationChannelOngoingDescription.
  ///
  /// In tr, this message translates to:
  /// **'Bildirim çubuğundaki vakitler ve geri sayım'**
  String get notificationChannelOngoingDescription;

  /// No description provided for @notificationPrayerEntered.
  ///
  /// In tr, this message translates to:
  /// **'{prayer} vakti girdi'**
  String notificationPrayerEntered(String prayer);

  /// No description provided for @widgetNextPrayerName.
  ///
  /// In tr, this message translates to:
  /// **'Sıradaki vakit'**
  String get widgetNextPrayerName;

  /// No description provided for @widgetDailyTimesName.
  ///
  /// In tr, this message translates to:
  /// **'Günün vakitleri'**
  String get widgetDailyTimesName;

  /// No description provided for @widgetCompactName.
  ///
  /// In tr, this message translates to:
  /// **'Kompakt vakit'**
  String get widgetCompactName;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
