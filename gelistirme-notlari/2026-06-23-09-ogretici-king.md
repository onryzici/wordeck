# 2026-06-23 — İlk-giriş etkileşimli öğreticisi + King kartı

**Dosyalar:** `scripts/game.gd`, `scripts/settings.gd`, `assets/images/king.png`
**Mantık etkisi:** YOK — sadece sunum/UX. Motor testleri: 106/106.
**Commit:** `15bed8a`

---

## 1. King kartı (referans/maskot asset)
- `assets/images/king.png` (469×641 pixel-art taç) köşeleri **taşlarla aynı oranda**
  yuvarlatıldı: taş 124px'de 14px yarıçap → king 469px'de **53px** (anti-aliased, alpha bake;
  crown'a dokunulmadı). `.import` gitignore'lu (`*.import`) → diğer makinede Godot yeniden import eder.
- NOT: Öğreticide önce maskot olarak kullanıldı, sonra kullanıcı **"ikon olmasın"** dedi →
  öğreticiden çıkarıldı. Asset duruyor, ileride kullanılabilir.

## 2. Etkileşimli öğretici (ilk açılışta, YAPTIRARAK)
**Tetik:** `enter_session` → `Settings.tutorial_done` false ise, giriş vortex'i bitince
(1.2s gecikme, çakışmasın) `_tut_start()`. Kalıcılık: `settings.cfg [progress] tutorialDone`.
Sadece ilk açılış (tekrar yok). **ATLA** her an kapatır (soft-lock yok).

**Akış (state machine, `_tut_mode`):**
1. `blind` — "Bir TUR seç" (dim YOK, ekran serbest tıklanır) → `_on_blind_select` → `blind_selected` olayı
2. `word` — "Kelime kur" (el spotlight) → geçerli kelime → `selection_changed`+`_is_current_valid`
3. `play` — "OYNA'ya bas" (el+OYNA spotlight) → `_on_play`
4. `_on_play`: rehberli basışta (`_tut_mode=="play"`) skor animasyonu için katman gizlenir,
   skor sonrası **`await _tut_postplay()`** → açıklama balonları (çip×çarpan / DEĞİŞTİR / hedef).
   Bu await won→"TUR GEÇİLDİ"→dükkan akışından **ÖNCE** olur → **sıra karışmaz** (kullanıcı bug'ı).
5. postplay biter → `_tut_mode="await_shop"`, katman gizli → oyuncu engelsiz oynar (turu geçmek
   birkaç el sürebilir).
6. `await_shop` + dükkan açılınca (`_open_shop`) → **`_tut_shop_tour()`**: raflar (joker/paket)
   + YENİLE + SONRAKİ TUR anlatılır → `_tut_finish()` (tutorialDone kaydedilir).

**Bağlamsal balon + spotlight (kullanıcı: "o an neresi ilgilendiriyorsa orada olsun"):**
- Balon, ilgili öğenin yanına konumlanır (`_tut_position_panel`: above/below/right/left/center,
  ekrana clamp) ve o öğe **spotlight** edilir.
- Spotlight = **4-kenar cutout** (`_tut_set_cutout`): hedefin etrafını karartan 4 ColorRect,
  ORTASI delik. KRİTİK: Godot'ta **`z_index` fare/input sırasını ETKİLEMEZ** — tam ekran dim
  tıklamayı yutuyordu; cutout deliğinden gerçek hedef tıklanır (`_tut_layer` mouse IGNORE).
- KRİTİK ZAMANLAMA: yeni el **asenkron** dağıtıldığından hedef rect'i layout oturduktan sonra
  TAZE almak gerek (`_tut_present` 0.18s + 1 kare bekler, sonra rect/cutout/konum). Aksi halde
  stale rect → çerçeve hedefi kaplar (taşlar tıklanamaz — yaşanan bug).

**Sunum mimarisi:** `_tut_layer` (z=70, IGNORE) içinde 4 cutout ColorRect + `_tut_panel`
(konuşma balonu, top-left anchor + elle konum). Giriş yumuşak fade-in (modulate 0→1). İkon/pop/
ember YOK (kullanıcı "animasyon kötü" dedi → sadeleşti).

**Awaitable bilgi balonu:** `_tut_info` → `_tut_present` + `await _tut_continue` (signal).
İLERİ → emit; ATLA → `_tut_finish` (emit ile bekleyeni serbest bırakır → hang yok).

**Güvenlik:**
- `_tut_reset()` `enter_session` başında → yarım bırakılmış öğreticiyi temizler (tutorialDone'a
  dokunmaz → bitmediyse sonraki girişte yine gösterilir).
- `_open_lose` içinde `_tut_active` ise `_tut_finish` → kaybedince asılı kalmaz.

## Kancalar (mevcut fonksiyonlara eklenen tek satırlar)
`enter_session`, `_on_blind_select` (`blind_selected`), `_toggle_select`/`_on_tile_reorder`
(`selection_changed`), `_on_play` (gizle + `await _tut_postplay`), `_open_shop` (shop tour),
`_open_lose` (temizle). Öğretici kapalıyken hepsi `if _tut_active` ile no-op → normal oyuna sıfır etki.

## İterasyon notları (kullanıcı)
- Taşlara tıklanamıyordu (z_index input'u etkilemez → cutout; sonra stale-rect zamanlama düzeltildi).
- "İkon olmasın" → king çıkarıldı. "Animasyon kötü" → pop/ember kalktı, yumuşak fade kaldı.
- "Tur geçince dükkan da anlatılsın" → `await_shop` + `_tut_shop_tour` eklendi.
- "Demoyu ben söylemeden açma" → artık oyun yalnız kullanıcı "aç" deyince çalıştırılır.
