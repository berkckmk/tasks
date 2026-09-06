# Ortak mobil uygulamaya geçiş ve yeni sistem kurulum planı

Tarih: 6 Eylül 2026  
Durum: Plan hazır; yeni uygulama kurulmadı, taşıma başlatılmadı.  
Hedef: Ana uygulamayı iOS ve Android için ortak kodla geliştirmek; mevcut Android ana ekran widget'ının görünümünü ve işlevlerini korumak.

## 1. Karar ve kapsam

Önerilen hedef **React Native + TypeScript + Expo development build**. Bu seçim önce mevcut Kotlin/XML widget'ıyla çalışan bir prototipte doğrulanacak. Flutter kodunu satır satır çevirmek yerine, mevcut veri sözleşmelerini ve davranışları anlayarak yeni mobil istemciyi aşamalı yazacağız.

- Android widget'ı ortak UI diliyle yeniden yazılmayacak. Kotlin, XML ve RemoteViews yapısı korunacak.
- Ana uygulamanın mevcut renkleri, Inter font dosyaları, ikonları ve görsel karakteri korunacak. Bileşenlerin aynı işi farklı biçimde yaptığı yerler standartlaştırılacak.
- Firebase veri modeli, hesap kimlikleri, uygun Cloud Functions, yetkilendirme kuralları ve entegrasyonlar yeniden kullanılacak; yeni bir üretim veritabanına toplu taşıma hedeflenmiyor.
- Yeni kod, mevcut Flutter uygulamasından ayrı geliştirilecek. Flutter uygulaması geçiş kabul edilene kadar çalışır referans olarak tutulacak.
- iOS ana uygulaması kapsamda; iOS widget'ı ayrı bir sonraki iş. Android widget'ının iOS için değiştirilmesi kapsam dışında.
- Mevcut web uygulaması korunacak; React Native web'e geçiş bu planın kabul şartı değil.
- Bu belge uygulama planıdır; mağaza yayını, üretim backend değişikliği veya mevcut kurulumun değiştirilmesi bu aşamada yapılmaz.

## 2. Mevcut projeden doğrulanan başlangıç noktaları

| Alan | Mevcut durum | Geçiş kararı |
|---|---|---|
| Ana uygulama | Flutter/Dart; ekran, iş mantığı ve veri katmanları ayrılmış | Davranışları referans alarak TypeScript'e taşı |
| Android widget | `android/app/src/main/kotlin/com/steadyprogress/steady_progress/widget/` ve Android kaynakları | Görsel/işlevsel kodu koru |
| Bağlantı | `MainActivity.kt` içindeki `com.steadyprogress/widget` MethodChannel | Aynı işlemleri sunan yerel köprüyle değiştir |
| Veriler | Widget snapshot'ı ve ayarları SharedPreferences'ta | Dosya adları, anahtarlar ve türleri koru |
| Widget işlemleri | Ekleme ve tamamlama ayrı kalıcı kuyruklarda | Başarılı işlenen kayıtları onaylayan eşitleme akışını taşı |
| Eşitleme | `HomeWidgetSync`, açılışta ve uygulamaya dönüşte kuyrukları işliyor | Aynı yaşam döngüsünü yeni uygulamada kur |
| Widget yönlendirme | `steady_progress_route` bilgisiyle `MainActivity` açılıyor | Soğuk/sıcak başlangıçta aynı kaydın doğru ekranını aç |
| Android kimliği | `com.steadyprogress.steady_progress` | Nihai güncellemede koru |
| Backend | Firebase `tasks-1903`; üretimle kaynak kod arasında geçmişte fark oluşmuş | Canlı sürümü başlangıçta yeniden doğrula |
| iOS | İncelenen proje kökünde `ios/` dizini yok | iOS hedefini ve servis yapılandırmasını yeni kur |

Önemli mevcut davranış: Widget, uygulama çalışmıyorken yerel görüntüyü güncelleyebilir ve işlem kuyruğuna kayıt bırakabilir. Buluta yazma, uygulamanın tekrar çalışıp kuyruğu işlemesiyle olur. Geçiş, sürekli arka plan senkronizasyonu varmış gibi tasarlanmayacak.

`docs/ANDROID_WIDGET.md` içindeki bazı eski bölümler artık dosya ağacında bulunmayan cam/bitmap sınıflarını anlatıyor. Referans, güncel kaynak kod ve cihazdaki onaylanan görünüm olacak; eski belge metni üzerinden widget yeniden oluşturulmayacak.

Çalışma ağacında önceden var olan çok sayıda düzenleme ve kaydedilmemiş yeni dosya var. Ayrıca önceki çalışmada başlayan güvenli alan/klavye düzenlemeleri henüz doğrulanmış bir sürüm sayılmamalı. Başlangıç referansı yalnızca Git HEAD üzerinden alınmayacak; mevcut çalışma durumu ve cihazdaki sürüm ayrı kaydedilecek.

## 3. Hedef mimari

```text
Ortak iOS / Android uygulaması — React Native + TypeScript
  ├─ Mevcut tasarımdan türetilen ortak bileşenler ve sayfa şablonları
  ├─ Görev / alışkanlık / hatırlatıcı iş kuralları
  ├─ Firebase veri erişimi ve entegrasyon servisleri
  ├─ Widget eşitleme koordinatörü
  │    └─ Android bağlantı modülü
  │         └─ Mevcut Kotlin/XML widget + veri deposu + işlem kuyrukları
  └─ Bildirim arayüzü
       ├─ Android alarm / bildirim uygulaması
       └─ iOS bildirim / uygun alarm uygulaması

Mevcut Firebase backend — eski ve yeni istemciyle uyumlu sözleşmeler
```

Yeni mobil istemci için önerilen ayrı dizin: çalışma alanında `steady_progress_mobile/`. Başlangıçta mevcut `steady_progress/` klasörünü yeniden düzenlemeyeceğiz. Yeni yapıda `src/app`, `src/features`, `src/components`, `src/theme`, `src/services` ve yerel bağlantı modülü ayrılacak; kesin dizin planı kurulum aşamasında sabitlenecek.

**Yerel proje bakım yöntemi:** Android ve iOS proje dosyaları Git'te tutulacak. İlk iskelet üretiminden ve widget entegrasyonundan sonra bu projeler elle yönetilecek; normal geliştirme/CI akışında `expo prebuild --clean` çalıştırılmayacak. Expo, elle yönetilen yerel projelerde Prebuild'in özelleştirmeleri ezebileceğini belirtiyor. Özel widget nedeniyle Expo Go yerine development build kullanılacak. [Expo CNG](https://docs.expo.dev/workflow/continuous-native-generation/), [özel yerel kod](https://docs.expo.dev/workflow/customizing/)

SDK, React Native, Node, Java, Gradle ve Xcode sürümleri kurulum tarihinde birlikte uyumluluğu doğrulanan sürümlere sabitlenecek; prototip ve ekran taşıması arasında gereksiz SDK yükseltmesi yapılmayacak. Bulut derleme zorunlu değil; yerel Android/Xcode derlemeleriyle başlanabilir.

## 4. Aşamalar, çıktılar ve tamamlanma koşulları

### Aşama 0 — Mevcut sistemi ve referansı kaydet

1. Mevcut değişiklikleri ve takip edilmeyen dosyaları kaybetmeden sürümlenebilir başlangıç kopyası oluştur.
2. S25 modelini, Android/One UI sürümünü, ekran yoğunluğunu, yazı ölçeğini ve launcher ayarlarını kaydet.
3. Aynı örnek verilerle widget'ın kullanılan boyutlarını, açık/koyu duvar kâğıtlarını, ayar ekranını ve hızlı eklemeyi görüntüle; etkileşim akışlarını kaydet.
4. Kurulu uygulamanın kimliğini, sürümünü ve imza sertifikası parmak izini doğrula. Anahtarların içeriğini belgeye yazma.
5. Mevcut Flutter kontrollerinin sonucunu, Android widget testlerini ve bilinen hataları ayrı kaydet. Yeni prototip hatalarıyla mevcut hataları karıştırma.
6. Ekran/modül envanterini, Google entegrasyonlarını, abonelik akışlarını ve tüm kayıt oluşturma/güncelleme yollarını çıkar.
7. `DEPLOYMENT_STATE.md` bilgilerini güncel canlı durumla karşılaştır; oradaki eski tarihli iddiaları doğrulanmış güncel durum sayma.

**Çıktı:** Referans görseller, dosya envanteri, özellik matrisi ve başlangıç kontrol raporu.  
**Tamamlanma koşulu:** Korunacak widget sürümü ve davranışları açıkça tanımlı.

### Aşama 1 — Widget bağlantı sözleşmesini sabitle

Mevcut sözleşmeyi sürümlü bir belge ve örnek JSON verileriyle tarif et:

| İşlem | Korunacak anlam |
|---|---|
| `updateWidget` | Sayaçlar ve `habits/tasks/reminders` listeleriyle snapshot güncelleme |
| `clearWidget` | Oturum kapatma sırasında eski hesabın widget verisini temizleme |
| `readPendingToggles` | `{id, kind, done, at}` biçimindeki bekleyen işlemleri okuma |
| `clearPendingToggles` | Yalnızca başarıyla uygulanan işlemleri temizleme |
| `readPendingAdds` | Başlık/tür ve `startAt/endAt/allDay` zaman bilgilerini okuma |
| `clearPendingAdds` | Başarılı eklemeleri ve bunların geçici yerel satırlarını temizleme |

- Zaman dilimi, gün sınırı, gecikmiş kayıtlar, sıralama, görünür kayıt sınırı ve saat metni kurallarını mevcut koddan çıkar.
- Arızada kuyruk kaybını, tekrar denemede çift kayıt oluşmasını, aynı maddeye art arda dokunmayı ve işlem sürerken gelen yeni kaydın silinmesini sınayan senaryolar tanımla.
- Ekleme işlemleri için kalıcı işlem kimliğiyle tekrar uygulama güvenliğini değerlendir. Sunucuda ek destek gerekiyorsa eski istemciyle uyumlu, ayrı bir değişiklik olarak planla; mevcut API'nin otomatik olarak çift kaydı önlediğini varsayma.
- Oturum hazır olmadan kuyruk çalıştırma; bekleyen işlemleri yanlış kullanıcıya yazmama kuralını belirle.
- Widget'ın snapshot'ını uygulama verileri henüz yüklenmeden boş listeyle ezme.

**Çıktı:** `WIDGET_CONTRACT.md`, veri örnekleri ve bağlantı kabul senaryoları.  
**Tamamlanma koşulu:** Flutter'a ait hangi sorumlulukların yeni bağlantıya taşınacağı belli.

### Aşama 2 — Yeni iskelet ve widget prototipi

1. Ayrı dizinde TypeScript tabanlı React Native/Expo development build oluştur; Android ve iOS iskeletlerini derle.
2. Widget sınıflarını, XML'leri, drawable/font/renk/stil kaynaklarını, servislerini ve manifest kayıtlarını koruyarak Android hedefe dahil et. İlk aşamada widget paketini yeniden isimlendirme veya yeni bir UI teknolojisine taşıma.
3. Yeni yerel bağlantı modülünden mevcut widget deposuna örnek veri gönder; widget kuyruğunu okuyup onayla.
4. `MainActivity` uyarlamasıyla eski `steady_progress_route` bilgisini yeni yönlendirmeye aktar. Kimlik doğrulama bekleniyorsa hedefi sakla ve sonrasında aç.
5. WorkManager worker sınıf adları, bekleyen işler, PendingIntent hedefleri ve kaynak bağımlılıklarının yeni derlemede korunmasını doğrula.
6. Widget kaynaklarının yeni tema, SDK veya Gradle ayarları nedeniyle farklı çizilmediğini S25'te karşılaştır.

Prototipin ilk kurulumu ayrı geliştirme kimliğiyle, mevcut uygulamanın yanına yapılabilir. Bu yöntem görünüm/işlev denemesi içindir; mevcut yerleştirilmiş widget'ların güncellemede korunmasını kanıtlamaz.

**Çıktı:** Yeni uygulamanın eski widget'la haberleştiği Android prototipi; açılan iOS iskeleti.  
**Tamamlanma koşulu:** Widget'ın referans görünümü ve yerel işlemleri korunuyor. Bu koşul geçmeden bütün ekranların yeniden yazımına başlanmaz.

### Aşama 3 — Güncelleme, kimlik ve veri sürekliliğini kanıtla

- Nihai Android `applicationId`, widget provider/servis/activity kimlikleri ve ilgili manifest metadata kaynaklarını koru.
- Aynı uygulamaya güncelleme için imza uyumluluğunu doğrula; Play App Signing ile upload key ayrımını dikkate al. Sadece aynı paket adının yeterli olduğunu varsayma. [Android güncelleme kuralları](https://developer.android.com/google/play/app-updates)
- `steady_progress_widget`, `steady_progress_widget_config`, ekleme ve tamamlama kuyruğu depolarını koru.
- Eski sürümde yerleştirilmiş birden fazla widget varken, uygulamayı kaldırmadan yeni sürüme güncelle. Konum, boyut, kişisel ayarlar, veriler ve bekleyen işlemleri karşılaştır.
- Firebase SDK seçimini yerel oturum ve çevrimdışı davranış gereksinimine göre yap. Eski Flutter oturumunun yeni SDK tarafından otomatik okunacağını varsayma; güncelleme deneyiyle doğrula. Yeniden giriş gerekirse eski widget verisini veya bekleyen işlemleri yanlışlıkla silmeyen kontrollü akış tasarla.
- Flutter Firestore önbelleğindeki henüz sunucuya ulaşmamış yazılar ve yerel tercihler için geçiş stratejisi belirle. Gerekirse son Flutter sürümünde uyum hazırlığı yap; veriyi yalnızca yeni SDK'nın önbelleği okuyacağı varsayımına bırakma.
- FCM token kayıtları, Google oturumu/yönlendirme yapılandırması ve zamanlanmış alarmların güncelleme sonrası durumunu sınayarak taşı.

**Çıktı:** Eski sürümden yeni sürüme veri kaybetmeden güncelleme raporu.  
**Tamamlanma koşulu:** Widget yeniden eklenmeden çalışıyor; kayıtlar ve bekleyen işlemler korunuyor. İmza/cihaz erişimi eksikse bu koşul açık kalır.

### Aşama 4 — Görünümü koruyarak ortak bileşenleri kur

1. Mevcut `app_colors.dart`, `app_type.dart`, `app_spacing.dart`, font ve ikon varlıklarını referans al; renk/font yenilemesi yapma.
2. Aynı işlev için farklılaşmış örnekleri “mevcut örnekler / ortak seçim / gerekçe” tablosunda topla. Görünür fark doğuran seçimleri kullanıcıyla netleştir; tekil, işlevsel farklılıkları zorla aynılaştırma.
3. Ortak buton, textbox, label, başlık, filtre, liste satırı, durum etiketi, hata/boş/yükleniyor görünümü ve modal bileşenlerini oluştur.
4. Liste ekranı, ekleme/düzenleme formu ve ayarlar sayfası için ortak şablonlar oluştur. Habits ve Tasks aynı sayfa iskeletini kullansın.
5. Safe area ve klavye boşluğunu tek yerde yönet. Üst çentik, yatay ekran, büyük yazı, klavye açık modal ve erişilebilir işlem alanlarını sınayarak standarda bağla.
6. Alttaki “+” ile aynı işi yapan Add butonlarını kaldır; kayıt kaydetme, farklı türde ekleme veya farklı işlev taşıyan butonları yanlışlıkla kaldırma.

**Çıktı:** `UI_STANDARDS.md`, ortak bileşenler ve mevcut tasarımla karşılaştırılabilen örnek ekranlar.  
**Tamamlanma koşulu:** Renk/font karakteri korunmuş; sayfa ve bileşen tutarsızlıkları üzerinde ortak karar var.

### Aşama 5 — İşlevleri uçtan uca taşı

Sıra:

1. Giriş, hesap, oturum, yönlendirme, profil, yetki/plan kontrolü ve Firebase servisleri.
2. Tasks: listeleme, ekleme, düzenleme, tamamlama, tarihler, alt maddeler, toplu işlemler ve widget eşitlemesi.
3. Reminders: tarih/saat, öncelik, not, tekrar/erken uyarı gibi mevcut alanlar; her alanın çalışan davranışını envantere göre taşı.
4. Habits: program, günlük kayıtlar, seri hesabı, kategori ve widget tamamlama akışı.
5. Dashboard/Today ve ortak seçiciler.
6. Learning, Content, Finance, Workout, Goals, Analytics, Reports ve More/Profile/Settings ekranları.
7. Google Calendar/Drive/Sheets/Docs, abonelik ve satın alma geri yükleme gibi entegrasyonlar. iOS mağaza satın alma desteğini ayrı doğrula; Play doğrulamasını iOS'ta kullanma.

Her modül için veri okuma/yazma, hata, çevrimdışı durum, yetki ve yönlendirme senaryoları tamamlanacak. Widget eşitlemesi yalnızca bir ekran açıkken çalışan bir yan etki olmayacak; oturum/uygulama yaşam döngüsü seviyesinde kurulacak.

Mevcut güvenlik kuralları korunacak: Tasks ve Habits oluşturma `createTask` / `createHabit` callable yollarından geçecek. Abonelik yetkisi istemci tarafından verilmeyecek. Firebase emulator ve test verileriyle kontroller yapılacak; mevcut üretim projesi deneme veritabanı gibi kullanılmayacak.

**Çıktı:** Android/iOS özellik eşliği matrisi tamamlanmış yeni istemci.  
**Tamamlanma koşulu:** Sadece ekran görüntüsü değil, ilgili iş akışı ve veri sonucu da doğrulanmış.

### Aşama 6 — Bildirim ve cihaz davranışlarını doğrula

Bu çalışma widget görsel katmanından ayrı yürütülecek. Ortak kod, platformların bildirim kurallarını ortadan kaldırmaz.

- Android yerel alarm ve uzak push yollarını birlikte incele. Aynı hatırlatıcı için çift bildirim, iptal sonrası alarm, tekrar, yeniden başlatma ve saat dilimi değişimini sınayarak eşitle.
- Önemli kategorisinin sessiz modda ses vermesi için Android ses kullanımı/kanal stratejisini gerçek S25'te doğrula. Sessiz mod, Rahatsız Etmeyin ve alarm ses seviyesini ayrı senaryolar olarak ele al.
- Hedef ses: telefonun varsayılan hatırlatıcı/bildirim sesi. Samsung Reminder'ın uygulamaya özel sesiyle sistem varsayılanının aynı olduğunu varsayma; cihazdan doğrula. Özel uygulama sesi erişilebilir değilse farkı kullanıcıya açıkla ve ortak karar al.
- iOS için normal bildirim, Critical Alerts ve desteklenen sürümlerde AlarmKit seçeneklerini gereksinime göre değerlendir. Önceki konuşmadaki Critical Alerts açıklaması normal bildirim içindi; AlarmKit ayrı izin ve alarm deneyimiyle sessiz/odak modunu aşabilen bir seçenektir. Android davranışıyla birebir eşlik prototipten önce taahhüt edilmez. [Apple AlarmKit](https://developer.apple.com/documentation/AlarmKit/scheduling-an-alarm-with-alarmkit), [Critical Alerts](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.usernotifications.critical-alerts)
- Bildirim kapatma, izin reddi ve oturum kapatma tercihlerinin yerel/uzak tüm yollarda uygulanmasını doğrula.

**Çıktı:** Cihaz/izin/bildirim davranış matrisi.  
**Tamamlanma koşulu:** Desteklenen davranışlar gerçek cihazda doğrulanmış; platforma bağlı eksikler görünür ve karara bağlanmış.

### Aşama 7 — Son kabul ve kontrollü geçiş

1. Android widget için mevcut instrumentation testlerini yeni hedefte çalıştır; ekran görüntülerini aynı veri, duvar kâğıdı, boyut, yoğunluk ve yazı ölçeğiyle karşılaştır.
2. S25'te temiz kurulumdan ayrı olarak gerçek güncelleme senaryosunu tamamla. iPhone'da form/klavye, safe area, giriş ve bildirim davranışlarını kontrol et.
3. Büyük veri listeleri, açılış, uygulama dönüşü, ağ kopması ve tekrar deneme davranışını ölç. Flutter sürümüne göre önemli gerilemeleri çöz.
4. Kullanıcıya karşılaştırma raporu ve kurulabilir test sürümü sun. Widget farkı varsa kabul koşulu geçilmiş sayma.
5. Yayın adımını ayrıca planla. Eski istemciyle backend uyumluluğunu koru; üretim geri dönüşünü düşük sürüm numaralı APK kurmak yerine, gerekirse daha yüksek sürüm numaralı uyumlu düzeltme sürümüyle yap.
6. Yeni sürümün kabulü ve izleme dönemi bitmeden Flutter kaynaklarını kaldırma.

**Çıktı:** Kabul raporu, kurulum/yayın yönergesi ve geri dönüş planı.

## 5. Widget kabul listesi

- [ ] Renkler, fontlar, ikonlar, opaklık, satır yoğunluğu, köşeler ve boşluklar referansla aynı.
- [ ] Kullanılan boyutlarda yeniden boyutlandırma ve kaydırma aynı şekilde çalışıyor.
- [ ] Kapsam, görünür kayıt seçimi, ayarlar ve hızlı ekleme ekranı korunmuş.
- [ ] Tamamlama ve “+” işlemleri yerelde hemen görünüyor; uygulama açılınca doğru hesaba eşitleniyor.
- [ ] Hızlı eklemenin görev tarih aralığı, hatırlatıcı saati ve alışkanlık seçenekleri korunmuş.
- [ ] Soğuk başlangıçta ve uygulama açıkken kayıt dokunuşu doğru editöre gidiyor.
- [ ] Birden fazla widget ve kişisel ayarları güncellemeden sonra korunuyor.
- [ ] Çevrimdışı işlem, süreç sonlandırılması, yeniden açma ve tekrar denemede kayıt kaybı/çoğalması yok.
- [ ] Zorla durdurma, normal süreç ölümü ve yeniden başlatma ayrı sınanmış; Android'in engellediği çalışmayı varmış gibi raporlamıyoruz.
- [ ] Oturum kapatma/değiştirme eski hesabın verisini yeni hesaba taşımıyor.
- [ ] Gerçek S25 kontrolü yapılmış. Simülatör/emülatör veya test geçişi bunun yerine sayılmıyor.

## 6. Yönetim ve karar noktaları

**İlk uygulama paketi:** Aşama 0–2; referans kaydı, sözleşme ve widget prototipi. Bu paketin sonucu görülmeden tüm modüller için kesin süre verilmez. Sonraki takvim prototipte çıkan bağlantı, imza ve veri sürekliliği bulgularına göre modül bazında çıkarılır.

Kod standardı ve mimari kararlar depodaki belgelerle korunacak. Figma isteğe bağlı karşılaştırma aracı olabilir; bu geçişte yeniden tasarım veya yeni brand kit üretimi şart değil.

Henüz doğrulanmamış konular: kullanılacak son Expo/SDK sürümleri, mevcut kurulumun imza erişimi, gerçek S25 referans görüntüleri, iPhone test cihazı ve minimum iOS sürümü, Firebase oturum/önbellek sürekliliği ve platformlara göre önemli alarm davranışı. Bunlar ilgili aşamanın çıktısıyla kapanacak; varsayımla tamamlanmış sayılmayacak.
