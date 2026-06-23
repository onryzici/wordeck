# Joker Referansı — Kart Tasarımı İçin

Kaynak: `data/jokers.gd` (62 joker). Açıklamalar koddaki **gerçek efektten** çıkarıldı —
oyun-içi kısa açıklamayla küçük farklar olabilir (aşağıda "kod notu" ile belirtildi).

**Skorlama:** Jokerler **soldan sağa** işlenir. `+Çip` toplanır, `+Çarpan` toplanır,
`×Çarpan` çarpılır (çarpımlar toplama sonrası uygulanır). Çoğu joker `onWordScored`
(kelime skorlanınca) tetiklenir; bazıları `onDiscard` (harf atınca).

## Tasarım için hızlı sınıflandırma

Kart tasarımında bunlar özel muamele isteyebilir:

- **Kalıcı büyüyen (kartta sayaç göster):** Harf Simyacısı, Sayaç, Çığ, Kronik
- **Eriyen / azalan (kartta kalan değer):** Patlamış Mısır, Çırak
- **Rastgele (şans göstergesi):** Kumarbaz, Mürekkep Lekesi
- **Ekonomi / para (altın vurgu):** Altın Kalem, Geri Dönüşüm, Çaylak Kalem, Borsa, Banker, Tasarruf
- **Atma (discard) tetikli:** İntikam, Geri Dönüşüm
- **Tur durumuna bağlı (tur boyu hafıza):** Zincir, Sözlük Kurdu, İlk Hamle, Anagram Şeytanı, Sonsuz
- **×Çarpan "patlaması" (büyük anlar):** Palindrom Tanrısı (×10), Sonsuz, Anagram Şeytanı, Cimri, ve diğer ×2'ler

Nadirlik renkleri (`RARITY_COLORS`): common `#5b8fb0` · uncommon `#4aa3ff` · rare `#ff5a4d` · legendary `#ffcb45`

---

## LEGENDARY (2)

| İkon | İsim | Maliyet | Etki |
|---|---|---|---|
| 🪞 | **Palindrom Tanrısı** | $9 | Kelime palindromsa (tersten aynı, 2+ harf) **×10 Çarpan**. |
| ♾️ | **Sonsuz** | $9 | Tur skoru **1000'i geçtiyse** kalan kelimelerde **×2 Çarpan**. |

---

## RARE (10)

| İkon | İsim | Maliyet | Etki |
|---|---|---|---|
| 🌿 | **Simbiyoz** | $8 | Her sesli için **+3 Çip**, her sessiz için **+1 Çarpan**. |
| ⚗️ | **Harf Simyacısı** | $7 | Oynadığın her **'A'** bu jokeri **kalıcı +1 Çarpan** büyütür (tavan **+25**). Her kelimede mevcut birikimi +Çarpan olarak verir. |
| 🔀 | **Anagram Şeytanı** | $7 | Bu turda daha önce oynadığın bir kelimenin **anagramını** oynarsan **×3 Çarpan**. |
| 🔁 | **Yankı** | $7 | Kelimenin **ilk harfinin** çip değeri **bir kez daha** sayılır. |
| 🐛 | **Sözlük Kurdu** | $7 | Bu turda oynanan her kelime için **+2 Çarpan** (tur başında sıfırlanır; o ana kadarki kelime sayısına göre). |
| 🔮 | **Tılsım** | $7 | Kelimede **nadir harf (J, Ğ, F, V, Ö)** varsa **+5 Çarpan**. |
| 🎵 | **Ahenk** | $7 | Sesli–sessiz **tam dönüşümlü** dizilen kelime (3+ harf): **×2 Çarpan**. |
| 🦄 | **Eşsiz** | $7 | **6+ harf** ve tüm harfler **farklı** ise **×2 Çarpan**. |
| ☯️ | **Denge Bekçisi** | $7 | Sesli ve sessiz harf sayısı **eşitse** (>0) **×2 Çarpan**. |
| 🎼 | **Ünlü Uyumu** | $8 | Tüm sesliler ya **kalın (A I O U)** ya **ince (E İ Ö Ü)** ise **×2 Çarpan**. |

---

## UNCOMMON (27)

| İkon | İsim | Maliyet | Etki |
|---|---|---|---|
| 🪙 | **Cimri** | $6 | **3 harf ve altı** kelimeler **×3 Çarpan**. |
| 📐 | **Mimar** | $6 | **6+ harfli** kelime: harf sayısı **× 6 Çip**. |
| 🔥 | **Türkçe Belası** | $6 | **8+ harfli** kelime: **+60 Çip ve +5 Çarpan**. |
| ⛓️ | **Zincir** | $6 | Bu turda kelime bir öncekinden **uzunsa** **+4 Çarpan** (turun ilk kelimesinde tetiklenmez). |
| 🎲 | **Kumarbaz** | $5 | Her kelimede **%50 ihtimalle ×2 Çarpan**. (önizlemede tetiklenmez) |
| 📈 | **Borsa** | $6 | **Paran** her **6 birim** için **+1 Çarpan**. |
| ❄️ | **Çığ** | $6 | Geçtiğin her tur için **kalıcı +1 Çarpan** (oyun boyunca büyür). |
| 🖋️ | **Altın Kalem** | $6 | Her oynanan kelime **+2 Para** kazandırır. |
| 📚 | **Kütüphaneci** | $6 | Kelimedeki her **benzersiz** harf için **+4 Çip**. |
| 🧮 | **Sayaç** | $6 | Oynadığın her kelime bu jokeri **kalıcı +3 Çip** büyütür (tavan **+150**). |
| ⛏️ | **Madenci** | $6 | Çip değeri **5+** olan her harf için **+15 Çip** (G H P F Ö V Ğ J). |
| 🎭 | **İkili** | $6 | Kelimede aynı harften **en az 2** varsa **×2 Çarpan**. |
| ⚖️ | **Denge** | $6 | **En az 3 sesli VE en az 3 sessiz** varsa **×2 Çarpan**. |
| 👥 | **Topluluk** | $6 | Sahip olduğun **her joker** için **+2 Çarpan**. |
| 🍿 | **Patlamış Mısır** | $5 | **+20 Çarpan**, ama geçtiğin her tur **−4** (0'da tükenir). |
| ♻️ | **Geri Dönüşüm** | $6 | **Attığın (değiştirdiğin) her harf +1 Para** (`onDiscard`). |
| 🖌️ | **Hattat** | $5 | Kelimedeki her **sessiz** harf için **+4 Çip**. |
| 🔨 | **Çifte Sessiz** | $6 | **Yan yana** her sessiz harf çifti için **+12 Çip**. |
| 🫁 | **Uzun Soluk** | $6 | **7+ harfli** kelime: **×2 Çarpan**. |
| 💎 | **Cevher** | $6 | **En yüksek çipli** harfin değeri **bir kez daha** eklenir. |
| 🧵 | **Çifte Dikiş** | $6 | Aynı harften **3 veya daha fazla** varsa **+60 Çip**. |
| 🏦 | **Banker** | $6 | **Paran 20+** ise **+40 Çip**. |
| 🐀 | **Sözlük Faresi** | $6 | **5+ farklı** harf varsa **+5 Çarpan**. |
| 📜 | **Kronik** | $6 | Geçtiğin her tur için **+8 Çip** (oyun boyunca büyür). |
| 🛢️ | **Sondaj** | $6 | Çip değeri **7+** olan her harf için **+25 Çip** (F Ö V Ğ J). |
| ⚱️ | **Mihenk** | $6 | **3+ farklı sesli türü** varsa **×2 Çarpan**. |
| 🐷 | **Tasarruf** | $6 | **Hiç paran yoksa (0)** **+6 Çarpan**. |

---

## COMMON (23)

| İkon | İsim | Maliyet | Etki |
|---|---|---|---|
| 🎯 | **Sesli Avcısı** | $4 | Her **sesli** harf için **+2 Çarpan**. |
| 👯 | **İkizler** | $4 | Tekrar eden her **harf çifti** için **+15 Çip**. |
| 🧱 | **Köşe Taşı** | $4 | İlk ve son harf **aynıysa** **+30 Çip**. |
| ⚔️ | **İntikam** | $4 | Attığın her harf, **sıradaki** kelimene **+5 Çip** ekler (`onDiscard`+`onWordScored`; kelime sonrası birikim sıfırlanır). |
| ✏️ | **Heceleyici** | $4 | **5+ harfli** kelime: **+18 Çip**. |
| 🏷️ | **Tutumlu** | $4 | Kalan her **değişim hakkı** için **+12 Çip**. |
| 🧗 | **Çıkmaz** | $4 | Değişim hakkın **hiç kalmadıysa** **+12 Çarpan**. |
| 🫐 | **Mürekkep** | $5 | Destede **kalan her harf** için **+1 Çip**. |
| 📡 | **Telgraf** | $5 | Her **'A' ve 'E'** için **+5 Çip ve +1 Çarpan**. |
| ⬛ | **Dörtgen** | $4 | **Tam 4 harfli** kelime: **+30 Çip**. |
| 🎰 | **Mürekkep Lekesi** | $4 | Her kelimede **+0 ila +20 arası rastgele Çarpan**. (önizlemede tetiklenmez) |
| ✒️ | **Kâtip** | $4 | İlk harfin çip değeri **3 kat** sayılır (taban + 2 ekstra). |
| 🍇 | **Sesli Tüccarı** | $4 | Her **sesli** harf için **+6 Çip**. |
| 💧 | **Sesli Kümesi** | $5 | **Yan yana** her sesli harf çifti için **+10 Çip**. |
| 🤏 | **Kısa ve Öz** | $4 | **2–3 harfli** kelime: **+40 Çip**. |
| ❗ | **Noktalama** | $4 | Son harfin çip değeri **2 kat** sayılır (taban + 1 ekstra). |
| 🚀 | **İlk Hamle** | $5 | Turun **ilk** kelimesinde **×2 Çarpan**. |
| ⚡ | **Z Faktörü** | $5 | Kelimede **C, Ç, Ş veya Z** varsa **+25 Çip**. |
| 🧒 | **Çırak** | $4 | **+30 Çip**, ama geçtiğin her tur **−5** (0'da tükenir). |
| 🔢 | **Tek Tip** | $4 | Harf sayısı **tekse +20 Çip**; **çiftse +2 Çarpan**. |
| 🥁 | **Ritim** | $5 | **Tam 5 harfli** kelime: **+28 Çip**. |
| 📝 | **Çaylak Kalem** | $4 | Her oynanan kelime **+4 Çip ve +1 Para**. |
| 🦋 | **Çift Kanat** | $5 | Sesli ve sessiz sayısı farkı **en çok 1** ise **+20 Çip**. |

---

## Notlar (kart tasarımında dikkat)

- **Önizleme (`preview`):** Kelime seçilirken canlı önizleme gösterilir. Para veren / RNG / kalıcı
  büyüyen jokerler önizlemede **kalıcı etki yapmaz** (Kumarbaz, Mürekkep Lekesi, Altın Kalem,
  Çaylak Kalem, Harf Simyacısı, Sayaç, İntikam vb.). Kart üstünde "şans/birikim" göstergesi
  düşünüyorsan bu ayrımı koru.
- **Kalıcı büyüyen jokerler** (Harf Simyacısı, Sayaç, Çığ, Kronik) ve **eriyenler** (Patlamış
  Mısır, Çırak) için kartta **anlık değer/sayaç** göstermek çok yardımcı olur (Balatro'daki gibi).
  Bu değerler `state.run.jokerVars` içinde tutulur (`blindsPassed`, `sayac`, `harfSimyacisi`,
  `intikam`).
- **Harf çip değerleri** `data/letter_values.gd` içinde. Madenci (≥5) ve Sondaj (≥7) bu değerlere
  bakar; kart tasarımında "değerli harf" temasıyla uyumlu olabilir.
- **Sesliler:** A E I İ O Ö U Ü. **Kalın:** A I O U · **İnce:** E İ Ö Ü (Ünlü Uyumu/Mihenk bunları kullanır).
