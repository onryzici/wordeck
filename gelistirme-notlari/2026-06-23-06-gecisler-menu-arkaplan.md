# 2026-06-23 — Geçişler (kara delik) + Balatro menü arkaplanı + pack efektleri + CRT

**Dosyalar:** `scripts/main.gd`, `scripts/game.gd`, `shaders/*`
**Mantık etkisi:** YOK — sadece sunum. Motor testleri: 106/106.

---

## 1. Kara delik / vakum geçişi (`shaders/vortex_transition.gdshader`)
Düz fade-black yerine: ekran içeriği gravitasyonel çekimle **merkeze akar** (ekran dolu
kalır, siyah çerçeve YOK), merkezden büyüyen kara delik yutar; çok hafif spiral.
- `progress` 0→1 (çekiliş, `QUART` ease-in ~1.0s) → sahne değişir → 1→0 (yeni ekran
  girdaptan açılır, `CUBIC` ease-out ~0.85s). `progress=0` birebir normal ekran (kopma yok).
- Bağlandığı yerler: OYNA (menü→oyun), ana menüye dönüş, DÜKKANA GİT (`_go_to_shop`).
- İterasyon notu: ilk "girdap" çok hızlı/baş döndürücüydü → yavaşlatıldı; "küçülüp siyah
  çerçeve" yanlıştı → gravitasyonel-çekim warp'a geçildi (kullanıcı onayladı).

## 2. CRT geçişte aktif kalır (önemli kayan-katman düzeltmesi)
İki screen-texture shader (girdap + CRT) üst üste → üstteki alttakini görsün diye
**`BackBufferCopy` (COPY_MODE_VIEWPORT)** eklendi. Ayrıca **CRT en üst z_index'te**
(crt=1001, bb=1000): dükkan perdesi (z=95) / overlay (z=100) gibi yüksek-z öğeler
z_index ağaç sırasını ezdiğinden CRT'yi örtüyordu → artık CRT hepsinin üstünde.

## 3. Balatro boya arkaplanı (`shaders/balatro_bg.gdshader`)
Menüde, KENDİ paletimizle: **mat tuğla-kırmızı (colour_1) + charcoal (colour_2) +
derin koyu (colour_3)**, `lighting=0.22` (mat). (Altın ton kullanıcı isteğiyle charcoal
oldu; kırmızı daha mat.)

## 4. Pack açma efektleri
- `pack_atmosphere.gdshader` — vinyet + ince CRT scanline (renkli kenar parıltısı YOK).
- `card_dissolve.gdshader` — burn-edge dissolve (ateş gradyanı: beyaz-sıcak→turuncu→kömür,
  kenardan içe bias). Kaynak: godotshaders 2d-dissolve-with-burn-edge.
- `card_tilt_3d.gdshader` — yelpaze kartlarında imlece 3B perspektif eğim (MrEliptik fake_3D).
- Düzeltme: dükkanda menü/overlay açılınca fiyat etiketleri (z=5) overlay'in altında
  kalsın → overlay z_index=100.

## Denenip GERİ ALINANLAR
- **Harf taşı 3B tilt** (snapshot+swap): çıkışta zıplama/bug → kaldırıldı.
- **Balatro hover bulge** (`card_hover` vertex shader): kompozit Control kartta tutarsız
  (kart uzuyor, pip'ler takip etmiyor) → kaldırıldı. Tek-quad/sprite için tasarlı.
