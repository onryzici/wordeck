# 2026-06-24 — Koleksiyon + Rekor + Dinamik müzik + Puanlama cilası (Balatro-grade)

**Dosyalar:** `scripts/main.gd`, `scripts/game.gd`, `scripts/records.gd` (yeni),
`assets/sounds/music_arcade.mp3` (yeni), `assets/sounds/music_shop.mp3` (yeni)
**Mantık etkisi:** YOK — sadece sunum/meta. Motor testleri 106/106 yeşil.

Bu oturum dört iş + bir build. Hepsi sunum katmanı; `engine/`, `data/` mantığına dokunulmadı.

---

## 1. KOLEKSİYON ekranı (joker galerisi)
- Ana menü alt çubuğuna **KOLEKSİYON** butonu (mor/LILAC).
- Tam-ekrana yakın, nadirlik gruplu (SIRADAN / SIRA DIŞI / NADİR / EFSANEVİ), kaydırılabilir
  vitrin; her grupta renkli nokta + ad + adet; HFlowContainer otomatik sarmal.
- Kartlar oyun-içiyle **birebir aynı** — `game.build_showcase_card(joker)` (yeni public fn,
  `_make_joker_card` görselini sürüklemesiz/popoversız üretir; **tek kaynak, sapma yok**).
  - KRİTİK: kart menü ağacında render olduğu için `p.theme = theme` ile oyun teması (pixel
    font) açıkça verilir — yoksa amblem yazıları default fonta düşer (bkz. `_joker_info_card`).
- Açılışta hafif scale-in (TRANS_BACK) + fade.

## 2. REKOR sistemi (kalıcı)
- Yeni `scripts/records.gd` — `Settings` ile aynı statik kalıp, **`user://records.cfg`**:
  `bestScore` (+`bestWord`), `furthestAnte`, `wins`, `runs`.
- `Records.submit(stats, ante, won)` run sonunda çağrılır (game.gd `_add_run_stats`), KIRILAN
  rekorların anahtarlarını döndürür → uç ekranda o kutu **altın kenar + "★ YENİ REKOR ★" +
  altın nabız** alır (En İyi El / Bölüm).
- Ana menü alt çubuğunda **REKORLAR** butonu → ortada keçe panel (En İyi El / En İleri Bölüm /
  Galibiyet / Oynanan Run). (İlk tasarım sol-üst rozetti; kullanıcı "altta buton olsun" dedi.)

## 3. Dinamik müzik (durum tabanlı cross-fade)
- `main.gd`: tek oyun-müziği player'ı yerine **iki player arası 0.8 sn cross-fade**. Durumlar:
  `normal` / `boss` / `shop` (`GAME_TRACKS`, `GAME_TRACK_VOL`).
- Geçiş tetikleri = `game.gd` `signal music_state(state)`:
  - `_on_blind_select` → boss turuysa `boss`, değilse `normal`
  - `_open_shop` → `shop`; `_open_blind_select` → `normal`
- **MP3 ham bayttan yüklenir** (`AudioStreamMP3.data` + `loop`), editör import'u GEREKMEZ —
  `_load_png` felsefesinin ses hali (bu makinede editör import çöküyor). WAV (normal parça)
  hâlâ import'lu `_load_wav` ile.
- Fallback: bir durumun dosyası yoksa `normal`'e düşer, aynı parça **restart'sız** devam eder
  (`_gm_path` dedup) → eksik dosyada kesinti/spam olmaz.
- Parçalar: boss = `music_arcade.mp3` (8-Bit Arcade, 22 sn); shop = `music_shop.mp3` (8-bit
  oyun müziği 25 sn versiyonu). Ses: normal −6, boss −5, shop −8 dB.

## 4. PUANLAMA cilası — Balatro-grade (araştırma temelli)
Mevcut (zaten zengin) sekans KORUNDU, üstüne profesyonel katman. Referans: Blake Crosley
"Balatro juicy feedback" analizi → spring overshoot (cubic-bezier 0.34,1.56 ≈ TRANS_BACK/
EASE_OUT), soldan-sağa ritmik tetikleme, yükselen pitch merdiveni, skora göre kademeli sarsıntı.

- **Tüm tunable'lar `@export` gruplu** (game.gd, sabitlerin altında): ritim gecikmeleri, hop
  yüksekliği, punch, havalanma, float mesafe/süre, count tick, pitch merdiveni, sarsıntı
  eşikleri. *(Editör çökse de koddan düzenle + yeniden çalıştır.)*
- **Adım 1 — Kelime havalanması** (`_word_liftoff`): oynanan taşlar toplu yukarı kalkar (spring),
  oynanmayanlar kararır (`word_dim_others`); tetikleme boyunca kelime kalkık kalır. Sonda
  `_restore_dimmed`.
- **Adım 2 — Taş hop'u** (`_fire_tile`): scale punch + **yukarı zıplama + ±rastgele eğim +
  z öne-çıkma** (eski sadece scale'di).
- **Yükselen pitch merdiveni** (`_ladder_pitch`): harf blip'i her tetikte yarım-ses tırmanır,
  tavanla sınırlı (eski düz 1.0'dı).
- **Yüzen sayılar** (`_float_num`): ayarlanabilir mesafe/süre + organik eğim.
- **Harf başına COUNT-UP (kritik düzeltme)**: eskiden sayaç önizlemeden DOLU başlıyordu →
  harf başına saymıyordu, ritim görünmüyordu (kullanıcı "sayma/ritim yok" dedi). Artık çip
  sayacı **TABANDAN (0) başlar, her harfte yukarı tıklar** + pop; çarpan tür-tabanından başlar.
  `_score_sequence` `disp_chip/disp_mult` kapısı kaldırıldı; sayaç engine timeline running
  total'larından sürülür. Jokerlerin HEPSİ tek tek görünür (Balatro).
- **Count-up RAMP sesi** (`_play_score_ramp`): final skor count-up'ına eşlik eden yükselen
  perdeli prosedürel ton (330→1310 Hz), `_make_tone_wav` ile; süre skorla uzar. (Eksikti.)
- **EKRAN FLASH'ı** (`_screen_flash`): çip×çarpan çarpışmasında sıcak-beyaz kısa flash +
  büyük skorda eşiğe göre kademeli flash. (Eksikti.)
- **Adım 5 — Kademeli tepki**: final skor eşiğine göre (`shake_tier1/2`) trauma + partikül +
  collect tizliği + flash kademelenir; tur-skoru count-up süresi skor büyüklüğüyle uzar.
- Korunanlar: `_collide_seals`, `_slam_score`, `_juice_joker`, alev, ember.

## 5. Build (DMG)
- `godot --headless --export-release "macOS" build/Wordeck.dmg` (preset hazırdı, 4.7 şablonları
  kurulu). Universal (x86_64+arm64), ad-hoc imzalı. `build/` gitignore'lu → repoya girmez.

## Ayar / not noktaları
- Koleksiyon: `_collection_cell` hücre genişliği 150; grup başlık boyutu.
- Rekor: `Records.submit` mantığı; uç ekran vurgusu `_stat_cell(is_record)`.
- Müzik: `GAME_TRACKS` / `GAME_TRACK_VOL`, cross-fade 0.8 sn (`set_game_music_state`).
- Puanlama: `@export` blok — `letter_step_delay` (ritmin kalbi), `tile_hop_height`,
  `pitch_step_semitones`/`pitch_max_semitones`, `word_lift_height`, `shake_tier1/2` + amp'lar,
  `score_countup_min/max`.
