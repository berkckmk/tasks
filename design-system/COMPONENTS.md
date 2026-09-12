# COMPONENTS

## 1. Standard Card

- Background: `surface`
- Border: `1px border`
- Radius: `radius.md`
- Internal padding: `spacing.lg`
- Card gap: `spacing.md`
- Shadow: none veya çok hafif
- Yeni kart varyantı gerekmedikçe aynı component tekrar kullanılır.

Önerilen yapı:

`[leading icon/status] [title + secondary text] [trailing time/action]`

Varyantlar:
- default
- selected
- completed
- disabled

## 2. Buttons

### Primary
- Height: 52
- Radius: 14
- Accent background
- Primary text
- Pressed / disabled / loading state zorunlu

### Secondary
- Height: 52
- Radius: 14
- Transparent veya surface
- Accent border
- Accent text

### Ghost
- Arka plansız
- Aynı typography ve touch target standardı

### Icon Button / FAB
- Tek ikon
- Minimum touch target korunur
- Accent yalnızca aksiyon önemine göre kullanılır

## 3. Inputs

Yapı:

`Label`
`8px gap`
`Input`

Input:
- Height: 52–56
- Radius: 14
- Border: 1
- Background: surface veya mevcut form standardı
- Focused border: ilgili accent
- Placeholder: textSecondary

Textarea:
- Aynı border, radius ve typography
- Sadece yükseklik değişebilir

## 4. Bottom Sheet

Mevcut "Hatırlatıcı ekle" dili standart kabul edilir.

- Top-left/right radius: 28
- Background: surfaceElevated
- Drag handle: ortalı, kısa, nötr
- Horizontal padding: 16–24
- Section spacing: 24
- Form componentleri yukarıdaki Input standardını kullanır

AI yeni modal geometrisi oluşturmaz. Modal gerekiyorsa bu bottom-sheet sisteminden türetilir.

## 5. Page Header

Her ana tab ekranında başlık alanı şu sistemi kullanır:

- Sol hizalı page title
- İsteğe bağlı üst küçük tarih/section label
- Arkada tab accent renginden türetilmiş yumuşak gradient fade
- Radius: 18
- Padding: 16 yatay / 14 dikey
- Gradient tüm ekranı kaplamaz
- Gradient yalnızca header bölgesinde kalır

### Page Header renk eşlemesi

- Reminders → #9E86FF
- Today → #FFB986
- Habits → #86E6B0
- Tasks → #FF86EC
- More → #86DBFF

Gradient header'ı bir "renkli kart"a çevirmemelidir. Başlangıç alpha yaklaşık 0.20–0.28 aralığında,
son nokta tamamen transparan olmalıdır.

## 6. Iconography

- Tek icon family kullan.
- Mevcut proje ikonları varsa onları koru.
- Figma navbar ikonları export edildiyse bunları source asset kabul et.
- Emoji UI ikonu olarak kullanılmaz.
- Default: outline icon
- Small: 18
- Normal: 22
- Navigation: 24
