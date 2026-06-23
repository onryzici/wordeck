# Geliştirme Notları — Wordeck (Harf Destesi)

Bu klasör, oyuna eklenen **his / animasyon / efekt (juice)** güncellemelerinin
detaylı kayıtlarını tutar. Amaç: ileride "ne değişti, neden, nasıl ayarlanır,
nasıl test edilir" diye bakabilmen.

> **Kural:** Oyun mantığına ve sayılara (`engine/`, `data/`) dokunulmaz.
> Sadece sunum/feedback katmanı (`scripts/game.gd`, `shaders/`) değişir.

## İçindekiler

| Tarih | Not | Konu |
|-------|-----|------|
| 2026-06-22 | [01 — Trauma shake + Çarpışma beat](2026-06-22-01-trauma-shake-carpisma.md) | Puanlama sekansı hissi |
| 2026-06-22 | [02 — Alev shader + Panel + SLAM](2026-06-22-02-alev-panel-slam.md) | ÇİP/ÇARPAN alevi, Balatro panel, geçici SLAM |
| 2026-06-22 | [03 — Blind seçim ekranı](2026-06-22-03-blind-secim-ekrani.md) | Springy giriş, GEÇİLDİ damgası, boss kırmızı kenarlık (glow yok) |
| 2026-06-22 | [04 — Paket açma sekansı](2026-06-22-04-paket-acma-sekansi.md) | Booster: giriş→yırtılma→yelpaze→seçim→yanma |
| 2026-06-22 | [05 — Özel kart efektleri](2026-06-22-05-ozel-kart-efektleri.md) | Geliştirilmiş taş shimmer + renkli kıvılcım; joker zıplama |
| 2026-06-23 | [06 — Geçişler + menü arkaplanı](2026-06-23-06-gecisler-menu-arkaplan.md) | Kara delik/vakum geçişi, Balatro bg (charcoal+mat kırmızı), CRT z-index/BackBufferCopy, pack dissolve/tilt |
| 2026-06-23 | [07 — Sol panel + boss + dükkan](2026-06-23-07-sol-panel-boss-dukkan.md) | Balatro hedef kutusu + blind çipi, menü logo sheen/altyazısız, dükkanda sol panel SHOP + sürükle-bırak voucher |
| 2026-06-23 | [08 — Dükkan düzeni + geçiş + geri sayım](2026-06-23-08-dukkan-gecis-gerisayim.md) | Kupon paket yanında, "DÜKKAN" yüksek marquee; vortex yerine yumuşak dükkan geçişi; çip×çarpan geri sayarak sıfırlanır; (perf incelemesi ertelendi) |
| 2026-06-23 | [09 — İlk-giriş öğreticisi + King](2026-06-23-09-ogretici-king.md) | Etkileşimli öğretici (bağlamsal balon + spotlight cutout, dükkan turu, sıra düzeltildi); king.png yuvarlatıldı |

## Referanslar
- [jokerler-referans.md](jokerler-referans.md) — 62 jokerin tam etkisi + kart tasarımı için sınıflandırma

## Yol haritası / yapılacaklar
- [YAPILACAKLAR.md](YAPILACAKLAR.md) — sıradaki istekler (alev shader, blind ekranı, paket açma, özel kart efektleri)

## Nasıl test edilir (DMG almadan)
```bash
# 1) Mantık bozulmadı mı? (106 test, ~3 sn)
godot --headless --path /Users/trexoinnovation/wordeck --script res://tests/engine_test.gd

# 2) His testi — oyunu pencerede aç
godot --path /Users/trexoinnovation/wordeck
```
