# 2026-06-24 — İngilizce dil desteği (TR/EN) + puanlama ritmi düzeltmesi

**Dosyalar:** `scripts/loc.gd` (yeni), `scripts/loc_data.gd` (yeni), `data/master.txt` (yeni,
İngilizce sözlük), `scripts/settings.gd`, `engine/turkish_case.gd`, `data/letter_values.gd`,
`data/letter_bag.gd`, `engine/state.gd`, `scripts/game.gd`, `scripts/main.gd`
**Mantık etkisi:** Dil seçimi `engine/`+`data/`'ya dokunur AMA varsayılan "tr" → **106/106 test
yeşil** (EN koşullu/ek). Motorun çalışma mantığı değişmedi, sadece dil-duyarlı dallar eklendi.

Oyun artık **iki dilli**: Ayarlar → "Dil / Language" → TÜRKÇE ↔ ENGLISH. Üç fazda yapıldı.

---

## Faz 1 — İngilizce oynanış (altyapı)
- **`Settings.language`** ("tr"/"en") → `user://settings.cfg` `[locale] lang`. Ayarlarda toggle;
  değişince `get_tree().reload_current_scene()` (tüm ekranlar `_ready`'de bir kez kuruluyor →
  yeniden yükle = anında, eksiksiz, tutarlı).
- **Sözlük:** `kelimeler.txt` (TR) / `master.txt` (EN, ~306k kelime). `game.gd` `_apply_language()`
  her run'da çağrılır (dil değişince yalnız o zaman yeniden yükler — 3MB reload guard `_dict_lang`).
- **Casing tek noktadan:** `TurkishCase.tr_lower` dil-duyarlı → EN'de düz `to_lower()` ("I"→"i",
  Türkçe haritası atlanır). Sözlük/dealer/round otomatik tutarlı.
- **Harf seti dil-duyarlı:** `LetterValues.chips` (EN = Scrabble değerleri), `LetterBag.bag()`
  (EN = ~56 taş, Türkçe yapısını yansıtan İngilizce frekans). `state.gd` `LetterBag.bag()` çağırır.
- Tümü `set_lang()` deseni (sunum katmanı `game.gd._apply_language()` motora dili iter; engine saf).

## Faz 2 — Arayüz çevirisi
- **`scripts/loc.gd`:** kaynak Türkçe metni ANAHTAR alan `L.t(s)`; "en" değilse / haritada yoksa
  Türkçe'yi AYNEN döndürür (güvenli fallback).
- **Akıllı yöntem:** etiket/buton **fabrikaları** (`_label`, `_menu_label`, `_menu_button`,
  `_chunky_btn`, `_wavy_label`, `_drop_in_label`) `L.t`'den geçiyor → statik metinler OTOMATİK
  çevriliyor. Yalnız formatlı (`"%d JOKER" %`) ve doğrudan `.text=` siteleri (~25) elle sarıldı.
- Kapsam: menü, ayarlar, rekorlar, koleksiyon, yardım, **tutorial balonları**, HUD (ANTE/ROUND/
  PLAYS/DISCARDS/MONEY/TARGET/INFO/MENU), ÇİP→CHIPS/ÇARPAN→MULT, dükkan+cash-out, blind seçim
  (CHOOSE NEXT BLIND/SELECT/SKIP/ROUND), kazan-kaybet+istatistik, kutlama sözleri, **duraklat ekranı**.

## Faz 3 — İçerik çevirisi (`scripts/loc_data.gd`)
- ~160 çeviri: **62 joker** (ad+açıklama), **12 boss** (ad+kısıtlama), **4 voucher**, **5 enhancement**.
  Alt-ajan data dosyalarından birebir-anahtarlı taslak üretti; gözden geçirilip yerleştirildi.
- `loc.gd` `t()` önce UI haritası (`EN`), sonra `loc_data.EN_DATA`'ya bakar.
- Bağlanan display: joker isim plakası + bilgi kartı (`_highlight_desc` artık Chips/Mult de
  renklendirir), voucher kart+tooltip, enhancement seçici+tooltip, boss panel+banner.
- **Mimari:** data dosyaları (`jokers.gd` vb.) DEĞİŞMEDİ; çeviri display anında `L.t(name/desc)`
  ile yapılır → motor/oyun mantığı korunur, isim/açıklama yalnızca gösterimde çevrilir.

## Ayrıca — puanlama ritmi düzeltmesi (Faz 2 cilasının devamı)
- Kullanıcı: harf başına "+N" baloncukları arasında ritim yoktu. Sebep: `_float_num` sayıyı
  taş tetiklendikten **0.2 sn sonra** gösteriyordu → senkron bozuluyordu. Düzeltme: `num_delay`
  param (taş "+N"si için 0.04 = anında pop) + `letter_step_delay` 0.15→0.22.
- Sayaç **0'a düşmesin** (önizlemeden devam) korundu — kullanıcı tercihi (kısa süre 0'dan
  saydırma denendi, geri alındı).
- **Count-up ramp sesi** (`_play_score_ramp`, yükselen perdeli prosedürel ton) + **ekran flash'ı**
  (`_screen_flash`, çarpışma + büyük skor) eklendi.

## Ayar / not noktaları
- Yeni metin eksikse: `loc.gd` `EN` (arayüz) veya `loc_data.gd` `EN_DATA` (içerik) haritasına
  Türkçe-anahtar → İngilizce ekle. Fabrikadan geçen statik metin otomatik; formatlı/`.text=` ise
  siteyi `L.t(...)` ile sar.
- İngilizce harf dengesi: `letter_bag.gd` `BAG_EN`, `letter_values.gd` `VALUES_EN`.
- Dil testi: `settings.cfg` `[locale] lang="en"`; capture `--menu` / `--jokers` / `--blind` / `--play`.
