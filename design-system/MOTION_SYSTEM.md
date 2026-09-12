# MOTION SYSTEM

Bu dosya, Planner App'in hareket ve animasyon kurallarını tanımlar. Design system'in
diğer katmanları (color, typography, radius, spacing, components) ile eşdeğer bir
referans dokümanıdır.

## Felsefe

Her animasyon bir amaca hizmet etmelidir — dekoratif değil, bilgilendirici.

Hareket şu işlevlerden birini karşılamalıdır:
1. **Geri bildirim** — kullanıcının etkileşimini onaylama (button press, checkbox toggle)
2. **Yönlendirme** — dikkat çekme veya bağlam aktarma (page transition, navbar pill)
3. **Süreklilik** — elemanlar arasında mekansal ilişki kurma (item enter/exit, sheet slide)

Bu üç işlevi karşılamayan animasyon eklenmez.

## Timing Tiers

Proje genelinde 5 süre katmanı kullanılır. Bu değerler `MOTION_TOKENS.json` dosyasında
sabittir ve kod tarafında `motion.ts` ile senkronize tutulur.

| Tier | Süre (ms) | Kullanım alanı |
|------|-----------|----------------|
| `micro` | 150 | Button press, checkbox toggle, icon swap |
| `state` | 220 | Navbar pill, input focus, border color change, selection mode |
| `list` | 260 | Item ekleme/silme, liste reflow |
| `page` | 320 | Sayfa geçişi (tap veya swipe sonrası snap) |
| `sheet` | 360 | Bottom sheet açılma/kapanma |

Kural: Daha küçük/yerel etkileşimler daha kısa sürede, daha büyük/global
değişiklikler daha uzun sürede tamamlanır.

## Easing

| Bağlam | Easing tipi |
|--------|-------------|
| Varsayılan (tüm UI) | `easeInEaseOut` |
| Bottom sheet | `spring` (platform native) |
| Navbar pill slide | `spring` (hafif damping) |

Spring parametreleri platforma bırakılır; önemli olan hareketin doğal ve
aşırı bouncy olmaması.

## Scale Kuralları

Scale yalnızca iki bağlamda kullanılır:

| Bağlam | Scale değeri | Token |
|--------|-------------|-------|
| Button press (parmak basılı) | 0.96 | `scale.buttonPressed` |
| Yeni item enter | 0.98 → 1.00 | `scale.itemEnter` |

Başka bağlamda scale kullanılmaz. Özellikle:
- Navbar ikonlarına scale uygulanmaz
- Card hover/press için scale yerine opacity kullanılır
- Silinen item için scale-down yerine fade + collapse kullanılır

## Slide Distance

| Bağlam | Mesafe (dp) | Yön |
|--------|-------------|-----|
| Item enter (yeni eklenen) | 10 | Aşağıdan yukarı |
| Page transition | 24 | Geçiş yönüne göre (sol/sağ) |

## Opacity State'leri

Bu değerler design system'in diğer dokümanlarında da tanımlıdır;
burada motion bağlamında referanslanır:

| State | Opacity | Kullanım |
|-------|---------|----------|
| `pressed` | 0.80 | Pressable item feedback |
| `disabled` | 0.45 | Disabled button/input |
| `completed` | 0.55 | Tamamlanmış item (strikethrough) |
| `scrim` | 0.45 | Sheet arkası karartma |

## Swipe Gesture Kuralları

Sayfa geçişi için kullanılan swipe gesture'ın parametreleri:

| Parametre | Değer | Açıklama |
|-----------|-------|----------|
| `swipeThreshold` | 24 dp | Minimum yatay hareket, gesture algılanması için |
| `swipeRatio` | 2× | `dx > dy * 2` — yatay hareket dikeyin 2 katını geçmeli |
| `swipeRelease` | 55 dp | Release anında minimum dx, sayfa geçişi tetiklenmesi için |

Swipe dikey scroll'u engellememelidir. Yukarıdaki threshold ve ratio
bu dengeyi sağlamak için seçilmiştir.

## Yasaklar

Aşağıdaki animasyon türleri bu projede kullanılmaz:

- **Bounce** — overshot/bounce back efektleri
- **Neon pulse** — yanıp sönen glow efektleri
- **Rotation** — dönen ikonlar veya elemanlar
- **Path animation** — eğri üzerinde hareket
- **Parallax** — farklı hızda kayan katmanlar
- **3D transform** — perspektif/rotateX/rotateY
- **Auto-play loop** — kullanıcı etkileşimi olmadan sürekli hareket
- **Stagger** — art arda gecikmeyle başlayan liste animasyonları (performans riski)

## Kaynak Önceliği

Motion çakışması olduğunda:
1. `MOTION_TOKENS.json` değerleri
2. `INTERACTION_PATTERNS.md` tablosu
3. `MOTION_SYSTEM.md` kuralları
4. Mevcut koddaki implementasyon
5. AI modelinin önerisi

AI hiçbir zaman 1-3 arasında tanımlı bir motion değerini kendi estetik tercihiyle
değiştiremez.
