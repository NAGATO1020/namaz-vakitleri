# Namaz Vakitleri

Namaz vakitleri uygulaması. Vakitlerin tamamı seçilen takvimden alınır;
uygulama hiçbir vakti kendisi hesaplamaz.

İki takvim kaynağı var, ayarlardan seçilir:

| | Türkiye Takvimi | Fazilet Takvimi |
|---|---|---|
| Kaynak | turktakvim.com | fazilettakvimi.com |
| Vakit sayısı | 18 (İmsâk'ten Seher'e + Kıble Sâati) | 8 |
| İstenen târih | ✔ herhangi bir gün | ✘ yalnızca dün / bugün / yarın |
| Aylık indirme | ✔ | ✘ |
| Mübârek günler | ✔ | ✘ |
| Şehir sayısı | 122.314 | 6.470 |

Takvim değiştirilince öncekinin indirdiği vakitler silinir ve şehir yeniden
seçilir — iki kaynağın şehir kimlikleri ve hesap usûlleri farklıdır.

## Ne yapıyor

- **18 vakit**: İmsâk, Sabâh, Güneş, İşrak, Dahve-i Kübrâ, Kerâhet, Öğle,
  İkindi, Asr-ı Sânî, İsfirâr-ı Şems, Akşam, İştibâk-i Nücûm, Yatsı,
  İşâ-i Sânî, Gece Yarısı, Teheccüd, Seher, Kıble Sâati.
  Varsayılan olarak 9'u görünür, kalanı ayarlardan açılır.
- **Çevrimdışı**: Türkiye Takvimi'nde bir aylık vakit telefona indirilip
  saklanır; ay bitmesine 10 gün kala gelecek ay kendiliğinden iner. Fazilet
  yalnızca üç gün verdiği için orada uygulama her açılışta bu üç günü tazeler.
  Her iki kaynakta da **bir aydan eski kayıtlar** yer kaplamasın diye silinir.
  Şehir listeleri uygulamanın içinde, arama internetsiz çalışır.
- **Kalıcı bildirim**: bildirim çubuğunda sıradaki vakit ve canlı geri sayım.
  Kilit ekranında da görünür; kaydırılıp atılırsa kendiliğinden geri gelir.
  Sistem uygulamayı durdurduğunda silinmesin diye ön plan servisiyle basılır.
  Elde vakit kalmazsa kaybolmaz, "vakitlerin yenilenmesi gerekiyor" der.
- **Vakit bildirimleri**: seçilen vakitler girdiğinde bildirim.
- **Mübârek günler**: Regâib, Mi'râc, Berât, Kadr, Mevlid, Aşûre, hicrî yılbaşı,
  Ramazân ve bayram günleri — turktakvim'in kendi listesinden.
- **Üç widget**: sıradaki vakit (2×1), günün vakitleri (4×2), kompakt (1×1).
- **Açık/koyu tema**, **Türkçe/İngilizce**.
- **Havadan güncelleme**: yeni sürüm çıkınca uygulama haber verir, tek
  dokunuşla iner (bkz. [tool/RELEASE.md](tool/RELEASE.md)).

## Veri kaynakları

### Fazilet Takvimi

| İstek | Döndürdüğü |
|---|---|
| `fazilettakvimi.com/api/cms/daily?districtId={id}&lang=1` | Dün, bugün ve yarın; 8 vakit **UTC** olarak + `bolge_saatdilimi` (IANA) |
| `fazilettakvimi.com/api/cms/cities-by-country?districtId={ülkeId}&lang=1` | O ülkenin şehirleri |

UTC saatler şehrin IANA saat dilimiyle yerel saate çevrilir (`01:05Z` +
`Europe/Istanbul` = `04:05`). Târih parametresi kabul edilmiyor: `date`,
`tarih`, `day` denendi, hepsi yok sayılıyor. `monthly-times` uç noktası var
ama takvim ayını değil **Ramazan imsâkiyesini** döndürüyor.

Ülke listesi bir API'den gelmiyor, sitenin kendi uygulamasının içinde;
bir kez alınıp `tool/fazilet_countries.json` olarak kaydedildi.

### Türkiye Takvimi

Sitede belgelenmemiş ama `gadget.turktakvim.com`'un JavaScript'inden çıkarılan
uç noktalar:

| İstek | Döndürdüğü |
|---|---|
| `gadget.php?pg=1&sid={id}&cityID={id}&tarih=YYYY-MM-DD` | Tek satır, `;` ayraçlı: 18 vakit + koordinat + hicrî târih + şehrin yerel saati |
| `gadget.php?pg=2` | Bütün şehir listesi (`q` parametresi yok sayılır) |
| `turktakvim.com/yillikhicri.php` | Bütün yılın milâdî↔hicrî eşlemesi ve mübârek günler |

Mübârek günler de hesaplanmaz, bu sayfadan alınır — kandil gecelerinin bir
önceki akşam başlaması dâhil, sitede nasıl yazıyorsa öyle gösterilir.

Alan sıraları ve ayrıştırma kuralları [`lib/data/turktakvim_parser.dart`](lib/data/turktakvim_parser.dart)
içinde belgelendi.

**Kaynağa saygı:** indirilen her gün kalıcı olarak saklanır ve bir daha
istenmez; bir aylık indirme 31 istektir ve istekler arasında bekleme vardır.

### Bilinen sınırlar

- Kutup bölgesindeki şehirlerde (ör. Longyearbyen) güneş ufkun altına inmediği
  için vakitler tanımsızdır; servis **HTTP 500** döner. Uygulama bunu ayrı bir
  hata olarak ele alıp "yakın bir şehir seçin" der.
- Vakitler **şehrin yerel saatiyle** gelir. Cihaz başka bir saat dilimindeyse
  geri sayım kayardı; bu yüzden yanıttaki "şehrin şimdiki saati" alanı ile
  cihaz saati arasındaki fark hesaplanıp (en yakın 15 dakikaya yuvarlanarak)
  saklanır. Bu fark **sâbit değildir**: yaz saatini kimi ülke uyguluyor kimi
  uygulamıyor (Türkiye 2016'dan beri saatini değiştirmiyor, Avrupa yılda iki
  kez değiştiriyor), uygulayanlar da aynı günde geçmiyor. Yâni İstanbul'u
  seçmiş bir İsviçre telefonunda fark yazın 1, kışın 2 saat. Bu yüzden fark
  her yenilemede baştan çıkarılır — Fazilet'te yanıttaki IANA bölge adından
  **hesaplanarak**, turktakvim'de şehrin bildirdiği saatten. Arka plan
  yenilemesi de (gece 03:00) farkı tâzeler, böylece uygulama açılmasa bile
  geçişin ertesi günü kendini toparlar.
- **Yaz saati geçişleri.** Saatlerin geri alındığı gün 25, ileri alındığı gün
  23 saat sürer. Vakitler bu yüzden gün başına süre **eklenerek** değil, takvim
  alanlarından (gün + "HH:mm") kurulur; eklemek bütün vakitleri geçiş günü bir
  saat kaydırıyordu. Saatlerin ileri alındığı gece atlanan saate düşen bir
  vakit (ör. Seher 02:50) o gün hiç yaşanmaz; geçişin sonuna taşınır.
  Kurulmuş alarmlar mutlak zamana bağlı olduğu için geçişte kayabilir:
  bildirim basılmadan önce vakit yeniden hesaplanıp denk gelip gelmediğine
  bakılır, denk gelmiyorsa basılmaz.
- Gece Yarısı, Teheccüd ve Seher takvim olarak **ertesi güne** düşer. Vakitler
  kronolojik bir zincir olarak çözülür: bir vakit kendinden öncekinden küçükse
  gün bir artar. Kıble Sâati bu zincire girmez.

## Mimari

```
lib/
  core/prayer.dart          18 vakti tanımlayan enum (API indisleri burada)
  core/theme.dart           Açık/koyu tema
  data/turktakvim_*.dart    API ve ayrıştırıcı
  data/city_repository.dart Çevrimdışı şehir listesi (assets/cities.tsv.gz)
  data/prayer_repository.dart  sqflite önbelleği + aylık indirme
  domain/next_prayer.dart   Sıradaki vakit, geri sayım, saat dilimi farkı
  platform/                 Native tarafa köprüler
  state/app_state.dart      Riverpod durumu
  ui/                       Ekranlar
android/app/src/main/kotlin/com/tunahan/namaz_vakitleri/
  PrayerStore.kt            Flutter'ın yazdığı veriyi okur
  PrayerSchedule.kt         Sıradaki vakit hesabı (Dart'takinin aynısı)
  OngoingContent.kt         Kalıcı bildirim ne göstersin (saf karar, testli)
  OngoingNotification.kt    Kalıcı bildirim
  OngoingService.kt         Bildirimi taşıyan ön plan servisi
  AlarmScheduler.kt         Vakit alarmları
  widget/                   Üç widget
```

Kalıcı bildirimdeki ve widget'lardaki geri sayım `Chronometer` ile yapılır:
sayacı sistem işletir, arka planda hesap yürütülmez. Bildirim yalnızca vakit
değiştiğinde `AlarmManager` ile yeniden kurulur.

Kalıcı bildirim `OngoingService` adlı bir ön plan servisine (`specialUse`)
bağlıdır. Servis iş yapmaz; sıradan bir bildirim, üretici pil yönetimi
uygulamayı durdurunca silindiği (ve alarmlar da gittiği için geri
gelemediği) için gerekli. Android 12+ arka plandan servis başlatmaya her
zaman izin vermez; o anlarda bildirim sıradan bildirim olarak basılır ve ilk
fırsatta (vakit alarmı, uygulama açılışı) servise alınır.

15 dakikada bir dönen emniyet alarmı **tam zamanlı** kurulur. Sebebi pil değil
izin: Android 12'den beri arka plandan ön plan servisi başlatmak yasak, ama tam
zamanlı bir alarmın yayınını işlerken serbest. Yaklaşık alarmla uyanan emniyet
ağı bildirimi servise alamıyor, yalnızca sıradan bildirim basabiliyordu — sistem
de onu silmeye devam ediyordu. Her vuruşta vakit alarmları da yeniden kurulur,
böylece saat ya da yaz saati değişimi en geç 15 dakikada kendini düzeltir.

## Geliştirme

```bash
flutter test
```

```bash
flutter analyze
```

```bash
flutter build apk --release
```

Android tarafındaki zamanlama mantığının testleri:

```bash
cd android && ./gradlew :app:testDebugUnitTest
```

Yeni sürüm yayınlamak için [tool/RELEASE.md](tool/RELEASE.md).

Yardımcı araçlar:

```bash
python tool/build_city_db.py
```

```bash
python tool/make_icon.py
```

## Teşekkür

Vakitler [turktakvim.com](https://turktakvim.com) (Türkiye Takvimi) tarafından
hesaplanmaktadır.
