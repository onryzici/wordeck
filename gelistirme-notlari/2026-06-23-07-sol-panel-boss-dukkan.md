# 2026-06-23 — Sol panel (Balatro hedef kutusu) + boss çipi + menü logo + dükkan düzeni

**Dosyalar:** `scripts/game.gd`, `scripts/main.gd`
**Mantık etkisi:** YOK — sadece sunum. Motor testleri: 106/106.

---

## 1. Sol panel — Balatro "Score at least / Reward" hedef kutusu
`_build_target_box()` (eski düz "EN AZ X PUAN" etiketinin yerine):
- **Blind çipi** (renkli yuvarlak rozet, tür rengine göre): TUR 1 = yeşil ●, TUR 2 =
  altın ●, **PATRON = kırmızı 💀** (`_chip_sb` rengi `_refresh_hud`'da güncellenir).
- **HEDEF** + büyük kırmızı hedef sayısı + **Ödül: $$$** (blind reward, $ ikonu).
- İçerik ORTALI. Vars: `_target_box`, `blind_chip`, `blind_chip_icon`, `_chip_sb`,
  `target_reward_label`.
- Alt stat alanı (HAK/DEĞİŞİM/PARA/BÖLÜM/TUR) eski yüksekliğinde (EXPAND_FILL) — kullanıcı
  kompakt denemesini geri istedi.

## 2. Boss
Patron turunda `boss_panel` zaten isim + yetenek açıklamasını kırmızı kutuda gösteriyor;
blind çipi de kırmızı 💀 olur.

## 3. Menü logosu profesyonelleştirme
- "TÜRKÇE KELİME ROGUELIKE" **altyazısı kaldırıldı** (taşlar logonun kendisi).
- WORDECK taşlarına **sheen (üst parlaklık)** eklendi — cilalı his.

## 4. Dükkan — tam Balatro düzeni
- **Sol panel tepesi dükkanda SHOP olur** (`_set_shop_sidebar`): blind ismi/hedef kutusu
  yerine kırmızı **"DÜKKÂN" marquee**'si; çıkışta `_refresh_hud` normale döndürür.
  Merkezdeki tekrar eden SHOP marquee kaldırıldı.
- **KUPON kartı** (`_voucher_card`): tam genişlik bar DEĞİL → üstte ortalı tek mor kart.
  **Sürükle-bırak ile satın alma** (`_voucher_input`/`_vdrag`): tıkla = al, ya da kartı
  sürükleyip bırak = al (top_level ile imleci takip eder). Eşik 8px.
- Voucher pakettenraftan çıkarıldı (`_shop_pack_slots` artık sadece harf/cila paketi).

## İterasyon notları (kullanıcı geri bildirimi)
- Hedef kutusu önce sol-hizalıydı → ortalandı. Alt alan kompaktlaştı → geri büyütüldü.
- Voucher önce tam-genişlik bar yapıldı → "tam genişlik olmamalı, sürükle-bırak alanı"
  denince ortalı drag-edilebilir karta çevrildi.
