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

## Yol haritası / yapılacaklar
- [YAPILACAKLAR.md](YAPILACAKLAR.md) — sıradaki istekler (alev shader, blind ekranı, paket açma, özel kart efektleri)

## Nasıl test edilir (DMG almadan)
```bash
# 1) Mantık bozulmadı mı? (106 test, ~3 sn)
godot --headless --path /Users/trexoinnovation/wordeck --script res://tests/engine_test.gd

# 2) His testi — oyunu pencerede aç
godot --path /Users/trexoinnovation/wordeck
```
