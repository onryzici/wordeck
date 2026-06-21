# Wordeck

> **Türkçe kelime-roguelike** — *Kelimelik × Balatro*. Harflerden kelime kurarak skor
> avlarsın: **skor = çip × çarpan.** Sınırlı kelime hakkı + harf tutma + deste kurma ile
> her el bir bulmaca; **jokerlerle** her run yeni bir kombo motoru.

Godot 4.7 · yatay (landscape) · GL Compatibility (geniş cihaz uyumu).

---

## Nasıl çalıştırılır

1. [Godot 4.7](https://godotengine.org/) (stable) indir.
2. Bu depoyu klonla: `git clone <repo-url>`
3. Godot'u aç → **Import** → bu klasördeki `project.godot`'u seç → **Run** (F5).

İlk açılışta Godot içerikleri içe aktarır (`.godot/` önbelleği oluşur, depoya girmez).

### Komut satırından (opsiyonel)

```bash
# Oyunu pencerede aç (OpenGL)
godot --path . --rendering-driver opengl3 --resolution 1366x768

# Motor duman testleri (106 test)
godot --path . --headless --script res://tests/engine_test.gd

# Denge simülasyonu (gerçek motorla N run)
godot --path . --headless --script res://tests/sim_balance.gd -- 120
```

---

## Nasıl oynanır

- Harf taşlarına dokun → seçili harfler **ortaya** dizilir (sürükle-bırak ile sırala).
- Geçerli Türkçe kelimede **OYNA** yeşil yanar → bas, skoru çöz.
- **DEĞİŞTİR**: seçili harfleri desteye atıp yenisini çek (kelime hakkı harcamaz).
- **🔀**: eldeki harfleri karıştır.
- Her turun **hedef puanı** var. Tur geç → **dükkân** (joker/harf paketi/cila/kupon).
- Her bölümün sonunda **Patron** turu (özel kısıtlama). 8 bölümü geç → kazandın.

---

## Proje yapısı

```
engine/    saf oyun mantığı (DOM/UI yok, test edilebilir): skorlama, hook'lar,
           deste, dağıtıcı, sözlük, ekonomi, dükkân, round akışı
data/      içerik (VERİ): 62 joker, 12 patron, harf değerleri, blinds, kuponlar,
           geliştirmeler, config + kelimeler.txt (Türkçe sözlük)
scripts/   UI + juice (game.gd / main.gd / theme.gd / settings.gd …)
shaders/   keçe girdap arka plan, CRT, alev tacı
scenes/    Main.tscn
tests/     engine_test.gd (duman testi) · sim_balance.gd (denge)
assets/    fontlar (m6x11) · sesler · müzik
```

**Altın kural:** `engine/` ve `data/` arayüze (UI) dokunmaz — mantık testlerle korunur.
Yeni joker/patron eklemek = `data/` içine bir **veri nesnesi** (skorlamaya `if id==` yazılmaz).

---

## Krediler

- Yazı tipi: **m6x11 / m6x11plus** — Daniel Linssen.
- Tür: Kelimelik (kelime/puan) × Balatro (deckbuilder roguelike) esinli, özgün içerik.

🤖 Geliştirme: Claude Code ile.
