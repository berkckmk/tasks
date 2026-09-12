# TYPOGRAPHY

## Ana kural

Projede hali hazırda tanımlı bir primary font varsa onu kullan ve tüm ekranlarda tek aileye indir.
Projede açıkça tanımlı bir font yoksa `Inter` kullan; fallback sistem sans-serif olsun.

AI yeni bir font ailesi ekleyemez.

## Tokenlar

| Token | Size | Weight | Kullanım |
|---|---:|---:|---|
| Display | 32 | 600 | Büyük ekran başlığı |
| Title | 24 | 600 | Ana bölüm / bottom sheet başlığı |
| Heading | 18 | 600 | Kart veya alt bölüm başlığı |
| Body | 16 | 400 | Normal içerik |
| Body Medium | 16 | 500 | Kart başlığı / önemli satır |
| Caption | 14 | 400 | Tarih, saat, metadata |
| Label | 12 | 600 | QUICK CAPTURE ve section label |

## Kurallar

- Rastgele 17, 19, 21, 27 gibi yeni font size üretme.
- Yeni weight ekleme; gerekirse önce design system değişikliği öner.
- Tab label ve icon ile page title arasında net hiyerarşi olmalı.
- Tamamlanmış task/reminder metni opacity + strike-through ile zayıflatılabilir; font ailesi değişmez.
- Widget tipografisi aynı aileyi kullanır; yalnızca platform limitleri nedeniyle ölçek küçültülebilir.
