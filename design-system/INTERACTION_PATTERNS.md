# INTERACTION PATTERNS

Bu dosya, hangi kullanıcı etkileşiminde hangi animasyonun kullanılacağını tanımlar.
Her satır `MOTION_TOKENS.json` dosyasındaki token isimlerini referans alır.

## Temel Etkileşimler

### Button tap
→ Subtle scale down (`scale.buttonPressed: 0.96`) + release geri dönüşü
- Süre: `duration.micro` (150 ms)
- Easing: `easing.default`
- Not: Scale yalnızca parmak basılıyken uygulanır; release ile 1.0'a döner.

### Add item (yeni öğe ekleme)
→ Fade in + slide up + layout reflow
- Süre: `duration.list` (260 ms)
- Slide mesafe: `distance.itemEnter` (10 dp) — aşağıdan yukarı
- Başlangıç scale: `scale.itemEnter` (0.98) → 1.0
- Başlangıç opacity: 0 → 1
- Easing: `easing.default`

### Delete item (öğe silme)
→ Fade out + shrink + collapse
- Süre: `duration.list` (260 ms)
- Bitiş opacity: 1 → 0
- Layout collapse: LayoutAnimation tarafından yönetilir
- Easing: `easing.default`
- Not: Scale-down kullanılmaz; fade + collapse yeterlidir.

### Complete item (öğe tamamlama)
→ Checkbox icon swap + text state transition
- Süre: `duration.state` (220 ms)
- Checkbox: icon crossfade (circle → checkCircle)
- Text: opacity `1.0 → opacity.completed` (0.55) + strikethrough
- Easing: `easing.default`

### Navbar tab change (sekme değiştirme)
→ Active pill slides to target position
- Süre: `duration.state` (220 ms)
- Easing: `easing.navPill` (spring)
- Active pill: width expand + gradient color morph
- Inactive pill: width shrink + icon only
- Not: Container geometrisi değişmez; yalnızca pill pozisyonu ve boyutu değişir.

### Page change by tap (dokunarak sayfa değiştirme)
→ Directional slide + opacity fade
- Süre: `duration.page` (320 ms)
- Slide mesafe: `distance.pageTransition` (24 dp)
- Yön: hedef sayfa sağdaysa sola doğru slide, soldaysa sağa doğru
- Çıkan sayfa: opacity 1 → 0 + slide out
- Giren sayfa: opacity 0 → 1 + slide in
- Easing: `easing.default`

### Page change by swipe (kaydırarak sayfa değiştirme)
→ Content follows finger, release snaps to target
- Gesture threshold: `gesture.swipeThreshold` (24 dp)
- Direction ratio: `gesture.swipeRatio` (dx > dy × 2)
- Release distance: `gesture.swipeRelease` (55 dp)
- Snap süresi: `duration.page` (320 ms)
- Not: Eşik karşılanmazsa sayfa geri snap eder.

### Bottom sheet open (alt panel açılma)
→ Slide from bottom + backdrop scrim fade
- Süre: `duration.sheet` (360 ms)
- Easing: `easing.sheet` (spring — platform native)
- Scrim opacity: 0 → `opacity.scrim` (0.45)
- Not: Platform native sheet API kullanılıyorsa animasyon API'ye bırakılır.

### Bottom sheet dismiss (alt panel kapanma)
→ Reverse of open
- Süre: `duration.sheet` (360 ms)
- Scrim opacity: `opacity.scrim` → 0
- Easing: `easing.sheet`

### Input focus (giriş alanı odaklanma)
→ Border color transitions to page accent
- Süre: `duration.state` (220 ms)
- Easing: `easing.default`
- Geçiş: `colors.border` → aktif sayfanın accent rengi
- Blur: accent → `colors.border`

### Selection mode enter (çoklu seçim moduna geçiş)
→ Selection bar slides up from bottom
- Süre: `duration.state` (220 ms)
- FAB: fade out (selection bar FAB'ın yerini alır)
- Selection bar: slide up + fade in
- Easing: `easing.default`

### Multi-select toggle (çoklu seçimde öğe seçme/bırakma)
→ Checkbox icon crossfade
- Süre: `duration.micro` (150 ms)
- Icon: circle ↔ checkCircle
- Easing: `easing.default`

## Token Referans Tablosu

| Olay | duration | easing | scale | distance | opacity |
|------|----------|--------|-------|----------|---------|
| Button tap | `micro` | `default` | `buttonPressed` | — | — |
| Add item | `list` | `default` | `itemEnter` | `itemEnter` | 0→1 |
| Delete item | `list` | `default` | — | — | 1→0 |
| Complete item | `state` | `default` | — | — | `completed` |
| Navbar change | `state` | `navPill` | — | — | — |
| Page (tap) | `page` | `default` | — | `pageTransition` | 0↔1 |
| Page (swipe) | `page` | `default` | — | — | — |
| Sheet open | `sheet` | `sheet` | — | — | `scrim` |
| Sheet dismiss | `sheet` | `sheet` | — | — | `scrim` |
| Input focus | `state` | `default` | — | — | — |
| Selection enter | `state` | `default` | — | — | — |
| Multi-select | `micro` | `default` | — | — | — |

## Yasaklar

Bu tabloda olmayan etkileşim animasyonu eklemeden önce:
1. `MOTION_SYSTEM.md` yasaklar listesini kontrol et.
2. Yeni bir pattern gerçekten gerekiyorsa, kodlamadan önce belgeye ekle ve raporla.
