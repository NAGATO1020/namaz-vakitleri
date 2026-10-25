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

Yayın bu makineden `gh` (GitHub CLI) ile yapılır. İmza anahtarı bilgisayardan
çıkmaz — GitHub Actions ile denendi ama anahtarın bir kopyasını GitHub
Secrets'a koymayı gerektirdiği için vazgeçildi.

1. **Sürüm numarasını artır** — `pubspec.yaml`:

   ```yaml
   version: 1.2.4+7
   #        ^^^^^ görünen ad   ^ versionCode (her sürümde artmalı)
   ```

   `versionCode` (artıdan sonraki sayı) mutlaka artmalı; güncelleme kontrolü
   bunu karşılaştırır.

2. **Testleri koştur ve imzalı APK üret:**

   ```bash
   flutter test && (cd android && ./gradlew :app:testDebugUnitTest)
   ```

   ```bash
   flutter build apk --release --split-per-abi
   ```

3. **İmzayı doğrula.** Çıktıda `CN=Android Debug` görünürse APK'yı
   **yayınlama** — imzası değişen güncellemeyi Android reddeder ve
   kullanıcıların uygulamayı silip yeniden kurması gerekir:

   ```bash
   apksigner verify --print-certs build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
   ```

4. **Etiketi ve release'i oluştur** (manifestten **önce** — sırası önemli):

   ```bash
   git tag -a v1.2.4 -m "Mübârek günler eklendi." && git push origin v1.2.4
   ```

   ```bash
   gh release create v1.2.4 --title 1.2.4 --notes "Mübârek günler eklendi." build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
   ```

5. **`update.json`'u güncelle** ve `main` dalına gönder — release yayımlandıktan
   *sonra*. Ters sırada yaparsan uygulama bir süre "güncelleme var" deyip
   indiremez. (1.2.1'den itibaren uygulama indirmeden önce APK'nın varlığını
   kontrol ediyor, ama sırayı yine de doğru tut.)

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
