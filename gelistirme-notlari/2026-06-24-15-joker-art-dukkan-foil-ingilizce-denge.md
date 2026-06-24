# 2026-06-24 — Yeni joker artları + dükkan düzeni + booster paket + Balatro foil + İngilizce denge

**Dosyalar:** `data/letter_bag.gd`, `scripts/game.gd`, `shaders/balatro_foil.gdshader` (yeni),
`assets/images/jokers/` (5 yeni PNG + esssiz güncellendi), `tests/sim_english.gd` (yeni)
**Mantık etkisi:** Sadece İngilizce harf torbası (`BAG_EN`) — varsayılan TR değişmedi, **106/106 test yeşil**.
Geri kalan her şey sunum katmanı (`game.gd` + shader + art).

---

## 1. Yeni joker pixel-art kartları (5) + varsayılan/yedek kart
- Tam-kart "JOKER" pixel-art'ları eklendi: **sesli-avcisi, ikizler, kose-tasi, ilk-hamle, esssiz**
  (`JOKER_ART` + `JOKER_ART_PIXEL` haritalarına; `_load_png` ham-bayt ile yüklenir, `.import` gerekmez).
  - NOT: dosya `essiz.png` → joker ID `esssiz` (üçlü s). Eşleme buna göre.
- **duz-joker.png = VARSAYILAN/YEDEK kart** (klasik palyaço). `_joker_face` artık özel artı olmayan
  TÜM jokerler için bu fallback'i gösterir (eski emoji+stylebox yüzü kalktı). `JOKER_ART_FALLBACK`.

## 2. Joker kart boyutu/oranı — görsel KIRPILMASIN
- Art portre **880×1200 (oran 0.733)**. Kart oranı buna eşitlendi → görselin TAMAMI kenardan kenara
  sığar (ne sağ/sol ne üst/alt kırpılır, bara/boşluk yok). `stretch_mode = KEEP_ASPECT_CENTERED`.
- Boyut iterasyonu (kullanıcı): 200→168→124×168→160×218 → **JOKER_W=176, JOKER_H=240**.
- `_pop_in_joker` pivot'u sabit (61,75) → `Vector2(JOKER_W,JOKER_H)*0.5` (dinamik).

## 3. Dükkan düzeni (Balatro referansı) + booster paket görseli
- **İki sıra:** ÜST = [SONRAKİ TUR + YENİLE butonları | jokerler], ALT = paketler. Butonlar joker
  kartı yüksekliğini doldurur (iki buton üst üste ≈ bir joker kartı; `btn_h=(JOKER_H+26-12)/2`).
- **Tezgah (tray) ALTA konumlu** + kompakt (raflara sarılı, boşluk yok): `tray=SHRINK_CENTER`,
  `shop_view.alignment=END`. (Önce "sidebar boyunda doldur" denendi → kullanıcı kompakt+alt istedi.)
- **Paketler = PACK_W×PACK_H (176×228)**, joker ile aynı genişlik.
- **Gerçek booster paketi görseli** (`_pack_visual` yeniden): folyo poşet gövde (`_pack_body_sb`) +
  joker_foil shimmer + dişli sızdırmaz ağız (crimp + delik sırası, `_pack_crimp_sb`) + altın kenarlı
  isim BANDI (`_pack_banner_sb`) + soluk ikon (HARF→"Aa", CİLA→"✦"). Düz renk kart gitti.
- Dükkan üst joker rafı (sahip olunan/sat) korundu (kullanıcı: "neden kaldırdın" → geri eklendi).

## 4. Satın alma efekti — yerinde (yukarı kayma YOK)
- `_celebrate_bought_joker`: alınan joker rafta YERİNDE kısa parıltıyla pop (TRANS_BACK) + altın kor
  patlaması + ışık halkası + hafif sarsıntı + "satın alındı" çanı. (Önceki "aşağıdan yukarı slota
  kayma" kullanıcı tarafından reddedildi.) `_buy_idx` → `_rebuild_jokers` o kartı özel kutlar.

## 5. Balatro holografik FOIL — özel kartlar (`shaders/balatro_foil.gdshader`, yeni)
- Akışkan yağ-tabakası gökkuşağı + metalik ışık bantları (çok frekanslı sin distorsiyon + hue).
- `_joker_shine`: **nadir + efsanevi** → bu foil (intensity rare 0.70 / legendary 1.0); sıradan/
  sıra dışı → eski basit beyaz sheen (`joker_foil`). Köşeler rounded-rect SDF ile kart formuna uyar.

## 6. İngilizce harf dengesi (oynanabilirlik) — `data/letter_bag.gd` BAG_EN
- **Sorun:** eski torba %45 ünlü + S yalnız 2 + yaygın ünsüzler tek + ölü harfler (Q/X) → İngilizce
  eller ünlü-ağırlıklı, kelime kurmak Türkçe'den zordu (kullanıcı raporu).
- **Yeni denge (~63 taş, ~%37 ünlü):** E8 A6 I4 O3 U2 / S4 R4 T4 N3 L3 D3 / G2 C2 M2 P2 H2 B2 /
  F1 V1 W1 Y1 K1 J1 Z1. **Q ve X çıkarıldı** (en ölü). S bollaştı (İngilizce'de kritik).
- **Doğrulama** (`tests/sim_english.gd`, 40 el): ort. **227 kurulabilir kelime/el**, ort. **3.33 ünlü**
  (8 taşta ~%42; dağıtıcı 0.4 hedefliyor), ort. en uzun **6.6 harf**, **kötü el (<3 kelime) = 0/40**.
  Örnek eller yaygın: create/berate/paused/flicker/sleeve/radiates.
- Değerler (`VALUES_EN`, Scrabble) ve dağıtıcı config (`targetVowelRatio 0.4`) DEĞİŞMEDİ (torba yeterli).

## Ayar / not noktaları
- Joker/paket boyutu: `JOKER_W/H`, `PACK_W/H` (`game.gd` başı). Buton yüksekliği bunlardan türer.
- Yeni PNG joker artı = `JOKER_ART` + `JOKER_ART_PIXEL`'e ekle, `_load_png` ile (asla `load()`).
- Foil şiddeti: `BALATRO_FOIL` (rare/legendary intensity+speed).
- İngilizce harf dengesi: `letter_bag.gd BAG_EN`. Tekrar test: `--headless --script res://tests/sim_english.gd`.
