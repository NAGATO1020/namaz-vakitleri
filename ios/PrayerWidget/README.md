# iOS widget'ları — Xcode'da kurulum

Bu klasördeki Swift dosyaları hazırdır ama **Xcode projesine bir hedef (target)
olarak eklenmeleri gerekir**; bu adım Windows'ta yapılamaz, bir Mac ister.

## Adımlar

1. `ios/Runner.xcworkspace` dosyasını Xcode ile aç.

2. **Widget Extension hedefi ekle**
   `File ▸ New ▸ Target… ▸ Widget Extension`
   - Product Name: **PrayerWidget**
   - "Include Live Activity" ve "Include Configuration App Intent" işâretlerini **kaldır**
   - Xcode'un ürettiği `PrayerWidget.swift` taslağını sil; bu klasördeki
     `PrayerWidget.swift` ve `PrayerData.swift` dosyalarını hedefe ekle.

3. **App Group tanımla** — widget ile uygulama veriyi bu grup üzerinden paylaşır.
   Hem `Runner` hem `PrayerWidget` hedefinde
   `Signing & Capabilities ▸ + Capability ▸ App Groups` ile şunu ekle:

   ```
   group.com.tunahan.namazvakitleri
   ```

   Bu değer `lib/platform/widget_bridge.dart` içindeki `iosAppGroup` ile
   birebir aynı olmalı; farklı olursa widget boş görünür.

4. **Dağıtım hedefi**: `containerBackground(_:for:)` iOS 17 ister.
   PrayerWidget hedefinin *Minimum Deployments* değerini **iOS 17.0** yap
   (daha eskisini destekleyeceksen o satırı `#available` ile sarmalaman gerekir).

5. Derle ve çalıştır: `flutter build ios` ardından Xcode'dan cihaza gönder.

## Bilinmesi gerekenler

- Vakitler ve ayarlar App Group'taki `UserDefaults`'a Flutter tarafından
  `home_widget` ile yazılır. Anahtar listesi `lib/platform/widget_bridge.dart`
  içindedir; Android'de aynı veriyi `PrayerStore.kt` okur.
- Geri sayım `Text(date, style: .timer)` ile gösterilir — sistem saniyeleri
  kendisi işletir, widget'ın sık yenilenmesine gerek yoktur. Zaman çizelgesi
  yalnızca vakit geçişlerinde yenileme noktası koyar.
- **iOS'ta Android'deki gibi kalıcı bildirim yoktur.** Apple, uygulamaların
  bildirim çubuğunda sürekli güncellenen bir bildirim tutmasına izin vermez.
  iOS'ta bunun karşılığı widget'lar ve (istenirse ileride) Live Activity'dir.
- Vakit bildirimleri iOS'ta `UNUserNotificationCenter` ile ayrıca kurulmalıdır;
  bu kısım henüz yazılmadı (Android tarafı `AlarmScheduler.kt` ile çalışıyor).
