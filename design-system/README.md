# Planner App — Brand Kit & UI Design System

Bu paket, uygulama ile widget'ların aynı görsel dili kullanması ve AI coding modellerinin
rastgele font, renk, radius, spacing, navbar veya modal tasarlamasını engellemek için hazırlandı.

## Dosyalar

- `BRAND_GUIDE.md` — Görsel kimlik ve genel tasarım karakteri
- `DESIGN_TOKENS.json` — Renk, tipografi, spacing, radius ve component tokenları
- `TYPOGRAPHY.md` — Yazı sistemi ve kullanım kuralları
- `COMPONENTS.md` — Buton, card, input, bottom sheet, header vb. component kuralları
- `NAVBAR.md` — Figma navbar'ının proje için uygulanma kuralları
- `NAVBAR_TAB_COLORS.css` — Tab renkleri ve gradient örnekleri
- `WIDGET_GUIDE.md` — Widget'ın uygulamayla aynı tasarım dilinde kalması için kurallar
- `AI_UI_RULES.md` — AI coding modelleri için zorunlu kurallar
- `MOTION_SYSTEM.md` — Hareket ve animasyon kuralları
- `MOTION_TOKENS.json` — Süre, easing, scale ve gesture sabitleri
- `INTERACTION_PATTERNS.md` — Olaya göre animasyon eşleme tablosu
- `IMPLEMENTATION_PROMPT.txt` — Claude / GPT / Gemini / coding agent'a verilecek hazır prompt
- `NAVBAR_FIGMA_REFERENCE.css` — Figma'dan alınan ham CSS referansı

## Temel prensip

Uygulama yeniden tasarlanmayacak. Bu sistem, mevcut arayüzü standardize eder.

Widget:
- uygulamanın renk sistemini,
- tipografisini,
- radius dilini,
- ikon yaklaşımını,
- spacing ritmini

miras alır; yalnızca widget platformunun gerektirdiği kompakt yerleşim, arkaplan görseli,
scrim/blur gibi uyarlamalar widget'a özel olabilir.

## Navbar tab renkleri

- Reminders: `#9E86FF`
- Today: `#FFB986`
- Habits: `#86E6B0`
- Tasks: `#FF86EC`
- More: `#86DBFF`

Bu renkler sayfanın tamamını boyamaz. Yalnızca seçili tab, ilgili küçük vurgu alanları
ve sayfanın üst başlık bölgesindeki yumuşak gradient fade için kullanılır.

## Uygulama sırası

1. Mevcut projedeki gerçek font ailesini ve mevcut ana renkleri tespit et.
2. `DESIGN_TOKENS.json` değerlerini projedeki gerçek sabitlerle eşleştir.
3. Navbar'ı `NAVBAR.md` kurallarına göre tek component olarak uygula.
4. Page header gradient sistemini aktif tab rengine bağla.
5. Ortak button/card/input/bottom-sheet stillerini component seviyesine taşı.
6. Widget'ları `WIDGET_GUIDE.md` kurallarına göre standardize et.
7. Bundan sonraki her AI UI işi öncesinde `AI_UI_RULES.md` okut.
