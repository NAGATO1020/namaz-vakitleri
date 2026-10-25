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

Yayın **GitHub Actions'a devredildi** (`.github/workflows/release.yml`).
Yapılacak tek şey sürümü artırıp etiket göndermek:

1. **Sürüm numarasını artır** — `pubspec.yaml`:

   ```yaml
   version: 1.2.4+7
   #        ^^^^^ görünen ad   ^ versionCode (her sürümde artmalı)
   ```

   `versionCode` (artıdan sonraki sayı) mutlaka artmalı; güncelleme kontrolü
   bunu karşılaştırır. Değişikliği `main` dalına gönder.

2. **Etiketi gönder** — adı `v` + pubspec'teki sürüm olmalı, yoksa iş akışı
   durur. Etiket mesajı kullanıcıya gösterilen sürüm notu olur:

   ```bash
   git tag -a v1.2.4 -m "Mübârek günler eklendi." && git push origin v1.2.4
   ```

Gerisi kendiliğinden olur: testler koşar, imzalı APK derlenir, release
oluşturulur, APK eklenir ve **en son** `update.json` güncellenip `main`'e
gönderilir. Sıra böyle; ters olsaydı uygulama bir süre "güncelleme var" deyip
indiremezdi.

İş akışı iki yerde bilerek durur: imza secret'ları eksikse ve üretilen APK
hata ayıklama anahtarıyla imzalanmışsa. İkisi de havadan güncellemeyi kalıcı
olarak kırardı.

### Tek seferlik: imza secret'ları

GitHub'ın imzalı APK üretebilmesi için anahtarın **Settings ▸ Secrets and
variables ▸ Actions** altında durması gerekir. Dört secret:

| Secret | Değeri |
|---|---|
| `KEYSTORE_BASE64` | `.jks` dosyasının base64'ü (aşağıdaki komut) |
| `KEYSTORE_PASSWORD` | `android/key.properties` içindeki `storePassword` |
| `KEY_ALIAS` | aynı dosyadaki `keyAlias` |
| `KEY_PASSWORD` | aynı dosyadaki `keyPassword` |

Base64'ü üretmek (PowerShell):

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$HOME\.namaz-vakitleri-upload.jks")) | Set-Clipboard
```

Panoya kopyalanır; `KEYSTORE_BASE64`'e yapıştır.

> Anahtar bundan sonra GitHub'da da duracak. Depo genel olsa bile secret'lar
> gizlidir ve iş akışı günlüklerinde görünmez; yine de anahtarın ikinci bir
> kopyasının orada olduğunu bil. Yerel yedeğini yine de sakla.

### Elle yayınlamak gerekirse

```bash
flutter build apk --release --split-per-abi
```

Sonra GitHub'da release oluştur (manifestten **önce**), `app-arm64-v8a-release.apk`
dosyasını ekle, en son `update.json`'u güncelleyip `main`'e gönder.

   > **Dikkat — `versionCode`:** `--split-per-abi` ile derlersen Flutter
   > APK'nın versionCode'una mimari ofseti ekler (arm64 için **+2000**,
   > armeabi-v7a için +1000). Yâni `version: 1.2.0+3` arm64'te **2003** olur.
   > Manifeste yazacağın sayı APK'nın gerçek değeri olmalı; kontrol et:
   >
   > ```bash
   > aapt2 dump badging build/app/outputs/flutter-apk/app-arm64-v8a-release.apk | head -1
   > ```
   >
   > 1.2.0'dan itibaren uygulama karşılaştırmayı `versionName` üzerinden
   > yapıyor, bu yüzden yeni sürümlerde ofset sorun çıkarmaz — ama daha eski
   > bir sürümden güncelleyen kullanıcılar için sayının doğru olması gerekir.


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
