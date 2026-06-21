extends RefCounted
# Jokerler — src/data/jokers.js portu (36 adet). Hepsi VERİ + efekt fonksiyonu.
# Hook'lar bu dosyadaki statik fonksiyonlara Callable ile bağlanır (data-driven;
# skorlamaya `if id==` YAZILMAZ). Soldan sağa işlenir.

const Self = preload("res://data/jokers.gd")
const LetterValues = preload("res://data/letter_values.gd")

const VOWELS := {"A": true, "E": true, "I": true, "İ": true, "O": true, "Ö": true, "U": true, "Ü": true}
const BACK_VOWELS := {"A": true, "I": true, "O": true, "U": true}    # kalın ünlüler
const FRONT_VOWELS := {"E": true, "İ": true, "Ö": true, "Ü": true}   # ince ünlüler

const RARITY_COLORS := {
	"common": "#5b8fb0", "uncommon": "#4aa3ff", "rare": "#ff5a4d", "legendary": "#ffcb45",
}

static func _is_vowel(ch: String) -> bool:
	return VOWELS.has(ch)

static func _char_counts(cards: Array) -> Dictionary:
	var c := {}
	for card in cards:
		c[card["char"]] = c.get(card["char"], 0) + 1
	return c

static func _sig(w: String) -> String:
	var chars := []
	for ch in w:
		chars.append(ch)
	chars.sort()
	return "".join(chars)

# ── Veri listesi ──
static func all() -> Array:
	return [
		{"id": "sesli-avcisi", "name": "Sesli Avcısı", "rarity": "common", "cost": 4, "icon": "🎯",
			"description": "Kelimedeki her sesli harf için +2 Çarpan.",
			"hooks": {"onWordScored": Self._sesli_avcisi}},
		{"id": "ikizler", "name": "İkizler", "rarity": "common", "cost": 4, "icon": "👯",
			"description": "Tekrar eden her harf çifti için +15 Çip.",
			"hooks": {"onWordScored": Self._ikizler}},
		{"id": "kose-tasi", "name": "Köşe Taşı", "rarity": "common", "cost": 4, "icon": "🧱",
			"description": "Kelimenin ilk ve son harfi aynıysa +30 Çip.",
			"hooks": {"onWordScored": Self._kose_tasi}},
		{"id": "cimri", "name": "Cimri", "rarity": "uncommon", "cost": 6, "icon": "🪙",
			"description": "3 harf ve altı kelimeler ×3 Çarpan.",
			"hooks": {"onWordScored": Self._cimri}},
		{"id": "mimar", "name": "Mimar", "rarity": "uncommon", "cost": 6, "icon": "📐",
			"description": "6+ harfli kelime: harf sayısı × 6 Çip.",
			"hooks": {"onWordScored": Self._mimar}},
		{"id": "turkce-belasi", "name": "Türkçe Belası", "rarity": "uncommon", "cost": 6, "icon": "🔥",
			"description": "8+ harfli kelime: +60 Çip ve +5 Çarpan.",
			"hooks": {"onWordScored": Self._turkce_belasi}},
		{"id": "zincir", "name": "Zincir", "rarity": "uncommon", "cost": 6, "icon": "⛓️",
			"description": "Bu turda her kelime bir öncekinden uzunsa +4 Çarpan.",
			"hooks": {"onWordScored": Self._zincir}},
		{"id": "kumarbaz", "name": "Kumarbaz", "rarity": "uncommon", "cost": 5, "icon": "🎲",
			"description": "Her kelimede %50 ihtimalle ×2 Çarpan.",
			"hooks": {"onWordScored": Self._kumarbaz}},
		{"id": "simbiyoz", "name": "Simbiyoz", "rarity": "rare", "cost": 8, "icon": "🌿",
			"description": "Her sesli için +3 Çip, her sessiz için +1 Çarpan.",
			"hooks": {"onWordScored": Self._simbiyoz}},
		{"id": "borsa", "name": "Borsa", "rarity": "uncommon", "cost": 6, "icon": "📈",
			"description": "Paran her 6 birim için +1 Çarpan.",
			"hooks": {"onWordScored": Self._borsa}},

		{"id": "palindrom-tanrisi", "name": "Palindrom Tanrısı", "rarity": "legendary", "cost": 9, "icon": "🪞",
			"description": "Palindrom kelime (tersten aynı): ×10 Çarpan!",
			"hooks": {"onWordScored": Self._palindrom}},
		{"id": "harf-simyacisi", "name": "Harf Simyacısı", "rarity": "rare", "cost": 7, "icon": "⚗️",
			"description": "Oynadığın her 'A' bu jokeri KALICI +1 Çarpan büyütür (tavan +25).",
			"hooks": {"onWordScored": Self._harf_simyacisi}},
		{"id": "anagram-seytani", "name": "Anagram Şeytanı", "rarity": "rare", "cost": 7, "icon": "🔀",
			"description": "Bu turda daha önce oynadığın bir kelimenin anagramını oynarsan ×3 Çarpan.",
			"hooks": {"onWordScored": Self._anagram}},
		{"id": "sonsuz", "name": "Sonsuz", "rarity": "legendary", "cost": 9, "icon": "♾️",
			"description": "Tur skoru 1000'i geçtiyse kalan kelimelerde ×2 Çarpan.",
			"hooks": {"onWordScored": Self._sonsuz}},
		{"id": "intikam", "name": "İntikam", "rarity": "common", "cost": 4, "icon": "⚔️",
			"description": "Attığın her harf, SIRADAKİ kelimene +5 Çip ekler.",
			"hooks": {"onDiscard": Self._intikam_discard, "onWordScored": Self._intikam_word}},
		{"id": "cig", "name": "Çığ", "rarity": "uncommon", "cost": 6, "icon": "❄️",
			"description": "Geçtiğin her tur için kalıcı +1 Çarpan (oyun boyunca büyür).",
			"hooks": {"onWordScored": Self._cig}},

		{"id": "yanki", "name": "Yankı", "rarity": "rare", "cost": 7, "icon": "🔁",
			"description": "Kelimenin ilk harfinin çip değeri bir kez daha sayılır.",
			"hooks": {"onWordScored": Self._yanki}},
		{"id": "altin-kalem", "name": "Altın Kalem", "rarity": "uncommon", "cost": 6, "icon": "🖋️",
			"description": "Her oynanan kelime +2 Para kazandırır.",
			"hooks": {"onWordScored": Self._altin_kalem}},
		{"id": "kutuphaneci", "name": "Kütüphaneci", "rarity": "uncommon", "cost": 6, "icon": "📚",
			"description": "Kelimedeki her BENZERSIZ harf için +4 Çip.",
			"hooks": {"onWordScored": Self._kutuphaneci}},
		{"id": "sozluk-kurdu", "name": "Sözlük Kurdu", "rarity": "rare", "cost": 7, "icon": "🐛",
			"description": "Bu turda oynadığın her kelime için +2 Çarpan (tur başında sıfırlanır).",
			"hooks": {"onWordScored": Self._sozluk_kurdu}},
		{"id": "heceleyici", "name": "Heceleyici", "rarity": "common", "cost": 4, "icon": "✏️",
			"description": "5+ harfli kelime: +18 Çip.",
			"hooks": {"onWordScored": Self._heceleyici}},
		{"id": "tilsim", "name": "Tılsım", "rarity": "rare", "cost": 7, "icon": "🔮",
			"description": "Kelimede nadir harf (J, Ğ, F, V, Ö) varsa +5 Çarpan.",
			"hooks": {"onWordScored": Self._tilsim}},
		{"id": "ahenk", "name": "Ahenk", "rarity": "rare", "cost": 7, "icon": "🎵",
			"description": "Sesli–sessiz tam dönüşümlü dizilen kelime: ×2 Çarpan.",
			"hooks": {"onWordScored": Self._ahenk}},
		{"id": "sayac", "name": "Sayaç", "rarity": "uncommon", "cost": 6, "icon": "🧮",
			"description": "Oynadığın her kelime bu jokeri KALICI +3 Çip büyütür (tavan +150).",
			"hooks": {"onWordScored": Self._sayac}},

		{"id": "tutumlu", "name": "Tutumlu", "rarity": "common", "cost": 4, "icon": "🏷️",
			"description": "Kalan her DEĞİŞİM hakkı için +12 Çip.",
			"hooks": {"onWordScored": Self._tutumlu}},
		{"id": "cikmaz", "name": "Çıkmaz", "rarity": "common", "cost": 4, "icon": "🧗",
			"description": "Değişim hakkın hiç kalmadıysa +12 Çarpan.",
			"hooks": {"onWordScored": Self._cikmaz}},
		{"id": "murekkep", "name": "Mürekkep", "rarity": "common", "cost": 5, "icon": "🫐",
			"description": "Destede kalan her harf için +1 Çip.",
			"hooks": {"onWordScored": Self._murekkep}},
		{"id": "telgraf", "name": "Telgraf", "rarity": "common", "cost": 5, "icon": "📡",
			"description": "Oynanan her 'A' ve 'E' için +5 Çip ve +1 Çarpan.",
			"hooks": {"onWordScored": Self._telgraf}},
		{"id": "dortgen", "name": "Dörtgen", "rarity": "common", "cost": 4, "icon": "⬛",
			"description": "Tam 4 harfli kelime: +30 Çip.",
			"hooks": {"onWordScored": Self._dortgen}},
		{"id": "madenci", "name": "Madenci", "rarity": "uncommon", "cost": 6, "icon": "⛏️",
			"description": "Çip değeri 5+ olan her harf için +15 Çip (G H P F Ö V Ğ J).",
			"hooks": {"onWordScored": Self._madenci}},
		{"id": "ikili", "name": "İkili", "rarity": "uncommon", "cost": 6, "icon": "🎭",
			"description": "Kelimede aynı harften en az 2 tane varsa ×2 Çarpan.",
			"hooks": {"onWordScored": Self._ikili}},
		{"id": "denge", "name": "Denge", "rarity": "uncommon", "cost": 6, "icon": "⚖️",
			"description": "Kelimede en az 3 sesli VE en az 3 sessiz varsa ×2 Çarpan.",
			"hooks": {"onWordScored": Self._denge}},
		{"id": "topluluk", "name": "Topluluk", "rarity": "uncommon", "cost": 6, "icon": "👥",
			"description": "Sahip olduğun her joker için +2 Çarpan.",
			"hooks": {"onWordScored": Self._topluluk}},
		{"id": "patlamis-misir", "name": "Patlamış Mısır", "rarity": "uncommon", "cost": 5, "icon": "🍿",
			"description": "+20 Çarpan, ama geçtiğin her tur −4 (0'da tükenir).",
			"hooks": {"onWordScored": Self._patlamis_misir}},
		{"id": "murekkep-lekesi", "name": "Mürekkep Lekesi", "rarity": "common", "cost": 4, "icon": "🎰",
			"description": "Her kelimede +0 ila +20 arası rastgele Çarpan.",
			"hooks": {"onWordScored": Self._murekkep_lekesi}},
		{"id": "geri-donusum", "name": "Geri Dönüşüm", "rarity": "uncommon", "cost": 6, "icon": "♻️",
			"description": "Değiştirdiğin (attığın) her harf +1 Para kazandırır.",
			"hooks": {"onDiscard": Self._geri_donusum}},
			{"id": "katip", "name": "Kâtip", "rarity": "common", "cost": 4, "icon": "✒️",
				"description": "Kelimenin İLK harfinin çip değeri 3 katı sayılır.",
				"hooks": {"onWordScored": Self._katip}},
			{"id": "sesli-tuccari", "name": "Sesli Tüccarı", "rarity": "common", "cost": 4, "icon": "🍇",
				"description": "Kelimedeki her sesli harf için +6 Çip.",
				"hooks": {"onWordScored": Self._sesli_tuccari}},
			{"id": "hattat", "name": "Hattat", "rarity": "uncommon", "cost": 5, "icon": "🖌️",
				"description": "Kelimedeki her sessiz harf için +4 Çip.",
				"hooks": {"onWordScored": Self._hattat}},
			{"id": "cifte-sessiz", "name": "Çifte Sessiz", "rarity": "uncommon", "cost": 6, "icon": "🔨",
				"description": "Yan yana her sessiz harf çifti için +12 Çip.",
				"hooks": {"onWordScored": Self._cifte_sessiz}},
			{"id": "sesli-kumesi", "name": "Sesli Kümesi", "rarity": "common", "cost": 5, "icon": "💧",
				"description": "Yan yana her sesli harf çifti için +10 Çip.",
				"hooks": {"onWordScored": Self._sesli_kumesi}},
			{"id": "uzun-soluk", "name": "Uzun Soluk", "rarity": "uncommon", "cost": 6, "icon": "🫁",
				"description": "7+ harfli kelime: ×2 Çarpan.",
				"hooks": {"onWordScored": Self._uzun_soluk}},
			{"id": "kisa-oz", "name": "Kısa ve Öz", "rarity": "common", "cost": 4, "icon": "🤏",
				"description": "2–3 harfli kelime: +40 Çip.",
				"hooks": {"onWordScored": Self._kisa_oz}},
			{"id": "noktalama", "name": "Noktalama", "rarity": "common", "cost": 4, "icon": "❗",
				"description": "Kelimenin SON harfinin çip değeri 2 katı sayılır.",
				"hooks": {"onWordScored": Self._noktalama}},
			{"id": "esssiz", "name": "Eşsiz", "rarity": "rare", "cost": 7, "icon": "🦄",
				"description": "6+ harf ve tüm harfler farklıysa ×2 Çarpan.",
				"hooks": {"onWordScored": Self._esssiz}},
			{"id": "cevher", "name": "Cevher", "rarity": "uncommon", "cost": 6, "icon": "💎",
				"description": "En yüksek çipli harfin değeri bir kez daha eklenir.",
				"hooks": {"onWordScored": Self._cevher}},
			{"id": "cifte-dikis", "name": "Çifte Dikiş", "rarity": "uncommon", "cost": 6, "icon": "🧵",
				"description": "Aynı harften 3 veya daha fazla varsa +60 Çip.",
				"hooks": {"onWordScored": Self._cifte_dikis}},
			{"id": "ilk-hamle", "name": "İlk Hamle", "rarity": "common", "cost": 5, "icon": "🚀",
				"description": "Turun İLK kelimesinde ×2 Çarpan.",
				"hooks": {"onWordScored": Self._ilk_hamle}},
			{"id": "banker", "name": "Banker", "rarity": "uncommon", "cost": 6, "icon": "🏦",
				"description": "Paran 20 veya üzeriyse +40 Çip.",
				"hooks": {"onWordScored": Self._banker}},
			{"id": "z-faktoru", "name": "Z Faktörü", "rarity": "common", "cost": 5, "icon": "⚡",
				"description": "Kelimede C, Ç, Ş veya Z varsa +25 Çip.",
				"hooks": {"onWordScored": Self._z_faktoru}},
			{"id": "sozluk-faresi", "name": "Sözlük Faresi", "rarity": "uncommon", "cost": 6, "icon": "🐀",
				"description": "5 veya daha fazla farklı harf varsa +5 Çarpan.",
				"hooks": {"onWordScored": Self._sozluk_faresi}},
			{"id": "denge-bekcisi", "name": "Denge Bekçisi", "rarity": "rare", "cost": 7, "icon": "☯️",
				"description": "Sesli ve sessiz harf sayısı eşitse ×2 Çarpan.",
				"hooks": {"onWordScored": Self._denge_bekcisi}},
			{"id": "cirak", "name": "Çırak", "rarity": "common", "cost": 4, "icon": "🧒",
				"description": "+30 Çip, ama geçtiğin her tur −5 (0'da tükenir).",
				"hooks": {"onWordScored": Self._cirak}},
			{"id": "kronik", "name": "Kronik", "rarity": "uncommon", "cost": 6, "icon": "📜",
				"description": "Geçtiğin her tur için +8 Çip (oyun boyunca büyür).",
				"hooks": {"onWordScored": Self._kronik}},
			{"id": "tek-tip", "name": "Tek Tip", "rarity": "common", "cost": 4, "icon": "🔢",
				"description": "Harf sayısı tekse +20 Çip; çiftse +2 Çarpan.",
				"hooks": {"onWordScored": Self._tek_tip}},
			{"id": "sondaj", "name": "Sondaj", "rarity": "uncommon", "cost": 6, "icon": "🛢️",
				"description": "Çip değeri 7+ olan her harf için +25 Çip (F Ö V Ğ J).",
				"hooks": {"onWordScored": Self._sondaj}},
			{"id": "ritim", "name": "Ritim", "rarity": "common", "cost": 5, "icon": "🥁",
				"description": "Tam 5 harfli kelime: +28 Çip.",
				"hooks": {"onWordScored": Self._ritim}},
			{"id": "unlu-uyumu", "name": "Ünlü Uyumu", "rarity": "rare", "cost": 8, "icon": "🎼",
				"description": "Tüm sesliler ya kalın (A I O U) ya ince (E İ Ö Ü) ise ×2 Çarpan.",
				"hooks": {"onWordScored": Self._unlu_uyumu}},
			{"id": "caylak-kalem", "name": "Çaylak Kalem", "rarity": "common", "cost": 4, "icon": "📝",
				"description": "Her oynanan kelime +4 Çip ve +1 Para.",
				"hooks": {"onWordScored": Self._caylak_kalem}},
			{"id": "cift-kanat", "name": "Çift Kanat", "rarity": "common", "cost": 5, "icon": "🦋",
				"description": "Sesli ve sessiz sayısı farkı en çok 1 ise +20 Çip.",
				"hooks": {"onWordScored": Self._cift_kanat}},
			{"id": "mihenk", "name": "Mihenk", "rarity": "uncommon", "cost": 6, "icon": "⚱️",
				"description": "3 veya daha fazla FARKLI sesli türü varsa ×2 Çarpan.",
				"hooks": {"onWordScored": Self._mihenk}},
			{"id": "tasarruf", "name": "Tasarruf", "rarity": "uncommon", "cost": 6, "icon": "🐷",
				"description": "Hiç paran yoksa (0) +6 Çarpan.",
				"hooks": {"onWordScored": Self._tasarruf}},
	]

# ── Hook gövdeleri ──
static func _sesli_avcisi(ctx) -> void:
	var v := 0
	for c in ctx.cards:
		if _is_vowel(c["char"]):
			v += 1
	if v: ctx.add_mult(2 * v)

static func _ikizler(ctx) -> void:
	var cnt := _char_counts(ctx.cards)
	var pairs := 0
	for k in cnt:
		pairs += int(cnt[k] / 2)
	if pairs: ctx.add_chips(15 * pairs)

static func _kose_tasi(ctx) -> void:
	var a: Array = ctx.cards
	if a.size() >= 2 and a[0]["char"] == a[a.size() - 1]["char"]:
		ctx.add_chips(30)

static func _cimri(ctx) -> void:
	if ctx.cards.size() <= 3: ctx.x_mult(3)

static func _mimar(ctx) -> void:
	var n: int = ctx.cards.size()
	if n >= 6: ctx.add_chips(n * 6)

static func _turkce_belasi(ctx) -> void:
	if ctx.cards.size() >= 8:
		ctx.add_chips(60)
		ctx.add_mult(5)

static func _zincir(ctx) -> void:
	if ctx.state["round"]["wordsPlayed"].size() == 0: return
	if ctx.cards.size() > ctx.state["round"]["lastWordLength"]: ctx.add_mult(4)

static func _kumarbaz(ctx) -> void:
	if ctx.preview: return
	if ctx.state["run"]["rng"].next() < 0.5: ctx.x_mult(2)

static func _simbiyoz(ctx) -> void:
	var v := 0
	var c := 0
	for card in ctx.cards:
		if _is_vowel(card["char"]): v += 1
		else: c += 1
	if v: ctx.add_chips(3 * v)
	if c: ctx.add_mult(c)

static func _borsa(ctx) -> void:
	var m := int(ctx.state["run"]["money"] / 6.0)
	if m: ctx.add_mult(m)

static func _palindrom(ctx) -> void:
	var w: String = ctx.word
	if w.length() >= 2:
		var rev := ""
		for i in range(w.length() - 1, -1, -1):
			rev += w[i]
		if w == rev: ctx.x_mult(10)

static func _harf_simyacisi(ctx) -> void:
	var v: Dictionary = ctx.state["run"]["jokerVars"]
	var a_now := 0
	for c in ctx.cards:
		if c["char"] == "A": a_now += 1
	var base: int = v.get("harfSimyacisi", 0)
	if not ctx.preview:
		v["harfSimyacisi"] = min(25, base + a_now)
	var total: int = min(25, base + a_now)
	if total: ctx.add_mult(total)

static func _anagram(ctx) -> void:
	var cur := _sig(ctx.word)
	for w in ctx.state["round"]["wordsPlayed"]:
		if w != ctx.word and _sig(w) == cur:
			ctx.x_mult(3)
			return

static func _sonsuz(ctx) -> void:
	if ctx.state["round"]["score"] >= 1000: ctx.x_mult(2)

static func _intikam_discard(ctx) -> void:
	var v: Dictionary = ctx.state["run"]["jokerVars"]
	v["intikam"] = v.get("intikam", 0) + ctx.count

static func _intikam_word(ctx) -> void:
	var v: Dictionary = ctx.state["run"]["jokerVars"]
	var pending: int = v.get("intikam", 0)
	if pending: ctx.add_chips(5 * pending)
	if not ctx.preview: v["intikam"] = 0

static func _cig(ctx) -> void:
	var n: int = ctx.state["run"]["jokerVars"].get("blindsPassed", 0)
	if n: ctx.add_mult(n)

static func _yanki(ctx) -> void:
	if ctx.cards.size() >= 1: ctx.add_chips(LetterValues.chips(ctx.cards[0]["char"]))

static func _altin_kalem(ctx) -> void:
	if not ctx.preview: ctx.state["run"]["money"] += 2

static func _kutuphaneci(ctx) -> void:
	var seen := {}
	for c in ctx.cards: seen[c["char"]] = true
	var uniq := seen.size()
	if uniq: ctx.add_chips(4 * uniq)

static func _sozluk_kurdu(ctx) -> void:
	var n: int = ctx.state["round"]["wordsPlayed"].size()
	if n: ctx.add_mult(2 * n)

static func _heceleyici(ctx) -> void:
	if ctx.cards.size() >= 5: ctx.add_chips(18)

static func _tilsim(ctx) -> void:
	var rare := {"J": true, "Ğ": true, "F": true, "V": true, "Ö": true}
	for c in ctx.cards:
		if rare.has(c["char"]):
			ctx.add_mult(5)
			return

static func _ahenk(ctx) -> void:
	var a: Array = ctx.cards
	if a.size() < 3: return
	var alt := true
	for i in range(1, a.size()):
		if _is_vowel(a[i]["char"]) == _is_vowel(a[i - 1]["char"]):
			alt = false
			break
	if alt: ctx.x_mult(2)

static func _sayac(ctx) -> void:
	var v: Dictionary = ctx.state["run"]["jokerVars"]
	var cur: int = v.get("sayac", 0)
	if cur: ctx.add_chips(cur)
	if not ctx.preview: v["sayac"] = min(150, cur + 3)

static func _tutumlu(ctx) -> void:
	var d: int = ctx.state["round"].get("discardsLeft", 0)
	if d: ctx.add_chips(12 * d)

static func _cikmaz(ctx) -> void:
	if ctx.state["round"].get("discardsLeft", 0) == 0: ctx.add_mult(12)

static func _murekkep(ctx) -> void:
	var left: int = ctx.state["round"]["pool"].size()
	if left: ctx.add_chips(left)

static func _telgraf(ctx) -> void:
	var n := 0
	for c in ctx.cards:
		if c["char"] == "A" or c["char"] == "E": n += 1
	if n:
		ctx.add_chips(5 * n)
		ctx.add_mult(n)

static func _dortgen(ctx) -> void:
	if ctx.cards.size() == 4: ctx.add_chips(30)

static func _madenci(ctx) -> void:
	var n := 0
	for c in ctx.cards:
		if LetterValues.chips(c["char"]) >= 5: n += 1
	if n: ctx.add_chips(15 * n)

static func _ikili(ctx) -> void:
	var cnt := _char_counts(ctx.cards)
	for k in cnt:
		if cnt[k] >= 2:
			ctx.x_mult(2)
			return

static func _denge(ctx) -> void:
	var v := 0
	var c := 0
	for card in ctx.cards:
		if _is_vowel(card["char"]): v += 1
		else: c += 1
	if v >= 3 and c >= 3: ctx.x_mult(2)

static func _topluluk(ctx) -> void:
	var n: int = ctx.state["run"]["jokers"].size()
	if n: ctx.add_mult(2 * n)

static func _patlamis_misir(ctx) -> void:
	var passed: int = ctx.state["run"]["jokerVars"].get("blindsPassed", 0)
	var m: int = max(0, 20 - 4 * passed)
	if m: ctx.add_mult(m)

static func _murekkep_lekesi(ctx) -> void:
	if ctx.preview: return
	var r := int(ctx.state["run"]["rng"].next() * 21)
	if r: ctx.add_mult(r)

static func _geri_donusum(ctx) -> void:
	ctx.state["run"]["money"] += ctx.count

# ── 3. dalga hook gövdeleri ──
static func _katip(ctx) -> void:
	if ctx.cards.size() >= 1:
		ctx.add_chips(LetterValues.chips(ctx.cards[0]["char"]) * 2)  # değer 3 KAT (taban + 2 ekstra)

static func _sesli_tuccari(ctx) -> void:
	var n := 0
	for c in ctx.cards:
		if _is_vowel(c["char"]): n += 1
	if n: ctx.add_chips(6 * n)

static func _hattat(ctx) -> void:
	var n := 0
	for c in ctx.cards:
		if not _is_vowel(c["char"]): n += 1
	if n: ctx.add_chips(4 * n)

static func _cifte_sessiz(ctx) -> void:
	var a: Array = ctx.cards
	var pairs := 0
	for i in range(1, a.size()):
		if not _is_vowel(a[i]["char"]) and not _is_vowel(a[i - 1]["char"]): pairs += 1
	if pairs: ctx.add_chips(12 * pairs)

static func _sesli_kumesi(ctx) -> void:
	var a: Array = ctx.cards
	var pairs := 0
	for i in range(1, a.size()):
		if _is_vowel(a[i]["char"]) and _is_vowel(a[i - 1]["char"]): pairs += 1
	if pairs: ctx.add_chips(10 * pairs)

static func _uzun_soluk(ctx) -> void:
	if ctx.cards.size() >= 7: ctx.x_mult(2)

static func _kisa_oz(ctx) -> void:
	var n: int = ctx.cards.size()
	if n >= 2 and n <= 3: ctx.add_chips(40)

static func _noktalama(ctx) -> void:
	var a: Array = ctx.cards
	if a.size() >= 1: ctx.add_chips(LetterValues.chips(a[a.size() - 1]["char"]))  # son harf değeri 2 KAT

static func _esssiz(ctx) -> void:
	var a: Array = ctx.cards
	if a.size() < 6: return
	var seen := {}
	for c in a: seen[c["char"]] = true
	if seen.size() == a.size(): ctx.x_mult(2)

static func _cevher(ctx) -> void:
	var best := 0
	for c in ctx.cards:
		best = max(best, LetterValues.chips(c["char"]))
	if best: ctx.add_chips(best)

static func _cifte_dikis(ctx) -> void:
	var cnt := _char_counts(ctx.cards)
	for k in cnt:
		if cnt[k] >= 3:
			ctx.add_chips(60)
			return

static func _ilk_hamle(ctx) -> void:
	if ctx.state["round"]["wordsPlayed"].size() == 0: ctx.x_mult(2)

static func _banker(ctx) -> void:
	if ctx.state["run"]["money"] >= 20: ctx.add_chips(40)

static func _z_faktoru(ctx) -> void:
	var set := {"C": true, "Ç": true, "Ş": true, "Z": true}
	for c in ctx.cards:
		if set.has(c["char"]):
			ctx.add_chips(25)
			return

static func _sozluk_faresi(ctx) -> void:
	var seen := {}
	for c in ctx.cards: seen[c["char"]] = true
	if seen.size() >= 5: ctx.add_mult(5)

static func _denge_bekcisi(ctx) -> void:
	var v := 0
	var c := 0
	for card in ctx.cards:
		if _is_vowel(card["char"]): v += 1
		else: c += 1
	if v > 0 and v == c: ctx.x_mult(2)

static func _cirak(ctx) -> void:
	var passed: int = ctx.state["run"]["jokerVars"].get("blindsPassed", 0)
	var n: int = max(0, 30 - 5 * passed)
	if n: ctx.add_chips(n)

static func _kronik(ctx) -> void:
	var passed: int = ctx.state["run"]["jokerVars"].get("blindsPassed", 0)
	if passed: ctx.add_chips(8 * passed)

static func _tek_tip(ctx) -> void:
	var n: int = ctx.cards.size()
	if n % 2 == 1: ctx.add_chips(20)
	else: ctx.add_mult(2)

static func _sondaj(ctx) -> void:
	var n := 0
	for c in ctx.cards:
		if LetterValues.chips(c["char"]) >= 7: n += 1
	if n: ctx.add_chips(25 * n)

static func _ritim(ctx) -> void:
	if ctx.cards.size() == 5: ctx.add_chips(28)

static func _unlu_uyumu(ctx) -> void:
	var back := false
	var front := false
	for c in ctx.cards:
		if BACK_VOWELS.has(c["char"]): back = true
		elif FRONT_VOWELS.has(c["char"]): front = true
	if (back or front) and not (back and front): ctx.x_mult(2)  # sadece tek grup sesli

static func _caylak_kalem(ctx) -> void:
	ctx.add_chips(4)
	if not ctx.preview: ctx.state["run"]["money"] += 1

static func _cift_kanat(ctx) -> void:
	var v := 0
	var c := 0
	for card in ctx.cards:
		if _is_vowel(card["char"]): v += 1
		else: c += 1
	if absi(v - c) <= 1: ctx.add_chips(20)

static func _mihenk(ctx) -> void:
	var seen := {}
	for c in ctx.cards:
		if _is_vowel(c["char"]): seen[c["char"]] = true
	if seen.size() >= 3: ctx.x_mult(2)

static func _tasarruf(ctx) -> void:
	if ctx.state["run"]["money"] == 0: ctx.add_mult(6)

# id ile joker bul (taze kopya — paylaşılan referans sızıntısını önler).
static func by_id(id: String):
	for j in all():
		if j["id"] == id:
			return j
	return null
