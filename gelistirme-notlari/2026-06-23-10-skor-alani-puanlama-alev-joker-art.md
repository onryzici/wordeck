# 2026-06-23 — Skor alanı + puanlama akışı + alev + joker kart görseli

**Dosyalar:** `scripts/game.gd`, `shaders/card_round.gdshader` (yeni),
`assets/images/jokers/anagram-seytani.png` (yeni)
**Mantık etkisi:** YOK — sadece sunum/UX. Motor testleri: 106/106.

---

## 1. Sol panel skor alanı (kendi kutusu + dalgalı başlık)
- Kelime-tipi etiketi + çip×çarpan artık **kendi çevreli kutusunda** (`PanelContainer`,
  `FELT_800` zemin, ince kenar, radius 16) — Balatro skor kutusu gibi bağımsız bir bölge.
- **Kelime-tipi etiketi** (eski turuncu/küçük "Orta · ×2") → **BEYAZ, 38pt**, dalgalı
  (`RichTextLabel [wave]` — hafif Meksika dalgası, amp 6, sürekli akar).
  - **Belirme:** kelime seçilince fade-in + aşağıdan hafif yaylanarak (TRANS_BACK) oturur.
    Her taşta yeniden fade etmez (`_tier_shown` durumu) — yalnız ilk görünüşte.
  - **Kaybolma:** sıfırlanınca ani değil; fade-out + hafif küçülme (`_show_tier`/`_hide_tier`).
- **Çip/çarpan kutuları:** 140×86 → **150×74** (daha geniş, daha alçak — kullanıcı isteği).
  Sayı puntosu 50→52. (Sidebar 384px olduğu için genişlikte tavan var.)

## 2. Puanlama akışı — önizlemeden DEVAM (0×1'e düşmez)
- **Sorun:** Önizlemede "20×2" yazıp OYNA'ya basınca kutu 0×1'e düşüp baştan sayıyordu.
- **Çözüm:** `_score_sequence` artık ekranda gösterilen önizleme değerinden başlar; taban
  (harf çipleri + kademe + deterministik jokerler önizlemede zaten var) **kutuyu saymaz**.
  Yalnız **önizlemeyi AŞAN ekstralar** (rastgele jokerler vb.) kutuyu yükseltir
  (`disp_chip`/`disp_mult` = ekranda gösterilen güncel değer; aşınca `maxi/maxf`).
- **Taş baloncukları korunur:** Her harfte `_fire_tile` "+N" pop + kıvılcım HER ZAMAN görünür;
  harf-üstü geliştirmelerde çip/çarpan baloncuğu HER ZAMAN görünür. Bunlar **juice** olarak akar,
  kutuyu düşürmez → `_show_op(..., set_box)` bayrağı: `set_box=false`'da baloncuk+pop+ses var,
  kutu değeri değişmez.
  - (Önce tabanı tamamen sessiz yapmıştım → baloncuklar hiç çıkmıyordu, kullanıcı "harflerin
    üzerinde puan/çarpan gelmiyor" dedi → baloncuklar geri, kutu yine sıfırlanmadan.)

## 3. Çip×çarpan + etiket sıfırlaması — skor AKAR AKMAZ (her durumda)
- Skor tur toplamına akınca (`_score_sequence` sonu, SLAM + tur skoru sayımından sonra)
  çip×çarpan **o an** geriye sayarak boşalır (`_countdown_seals`) ve `_hide_tier()`.
- Artık **tur geçilip dükkana giderken de** kutular ve "Orta ×2" etiketi boş kalıyor
  (eskiden won→dükkan dalında eski değerde takılıyordu). Eski (refill sonrası) sıfırlama kaldırıldı.

## 4. Çip/çarpan alevi — daha yüksek + yavaş sönüş
- `_drive_seal_flame`: hedef şiddet tabanı 0.5 → **0.68** (daha dolgun/uzun alev),
  alev tacı yüksekliği (`crown_h`) 40 → **56px**.
- Sönme yumuşatıldı: **yükselirken çabuk (lerp 0.12), sönerken yavaş (0.035)** + daha düşük
  kesme eşiği (0.008) → puan aktıktan sonra alev ani gitmez, kademeli azalarak söner.

## 5. Joker kart görseli (özel PNG) + köşe yuvarlama + sınıf parıltısı
- **Özel kart görseli sistemi:** `JOKER_ART` eşlemesi (id → PNG). Eşleşen jokerde emoji/stylebox
  düzeni yerine tam-kart `TextureRect` basılır (`_joker_face`). İlk örnek:
  **"anagram-seytani"** → `assets/images/jokers/anagram-seytani.png` (366×450 = kartın 3×'i,
  pixel-art, NEAREST filtre). Oyun-içi kart + sürükleme önizlemesinde geçerli.
- **Köşe yuvarlama:** `shaders/card_round.gdshader` (yeni) — kare pixel-art görselin köşelerini
  yuvarlar (rounded-rect SDF, `radius_px≈20` texture-px), yuvarlak karta uysun diye.
  (Kart stylebox radius 9'da kalır; görsel de yuvarlanır.)
- **Sınıfa (nadirlik) göre parıltı:** `_joker_shine` — `tile_shimmer.gdshader` ile çapraz kayan
  ışık bandı; nadirlik tonu + beyaz gloss. `JOKER_SHINE` haritası: common'da yok, uncommon hafif,
  rare belirgin, legendary en güçlü/hızlı. `Settings.particles_on` kapalıysa devre dışı.
- **Joker kart idle animasyonu:** düz sağa-sola "silecek" rotasyonu yerine **yumuşak dikey
  süzülme (float ±3.4px) + çok hafif eğilme (±1.4°, ayrı frekans, faz kaymalı)**. HBox konumunu
  bozmamak için additif offset (`bob_off` meta).

## Notlar
- **Kart tasarımı ölçüsü:** joker kartı native **122×150** (taban tuval 1920×1080). Net olsun diye
  2× (244×300) veya 3× (366×450) çiz; pixel-art için NEAREST. Art penceresi ≈ 112×116.
- `*.import` gitignore'lu → yeni PNG `.import`'suz commit edilir, diğer makinede Godot yeniden
  import eder. (`card_round.gdshader.uid` commit'lenir — diğer shader uid'leri gibi.)
