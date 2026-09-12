# AI UI RULES — ZORUNLU

Bu dosya UI üzerinde çalışan her AI coding modeline iş başlamadan önce okutulmalıdır.

## Önce oku

1. `BRAND_GUIDE.md`
2. `DESIGN_TOKENS.json`
3. `TYPOGRAPHY.md`
4. `COMPONENTS.md`
5. `NAVBAR.md`
6. `WIDGET_GUIDE.md`
7. `MOTION_SYSTEM.md`
8. `MOTION_TOKENS.json`
9. `INTERACTION_PATTERNS.md`
10. Gerekirse `NAVBAR_FIGMA_REFERENCE.css`

## Değiştirilemez kurallar

1. Yeni renk üretme.
2. Yeni font family ekleme.
3. Token dışında rastgele font size/weight üretme.
4. Token dışında rastgele spacing değeri üretme.
5. Token dışında rastgele radius üretme.
6. Mevcut component varken yeni component tasarlama.
7. Görsel değerleri uygun token varken hard-code etme.
8. Navbar'ı her route için ayrı yazma.
9. Tab accent rengini bütün sayfaya yayma.
10. Figma navbar görsel dilini keyfi biçimde yeniden yorumlama.
11. Widget için ayrı bir görsel kimlik oluşturma.
12. Gradient, glow, shadow veya blur eklerken design system dışında değer kullanma.
13. Emoji'yi UI iconu olarak kullanma.
14. Yeni görsel token gerçekten gerekiyorsa sessizce ekleme; önce raporla.
15. Motion, design system'in bir parçasıdır. Component'e özel keyfi animasyon oluşturma.
    Herhangi bir etkileşim animasyonu uygulamadan önce MOTION_SYSTEM.md, MOTION_TOKENS.json
    ve INTERACTION_PATTERNS.md dosyalarını oku.
16. MOTION_TOKENS.json dışında süre, easing, scale veya distance değeri hard-code etme.

## Navbar sabit renk mapping

- Reminders = #9E86FF
- Today = #FFB986
- Habits = #86E6B0
- Tasks = #FF86EC
- More = #86DBFF

## Page Header davranışı

Aktif tab rengi, ilgili ekranın üst page header alanında düşük yoğunluklu gradient fade olarak
kullanılır.

Bu gradient:
- sadece header alanında,
- düşük alpha,
- transparana doğru kaybolan,
- okunabilirliği bozmayan,
- tüm sayfa theme rengini değiştirmeyen

bir vurgu olmalıdır.

## Çalışma yöntemi

UI işi geldiğinde:

1. Önce mevcut component/theme yapısını incele.
2. Aynı işi yapan mevcut component var mı kontrol et.
3. Var olan tokenları eşleştir.
4. Sadece gerekli dosyalarda değişiklik yap.
5. Görsel değişiklikleri fonksiyonel değişikliklerden ayır.
6. Sonunda hangi token/componentlerin kullanıldığını kısa listele.
7. Eğer source ile design system çelişiyorsa kendi kararını verme; çelişkiyi belirt.

## Kabul kriteri

Bir ekran veya widget tamamlandığında:
- font ailesi tutarlı,
- spacing token bazlı,
- radius token bazlı,
- navbar state mapping doğru,
- page header accent doğru tab rengine bağlı,
- widget ve app aynı görsel ailede,
- yeni rastgele görsel değer eklenmemiş

olmalıdır.
