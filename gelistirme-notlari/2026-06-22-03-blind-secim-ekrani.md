# 2026-06-22 — Blind / Tur Seçim Ekranı Cilası

**Dosya:** `scripts/game.gd` (`_blind_column`, `_animate_blind_columns`)
**Mantık etkisi:** YOK — sadece görsel/his. Motor testleri: 106/106 geçti.

---

## Yapılan

Mevcut blind seçim ekranına Balatro tarzı cila eklendi (mantık/akış aynı):

1. **Springy stagger giriş** (`_animate_blind_columns`): sütunlar aşağıdan
   (y +52) ve küçükten (scale 0.86) **yaylanarak** gelir — `TRANS_BACK` + `EASE_OUT`
   ile overshoot (squash/stretch hissi), her sütun `i*0.09s` gecikmeli (cascade).

2. **GEÇİLDİ damgası** (`_blind_column`, done kolonlar): büyük (font 36), döndürülmüş
   (-12°), beyaz+koyu konturlu overlay etiket. `_animate`'te gecikmeli **"slap"**:
   scale 2.2→1.0 (`TRANS_BACK`) + fade-in. Eski küçük "✓ GEÇİLDİ" yazısı kaldırıldı.

3. **Aktif kolon vurgusu**: kalın kenarlık + accent renk (zaten vardı, korundu).
   **Boss aktifse**: kenarlık **kırmızı** (T.MULT) + kalın (5px) → tehdit hissi.

---

## Kullanıcı geri bildirimiyle ÇIKARILANLAR (önemli)

- **Rim-glow YOK**: önce aktif/boss kolona shadow-glow eklenmişti; kullanıcı
  "glowlu şeyler çok basit duruyor" dedi → kaldırıldı, yerine kalın/kırmızı kenarlık.
  (Genel tercih: soft glow/halo kullanma.)
- **Hover büyüme YOK**: sütun üstüne gelince scale büyüme kaldırıldı (gereksiz bulundu).
- **Aktif kolon kor patlaması YOK**: girişte ember burst kaldırıldı (gereksiz bulundu).

> Ders: Bu ekranda vurgu = **kenarlık + renk + springy giriş + damga**. Glow/hover/partikül yok.

---

## Doğrulama
- Capture ile görsel doğrulandı (done kolonlarda damga, boss'ta kırmızı kenarlık, glow yok).
- Motor testleri: **106 geçti, 0 başarısız**. Kullanıcı onayladı.
