# Yeni sürüm yayınlama

Uygulama açılışta depo kökündeki `update.json` dosyasına bakar; oradaki
`versionCode` telefondakinden büyükse "… güncellemesi var" kartını gösterir ve
tek dokunuşla APK'yı indirip kurulum ekranını açar.

## Bir kereye mahsus kurulum

1. **GitHub'da depo aç** (adı `namaz-vakitleri` olsun; farklıysa aşağıdaki
   adımlarda ona göre değiştir).

2. **Kullanıcı adını koda yaz** — `lib/data/update_service.dart` içinde:

   ```dart
   static const String githubOwner = 'DEPO-SAHIBI';   // ← kendi kullanıcı adın
   static const String githubRepo = 'namaz-vakitleri';
   ```

   Bu satır yer tutucu kaldığı sürece uygulama güncelleme kontrolü yapmaz.

3. `update.json` içindeki adresi de aynı şekilde düzelt.

4. Projeyi depoya gönder. **`android/key.properties` ve `.jks` dosyası
   gitignore'da — asla depoya girmemeli.**

## Her yeni sürümde

1. **Sürüm numarasını artır** — `pubspec.yaml`:

   ```yaml
   version: 1.2.4+5
   #        ^^^^^ görünen ad   ^ versionCode (her sürümde artmalı)
   ```

   `versionCode` (artıdan sonraki sayı) mutlaka artmalı; güncelleme kontrolü
   bunu karşılaştırır.

2. **İmzalı APK üret:**

   ```bash
   flutter build apk --release
   ```

   Çıktı: `build/app/outputs/flutter-apk/app-release.apk`

3. **GitHub'da release oluştur**, etiketi `v1.2.4` yap ve APK'yı ekle.

4. **`update.json`'u güncelle** ve `main` dalına gönder:

   ```json
   {
     "versionCode": 5,
     "versionName": "1.2.4",
     "apkUrl": "https://github.com/KULLANICI/namaz-vakitleri/releases/download/v1.2.4/app-release.apk",
     "notes": "Mübârek günler eklendi.",
     "mandatory": false
   }
   ```

   `mandatory: true` yaparsan kart kapatılamaz — kritik bir düzeltme için.

Kullanıcılar uygulamayı bir sonraki açışlarında kartı görür.

## Bilinmesi gerekenler

- **İmza anahtarı değişmemeli.** Anahtar `~/.namaz-vakitleri-upload.jks`,
  parolası `android/key.properties` içinde. **İkisini de yedekle** — kaybolursa
  mevcut kurulumların üstüne bir daha güncelleme yayınlanamaz, kullanıcıların
  uygulamayı silip yeniden kurması gerekir.
- `key.properties` bir Java properties dosyası; **ters bölü orada kaçış
  karakteri**. Windows yolunu `C:/Users/...` gibi eğik çizgiyle yaz (ya da
  `C:\\Users\\...` diye ikile), yoksa yol sessizce bozulur ve APK hata ayıklama
  anahtarıyla imzalanır. İmzayı kontrol et:

  ```bash
  apksigner verify --print-certs build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
  ```

  Çıktıda `CN=Android Debug` görüyorsan imza yanlıştır.
- **Sessiz kurulum mümkün değil.** Android, bir uygulamanın başka bir uygulamayı
  kullanıcı onayı olmadan kurmasına izin vermez. "Tek tuş" APK'yı indirir ve
  sistemin kurulum ekranını açar; son onayı kullanıcı verir.
- Kullanıcı ilk kez güncellerken Android "bilinmeyen kaynaklardan kuruluma izin
  ver" diye soracak; uygulama bu ekrana yönlendiriyor. Bir kez verilince yeter.
- APK boyutunu küçültmek istersen `flutter build apk --split-per-abi` ile
  mimariye özel APK üretip `arm64-v8a` olanı yayınlayabilirsin (~40% daha küçük).
  O zaman `apkUrl` o dosyayı göstermeli.
