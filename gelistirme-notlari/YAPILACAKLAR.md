# Yapılacaklar / Yol Haritası — Juice & Efektler

Sıradaki istekler. Hepsi **sunum katmanı** (mantığa dokunmadan).
Öncelik sırası tartışmaya açık; aşağıdaki sıra öneridir.

---

## 1) 🔥 Alev shader'ı — "gerçek alev" (ÖNCELİK)

**Sorun:** ÇİP/ÇARPAN kutularının üstündeki alev şu an **pixel** ve kötü görünüyor.
- Kaynak: `shaders/box_flame.gdshader` (bilinçli "pixel Balatro" yapılmış) +
  ayrıca `scripts/flame_block.gd` (`_draw` ile çizilen pixel "diller").
- Kullanım: `game.gd` `_seal()` (~577. satır) ve `_seal_flame_burst()` (~2093).
- `intensity` uniform'u ÇİP/ÇARPAN değerine göre alev boyunu sürüyor (bu davranış korunmalı).

**Hedef:** Yumuşak, akışkan, sıcak (turuncu→beyaz çekirdek) prosedürel ateş.
**Yaklaşım:**
- `box_flame.gdshader`'ı yeniden yaz: piksel ızgara kilidi (`floor(UV/cell)`) kaldırılır;
  domain-warped FBM noise + dikey gradyan ile yumuşak alev.
- Renk: taban kutu rengi → orta turuncu/sarı → tepe sıcak beyaz; üstte saydamlaşan duman.
- `intensity` ile yükseklik/parlaklık sürmeye devam et.
- `Settings.particles_on`/düşük-uç için sade bir fallback bırak.
- Gerekirse referans shader teknikleri araştırılacak (FBM fire, "The Book of Shaders" tarzı).

**Not:** Pixel görünümü tamamen mi bırakıyoruz yoksa "yumuşak ama retro" mu — kullanıcıyla netleştir.

---

## 2) 🎴 Blind / Tur seçim ekranı cilası

**Sorun:** Tur bitince açılan blind seçim ekranı, referanslar kadar şık değil.
- Kaynak: `game.gd` `_open_blind_select()` (~2511), `_blind_column()`, `_animate_blind_columns()`.

**Hedef (referans Balatro):**
- Sütunlar sırayla (stagger) yaylanarak insin/belirsin (overshoot + settle).
- Seçili/aktif sütun belirgin glow + hafif bob; geçilmiş "DEFEATED", atlanan "SKIPPED"
  damgası tatmin edici otursun (scale-in + hafif dönme + toz).
- Buton hover'da yaylanma; "Select" basışında punch + kısa shake.
- Boss turunda kırmızı rim-glow / tehdit hissi.

---

## 3) 📦 Dükkan — Booster paket açma sekansı (DETAYLI SPEC)

**Kaynak:** `game.gd` `_open_shop()` (~2694), `_build_shop_ui()`, `_pack_visual()`,
`_pack_content()`, `_on_buy_booster()`, `_on_choose_letter()` (paket içeriği seçimi).

**İstenen sekans (birebir brief):**

```
A booster pack opening sequence in the style of a juicy, tactile poker-roguelike
(Balatro-like), set against a dark felt/void background with subtle CRT scanlines,
a warm vignette, and a faint colored rim-glow tinted to the pack's type.

1. ENTRANCE (~0.0–0.4s): The sealed booster pack flies in from off-screen and
overshoots its center mark with a springy ease-out-back, then settles with a quick
squash-and-stretch wobble. A soft drop shadow and colored glow fade in beneath it.
Whoosh + low thud.

2. IDLE / ANTICIPATION (~0.4–0.8s): The pack hovers, bobbing gently up and down, a
slow specular shimmer sweeping across its foil surface. Tiny ambient sparkle
particles drift upward around it.

3. TEAR / BURST OPEN (~0.8–1.2s): The pack rips open from the top in a bright flash
with a burst of confetti-like particles and a few embers. The wrapper splits and
peels back with springy physics. Punchy rip/pop sound with a rising chime.

4. CARD FAN-OUT (~1.2–1.8s): The cards spring outward and fan into an arc, each card
overshooting then settling, staggered by ~60ms so they cascade in. Cards idle-float
and tilt toward the cursor (parallax). A "Choose 1 of X" label fades in above.

5. HOVER / SELECTION (interactive): The hovered card lifts, scales up ~10%, gains a
bright outline glow and a faint particle halo; neighboring cards subtly push aside.
Snappy, springy motion on every state change.

6. RESOLUTION — PICK & BURN (~0.8s on select): The chosen card flies smoothly toward
the hand/deck with a trailing glow. The remaining unselected cards and the empty pack
catch fire — an orange-to-white ember dissolve eats them from the edges inward,
curling and crumbling into glowing cinders and dark ash flakes that scatter, float up,
and fade out, leaving the scene empty. Crackling fire + a soft fwoosh as they vanish.

OVERALL FEEL: extremely bouncy and "juicy"; heavy squash-and-stretch and overshoot/
spring easing; light screen-shake on impacts; layered particles (sparkles, embers,
ash); warm fiery palette for the burn; retro/CRT presentation; punchy, satisfying
sound design.
```

**Teknik notlar:**
- Mevcut `_ember_burst`, `_flash_ring`, trauma shake, prosedürel ses altyapısı kullanılabilir.
- "Burn / ember dissolve" için kart sprite'ına dissolve shader (noise eşikli edge-burn).
- Yay hissi için `TRANS_BACK`/`TRANS_ELASTIC` + squash-stretch tween'leri.

---

## 4) ✨ Özel kart efektleri (desteye atılan özel kartlar)

**İstek:** Özel kartları desteye atarken/oynarken daha canlı, daha güzel efektler.
- Kaynak (araştırılacak): özel kart = harf geliştirmeleri (foil/holo/poly/altın/cam)?
  `data/enhancements.gd`, `game.gd` taş çizimi `_make_tile()`, geliştirme seçimi
  `_on_choose_enhancement` / `_enh_choice_card`.
- Hedef: enhancement'a göre sürekli parıltı/foil shimmer, atılırken iz + kor, desteye
  girişte "snap" + parçacık.
- **Netleştir:** "özel kart" tam olarak hangisi (enhancement'lı harf mi, joker mi,
  booster içeriği mi)?

---

## Açık sorular (kullanıcıya)
- Alev: tamamen yumuşak mı, "yumuşak ama hafif retro" mu?
- Hangi sırayla yapalım? (öneri: 1 → 4 → 2 → 3, çünkü alev her elde görünür, paket en büyük iş)
- "Özel kart" tanımı netleşmeli.
