# 2026-06-23 — Dükkan düzeni + yumuşak dükkan geçişi + çip×çarpan geri sayımı

**Dosyalar:** `scripts/game.gd`
**Mantık etkisi:** YOK — sadece sunum. Motor testleri: 106/106.
**Commit:** `15af12d`

---

## 1. Dükkan düzeni (kullanıcı iterasyonları)
- **KUPON kartı** artık ayrı/üstte değil → **harf paketinin YANINDA** paket rafında
  (`_shop_pack_slots`'a `_voucher_card` eklendi; sürükle-bırak/tıkla satın alma korundu).
- Marquee yazısı **"DÜKKÂN" → "DÜKKAN"** (şapkasız A) — `_set_shop_sidebar`.
- Marquee **daha yüksek/dolgun**: `_head_panel.custom_minimum_size.y = 104`, `_marquee_box`
  içerik boşluğu (top 22 / bottom 24).
- Alt stat alanı: önce esnek-boşlukla kompaktlaştırıldı → kullanıcı "o kadar boşluk olmasın,
  çarpanların hemen altından başlasın" dedi → geri alındı (çarpanların hemen altından akıyor).

## 2. Yumuşak dükkan geçişi (vortex KALDIRILDI)
`_go_to_shop()` artık girdap/vortex KULLANMIYOR (girdap yalnızca **oyun başlangıcında** —
`main.gd`). Yerine:
- Koyu keçeye **yumuşak kararma** (cover `modulate.a` 0→1, SINE EASE_IN_OUT, 0.30s)
- Dükkan kurulur (kapalıyken `_open_shop`)
- Dükkan **hafif ölçek-pop** ile açılır (`shop_view.scale` 0.965→1.0, BACK) + örtü yumuşakça kalkar
- Çok hafif `_add_trauma(0.06)` yerleşme vurgusu.

## 3. Çip × Çarpan geri sayımı (yeni turda)
Yeni tura geçince çip×çarpan kutuları (ör. 41×24) ANINDA 0/1 olmuyordu → kötü duruyordu.
- `_countdown_seals(dur)`: çip→0, çarpan→1 **geriye doğru sayar** (CUBIC EASE_IN).
- Asıl sıfırlama **yeni tur başında** (`_on_blind_select`): yeni el dağıtılırken seals
  **paralel** geri sayar (bekleyip sonra dağıtma → bayat board flaşı yok). El sonrası
  (`_on_play` else) için de aynı geri sayım kullanılır.
- Çarpan ham float gösterip "0.9485845" gibi ondalık çıkarıyordu → `_fmt(round(v))` ile
  **yuvarlanmış tam sayı** (çip zaten int).
- Oyuncu sayım sırasında taş seçerse `_update_word_display` tween'i öldürür (önizleme öncelikli).

## İterasyon notları (kullanıcı)
- Kupon önce alta alındı → "harf paketinin yanına koy" dendi → rafa taşındı.
- Geri sayım önce el-sonrası dalına eklendi ama kullanıcı tek elde turu geçince won-dalı
  çalıştığı için görmedi → asıl yerin **yeni tur başı** (`_on_blind_select`) olduğu anlaşıldı.

## Not: Performans (ertelendi)
Kullanıcı "kaliteyi bozmadan daha hızlı/stabil" istedi. İnceleme:
- Steady-state GPU maliyeti: `felt_swirl` (fbm gürültü) + `crt` her kare tam ekran (opak
  panellerin altında bile → overdraw).
- `precision mediump` denenebilir AMA her ağır shader'ın sıcak yolu highp gerektiriyor
  (hash `fract(sin*43758)`, büyük `TIME`, büyük `FRAGCOORD`) → kazanç ~yok, risk var. **Yapılmadı.**
- `max_fps=60` + vsync frame-pacing denendi → kullanıcı **geri al** dedi (optimizasyona en son bakacak).
- Gerçek büyük kazanç: arka planı **yarı çözünürlükte SubViewport**'a render (Kademe 2) —
  ileride, cihazda test ederek.
