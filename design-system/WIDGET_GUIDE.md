# WIDGET GUIDE

## Amaç

Widget, uygulamanın birebir küçültülmüş kopyası değildir; ancak aynı ürün ailesine ait olduğu
ilk bakışta anlaşılmalıdır.

## Widget'ın uygulamadan miras alacağı şeyler

- Font family
- Typography hierarchy
- Accent colors
- Icon language
- Checkbox / status dili
- Radius ailesi
- Spacing ritmi
- Text color hierarchy
- State colors

## Widget'a özel izin verilen uyarlamalar

- Background image
- Blur
- Scrim / overlay
- Transparency
- Daha kompakt spacing
- Platformun zorunlu widget sınırları
- Widget boyutuna göre bilgi yoğunluğu azaltma

## Widget navigation / state colors

Widget içerisinde tab benzeri category veya active state gösteriliyorsa, uygulamadaki aynı
accent mapping kullanılmalıdır.

- Reminders: #9E86FF
- Today: #FFB986
- Habits: #86E6B0
- Tasks: #FF86EC
- More: #86DBFF

## Widget item standardı

`[checkbox/status] [time] [title] [type label/icon]`

- Bilgi hiyerarşisi uygulamadaki task/reminder kartlarıyla aynı olmalı.
- Completed state: opacity azalt + strike-through kullanılabilir.
- Rastgele icon, font veya yeni accent üretilemez.
- Widget arkaplan görseli metin kontrastını bozuyorsa scrim eklenir.

## Widget header

Önerilen yapı:

`[Today / date selector] [progress] [add action]`

Altında:
- progress bar
- compact item list

Widget'ın üst bölümünde de aktif context rengi küçük vurgu olarak kullanılabilir; ancak
uygulama page header'ındaki kadar geniş bir gradient kullanmak zorunlu değildir.

## Yasaklar

- Widget için ayrı brand palette yaratmak
- Farklı font family kullanmak
- Uygulamadaki radius ailesinden kopmak
- Tasarımı yalnızca screenshot'a bakarak yeniden icat etmek
- Platform limiti gerekmediği halde component yapısını değiştirmek
