# BRAND GUIDE

## 1. Ürün karakteri

Koyu, sakin, minimal ve fonksiyonel kişisel planlayıcı arayüzü.

Arayüz:
- bilgiyi dekorasyondan önde tutar,
- düşük görsel gürültü kullanır,
- koyu lacivert/siyah taban üzerinde yükseltilmiş koyu yüzeyler kullanır,
- açık metin + düşük kontrastlı ikincil metin hiyerarşisi kullanır,
- ince border ve yumuşak radius dili taşır,
- aktif durumları renk ve hafif gradient ile belirtir.

## 2. Yasak görsel davranışlar

AI veya geliştirici aşağıdakileri kendiliğinden eklememelidir:
- yeni font ailesi,
- rastgele font size/weight,
- yeni accent rengi,
- neon glow,
- ağır shadow,
- yoğun glassmorphism,
- rastgele gradient,
- emoji tabanlı UI ikonu,
- mevcut componentlerden kopuk yeni radius değerleri,
- aynı amaç için ikinci bir button/card/input tasarımı.

## 3. Renk kullanımı

Ana uygulama koyu tema karakterini korur.

Tab renkleri yalnızca:
- aktif navbar item,
- aktif icon ve label,
- seçili tab ile ilişkili küçük UI vurguları,
- üst page header'ın yumuşak gradient fade alanı

için kullanılabilir.

Tab rengi bütün ekranın ana rengi değildir.

## 4. Page Header vurgusu

Her ana tab ekranının üst başlık alanında, aktif tab renginden türetilmiş yumuşak bir
gradient fade bulunabilir.

Örnek:
- Reminders ekranında mor,
- Today ekranında turuncu,
- Habits ekranında yeşil,
- Tasks ekranında pembe,
- More ekranında açık mavi.

Bu efekt:
- başlığın okunabilirliğini azaltmamalı,
- tüm ekranı kaplamamalı,
- sert bir renk bloğuna dönüşmemeli,
- dekoratif bir kart gibi değil, arkadan gelen yumuşak bir ışık/fade gibi görünmelidir.

## 5. Kaynak önceliği

Çakışma olduğunda öncelik:
1. Mevcut çalışan uygulamadaki gerçek design token / theme değerleri
2. Bu design system
3. Figma navbar referansı
4. AI modelinin önerisi

AI hiçbir zaman 1-3 arasında tanımlı bir değeri kendi estetik tercihiyle değiştiremez.
