# 2026-06-22 — Trauma-tabanlı Ekran Sarsıntısı + ÇİP×ÇARPAN Çarpışma Beat'i

**Dosya:** `scripts/game.gd` (tek dosya, başka hiçbir şeye dokunulmadı)
**Mantık etkisi:** YOK — sadece görsel/his. Motor testleri: 106/106 geçti.

---

## Neden?

Puanlama sekansı zaten zengindi (sıralı taş tetikleme, +N süzülme, çip count-up,
çarpan kick, joker tetikleme, final SLAM, kor patlamaları). İki eksik vardı:

1. **Ekran sarsıntısı** rastgele jitter'dı (`randf_range` ile titreme) — Balatro'nun
   tatmin edici sarsıntısı pürüzsüz ve "ağırlıklı" hissettirir.
2. Final anı, çip ve çarpan kutularını yerinde patlatıp bitiyordu; Balatro'daki gibi
   **iki değerin ortada buluşup çarpışması** yoktu.

---

## 1) Trauma-tabanlı ekran sarsıntısı

### Mantık
Klasik oyun-feel tekniği: olaylar bir **`trauma`** değeri *ekler* (0–1 arası),
sarsıntı her kare `trauma²` ile ölçeklenir (küçük trauma yumuşak, büyük trauma vurucu),
ve `trauma` zamanla **decay** eder (söner). Titreşim **`FastNoiseLite`** ile pürüzsüz
örneklenir — rastgele zıplama değil, akan dalga.

### Eklenenler (game.gd)

**a) Değişkenler ve ayar sabitleri** (`var shaker` hemen altı):
```gdscript
var _trauma := 0.0
var _shake_noise: FastNoiseLite
var _noise_t := 0.0
const SHAKE_MAX_OFFSET := 24.0  # trauma=1'de en büyük piksel kayması
const TRAUMA_DECAY := 1.7       # saniyedeki sönme hızı
const SHAKE_NOISE_SPEED := 16.0 # titreşim frekansı
# Katmanlı trauma şiddetleri:
const TRAUMA_TILE := 0.13   # normal harf taşı
const TRAUMA_CHIP_OP := 0.09  # çip katkısı (foil vb.)
const TRAUMA_MULT_OP := 0.34  # çarpan katkısı (joker/holo) — orta kick
const TRAUMA_COLLIDE := 0.55  # çip×çarpan çarpışması
```

**b) Noise kurulumu** (`_ready`, `_spark_tex` satırından sonra):
```gdscript
_shake_noise = FastNoiseLite.new()
_shake_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
_shake_noise.frequency = 1.0
```

**c) Her kare uygulama** (`_process` EN BAŞINA — erken return'lerden önce, hep çalışsın):
```gdscript
if shaker != null:
    if _trauma > 0.0:
        _noise_t += _delta
        var shake := _trauma * _trauma   # karesel ölçek
        var s := _noise_t * SHAKE_NOISE_SPEED
        var nx := _shake_noise.get_noise_2d(s, 0.0)
        var ny := _shake_noise.get_noise_2d(0.0, s)
        shaker.position = Vector2(nx, ny) * (SHAKE_MAX_OFFSET * shake)
        _trauma = maxf(0.0, _trauma - TRAUMA_DECAY * _delta)
    elif shaker.position != Vector2.ZERO:
        shaker.position = Vector2.ZERO  # sıfıra otur (drift olmasın)
```
> `shaker`, tüm UI'yi tutan Control olduğu için ona offset vermek tüm ekranı sarsar.

**d) Eski API korundu** — `_shake(amount, dur)` artık trauma enjekte ediyor; mevcut
iki çağrı noktası (final slam, kutlama) hiç değişmeden çalışıyor:
```gdscript
func _shake(amount: float, _dur: float) -> void:
    _add_trauma(clampf(amount / 14.0, 0.0, 0.85))

func _add_trauma(amount: float) -> void:
    if not Settings.shake_on:   # ayardan kapatılabilir
        return
    _trauma = clampf(_trauma + amount, 0.0, 1.0)
```

**e) Katmanlı his** — sekansın doğru anlarına trauma eklendi:
- `_fire_tile()` → `_add_trauma(TRAUMA_TILE)` (her harf, küçük)
- `_show_op()` çip dalı → `TRAUMA_CHIP_OP` (ufak)
- `_show_op()` çarpan dalı → `TRAUMA_MULT_OP` (orta kick)
- `_collide_seals()` → `TRAUMA_COLLIDE`
- final slam (mevcut `_shake(...)`) → ~0.8 (en büyük)

### Ayar ipuçları
- Genel şiddet az/çok: **`SHAKE_MAX_OFFSET`** (24 → büyüt/küçült).
- Daha çabuk/uzun sönsün: **`TRAUMA_DECAY`** (büyük = çabuk durur).
- Titreşim sıklığı: **`SHAKE_NOISE_SPEED`**.
- Tek tek olayların gücü: `TRAUMA_*` sabitleri.
- Tamamen kapatma: Ayarlar → sarsıntı (mevcut `Settings.shake_on`).

---

## 2) ÇİP × ÇARPAN çarpışma beat'i

### Mantık
Final SLAM'den hemen önce, ÇİP ve ÇARPAN değerlerinin **hayalet kopyaları** seal
kutularından ortadaki "×" işaretine doğru hızlanarak kayar, orada **çarpışır**
(kor patlaması + halka + trauma), sonra mevcut total SLAM devreye girer.

**Önemli:** Gerçek seal panelleri **yerinde kalır** — çarpışma, fx katmanındaki geçici
hayalet rozetlerle yapılır. Böylece sol panel düzeni (layout) hiç bozulmaz.

### Eklenen fonksiyonlar (game.gd, `_shake` üstü)
- `_collide_seals()` — iki hayaleti "×" orta noktasında buluşturur, çarpıştırır.
  - Yaklaşma: `TRANS_CUBIC` + `EASE_IN` (içeri hızlanır → çarpışma vurgusu).
  - Çarpışma anı: `_ember_burst(meet, 24, 3.6)` + `_flash_ring(meet, ...)` + `_add_trauma(TRAUMA_COLLIDE)`.
  - Hayaletler bir an `1.45` punch yapıp söner ve `queue_free`.
- `_seal_ghost(center, value_text, color)` — dönük karo + büyük puan içeren tek
  kullanımlık rozet (mevcut `_float_num` görsel diliyle uyumlu).

### Sekansa bağlama (`_score_sequence` final bloğu)
İki seal pop'undan sonra, total slam'den **önce** tek satır:
```gdscript
_pop(chip_seal_panel, 1.16)
_pop(mult_seal_panel, 1.16)
await _collide_seals()      # <-- eklendi
var mid := _node_center(total_label)
...
```

### Ayar ipuçları
- Çarpışma hızı: `_collide_seals` içindeki `dur := 0.24`.
- Çarpışma gücü: `TRAUMA_COLLIDE`, ember sayısı (`24`), halka boyu (`7.0`).
- Hayalet boyu/fontu: `_seal_ghost` içindeki `holder.size` / font `50`.

---

## Doğrulama
- `godot --headless ... engine_test.gd` → **106 geçti, 0 başarısız** (mantık sağlam).
- `game.gd` örneklenip `_ready` çöküyor değil; `_add_trauma(0.5)` → trauma 0.5 (çalışıyor).
- Oyun penceresi açıldı, oynandı, **runtime hatası yok**.

## Geri alma
Tüm değişiklik `scripts/game.gd` içinde ve şu bloklarla sınırlı: trauma değişkenleri,
`_ready` noise init, `_process` baş bloğu, `_shake`/`_add_trauma`, `_collide_seals`/
`_seal_ghost`, `_fire_tile`/`_show_op`/`_score_sequence` içindeki tek satırlık eklemeler.
İstenirse bunlar tek tek geri alınabilir.
