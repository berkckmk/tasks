# NAVBAR — Figma Referansının Projeye Uygulanması

## Amaç

Figma'daki navbar görsel mantığını projedeki 5 sekmeye uyarlamak.

Sekmeler:
1. Reminders
2. Today
3. Habits
4. Tasks
5. More

Navbar tek component olmalıdır. Beş ayrı navbar yazılmaz.

## Temel yapı

Container:
- koyu arkaplan
- yüksek radius / pill form
- her sekme aynı hizada
- seçili item genişleyerek icon + label gösterir
- pasif item yalnızca icon gösterebilir
- seçili state değişirken container geometrisi değişmez

## Fixed tab accent colors

- Reminders: `#9E86FF`
- Today: `#FFB986`
- Habits: `#86E6B0`
- Tasks: `#FF86EC`
- More: `#86DBFF`

Inactive:
- `#A9A4B0`

Navbar background:
- `#212329`

## Active pill

Figma mantığı:
- aktif item rengine göre gradient fade
- aktif icon ve label aynı accent family
- gradient bir uçta görünür, diğer uçta transparanlaşır
- sert solid pill yerine yumuşak fade karakteri korunur

Örnek yaklaşım:

`linear-gradient(101.53deg, rgba(tabColor, 0.90) -156.38%, rgba(tabColor, 0) 94.04%)`

Platform gradient API'si CSS ile birebir çalışmıyorsa görsel sonucu koruyacak eşdeğer implementasyon kullan.

## Page Header ile ilişki

Aktif navbar rengi, ilgili ekranın üst başlık alanına da düşük yoğunlukta yansır.

Örnek:
- Reminders seçili → navbar mor + Reminders başlığı arkasında yumuşak mor fade
- Today seçili → turuncu
- Habits seçili → yeşil
- Tasks seçili → pembe
- More seçili → açık mavi

Fakat:
- body background değişmez,
- bütün butonlar tab rengine dönmez,
- kartlar tab rengine boyanmaz,
- yalnızca kontrollü accent alanları etkilenir.

## Interaction

- Active state route/navigation state'ten türetilmeli.
- Color sabit tab mapping'den gelmeli.
- Aktif tab değişince pill ve page header gradient birlikte güncellenmeli.
- Renk transition varsa kısa ve sakin olmalı.
- Layout shift olmamalı.

## Asset kuralları

Figma'dan SVG ikonlar export edildiyse:
- doğrudan bu assetler kullanılır,
- başka icon library ile yaklaşık eşdeğer ikon seçilmez,
- SVG stroke/fill yalnızca tab state rengine bağlanabilir.

## Yasaklar

- Beş sekme için rastgele yeni renk üretme
- Her route için ayrı navbar component oluşturma
- Navbar radius/padding'ini route bazında değiştirme
- Active renkleri tema rengiymiş gibi tüm ekrana yayma
- Gradient yerine neon glow ekleme
- Figma referansını yeniden yorumlama
