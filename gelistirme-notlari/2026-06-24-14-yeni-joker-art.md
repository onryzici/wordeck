# 2026-06-24 — Yeni joker pixel-art kartları (5) + kart yüksekliği

**Dosyalar:** `scripts/game.gd`, `scripts/main.gd`, `assets/images/jokers/` (5 yeni PNG)
**Mantık etkisi:** YOK — sadece görsel (joker `name`/etki değişmedi). 106 test etkilenmez.

Kullanıcı 5 yeni pixel-art "JOKER" kartı (880×1200 portre) ekledi; temaya uygun jokerlere bağlandı.

## Eşleştirme (görsel → joker, anlamca yakın)
- kırmızı şeytan/keçi → **Türkçe Belası** (`turkce-belasi`)
- zombi koyun → **Patlamış Mısır** (`patlamis-misir`)
- vampir koyun → **İntikam** (`intikam`)
- centilmen koyun (takım+kart+madalya) → **Banker** (`banker`)
- venom/simbiyot → **Mürekkep Lekesi** (`murekkep-lekesi`)

## Yapılanlar
- PNG'ler kriptik isimlerden **joker-id.png**'ye yeniden adlandırıldı (konvansiyon: art dosyası = id).
- `JOKER_ART` + `JOKER_ART_PIXEL`'e 5 giriş (hepsi pixel-art → NEAREST filtre, keskin).
- Görseller `_load_png` ile **ham bayttan** yüklenir (editör import gerekmez — bkz. mevcut akış).
- Not: art-jokerlerin eski 3'ü (mimar/esssiz/denge-bekcisi) kullanıcı isteğiyle hâlâ kapalı;
  yalnız anagram-seytani + bu 5 yeni aktif.

## Kart yüksekliği — "şişko" düzeltmesi
- Görseller portre (880×1200, oran 0.733) ama yuva 150×166'ya `STRETCH_SCALE` ile yatayda
  %23 geriliyordu → şişko duruyordu.
- **`JOKER_H` 166 → 200** (yuva oranı görsele yaklaştı, art portre kaldı). Rafa taşmadan sığıyor.
- JOKER_H tüm joker kartlarında ortak (rail/dükkan/koleksiyon/drag) → tutarlı büyüdü.

## Test
- `demo_new_art()` / `--newart` bayrağı: 5 yeni-art jokeri rafta yan yana gösterir (MAX_JOKERS=5).
  `godot --path . -- --newart` (canlı, foil parıltısıyla).
