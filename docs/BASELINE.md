# Geçiş başlangıç kaydı — 6 Eylül 2026

## Korunan kaynak

- Flutter kaynak deposu: `../steady_progress`.
- Başlangıç yedeği: `../.migration-backups/20260906T074815Z/`.
- Yedek, Git HEAD ile sınırlı değil: değiştirilmiş ve takip edilmeyen 337 kaynak dosyası dahil.
- `source.tar.gz`, dosya bazlı SHA-256 manifesti, çalışma ağacı farkı ve Git durum kaydı yerel yedekte.
- Widget paketindeki Kotlin, Android kaynakları ve mevcut instrumentation testlerinden 71 dosya `baseline/widget-manifest.json` ile korunuyor.
- Orijinal Flutter/Kotlin/XML uygulama kodu bu geçiş paketinde değiştirilmedi.

## Başlangıç kontrolleri

| Kontrol | Sonuç |
|---|---|
| Flutter sürümü | 3.47.0 stable; Dart 3.13.0 |
| Flutter analyze | 11 info; hata/warning yok; lint nedeniyle çıkış kodu 1 |
| Flutter test | 57 başarılı, 1 başarısız |
| Başarısız test | `app_flow_test.dart`: core tabs; `tapMoreRow` sırasında `Bad state: Too many elements` |
| S25 bağlantısı | Başlangıçta ADB cihaz listesi boş; gerçek cihaz referansı henüz alınmadı |
| iOS derleme ortamı | Tam Xcode yok; yalnızca Command Line Tools aktif |
| Node / npm | 24.20.0 / 11.19.0 |
| Java | OpenJDK 17.0.19 |
| Android SDK | API 36 kurulu; NDK 27.1 ve 28.2 kurulu |

Flutter kontrol çıktıları `baseline/flutter-analyze.log` ve `baseline/flutter-test.log` dosyalarında. Başarısız test bu geçişin oluşturduğu bir hata olarak raporlanmayacak; mevcut davranışın tümünün hatasız olduğu da varsayılmayacak.

## Görsel referans ve güncelleme için açık koşullar

Gerçek S25 üzerinde widget boyutları (2×2, 4×2, 4×4), duvar kâğıdı, yoğunluk, yazı ölçeği, kapsamlar, ayarlar, kaydırma ve hızlı ekleme görüntülenecek. Aynı cihaz/veri/ayarlarla yeni sürüm karşılaştırılacak. Hash eşliği görsel/işlevsel cihaz testinin yerine geçmez.

Kurulu sürümün kimlik ve imza sürekliliği henüz doğrulanmadı. Prototip ayrı `.preview` uygulama kimliğiyle kurulacak; mevcut uygulamanın üzerine kurulmayacak. Nihai kimlikle güncelleme deneyi ayrı bir kabul aşaması.

## Mevcut kaynakta tespit edilen bağlantı riskleri

1. Tamamlama kuyruğu `(id, kind)` ile birleştirilirken eski `clear` yalnızca `id` üzerinden siliyor. Eşzamanlı yeni işlem ve farklı koleksiyonda aynı kimlik senaryoları üretim geçişinden önce çözülmeli.
2. Hızlı ekleme için Flutter tarafında işlem kimliğini sunucuya taşıyan idempotency sözleşmesi görünmüyor. Sunucuda oluşturma başarılı olduktan sonra onay kaybolursa tekrar deneme çift kayıt oluşturabilir.
3. Kuyruklar kullanıcı kimliği taşımıyor. Oturum bekleme/hesap değiştirme politikası doğrulanmadan üretim hesabına kuyruk uygulanmayacak.
4. Kuyruk kapasitesi: ekleme 50, tamamlama 100; sınır aşımında eski kayıtlar düşüyor. Sınırsız çevrimdışı saklama taahhüdü verilmeyecek.
5. Eski widget belgesinin bazı cam/bitmap bölümleri güncel dosya ağacıyla uyuşmuyor. Kaynak ve cihaz referans alınacak.

Bu bulgular widget görsel kaynaklarını yeniden yazmak için gerekçe değildir. Gerekli bağlantı/veri güvenliği uyarlamaları ayrı değerlendirilir.
