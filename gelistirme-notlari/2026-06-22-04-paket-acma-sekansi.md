# 2026-06-22 — Booster Paket Açma Sekansı

**Dosya:** `scripts/game.gd`
**Mantık etkisi:** YOK — sadece sunum. Alım/seçim mantığı `Shop.*` aynen kullanılıyor.
Motor testleri: 106/106 geçti.

---

## Akış

Dükkanda **harf paketi** (`_on_buy_booster`) veya **cila paketi** (`_on_buy_enhancer`)
alınınca, eski "şeritte seç" yerine tam ekran **paket açma sekansı** (`_open_pack_sequence`)
oynar. Seçim yapılınca mevcut handler'lar çağrılır (`_on_choose_letter` /
`_on_choose_enhancement`) → state + dükkan normal şekilde güncellenir.

`_open_pack_sequence(choices, kind)` — kind: `"letter"` (choices = harfler) | `"enh"`
(choices = enhancement id'leri). Tam ekran overlay (dim + hold + seqfx Node2D).

### Aşamalar (Balatro brief'ine göre)
1. **GİRİŞ** — kapalı paket (`_pack_sealed_card`) aşağıdan uçar, `TRANS_BACK` overshoot +
   squash/stretch otur, hafif trauma, whoosh sesi.
2. **BEKLEME** — kısa bob.
3. **YIRTILMA** — beyaz flash + ember/konfeti (`_ember_burst`, seqfx'e) + trauma + ses,
   paket büyüyüp kaybolur.
4. **YELPAZE** — kartlar (`_pack_overlay_card`) paket merkezinden yaylanarak yaya açılır
   (stagger 0.06s, parabolik y + hafif rotasyon). Üstte "X'TEN 1 SEÇ".
5. **HOVER** — `_pack_card_hover`: büyü + düzleş (glow YOK — [[wordeck-no-glow]]).
6. **SEÇİM → YANMA** — seçilen pop'layıp uçar; kalanlar `_burn_card` ile yanar; overlay
   kapanır, sonra ilgili choose handler çağrılır.

### Yanma (`_burn_card`) — kullanıcı "daha güzel" isteyince zenginleştirildi
- Yükselen **ateş közleri** (additive, sıcak beyaz→turuncu→koyu),
- Savrulan **kül pulları** (koyu, yavaş yükselen),
- Kart **kömürleşir** (kararır) → dikeyde **büzülerek çöker** + dönüp söner (yanan kağıt).

---

## Önemli teknik notlar
- Partiküller overlay'in ÜSTÜNDE görünsün diye `_ember_burst`'e opsiyonel `parent`
  parametresi eklendi (overlay'de `seqfx` Node2D'ye emer; varsayılan hâlâ `fx_layer`).
- Pick guard: `ov.set_meta("done")` ile çift seçim engellenir.
- Enhancement akışında overlay sadece "hangi cila" seçimini yapar; "hangi harfe uygula"
  adımı eski şerit UI'da kalır (pack açma değil, takip adımı).

## Test/doğrulama
- Geçici `--pack` demo + capture ile yelpaze hali görsel doğrulandı (sonra geri alındı).
- Motor testleri: **106 geçti, 0 başarısız**. Kullanıcı onayladı.

## Yapılmadı (istenirse sonra)
- Spec'teki **CRT/scanline + vignette** atmosfer (şimdilik düz dim).
- Gerçek **edge-dissolve shader**'lı yanma (Panel+Label'a uygulaması karmaşık; partikül+char
  ile taklit edildi).
