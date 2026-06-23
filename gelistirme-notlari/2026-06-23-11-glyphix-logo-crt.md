# 2026-06-23 — GLYPHIX ana menü logosu + çözünürlük-bağımsız CRT

**Dosyalar:** `scripts/main.gd`, `shaders/logo_fx.gdshader` (yeni),
`shaders/logo_shadow.gdshader` (yeni), `shaders/crt.gdshader`,
`assets/images/glyphix.png` (yeni)
**Mantık etkisi:** YOK — sadece sunum. Motor testleri etkilenmez (106/106).

> **Marka:** Oyun adı **WORDECK → GLYPHIX** oldu. Şimdilik yalnız ana menü başlığı değişti;
> `project.godot` uygulama adı ve kullanıcı veri klasörü hâlâ "Harf Destesi" (istenirse güncellenir).

---

## 1. Ana menü başlığı: harf taşları → GLYPHIX logosu
- Eski WORDECK harf-taşları yelpazesi (`_hero_tile`) **kaldırıldı**; yerine tek PNG logo
  (`assets/images/glyphix.png`, 3001×1277, gotik wordmark + mermer doku, alfa'lı).
- `_build_hero`: logo `TextureRect` olarak basılır.
  - **KRİTİK:** `expand_mode = EXPAND_IGNORE_SIZE` şart — yoksa TextureRect texture'ın doğal
    boyutunu (3001×1277) dayatıp DEV olur. Rect 680×(680·1277/3001) → aspect texture'la eşit
    (custom shader UV'yi tüm texture'a eşler → stretch_mode baypas; warp düzgün).
  - Konum: üst-merkez yerine **ekran ortasına yakın** (`hero.offset_top = -20`; çok yukarı
    olmasın diye iterasyonla indi). Boyut 680px.
- `_process`: logo + gölge birlikte hafifçe süzülür (dikey bob 6px, ±0.9° sallanma);
  `bob`/`rot` ortak hesaplanır, iki çocuğa da uygulanır → offset korunur.

## 2. Logo efekti — `logo_fx.gdshader` (ana logo)
- **Bükeylik:** banner kavisi (UV.x parabolü ile dikey kaydırma).
- **Nefes:** yumuşak yavaş dalga warp (wave_amp 0.006, speed 0.7).
- **Motion blur:** yatay 7-örnek, **yavaş + küçük yayılım** (blur 0.0032, vel = yavaş sin).
  - İlk deneme hızlı/güçlüydü → **hayalet/çift** gözüküyordu; yavaşlatıp küçülttüm.
- **Matlık (arka planla uyum):** ~%44 desatüre + kontrast 0.78 + ince film grain → cam/parlak
  his azaldı, mat balatro_bg ile bütünleşir.
- **CRT (logoda):** global CRT ile aynı frekansta tarama çizgisi (aşağıya bak) → logoda da yoğun.

## 3. Logo gölgesi — `logo_shadow.gdshader` (yeni)
- İlk versiyon: ana logonun **keskin** koyu kopyası offsetli → kullanıcı "gölge değil, **çift**
  gözüküyor" dedi.
- Düzeltme: ayrı gölge shader'ı — logoyla **aynı warp** parametreleri (hizalı bükülür) +
  **5×5 disk-blur** ile alfa yumuşatma → gerçek yumuşak gölge. Offset (7,12), koyuluk 0.42.

## 4. CRT tarama çizgileri — çözünürlük-bağımsız (4K düzeltmesi)
- **Sorun:** 4K tam ekranda CRT hiçbir yerde belli olmuyordu.
- **Neden:** çizgiler `FRAGCOORD.y * 2.1` (FİZİKSEL piksel). Proje `canvas_items/expand`
  stretch → 4K tam ekranda fiziksel çözünürlük 4K → ~3px çizgi (çok ince) → filtre yutuyor.
- **Düzeltme (`crt.gdshader` + `logo_fx`):** çizgiler artık `SCREEN_UV.y * scan_lines` ile —
  ekran yüksekliği boyunca **sabit 220 çizgi** → 1080p/1440p/4K hepsinde aynı yoğunlukta görünür.
  `scan_strength` 0.16 → **0.22**. (Ayar: çok kalınsa `scan_lines` artır = daha ince.)

## Notlar / ayar noktaları
- Logo boyutu/konumu: `_build_hero` `lw` (680) ve `hero.offset_top` (-20).
- Gölge: `logo_shadow` `softness`/`strength` + offset `(7,12)`.
- Matlık: `logo_fx` desatüre (0.56) / kontrast (0.78) / grain (0.075).
- CRT: `scan_lines` (220), `scan_strength` (0.22).
- `*.import` gitignore'lu → yeni PNG `.import`'suz commit; shader `.uid`'leri commit'lenir.
