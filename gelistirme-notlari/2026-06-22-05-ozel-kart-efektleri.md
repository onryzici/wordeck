# 2026-06-22 — Özel Kart Efektleri (Geliştirilmiş Taşlar + Jokerler)

**Dosyalar:** `scripts/game.gd`, `shaders/tile_shimmer.gdshader` (yeni)
**Mantık etkisi:** YOK — sadece görsel/his. Motor testleri: 106/106 geçti.

---

## 1) Geliştirilmiş harf taşları (foil/holo/poly/altın/cam)

**a) Sürekli PARILTI (shimmer)** — `shaders/tile_shimmer.gdshader` (yeni):
- Taşın üzerinden çapraz kayan ışık bandı (Balatro foil hissi). **Glow halo DEĞİL**
  ([[wordeck-no-glow]]) — hareketli specular sweep.
- Pixelli (ızgaraya snap) + Nearest filter; iki kayan band (foil çoklu parıltı).
- `_make_tile` enhancement bloğunda, enhancement rengine (`tint`) göre ColorRect overlay.
- Taş ayrıca `set_meta("enh_color", ecol)` ile işaretlenir.

**b) Oynanınca RENKLİ kıvılcım** — `_fire_tile`:
- Geliştirilmiş taş tetiklenince enhancement renginde ekstra kıvılcım
  (foil mavi, holo mor, altın sarı…).
- `_ember_burst`'e opsiyonel `tint` parametresi eklendi: verilirse ramp beyaz→tint→şeffaf.

## 2) Jokerler — karakterli tetikleme

`_juice_joker()` (yeni) — skor sekansında joker tetiklenince eski düz `_pop` yerine:
çömelme (anticipation squash) → uzayarak zıpla (+ yukarı) → iniş squash → otur.
- Sadece **scale + position:y** kullanır; `_process` joker rotasyonunu her kare ezdiği
  için rotasyona dokunulmaz (çakışma olmaz).
- Skor sekansındaki joker adımında `_pop(jcard, 1.24)` → `_juice_joker(jcard)`.

---

## Doğrulama
- `--enh` capture ile geliştirilmiş taşlar (renkli kenar + sembol + shimmer) görsel doğrulandı.
- Shader temiz derlendi; instantiate + `_ready` sorunsuz.
- Motor testleri: **106 geçti, 0 başarısız**. Kullanıcı onayladı.

## Ayar ipuçları
- Shimmer: `tile_shimmer.gdshader` → `strength`(0.42)/`speed`(0.55)/`band_w`(0.14).
- Renkli kıvılcım miktarı: `_fire_tile` içindeki `_ember_burst(..., 14, 3.2, null, color)`.
- Joker zıplama yüksekliği: `_juice_joker` → `y0 - 20.0`.
