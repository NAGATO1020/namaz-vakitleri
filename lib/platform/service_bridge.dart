import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native taraftaki alarm, bildirim ve izin işlemlerine erişim.
///
/// Sıradaki vaktin hesabı ve bildirimin çizilmesi Android tarafında yapılır;
/// Flutter yalnızca "veriler değişti, yeniden kur" der.
class ServiceBridge {
  const ServiceBridge._();

  static const MethodChannel _channel =
      MethodChannel('com.tunahan.namaz_vakitleri/platform');

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  /// Vakitler veya ayarlar değiştikten sonra çağrılır: alarmlar yeniden
  /// kurulur, kalıcı bildirim ve widget'lar tazelenir.
  static Future<void> syncSchedule() => _invoke<void>('syncSchedule');

  /// Bildirimler tamamen kapatıldığında.
  static Future<void> cancelAll() => _invoke<void>('cancelAll');

  static Future<bool> notificationsAllowed() async =>
      await _invoke<bool>('notificationsAllowed') ?? false;

  /// Android 13+ bildirim iznini ister. Kullanıcı reddederse `false`.
  static Future<bool> requestNotificationPermission() async =>
      await _invoke<bool>('requestNotificationPermission') ?? false;

  /// Tam zamanlı alarm kurulabiliyor mu (Android 12+ izni).
  static Future<bool> canScheduleExactAlarms() async =>
      await _invoke<bool>('canScheduleExactAlarms') ?? true;

  static Future<void> openExactAlarmSettings() =>
      _invoke<void>('openExactAlarmSettings');

  /// Uygulama pil optimizasyonundan muaf mı — değilse bildirimler gecikebilir.
  static Future<bool> isIgnoringBatteryOptimizations() async =>
      await _invoke<bool>('isIgnoringBatteryOptimizations') ?? true;

  static Future<void> openBatterySettings() =>
      _invoke<void>('openBatterySettings');

  static Future<void> openNotificationSettings() =>
      _invoke<void>('openNotificationSettings');

  // --- havadan güncelleme ---

  /// Uygulama "bilinmeyen kaynaklardan kurulum" iznine sâhip mi.
  static Future<bool> canInstallPackages() async =>
      await _invoke<bool>('canInstallPackages') ?? false;

  /// İzin ekranını açar (Android bu izni ancak kullanıcı verebilir).
  static Future<void> openInstallPermissionSettings() =>
      _invoke<void>('openInstallPermissionSettings');

  /// İndirilen APK için sistemin kurulum ekranını açar.
  ///
  /// Android, bir uygulamanın başka bir uygulamayı sessizce kurmasına izin
  /// vermez; son onay her hâlükârda kullanıcıdadır.
  static Future<bool> installApk(String path) async {
    if (!_supported) return false;
    try {
      return await _channel
              .invokeMethod<bool>('installApk', {'path': path}) ??
          false;
    } on PlatformException catch (e) {
      debugPrint('installApk başarısız: ${e.message}');
      return false;
    }
  }

  static Future<T?> _invoke<T>(String method) async {
    if (!_supported) return null;
    try {
      return await _channel.invokeMethod<T>(method);
    } on PlatformException catch (e) {
      debugPrint('ServiceBridge.$method başarısız: ${e.message}');
      return null;
    } on MissingPluginException {
      // Native taraf henüz hazır değil (ör. testlerde).
      return null;
    }
  }
}
