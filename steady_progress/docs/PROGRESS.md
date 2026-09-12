# Geçiş durumu

Son güncelleme: 9 Eylül 2026

## Efor seçimi

| Çalışma | Önerilen efor |
|---|---|
| Envanter, belge, rutin iskelet | Medium |
| Kotlin–React Native köprüsü, veri sürekliliği, bildirimler | High |
| Ekranları ortak bileşenlerle uygulama | Medium; karmaşık veri akışlarında High |

Android widget prototipi kabul edildi. Aşama 4'ün kod standardı tamamlandı; veri, widget drain ve bildirim geçişi nedeniyle öneri **High**.

## Aşama durumu

| Aşama | Durum | Kanıt / açık iş |
|---|---|---|
| 0 — Referansı kaydet | Kısmi | 337 dosyalık yedek ve 71 dosyalık widget manifesti hazır. S25 cihaz ayarları, üretim/preview widget karşılaştırması ve kurulu üretim imzası kaydedildi. Diğer ekranların görsel envanteri sürüyor. |
| 1 — Widget sözleşmesi | İstemci tamam; backend dağıtımı açık | Katı ayrıştırıcılar, yarış güvenli native onay ve repository tabanlı drain hazır. Task/Habit idempotency backend yaması derlenerek doğrulandı; production dağıtımı bekliyor. |
| 2 — Yeni iskelet ve prototip | Android kabulü tamam | Expo SDK 57 projesi, Android-only yerel modül, değişmeyen Kotlin/XML kaynakları, preview APK ve test APK'sı hazır. S25'te kurulum, köprü snapshot'ı, 11 instrumentation testi, eski/yeni widget görsel karşılaştırması ve canlı `+`/ekleme işlemi geçti. Tam Xcode ile iOS native build açık. |
| 3 — Güncelleme sürekliliği | Hazırlık doğrulandı; gerçek güncelleme bekliyor | Kurulu eski uygulamanın paket/sürüm/imzası okundu ve imzayı üreten yerel anahtar bulundu. Yeni istemci veri ve ekran eşliğine ulaşınca uygulamayı kaldırmadan güncelleme deneyi gerekiyor. |
| 4 — Ortak UI sistemi | Teknik uygulama tamam; cihaz kabulü açık | Nocturne tokenları, Phosphor ikonları, ortak bileşenler, Tasks/Habits `ListScreenShell`, tek FAB, güvenli/klavye kaydırmalı `AppSheet`, tasarım denetimi ve `/ui-standards` karşılaştırma yüzeyi hazır. S25 çentik+klavye görsel kabulü kullanıcı kontrollü yapılacak. |
| 5 — İşlev eşliği | Çekirdek sentetik akışlar genişletildi; Firebase ve harici entegrasyonlar açık | Tasks tarih aralığı, filtreleme, Goal bağlantısı, düzenleme, silme ve tamamlamayı sunuyor. Habits kategori, sıklık, renk, saat, seri ve son 60 günlük geçmişi taşıyor. Goals/milestones, Analytics, Reports, Learning, Content ve Workout ortak veri/UI sınırlarında hazır. Preview Firebase istemcileri olmadığı için native auth/Firestore bağlantısı etkin değil. |
| 6 — Bildirimler | Android istemci hazır; cihaz ve dağıtım kabulü açık | Yerel exact alarm, Android 13+ izin akışı ve sürümlü önemli kanal hazır. FCM kanal yaması derlenerek doğrulandı. S25 sessiz mod testi, backend dağıtımı ve iOS kritik bildirim yetkisi açık. |
| 7 — Son kabul | Bekliyor | Özellik eşliği, üretim güncellemesi ve Android/iOS cihaz matrisinden sonra. |

## Tamamlanan teknik işler

- Yeni uygulama `com.steadyprogress.steady_progress.preview` kimliğiyle üretim kurulumundan ayrıldı.
- Android `namespace` eski `com.steadyprogress.steady_progress` değerinde kaldı; widget sınıf ve `R` bağları değişmedi.
- Widget'ın 71 Kotlin/XML/font/drawable/test dosyası hash manifestiyle donduruldu. `npm run verify:widget` 142 kaynak+kopya hash kontrolü yapıyor.
- `SteadyWidget` Expo modülü snapshot yazma, kuyruk okuma, uyumluluk temizleme ve route alma işlemlerini sunuyor.
- Preview host gerçek hesap/Firebase kullanmıyor. Kuyrukta işlem varken sentetik snapshot yazmayı engelliyor ve kuyrukları kendiliğinden onaylamıyor.
- Cold start ve `onNewIntent` route bilgisi React Native yönlendiricisine aktarılıyor.
- Eksik Expo splash drawable'ı preview host'a eklendi; dondurulmuş widget kaynaklarına dokunulmadı.
- Android app ve instrumentation APK'ları `arm64-v8a` için derlendi.
- Android, iOS ve web JavaScript bundle üretimi başarılı.
- `npm run check`: widget hash kontrolü, tasarım denetimi, TypeScript ve 42/42 sözleşme/eşlik testi başarılı.
- Ortak UI tek `src/theme` girişinden besleniyor. Ham renk/font boyutu/köşe sapması `npm run audit:design` ile engelleniyor.
- Tasks ve Habits aynı `ListScreenShell` kullanıyor; boş durum ikinci Add butonu taşımıyor.
- Tasks ve Habits ortak editör sheet'i üzerinden mevcut kaydı düzenliyor ve onaydan sonra siliyor. Task'ın henüz görünmeyen tarih/öncelik/durum/Goal alanları başlık düzenlenirken korunuyor; Habit silme tamamlanma geçmişini de temizliyor.
- Habit editörü Morning/Evening/Health/Work kategorilerini, beş eski sıklık değerini, mevcut beş renk değerini ve isteğe bağlı yerel saat seçimini sunuyor. Weekdays yalnızca pazartesi–cuma planlıdır; gün seçimi saklamayan Weekly/3x/5x seçenekleri eski modeldeki gibi her gün yapılabilir kalır. Eski 12/24 saat metinleri okunur, yeni saat `HH:mm` biçiminde yazılır.
- `AppSheet` yarım ekran detent'inde kalıyor, üst güvenli alanı pencere yüksekliğinden düşürüyor ve uzun formları klavyeyle kendi içinde kaydırıyor. Learning title alanı ortak kontrollü `AppTextField` kullanıyor.
- Phosphor Regular/Fill ikon sözleşmesi Flutter'dan ortak `AppIcon` bileşenine taşındı.
- Widget kuyruk onayı `id + kind + at` ile yarış güvenli hale getirildi. Hızlı ekleme, geçici satıra ait toggle'dan önce işleniyor.
- Task/Habit/Reminder/Learning repository'leri Firebase'den bağımsız `DataGateway` sınırına taşındı. Üretime bağlanmayan `MemoryDataGateway`, aynı repository'lerle çalışan Tasks, Habits, Learning ve Reminders ekranlarını besliyor.
- Widget hızlı ekleme ve tamamlama işlemlerini repository'lere yönlendiren adapter hazır. Reminder yerel işlem kimliğiyle kararlı belge kullanıyor; Task/Habit aynı kimliği callable function'a taşıyor.
- `migration-patches/functions-widget-idempotency-and-important-channel.patch` ayrı backend kopyasında uygulandı ve Functions TypeScript derlemesi geçti. Orijinal proje değiştirilmedi.
- Android 13+ `POST_NOTIFICATIONS` izni reminder ilk kez planlanırken isteniyor.
- `steady-reminders` Android Expo modülü exact alarm planlama/iptal ve yeni `channel_important_alarm_v1` kanalını sunuyor.
- Reminder editörü gerçek tarih/saat, düzenleme, onaylı silme, 10 dakika snooze, erken uyarı, tekrar, konum, kategori, checklist ve yıldız alanlarını taşır. Kaydetme/snooze alarmı yeniden planlar; tamamlama/silme iptal eder.
- Android reminder programları yerel kayıt defterinde tutulur; açılış, paket güncellemesi, sistem saati ve saat dilimi değişikliğinde `ReminderRescheduleReceiver` gelecekteki alarmları tekrar kurar.
- Learning Tracker tür, durum, puan, durum filtresi, oluşturma, düzenleme ve onaylı silme işlemlerini ortak bileşenlerle sunuyor.
- Content Planner platform, durum, isteğe bağlı yerel tarih seçici, oluşturma, düzenleme ve onaylı silme işlemlerini ortak bileşenlerle sunuyor.
- Workout Tracker haftalık kayıt sayısı, geçmiş, yerel tarih seçimi, birden fazla egzersiz satırı ve egzersiz kayıtlarıyla birlikte onaylı silme işlemlerini ortak bileşenlerle sunuyor.
- Goals oluşturma, kategori, hedef tarih, yüzde ilerlemesi ve tamamlanabilir milestone satırlarını ortak bileşenlerle sunuyor; Task editörü gerçek Goal seçicisini kullanıyor.
- Analytics son dört haftanın habit/task oranlarını, Goal ortalamasını, en iyi seriyi, en tutarlı alışkanlığı ve bileşik üretkenlik puanını hesaplıyor.
- Reports backend rapor durumunu, türünü ve tarih aralığını listeliyor; hazır raporların Google Docs bağlantısını açıyor.
- Habit kartı son 60 gün içindeki tamamlanma sayısını ve son 14 tamamlanma tarihini açılır geçmiş görünümünde gösteriyor.
- Today ekranı bugünkü Reminder, Task ve planlı Habit kayıtlarını tek sıralı akışta birleştiriyor; tamamlama ve editör yönlendirmeleriyle Quick Capture gerçek repository katmanını kullanıyor.
- Finance aylık gelir/gider/birikim oranını, sent korumalı işlem kayıtlarını ve düzenlenebilir birikim hedefini taşıyor.
- Bildirim ayarları backend ile ortak `appPreferences` anahtarlarını, genel izin anahtarını, üç kanal tercihini, digest saatini ve izin reddinden sistem ayarlarına geçişi sunuyor.
- Profile kimlik bilgilerini ve gerçek Task/Reminder tamamlanma sayılarını gösteriyor; ortak editörle görünen ad/e-posta ve cihaz saat dilimini kaydediyor. Avatar yükleme Firebase Storage bağlantısını bekliyor.
- Starter/Growth/Complete plan kataloğu, fail-closed limit kararı ve ortak pricing ekranı taşındı. Kapalı beta boyunca Complete erişimi açık ve satın alma düğmeleri ücret çekmeyecek şekilde pasif.
- More ekranı taşınan yardımcı modülleri dört ortak bilgi grubunda topluyor.
- Flutter ile eş canlı widget snapshot seçicisi bugünkü/gecikmiş reminder kapsamını, tamamlanma-zaman sırasını ve her bölümde 12 kayıt sınırını uygular. Gerçek, sentetik olmayan hostta üç repository de hazır olduğunda değişen snapshot native köprüye yazılır.
- Açık işlerin tek kontrol listesi proje kökündeki `KALANLAR.md` dosyasına taşındı.

## Son derleme kanıtı

- Cihaz kabul APK'sı: `android/app/build/outputs/apk/release/app-release.apk` (standalone preview; geçici Android debug sertifikasıyla imzalı)
- Development APK: `android/app/build/outputs/apk/debug/app-debug.apk`
- Instrumentation APK: `android/app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk`
- Güncel release APK SHA-256: `db12f4fce83446af17afe95c116586ba62215742703387e988a808b42772fd07` (42.620.763 bayt)
- Development APK SHA-256: `9c7dfdd66f2643171074a23d926ca882fcbb894ae5e0bac1fa39d604cf95d6b1`
- Test APK SHA-256: `06046e475568151744b835ac21ae014f2abcf767f492630e66533916674a7816`
- APK manifesti: paket `com.steadyprogress.steady_progress.preview`, sürüm `0.1.0`, min SDK 24, target SDK 36.
- APK içinde `SteadyProgressWidgetProvider`, `SteadyProgressWidgetConfigureActivity`, `WidgetQuickAddActivity` ve `WidgetItemsService` kayıtları doğrulandı.

Debug APK'daki `SYSTEM_ALERT_WINDOW`, Expo development-client tarafından ekleniyor ve release APK'da bulunmuyor. Expo FileSystem'ın eklediği eski Android depolama izinleri host manifestinde kaldırıldı; debug ve release APK'larında bulunmuyor.

Expo Doctor'ın native klasör + `app.json` eşitleme denetimi bilinçli olarak kapalıdır. Proje widget nedeniyle native Android/iOS klasörlerini elle yönetir ve yeniden Prebuild çalıştırmaz. `app.json` değişirse karşılığı native projelere de elle uygulanmalıdır.

## Galaxy S25 cihaz kanıtı — 8 Eylül 2026

- Bağlı cihaz: `SM-S931B` (Galaxy S25), Android 16.
- Fiziksel ekran: 1080×2340; etkili yoğunluk: 420; sistem yazı ölçeği: 0.8.
- Preview release APK, üretim uygulamasından ayrı paket olarak başarıyla kuruldu ve açıldı.
- React Native ekranı köprünün bağlı olduğunu gösterdi. Sentetik snapshot yazıldı ve tekrar okunarak `habits 1/2`, `tasks 0/2`, `bestStreak 7` ile üç widget listesi doğrulandı.
- Android AppWidget sistemi preview `SteadyProgressWidgetProvider`, ayar activity'leri ve `WidgetItemsService` bileşenlerini kayıtlı gösterdi.
- Cihazda instrumentation sonucu: `WidgetLayoutInflationTest` 6, `WidgetRenderCaptureTest` 1, `WidgetTextContrastTest` 3 ve `ZzTypeScaleSweepTest` 1; toplam **11/11 başarılı**.
- Test için geçici debug APK kuruldu, ardından tekrar standalone preview release APK'ya dönüldü.
- Cihazdaki aktif ana ekran uygulaması Flower Launcher. Kullanıcı preview widget'ı eski widget'ın altına yerleştirdi. İki widget'ın dış ölçüleri, panel boşlukları, başlık/sayaç/`+` yerleşimi, ilerleme çizgisi, satır yüksekliği, yazı ve ikon düzeni eşleşti. Veri içeriği beklendiği gibi farklıydı.
- Kullanıcı `+` ve ekleme akışının çalıştığını “denenene” adlı kayıt ekleyerek doğruladı.

## Android güncelleme kimliği — 8 Eylül 2026

- Kurulu eski uygulama: `com.steadyprogress.steady_progress`, sürüm `1.0.0`, versionCode 1, APK signing v2.
- Kurulu eski APK sertifika SHA-256: `eafe2fd63a2c9471c1569c91e4c6b2cdf3b2fc251d62dff9c06d0a0f932e1740`.
- Bu parmak izi `/Users/pix/.android/debug.keystore` içindeki mevcut anahtarla eşleşiyor.
- Preview APK ayrı geçici anahtarla imzalı; üretim paketinin üzerine kurulamaz.
- Gerçek güncelleme, veri/oturum ve ekran eşliği tamamlandıktan sonra eski paket kimliği ve eşleşen anahtarla sınanacak. Mevcut uygulamanın üzerine erken kurulum yapılmadı.

## Sıradaki kabul kapıları

1. Preview Android ve iOS Firebase uygulama yapılandırmalarını oluştur; üretim kimlik bilgilerini sentetik host'a koyma.
2. Backend yamasını dağıt ve Emulator Suite üzerinde tekrar edilen `clientMutationId` çağrısının tek Task/Habit oluşturduğunu doğrula.
3. React Native Firebase gateway ve oturum katmanını etkinleştir; yalnızca bundan sonra production widget drain'ini uygulama yaşam döngüsüne bağla.
4. Kullanıcı kontrollü S25 kabulünde Tasks/Habits eşit düzeni, Learning title görünürlüğü, Habits klavye konumu ve hiçbir sheet'in kamera/durum alanına girmediğini doğrula.
5. S25 sessiz modda önemli ve normal reminder'ı ayrı ayrı dene. Önemli kayıt varsayılan bildirim tonunu alarm ses akışından çalmalı.
6. Tam Xcode ortamında iOS build, APNs ve kritik bildirim/AlarmKit yetki kararını tamamla.
7. Özellik eşliğinden sonra eski üretim paketinin üzerine kaldırmadan, eşleşen imzayla güncelleme testi yap.

Telefon üzerindeki sonraki kabul adımları kullanıcı kontrolündedir; bu aşamadaki derleme telefon ekranına veya kurulu paketlere dokunmadan tamamlandı.
