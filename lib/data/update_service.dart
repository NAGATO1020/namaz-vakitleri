import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Uzaktaki sürüm bildirimi.
///
/// Manifest biçimi (düz JSON, herhangi bir statik barındırmada durabilir):
/// ```json
/// {
///   "versionCode": 3,
///   "versionName": "1.2.4",
///   "apkUrl": "https://.../namaz-vakitleri-1.2.4.apk",
///   "notes": "Mübârek günler eklendi.",
///   "sha256": "…",
///   "mandatory": false
/// }
/// ```
class AppRelease {
  const AppRelease({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    this.notes = '',
    this.sha256,
    this.mandatory = false,
  });

  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String notes;
  final String? sha256;
  final bool mandatory;

  static AppRelease? fromJson(Map<String, Object?> json) {
    final code = json['versionCode'];
    final name = json['versionName'];
    final url = json['apkUrl'];
    if (code is! int || name is! String || url is! String || url.isEmpty) {
      return null;
    }
    return AppRelease(
      versionCode: code,
      versionName: name,
      apkUrl: url,
      notes: json['notes'] as String? ?? '',
      sha256: json['sha256'] as String?,
      mandatory: json['mandatory'] as bool? ?? false,
    );
  }
}

/// İndirme ilerlemesi (0..1). Toplam boyut bilinmiyorsa `null`.
typedef DownloadProgress = void Function(double? fraction);

/// Havadan güncelleme: sürüm kontrolü, APK indirme.
///
/// Kurulumun kendisi Android'in paket yükleyicisiyle yapılır — uygulamalar
/// başka bir uygulamayı sessizce kuramaz (cihaz sâhibi/kurumsal yönetim
/// dışında). Yani "tek tuş" indirmeyi başlatır ve sistemin kurulum ekranını
/// açar; son onay kullanıcıda kalır.
class UpdateService {
  UpdateService({http.Client? client, String? manifestUrl})
      : _client = client ?? http.Client(),
        manifestUrl = manifestUrl ?? defaultManifestUrl;

  /// GitHub kullanıcı adı ve depo adı.
  /// Sürüm yayınlama adımları için `tool/RELEASE.md` dosyasına bak.
  static const String githubOwner = 'NAGATO1020';
  static const String githubRepo = 'namaz-vakitleri';

  /// Güncelleme bildiriminin okunacağı adres.
  ///
  /// Varsayılan olarak depo kökündeki `update.json`; her yeni sürümde bu
  /// dosyadaki `versionCode` artırılır ve `apkUrl` yeni release'i gösterir.
  /// Derlerken `--dart-define=UPDATE_MANIFEST_URL=…` ile değiştirilebilir.
  static const String defaultManifestUrl = String.fromEnvironment(
    'UPDATE_MANIFEST_URL',
    defaultValue: 'https://raw.githubusercontent.com/'
        '$githubOwner/$githubRepo/main/update.json',
  );

  /// Adres yer tutucu hâlindeyse güncelleme kontrolü yapılmaz.
  static bool get isConfigured => !defaultManifestUrl.contains('DEPO-SAHIBI');

  final http.Client _client;
  final String manifestUrl;

  /// Kurulu sürümden yeni bir sürüm varsa döner, yoksa `null`.
  Future<AppRelease?> check() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    if (manifestUrl == defaultManifestUrl && !isConfigured) return null;
    try {
      final response = await _client
          .get(Uri.parse(manifestUrl))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, Object?>) return null;
      final release = AppRelease.fromJson(decoded);
      if (release == null) return null;

      final info = await PackageInfo.fromPlatform();
      final current = int.tryParse(info.buildNumber) ?? 0;
      return release.versionCode > current ? release : null;
    } catch (e) {
      // Güncelleme kontrolü uygulamanın çalışmasını engellememeli.
      debugPrint('Güncelleme kontrolü başarısız: $e');
      return null;
    }
  }

  /// Kurulu sürümün adı ("1.2.3") ve numarası.
  static Future<({String name, int code})> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return (name: info.version, code: int.tryParse(info.buildNumber) ?? 0);
  }

  /// APK'yı indirir ve dosya yolunu döner.
  ///
  /// Uygulamanın kendi önbellek klasörüne iner; depolama izni gerekmez.
  Future<File> download(
    AppRelease release, {
    DownloadProgress? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/namaz-vakitleri-${release.versionName}.apk');
    if (await file.exists()) await file.delete();

    final request = http.Request('GET', Uri.parse(release.apkUrl));
    request.headers['User-Agent'] = 'NamazVakitleri-Updater';
    final response = await _client.send(request);

    if (response.statusCode != 200) {
      throw HttpException(
          'APK indirilemedi (${response.statusCode}): ${release.apkUrl}');
    }

    final total = response.contentLength;
    var received = 0;
    final sink = file.openWrite();
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(total == null || total == 0 ? null : received / total);
      }
    } finally {
      await sink.close();
    }
    return file;
  }

  void close() => _client.close();
}
