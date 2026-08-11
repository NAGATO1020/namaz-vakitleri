# İlk yayın — bundan sonra güncellemeler havadan gelir

Depo yerelde hazır ve işlendi. Yapılacak tek şey: GitHub'a göndermek ve
bir release oluşturmak. Ondan sonra uygulama güncellemeleri kendisi bulur.

## 1. GitHub'da boş bir depo aç

https://github.com/new → ad: **namaz-vakitleri** → **Public**
(APK'nın indirilebilmesi için genel olmalı; özel depoda uygulama indiremez.)

"Add a README" kutusunu **işâretleme** — burada zaten var.

## 2. Projeyi gönder

Proje klasöründe:

```bash
git remote add origin https://github.com/NAGATO1020/namaz-vakitleri.git
```

```bash
git push -u origin main
```

Kullanıcı adı/parola sorarsa: parola yerine GitHub'dan aldığın bir
**personal access token** gerekir (Settings ▸ Developer settings ▸
Personal access tokens ▸ Fine-grained ▸ `Contents: Read and write`).

## 3. Release oluştur ve APK'yı ekle

https://github.com/NAGATO1020/namaz-vakitleri/releases/new

- **Tag:** `v1.2.0`
- **Title:** `1.2.0`
- Aşağıdaki dosyayı sürükle bırak:

  ```
  build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
  ```

- **Publish release**

## 4. Kontrol

Tarayıcıda şunu aç, JSON görünmeli:

```
https://raw.githubusercontent.com/NAGATO1020/namaz-vakitleri/main/update.json
```

Ve APK bağlantısı inmeli:

```
https://github.com/NAGATO1020/namaz-vakitleri/releases/download/v1.2.0/app-arm64-v8a-release.apk
```

İkisi de çalışıyorsa bitti.

---

## Bundan sonrası

Telefonda **1.1.0 veya 1.2.0** varsa: uygulamayı aç, "1.2.0 güncellemesi var"
kartı çıkar (ya da Ayarlar ▸ en alttaki sürüm satırına dokunup denetlet).

Telefonda hâlâ **1.0.0** varsa: o sürüm güncelleme adresini bilmiyor, bir kez
elle kurman gerekiyor. Sonrasında hep havadan gelir.

Yeni sürüm çıkarma adımları: [RELEASE.md](RELEASE.md)
