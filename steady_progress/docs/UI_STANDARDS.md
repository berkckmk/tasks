# Steady Progress ortak UI standardı

Bu standart uygulamanın görünümünü yenilemez. Flutter sürümündeki Nocturne renkleri, Inter fontları, yoğunluk, köşeler ve çizgisel buton karakteri ortak React Native bileşenlerinde korunur. Yeni ekranlar ham görsel değerler yerine `src/theme` ve `src/components/ui` kullanır.

## Ortak kararlar

| Mevcut farklılık | Ortak seçim | Gerekçe |
|---|---|---|
| Tasks ve Habits başlık, filtre, boş durum ve ekleme konumları farklı | İkisi de `ListScreenShell` kullanır | Bilgi sırası ve ekleme hareketi aynı kalır |
| Sayfa içi Add düğmesi ile sağ alttaki `+` aynı işi yapıyor | Yalnızca sağ alttaki `AppFab` kalır | Aynı eylemin iki kopyasını kaldırır |
| Textbox renk, yükseklik, label ve hata davranışları farklı | Bütün formlar `AppTextField` kullanır | Yazılan metin, seçim, odak ve hata durumu tek sözleşmeyle görünür |
| Modal ve klavye boşluğu ekran bazında hesaplanıyor | Bütün sheet formları `AppSheet` kullanır | Üst güvenli alan ve klavye davranışı tek yerde yönetilir |
| Renk, yazı boyutu ve köşeler ekranda sayı olarak yazılıyor | Yalnızca tema tokenları kullanılır | Görsel sapmayı otomatik denetlenebilir hale getirir |

## Tema kaynağı

- `colors.ts`: Flutter `app_colors.dart` Nocturne paletinin aynı değerleri.
- `typography.ts`: Flutter `app_type.dart` içindeki Inter rolleri; başlık ağırlığı medium düzeyini geçmez.
- `spacing.ts`: Mevcut 0.70 yoğunluklu boşluk ölçeği ve erişilebilir kontrol ölçüleri.
- `radius.ts`, `shadows.ts`, `motion.ts`: ortak köşe, gölge ve hareket değerleri.
- `index.ts`: ekranların kullanacağı tek tema giriş noktası.

Tema dışındaki kaynaklarda ham hex renk, sayısal `fontSize` veya sayısal `borderRadius` kullanımı `npm run audit:design` ile reddedilir.

## Bileşen sözleşmeleri

- `AppText`: bütün metin rolleri ve semantik renk tonları.
- `AppButton`: primary, secondary, text ve destructive çeşitleri. Primary görünüm mevcut tasarımdaki gibi dolgusuz, accent çizgilidir.
- `AppTextField`: label, placeholder, odak, hata ve devre dışı durumunun tek uygulaması. Learning başlık alanı dahil bütün metin girişleri bunu kullanır.
- `AppCard`: ortak yüzey, kenarlık, köşe ve iç boşluk.
- `AppFab`: liste ekranındaki tek ekleme eylemi.
- `EmptyState`: yalnızca açıklama gösterir; ikinci bir Add düğmesi içermez.
- `AppScreen`: yatay sayfa boşluğunu, kaydırmayı, alt güvenli alanı ve klavye dokunma davranışını yönetir.
- `AppSheet`: form modallarının tek giriş noktasıdır; Android ve iOS'ta yarım ekran detent'inde kalır, uzun içerik içeride kayar.
- `ListEditorSheet`: bütün ekleme/düzenleme formlarının başlık, hata ve kaydetme sırasıdır.
- `ListScreenShell`: Tasks ve Habits ekranlarının ortak başlık, kontrol, içerik ve FAB sırasıdır.

## Sayfa düzenleri

Liste ekranı sırası başlık, kısa açıklama, seçim/toplu işlem alanı, filtreler, liste veya boş durum ve sağ alttaki `+` biçimindedir. Tasks ve Habits yalnızca içerik modeli ve gerekli filtreleri sağlar; dış yapıyı değiştirmez.

Ekleme ve düzenleme formları `AppSheet` içinde başlık, ana isim alanı, ikincil alanlar, hata metni ve kaydetme eylemi sırasını izler. Farklı kayıt türlerine özgü alanlar bu sıraya eklenebilir.

## Güvenli alan ve klavye

`AppSheet`, pencere yüksekliğinden üst güvenli alanı çıkararak içeriğin erişebileceği üst sınırı hesaplar ve yalnızca yarım ekran detent'i sunar. İçerik kamera çentiği veya durum çubuğu alanına geçemez. Alt boşluk cihazın alt inset değerinden küçük olamaz. iOS klavye yüksekliği `KeyboardAvoidingView` ile, Android klavye yerleşimi yerel sheet davranışıyla yönetilir.

Galaxy S25 referansında üst inset, kamera çentiği ve klavye açık form birlikte kabul edilir. Alışkanlık adı ve Learning title alanları otomatik odaklandığında alanın tamamı üst sistem yazılarının altında kalmalıdır. Yatay ekran, büyük yazı ve uzun hata metni aynı sözleşmeyle ayrıca sınanır.

## Durumlar ve erişilebilirlik

Butonların en küçük dokunma alanı 44 dp'dir. Yükleniyor durumu butonu kilitler ve erişilebilir busy durumunu bildirir. Hata metni `alert`, köprü durumu canlı bölge olarak sunulur. Renk tek başına anlam taşımaz; hata metni ve kontrol durumu birlikte gösterilir.

Ortak yapının karşılaştırma yüzeyi `/ui-standards` rotasındadır. `/tasks`, `/habits`, `/learning`, `/reminders`, `/content` ve `/workout` rotaları üretime bağlanmayan sentetik gateway üzerinde gerçek repository akışlarını ve ortak ekleme formlarını çalıştırır.
