# UI Revision Context

Bu revizyonun amacı, mevcut tasarım dilini bozmak değil; projeyi daha tutarlı, daha rafine ve daha düzenli hale getirmektir. Şu an uygulamada açık bej / kırık beyaz ana palet, sayfa bazlı renkli başlık alanları ve koyu navbar yaklaşımı oluşmaya başlamış durumda. Bu yön korunmalı; ancak component geometrisi, navbar ağırlığı ve formu, buton biçimi ve sayfalar arası geçiş davranışı daha sistematik hale getirilmelidir.

---

## 1. Köşe yuvarlaklıkları proje genelinde tutarlı hale getirilmeli

Proje genelinde köşeleri yuvarlatılmış tüm öğeler ortak bir geometri diline bağlanmalıdır. Şu anda farklı alanlarda radius karakteri birbirinden kopuk hissediyor. Bunun yerine, bütün yuvarlatılmış item’lar için referans olarak sayfaların en üstündeki başlık alanının köşe formu alınmalıdır.

Başlık alanındaki radius dili, uygulamanın ana şekil referansı olacaktır. Diğer bileşenler bu formdan türemelidir. Elbette tüm öğelerde birebir aynı pixel değeri kullanılmak zorunda değildir; kullanım yerine göre yaklaşık %2–3 oranında daha az veya daha fazla radius uygulanabilir. Ancak genel his aynı aileden gelmelidir.

Bu kural aşağıdaki alanlarda geçerli olmalıdır:

* üst başlık alanları
* kartlar
* input alanları
* filtre / segment butonları
* bottom sheet ve modal alanları
* navbar active pill
* küçük aksiyon butonları
* sayfalardaki ekleme butonları

Amaç, tüm UI’nin tek bir ürün dili taşımasıdır. Bir component diğerinden bağımsız bir köşe mantığına sahip görünmemelidir.

---

## 2. “Kaydet” butonunun yerleşimi düzeltilmeli

Quick Capture alanındaki `Kaydet` butonunun konumu bozulmuş görünüyor. Buton yerleşim olarak bulunduğu alanla tam hizalanmıyor ve sağ tarafa kaymış / orantısız duruyor. Bu alan yeniden dengelenmelidir.

İstenen yapı şudur:

* Input alanı ve `Kaydet` butonu aynı satır düzeninde, aynı yükseklik hissiyle çalışmalı
* Aralarındaki boşluk kontrollü ve düzenli olmalı
* `Kaydet` butonu sağa sıkışmış ya da kopuk görünmemeli
* Bulunduğu kapsayıcı alan içinde dikey ve yatay hizası dengeli olmalı
* Input + action ilişkisi tek bir birleşik quick capture bileşeni gibi görünmeli

Amaç yalnızca butonu sola ya da sağa taşımak değil; bileşenin bütün yerleşim mantığını toparlamaktır.

---

## 3. Navbar görsel olarak daha güçlü hale getirilmeli

Navbar’da şu anda genel fikir doğru olsa da içeride bir “çiğlik” hissi var. İçindeki item’lar, ikonlar ve butonlar biraz fazla çelimsiz duruyor. Navbar, uygulamanın güçlü ve karakterli bir alt navigasyon elemanı gibi görünmelidir.

### Revize hedefi:

* Navbar içindeki item’lar daha dolgun ve daha dengeli olmalı
* Icon boyutları ve aktif alanın ağırlığı biraz artırılmalı
* Active pill daha güçlü ve daha oturmuş görünmeli
* Label’lar çok zayıf ya da sönük kalmamalı
* Genel görünüm daha premium, daha rafine ve daha kontrollü olmalı

### Navbar arkaplanı da revize edilmeli:

Navbar’ın arkaplanı şu anda fazla koyu kalıyor. Bu karanlık hissi bir miktar yumuşatılmalı. Ancak tamamen açık yapılmamalı. Uygulamanın geneline uyumlu olacak şekilde, yine projenin en koyu elemanlarından biri olabilir; fakat mutlak siyaha yakın, çok sert koyu hissi azaltılmalıdır.

Yani yaklaşım şu olmalı:

* navbar, proje genelinden hâlâ daha koyu olabilir
* ama mevcut kadar ağır, sert ve boğucu görünmemeli
* koyu charcoal / sıcak koyu nötr / yumuşatılmış derin tonlar tercih edilmeli
* uygulamanın açık taş-bej yüzeyleriyle uyumlu, daha sofistike bir koyu ton seçilmeli

---

## 4. Sayfalardaki “+” ekleme butonu yuvarlak olmamalı

Sayfa içlerinde kullanılan `+` ekleme butonları artık dairesel / tam yuvarlak formda olmamalıdır. Bu form, projenin yeni genel geometri diliyle uyumlu görünmüyor.

Bunun yerine `+` butonu şu karaktere geçmelidir:

* köşeleri yuvarlatılmış
* küçük / kompakt
* mini dikdörtgen ya da yumuşatılmış kapsül-rect formunda
* uygulamanın genel radius sistemiyle uyumlu
* fazla oyuncak gibi görünmeyen
* modern ve işlevsel

Yani `floating round action button` mantığından çıkılmalı; yerine projenin genel tasarım diline daha uygun, küçük, yuvarlatılmış dikdörtgenimsi bir aksiyon butonu kullanılmalıdır.

Bu kural tüm ana sayfalarda tutarlı olmalıdır.

---

## 5. Sayfalar arası geçiş swipe ile mümkün olmalı

Ana sayfalar arasında geçiş, yalnızca navbar tıklamasıyla değil; ekran üzerinde yatay kaydırma hareketiyle de mümkün olmalıdır.

İstenen davranış:

* Sayfanın yaklaşık **%90’lık ana içerik alanı** üzerinden sağa / sola kaydırma algılanabilmeli
* Kullanıcı içerik alanında yatay swipe yaptığında bir önceki / sonraki ana sayfaya geçebilmeli
* Bu alan çok dar olmamalı; ekranın büyük çoğunluğu bu gesture’ı desteklemeli
* Swipe geçişi doğal, akıcı ve kontrollü olmalı
* Geçiş sırasında sayfa yapısı kararsız ya da kırık görünmemeli

Buradaki amaç, uygulamayı daha akıcı ve daha native hissettirmektir. Kullanıcı yalnızca alt navbar’a bağımlı kalmadan, içerik alanı üzerinden de bölümler arasında geçebilmelidir.

Elbette bu gesture, metin girişi, yatay özel kontrol veya başka bir etkileşim alanıyla çakışıyorsa akıllıca yönetilmelidir; ancak genel olarak ana sayfalar arası geçiş swipe ile desteklenmelidir.

---

## 6. Navbar Ek Revizyonu

Navbar’ın genel yapısı korunacak ancak mevcut görünüm hâlâ gereğinden koyu ve fazla oval. Daha rafine, daha açık ve proje genelindeki bej / kırık beyaz / sıcak nötr yüzeylerle daha uyumlu hale getirilmelidir.

### 1. Navbar arkaplan rengini aç

Navbar şu anda hâlâ fazla koyu görünüyor. Tamamen açık yapılmasın ancak mevcut koyu charcoal tonundan daha yumuşak, daha sıcak ve proje geneline daha yakın bir tona çekilsin.

Amaç:

* navbar hâlâ ana içerikten biraz daha koyu kalsın,
* fakat siyaha yakın ağır görünmesin,
* açık taş/bej UI ile daha doğal bağ kursun,
* seçili gradient alanlarının kontrastını korusun.

Yani navbar “dark anchor” olarak kalabilir ama ton farkı yumuşatılmalıdır.

### 2. Navbar dış radius azaltılsın

Navbar container’ın dış köşeleri şu anda fazla yuvarlak / kapsül formunda. Bu radius belirgin şekilde azaltılmalı.

Yeni hedef:

* hâlâ köşeleri yuvarlatılmış,
* ancak “pill” görünümünden daha çok yumuşatılmış dikdörtgen karakterine yakın,
* proje genelindeki card ve header radius diliyle daha uyumlu.

### 3. Seçili item alanının radius’u da aynı oranda azaltılsın

Aktif sekmenin üstüne gelen renkli gradient seçici alan da fazla oval. Navbar dış radius’u ne oranda azaltılıyorsa, aktif item/pill radius’u da yaklaşık aynı oranda azaltılmalıdır.

İkisi aynı geometrik ailede görünmeli.

Yani:

* navbar daha az oval,
* active selector da daha az oval,
* ikisi birlikte daha kontrollü ve modern görünmeli.

### 4. Active Selector Boyut Revizyonu (Dikeyde Güçlendirme & Yatay Denge)

Bunun yerine aktif sekmenin üstüne gelen renkli gradient selector alanı **üst ve alt yönde biraz büyütülerek daha güçlü ve tok hale getirilecek**, aynı zamanda yatay nefes alanı korunacaktır.

Amaç:

* selector’ın daha dolgun görünmesi,
* navbar içindeki item’ların çelimsiz hissini azaltması,
* aktif sekmenin daha güçlü vurgulanması,
* yatay sıkışma yaratmadan dengeli bir görsel ağırlık sunması.

Uygulama kuralı:

* Selector yüksekliği yaklaşık **%4–6 artırılabilir**.
* Üst ve alt padding/alan dengeli büyütülmeli.
* İçerideki icon ve label merkezde kalmalı.
* Navbar container yüksekliğiyle selector arasında hâlâ net bir iç boşluk bulunmalı.
* Selector navbar sınırlarına yapışmamalı.
* Radius azaltma kararı korunmalı; yani selector daha yüksek olsa da aşırı kapsül/pill görünümüne dönmemeli.

> **Ek:** Active selector yalnızca dikeyde büyütülmeyecek; aynı zamanda mevcut konum ve merkez hizası korunarak **sağdan ve soldan yaklaşık %1–2 oranında daraltılacak**. Böylece selector daha yüksek ve tok görünürken yatayda gereksiz geniş kalmayacak. İçindeki icon ve label merkezde kalmalı; bu değişiklik navbar item hizalarını veya geçiş animasyonunu bozmamalıdır.

Beklenen görünüm:

Selector dikeyde biraz daha kalın, daha tok, daha güçlü ve daha dengeli; yatayda ise kenarlardan %1–2 kontrollü daraltılmış ve ferah görünmeli. Navbarı doldurup taşmamalı, üst ve alt sınırlarla çakışmamalıdır. Navbar dış radius ve selector radius’u yine aynı geometrik ailede, daha az oval karakterde kalmalıdır.

### 5. Korunacak davranışlar

Şunlar değişmemeli:

* sekme bazlı gradient renk sistemi
* aktif icon + label accent rengi
* navbar active selector’ın hareketli geçiş mantığı
* soldaki item sağa, sağdaki item sola, ortadakiler iki yana dengeli genişleme davranışı
* sayfa accent renk eşleşmeleri

Bu revizyon yalnızca:

* navbar tonu,
* dış radius,
* active selector radius,
* active selector dikey dolgunluğu / yüksekliği (%4–6 artış)

üzerinde yapılmalıdır.

---

# Genel beklenti

Bu revizyon sonunda uygulama:

* geometri olarak daha tutarlı,
* köşe yuvarlaklıklarında daha bütünlüklü,
* navbar açısından hem daha güçlü ve olgun, hem de daha az oval (yumuşatılmış dikdörtgen karakterinde) ve bej/taş yüzeylerle daha uyumlu açık/yumuşak koyu tonda,
* active selector alanı yatayda sıkışmadan dikeyde daha dolgun/tok (%4–6 yükseklik artışı ile güçlendirilmiş) ve navbar ile uyumlu yumuşatılmış köşe formunda,
* ekleme butonlarında genel tasarım diline daha uygun,
* yerleşim açısından daha düzenli,
* sayfalar arası kullanım deneyimi açısından daha akıcı

bir yapıya kavuşmalıdır.

Amaç yeni bir stil icat etmek değil; mevcut yönü toparlamak, görsel dili tekleştirmek ve projeyi daha profesyonel bir seviyeye taşımaktır.
