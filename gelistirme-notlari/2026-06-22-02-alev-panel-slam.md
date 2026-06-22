# 2026-06-22 — Alev Shader'ı + Sol Panel Kompaktlaştırma + Geçici SLAM

**Dosyalar:** `shaders/box_flame.gdshader` (tam yeniden yazıldı), `scripts/game.gd`
**Mantık etkisi:** YOK — sadece görsel/his. Motor testleri: 106/106 geçti.

İteratif çalışıldı (kullanıcı her adımda oyunu açıp geri bildirim verdi). Sonuç durum:

---

## 1) ÇİP/ÇARPAN kutusu alevi — `shaders/box_flame.gdshader`

**Sorun:** Eski alev pixel "diller" hâlindeydi, kötü duruyordu. Birkaç deneme yapıldı:
- (a) yumuşak-retro akışkan ateş → kullanıcı "kutuyu da sıvı yapalım" dedi,
- (b) tüm kutu = sıvı/lav yüzey (tek ColorRect) → kullanıcı "dikiş kalksın istemiştim ama
  bu efekt KALICI olmasın, sadece PUAN ALIRKEN gelsin; radius da çok büyük oldu" dedi.

**Nihai (kullanıcı onayladı):**
- Kutu yine **temiz dolu kutu**, **eski radius** (`T.seal`, 10px) — `_seal()` içinde `Panel` + `T.seal(color)`.
- Üstünde **PUAN ALIRKEN beliren** blobby pixel alev tacı (image-5 tarzı): kutu renginde,
  tabandan köklenir, yumru yumru, tepeye doğru açılır; birkaç **kopuk pixel** (uçuşan nokta).
- Shader **pixelli** (UV ızgaraya snap) + **keskin kenar** (`step`/`discard`, smoothstep yok),
  kendi value-noise'u var.
- `intensity` uniform'u = alev boyu. **Normalde 0 (alev yok)**; `_drive_seal_flame()` sadece
  `_flame_on` (OYNA sonrası) iken değere göre 0.5..1.0 sürer → tur bitince/yeni elde söner.
- Ayar uniform'ları: `cells_x`(28)/`cells_y`(12) pixel iriliği, `speed`(2.4) oynama hızı.

**game.gd:** `_seal()` (caption parametresi kaldırıldı — artık ÇİP/ÇARPAN yazısı YOK, sadece
sayı, kutuda ortalı), `_drive_seal_flame()` intensity'i score-only sürer.

---

## 2) Sol panel — Balatro kompaktlığı

**Sorun:** Panel "çok boşluklu"ydu; ortadaki büyük turuncu TOPLAM "0" etrafında kocaman
boşluklar vardı (referans Balatro paneli sıkı/dengeli).

**Karar (kullanıcı):** Büyük turuncu TOPLAM sayısını **tamamen KALDIR**, tam Balatro düzeni.

**Yapılan (`_build_left_panel`):**
- `total_label` ve değişkeni tamamen kaldırıldı (tüm referanslar: `_update_word_display`,
  `_score_sequence`). Önizleme zaten çip/çarpan kutularında görünüyor (yeterli).
- Sıralama Balatro gibi: **TUR SKORU → kademe (kelime tipi · ×) → çip×çarpan kutuları**.
  `tier_label` kutuların ÜSTÜNE taşındı.
- Büyük boşluklar (30px total_gap + 34px crown_gap) kısaldı (crown_gap 12, alt gap 6).

---

## 3) Geçici (transient) SLAM — `_slam_score()`

Turuncu TOPLAM kalkınca, çip×çarpan sonucu artık **ekranda geçici büyük SLAM** ile gösteriliyor
(çarpışma noktasında belirir → patlar → yükselip söner). Kalıcı kutu yok.

**İki kritik düzeltme (kullanıcı geri bildirimi):**
1. **Font uyumu:** `fx_layer` bir **Node2D** → Control teması (font) **miras alınmaz**; etiket
   varsayılan sistem fontuna düşüyordu (uyumsuz). Çözüm: `lbl.add_theme_font_override("font",
   _tile_font)` — oyunun ana sayı fontu (m6x11). *(Aynı sebeple `_float_num`/`_fly_score` de
   override ediyordu; SLAM'de unutulmuştu.)*
2. **Vurucu efekt:** çarpma anında kor patlaması (`_ember_burst`, puanla ölçekli) + halka
   (`_flash_ring`) + sert SLAM (scale 2.3→0.9→1.0) + parlak→normal flash + count-up.

**Ayar:** font boyu 84, ember sayısı `clampi(score/14+18, 18, 64)`, bekleme 0.7s.

---

## Doğrulama
- Instantiate + `_ready` çöküyor değil; `total_label` referansı kalmadı.
- Motor testleri: **106 geçti, 0 başarısız**.
- Oyun açıldı, oynandı, runtime hatası yok. Kullanıcı sonucu ONAYLADI.
