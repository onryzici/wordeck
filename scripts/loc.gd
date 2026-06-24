extends RefCounted
# Lokalizasyon — kaynak Türkçe metni ANAHTAR alır; dil "en" ise İngilizce karşılığını döndürür,
# haritada yoksa Türkçe'yi AYNEN döndürür (güvenli fallback). Etiket/buton fabrikaları bu
# fonksiyondan geçer → statik metinler otomatik çevrilir. Joker ad/açıklamaları Faz 3'te.

const Settings = preload("res://scripts/settings.gd")
const Data = preload("res://scripts/loc_data.gd")  # Faz 3: joker/boss/voucher/enhancement

const EN := {
	# ── Ana menü ──
	"OYNA": "PLAY",
	"AYARLAR": "SETTINGS",
	"KOLEKSİYON": "COLLECTION",
	"REKORLAR": "RECORDS",
	"NASIL OYNANIR": "HOW TO PLAY",
	"ÇIKIŞ": "QUIT",
	"KAPAT": "CLOSE",
	"v0.1 · erken erişim": "v0.1 · early access",
	"müzik: alexrockbeat · yazı tipi: m6x11 / Daniel Linssen": "music: alexrockbeat · font: m6x11 / Daniel Linssen",
	# ── Ayarlar ──
	"Müzik Sesi": "Music Volume",
	"Efekt Sesi": "SFX Volume",
	"Ekran Sarsıntısı": "Screen Shake",
	"Partiküller": "Particles",
	"Tam Ekran": "Fullscreen",
	"AÇIK": "ON",
	"KAPALI": "OFF",
	# ── Rekorlar ──
	"🏆 REKORLAR": "🏆 RECORDS",
	"Henüz rekor yok.\nBir run tamamla, burada belirsin!": "No records yet.\nFinish a run to see them here!",
	"En İyi El": "Best Hand",
	"En İleri Bölüm": "Furthest Ante",
	"Galibiyet": "Wins",
	"Oynanan Run": "Runs Played",
	# ── Koleksiyon / nadirlik ──
	"SIRADAN": "COMMON",
	"SIRA DIŞI": "UNCOMMON",
	"NADİR": "RARE",
	"EFSANEVİ": "LEGENDARY",
	"Sıradan": "Common",
	"Sıra Dışı": "Uncommon",
	"Nadir": "Rare",
	"Efsanevi": "Legendary",
	# ── HUD / sol panel ──
	"HEDEF": "TARGET",
	"TUR SKORU": "ROUND SCORE",
	"PATRON": "BOSS",
	"TUR 1": "ROUND 1",
	"TUR 2": "ROUND 2",
	"HAK": "PLAYS",
	"DEĞİŞİM": "DISCARDS",
	"PARA": "MONEY",
	"TUR": "ROUND",
	"BÖLÜM": "ANTE",
	"BİLGİ": "INFO",
	"MENÜ": "MENU",
	"DÜKKAN": "SHOP",
	"DEĞİŞTİR": "DISCARD",
	"Harfleri karıştır": "Shuffle letters",
	# ── Çip / Çarpan ──
	"ÇİP": "CHIPS",
	"ÇARPAN": "MULT",
	"ÇARPAN/ÇİP": "MULT/CHIPS",
	"Çip": "Chips",
	"Çarpan": "Mult",
	"çip": "chips",
	"çarpan": "mult",
	# ── Puanlama / kutlama ──
	"TUR GEÇİLDİ!": "ROUND CLEARED!",
	"TUR GEÇİLDİ": "ROUND CLEARED",
	"GÜZEL!": "NICE!",
	"SÜPER!": "GREAT!",
	"MUHTEŞEM!": "AMAZING!",
	"İNANILMAZ!": "INCREDIBLE!",
	# ── Dükkan / cash-out ──
	"SONRAKİ TUR": "NEXT ROUND",
	"DÜKKANA GİT": "GO TO SHOP",
	"FAİZ  (her $5 → $1)": "INTEREST  (per $5 → $1)",
	"Run'ını geliştir!": "Upgrade your run!",
	"(jokerler tükendi)": "(jokers sold out)",
	"HARF\nPAKETİ": "LETTER\nPACK",
	"CİLA\nPAKETİ": "POLISH\nPACK",
	"Bir harfine kalıcı geliştirme": "Permanent upgrade to a letter",
	"HARF\nSEÇ →": "PICK\nLETTER →",
	"CİLA\nSEÇ →": "PICK\nPOLISH →",
	"SEÇ": "SELECT",
	"SONRAKİ\nTUR  →": "NEXT\nROUND  →",
	# ── Blind seçim ──
	"SIRADAKİ TURU SEÇ": "CHOOSE NEXT BLIND",
	"GEÇİLDİ": "DEFEATED",
	"🏷  ATLA": "🏷  SKIP",
	"EN AZ": "AT LEAST",
	"— veya —": "— or —",
	"SIRADA": "UP NEXT",
	# ── Kazan / kaybet + istatistik ──
	"KAZANDIN!": "YOU WIN!",
	"Tüm bölümleri geçtin.": "You cleared every ante.",
	"OYUN BİTTİ": "GAME OVER",
	"Yenilen": "Defeated By",
	"Oynanan Kelime": "Words Played",
	"Atılan Harf": "Letters Discarded",
	"Satın Alınan": "Purchases",
	"Reroll": "Rerolls",
	"Tur": "Round",
	"Kalan Para": "Money Left",
	"Toplam Joker": "Total Jokers",
	"★ YENİ REKOR ★": "★ NEW RECORD ★",
	"TEKRAR DENE": "RETRY",
	"ANA MENÜ": "MAIN MENU",
	# ── Duraklat (oyun-içi MENÜ tuşu) ──
	"DURAKLATILDI": "PAUSED",
	"Run devam ediyor.": "Your run continues.",
	"DEVAM ET": "RESUME",
	"ANA MENÜ (run'ı bırak)": "MAIN MENU (quit run)",
	# ── Uzun metinler ──
	"Elindeki harf taşlarından geçerli bir TÜRKÇE kelime kur, OYNA'ya bas.\n\nSkor = ÇİP × ÇARPAN. Uzun kelimeler ve jokerler skoru patlatır.\n\nHer turun bir HEDEF puanı var; tutturursan geçersin. Sınırlı kelime HAKKIN ve harf DEĞİŞİM hakkın var — değiştirmek hak harcamaz.\n\nKullanmadığın harfler elinde kalır; deste 8'e tamamlanır. Asıl strateji: şimdi mi oynasam, yoksa harf tutup daha büyük kombo mu kursam?":
		"Build a valid word from your letter tiles and press PLAY.\n\nScore = CHIPS × MULT. Longer words and jokers blow up your score.\n\nEach round has a TARGET; beat it to pass. Your word PLAYS and DISCARDS are limited — discarding costs no play.\n\nUnused letters stay in your hand; the deck refills to 8. The real strategy: play now, or hold letters for a bigger combo?",
	"Harf taşlarından geçerli TÜRKÇE kelime kur → OYNA.\nSkor = ÇİP × ÇARPAN. Uzun kelime + jokerler skoru patlatır.\nHer turun HEDEF puanı var. Kelime HAKKIN + DEĞİŞİM hakkın sınırlı (değişim hak harcamaz).\nKullanılmayan harfler elde kalır. Patron turlarında özel kısıtlama olur.":
		"Build a valid word from your letter tiles → PLAY.\nScore = CHIPS × MULT. Longer words + jokers blow up your score.\nEach round has a TARGET. Your word PLAYS + DISCARDS are limited (discarding costs no play).\nUnused letters stay in hand. Boss rounds add a special restriction.",
	# ── Formatlı / dinamik metinler (format dizisi anahtar; %d/%s korunur) ──
	"%d JOKER": "%d JOKERS",
	"JOKERLER %d/%d — tıkla → SAT": "JOKERS %d/%d — click → SELL",
	"Ödül: ": "Reward: ",
	"Ödül: $": "Reward: $",
	"Ödül:  %s": "Reward:  %s",
	"YENİLE\n$%d": "REROLL\n$%d",
	"%s\nNEREYE? →": "%s\nWHERE? →",
	"%d'TEN 1 SEÇ": "PICK 1 OF %d",
	"“%s” (deste: ×%d) — %s ekle": "“%s” (deck: ×%d) — add %s",
	"TOPLA:  $%d": "TOTAL:  $%d",
	"TOPLA:  $0": "TOTAL:  $0",
	"Tur geçildi!   +$%d   (taban %d · hak %d · faiz %d)": "Round cleared!   +$%d   (base %d · plays %d · interest %d)",
	# ── Tutorial butonları ──
	"İLERİ →": "NEXT →",
	"BAŞLA!": "START!",
	"ATLA": "SKIP",
	# ── Tutorial balonları ──
	"ÇİP × ÇARPAN = kazandığın PUAN!\nSol üstte TUR SKORU yükseldi.": "CHIPS × MULT = your SCORE!\nTop-left ROUND SCORE went up.",
	"İşine yaramayan harfleri DEĞİŞTİR ile\natıp yenilerini çekebilirsin (hakkın sınırlı).": "Use DISCARD to dump letters you don't\nneed and draw new ones (limited uses).",
	"Hedef PUANA ulaşana dek kelime\noynamaya devam et. Hedefi aşınca\nTUR GEÇİLİR ve DÜKKAN açılır! 👇": "Keep playing words until you reach\nthe TARGET. Beat it and the round is\nCLEARED — the SHOP opens! 👇",
	"İşte DÜKKAN! 👑\nKazandığın parayla güçlenirsin.\nJOKER al — her kelimede otomatik\nbonus verir, puanını KATLAR.": "This is the SHOP! 👑\nSpend your money to get stronger.\nBuy a JOKER — it auto-bonuses every\nword and MULTIPLIES your score.",
	"Paketlerden yeni HARF / CİLA çek.\nVitrin kötüyse YENİLE ile değiştir.": "Open packs for new LETTERS / POLISH.\nBad shelf? REROLL to refresh it.",
	"Hazır olunca SONRAKİ TUR ile\ndevam et. İyi oyunlar! 👑": "When ready, hit NEXT ROUND to\ncontinue. Have fun! 👑",
}

static func t(s: String) -> String:
	if Settings.language == "en":
		if EN.has(s):
			return EN[s]
		return Data.EN_DATA.get(s, s)
	return s
