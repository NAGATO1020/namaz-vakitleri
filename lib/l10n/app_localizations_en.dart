// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Prayer Times';

  @override
  String get nextPrayer => 'Next prayer';

  @override
  String get remainingTime => 'Time remaining';

  @override
  String get currentPrayer => 'Current prayer';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get settings => 'Settings';

  @override
  String get close => 'Close';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get done => 'Done';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System language';

  @override
  String get languageTurkish => 'Türkçe';

  @override
  String get languageEnglish => 'English';

  @override
  String get location => 'Location';

  @override
  String get changeCity => 'Change city';

  @override
  String get citySearchTitle => 'Search city';

  @override
  String get citySearchHint => 'Type a city name';

  @override
  String get citySearchEmpty => 'Type a city name to search';

  @override
  String get citySearchNoResult => 'No results found';

  @override
  String cityCount(int count) {
    return '$count cities';
  }

  @override
  String get visiblePrayersTitle => 'Visible times';

  @override
  String get visiblePrayersSubtitle =>
      'Which times appear on the home screen and widgets';

  @override
  String get selectAll => 'Select all';

  @override
  String get clearAll => 'Clear all';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get prayerNotifications => 'Prayer alerts';

  @override
  String get prayerNotificationsSubtitle =>
      'Notify when a selected prayer time begins';

  @override
  String get notifyPrayersTitle => 'Times to be notified for';

  @override
  String get persistentNotification => 'Persistent notification';

  @override
  String get persistentNotificationSubtitle =>
      'Times and countdown in the status bar';

  @override
  String get showSeconds => 'Show seconds in countdown';

  @override
  String get monthlyTitle => 'Monthly times';

  @override
  String get downloadMonth => 'Download this month';

  @override
  String downloading(int done, int total) {
    return 'Downloading… $done/$total';
  }

  @override
  String monthDownloaded(int count) {
    return '$count days downloaded and stored on your phone';
  }

  @override
  String monthPartial(int failed) {
    return '$failed days could not be downloaded, you can try again';
  }

  @override
  String monthCached(int cached, int total) {
    return '$cached of $total days available offline';
  }

  @override
  String get previousMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String get errorOffline => 'No internet connection. Showing saved times.';

  @override
  String get errorNoData =>
      'No saved times for this day. Connect and download.';

  @override
  String get errorCityNotSupported =>
      'Prayer times cannot be calculated for this city. At latitudes where the sun does not set below the horizon the times are undefined; please pick a nearby city.';

  @override
  String errorGeneric(String message) {
    return 'Something went wrong: $message';
  }

  @override
  String get calendarSourceTitle => 'Calendar';

  @override
  String get calendarSourceSubtitle =>
      'Times come from the calendar you pick. Switching calendars deletes the times downloaded from the previous one.';

  @override
  String sourceFull(int count) {
    return '$count times · a month can be downloaded';
  }

  @override
  String sourceLimited(int count) {
    return '$count times · yesterday, today and tomorrow only';
  }

  @override
  String sourceChangeTitle(String name) {
    return 'Switch to $name?';
  }

  @override
  String get sourceChangeBody =>
      'All times downloaded from the previous calendar will be deleted and you will need to pick your city again. The two calendars use different city lists.';

  @override
  String monthUnsupported(String name) {
    return '$name only serves yesterday, today and tomorrow, so a month cannot be downloaded. These three days refresh every time you open the app.';
  }

  @override
  String get retentionNote =>
      'Times older than a month are deleted to save space.';

  @override
  String get holyDayToday => 'TODAY IS A HOLY DAY';

  @override
  String get holyDaysUpcoming => 'Upcoming holy days';

  @override
  String get holyDaysTitle => 'Holy days';

  @override
  String get holyDaysEmpty => 'Connect to the internet to load holy days';

  @override
  String daysAway(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'in $days days',
      one: 'tomorrow',
      zero: 'today',
    );
    return '$_temp0';
  }

  @override
  String updateAvailable(String version) {
    return 'Update $version is available';
  }

  @override
  String get updateNow => 'Update';

  @override
  String get updateDownloading => 'Downloading…';

  @override
  String updateDownloadingPercent(int percent) {
    return 'Downloading… $percent%';
  }

  @override
  String get updateFailed => 'Could not download the update';

  @override
  String updateCurrentVersion(String version) {
    return 'Installed version $version';
  }

  @override
  String get updateCheck => 'Check for updates';

  @override
  String get updateUpToDate => 'You are on the latest version';

  @override
  String get autoNextMonth =>
      'Next month downloads automatically before this one ends';

  @override
  String get sourceTitle => 'Source';

  @override
  String sourceNote(String name) {
    return 'All prayer times are calculated by $name.';
  }

  @override
  String openSource(String host) {
    return 'Open $host';
  }

  @override
  String get hijriDate => 'Hijri';

  @override
  String get qiblaHourNote =>
      'At the Qibla Hour, facing the sun means facing the qibla.';

  @override
  String get permissionNotificationTitle => 'Notification permission needed';

  @override
  String get permissionNotificationBody =>
      'Prayer alerts require notification permission.';

  @override
  String get permissionExactAlarmTitle => 'Exact alarm permission';

  @override
  String get permissionExactAlarmBody =>
      'Grant the \'alarms and reminders\' permission so alerts arrive on time.';

  @override
  String get permissionBatteryTitle => 'Battery optimisation';

  @override
  String get permissionBatteryBody =>
      'If the phone puts the app to sleep, alerts may be delayed. Excluding it from battery optimisation is recommended.';

  @override
  String get grantPermission => 'Grant';

  @override
  String get later => 'Later';

  @override
  String get notificationChannelPrayerName => 'Prayer alerts';

  @override
  String get notificationChannelPrayerDescription =>
      'Notification when a prayer time begins';

  @override
  String get notificationChannelOngoingName => 'Persistent prayer notification';

  @override
  String get notificationChannelOngoingDescription =>
      'Times and countdown in the status bar';

  @override
  String notificationPrayerEntered(String prayer) {
    return '$prayer has begun';
  }

  @override
  String get widgetNextPrayerName => 'Next prayer';

  @override
  String get widgetDailyTimesName => 'Today\'s times';

  @override
  String get widgetCompactName => 'Compact time';
}
