extends SceneTree
# İngilizce oynanabilirlik simülasyonu — yeni BAG_EN gerçekten kelime-kurulabilir eller veriyor mu?
# Çalıştır: tools/godot.exe --path . --headless --script res://tests/sim_english.gd

const LetterBag = preload("res://data/letter_bag.gd")
const LetterValues = preload("res://data/letter_values.gd")
const Deck = preload("res://engine/deck.gd")
const Dictionary_ = preload("res://engine/dictionary.gd")
const Dealer = preload("res://engine/dealer.gd")
const Rng = preload("res://engine/rng.gd")
const TurkishCase = preload("res://engine/turkish_case.gd")

const VOWELS := {"a": true, "e": true, "i": true, "o": true, "u": true}
const DEALER_CFG := {
	"maxAttempts": 24, "minWords": 6, "qualityCap": 12,
	"targetVowelRatio": 0.4, "vowelTolerance": 0.12, "vowelPenaltyWeight": 8,
}

func _init() -> void:
	# İngilizce moduna geç
	LetterBag.set_lang("en")
	LetterValues.set_lang("en")
	TurkishCase.set_lang("en")
	var n := Dictionary_.load_from_file("res://data/master.txt")
	print("Sözlük: %d kelime" % n)

	# Aday kelimeler (2..8 harf) — gerçek string + harf sayımı
	var cands := []
	for w in Dictionary_.get_word_set():
		var L: int = w.length()
		if L < 2 or L > 8:
			continue
		var counts := {}
		for ch in w:
			counts[ch] = counts.get(ch, 0) + 1
		cands.append({"w": w, "len": L, "counts": counts})
	print("Aday kelime (2-8 harf): %d" % cands.size())
	print("Torba: %d taş\n" % Deck.build_deck(LetterBag.bag()).size())

	var trials := 40
	var total_words := 0
	var total_vowels := 0
	var total_longest := 0
	var few := 0  # 3'ten az kelime kurulan el sayısı (kötü el)
	for t in trials:
		var deck := Deck.build_deck(LetterBag.bag())
		var pool := deck.duplicate()
		var hand := []
		var rng = Rng.make_rng("ensim-%d" % t)
		Dealer.deal_to_hand(hand, pool, 8, rng, DEALER_CFG, null)
		# el harf sayımı
		var hc := {}
		var vowels := 0
		var letters := ""
		for c in hand:
			var ch := String(c["char"]).to_lower()
			hc[ch] = hc.get(ch, 0) + 1
			if VOWELS.has(ch):
				vowels += 1
			letters += String(c["char"])
		# kurulabilir kelimeleri say + örnek topla
		var found := []
		for cand in cands:
			var ok := true
			for ch in cand["counts"]:
				if hc.get(ch, 0) < cand["counts"][ch]:
					ok = false
					break
			if ok:
				found.append(cand["w"])
		found.sort_custom(func(a, b): return a.length() > b.length())
		var examples := found.slice(0, 4)
		total_words += found.size()
		total_vowels += vowels
		total_longest += (found[0].length() if found.size() > 0 else 0)
		if found.size() < 3:
			few += 1
		if t < 14:
			print("El %2d: [%s]  ünlü=%d  kelime=%3d  örnek=%s" % [t, letters, vowels, found.size(), str(examples)])

	print("\n=== ÖZET (%d el) ===" % trials)
	print("Ort. kelime/el : %.1f" % (float(total_words) / trials))
	print("Ort. ünlü/el   : %.2f (8 taşta)" % (float(total_vowels) / trials))
	print("Ort. en uzun   : %.1f harf" % (float(total_longest) / trials))
	print("Kötü el (<3 kelime): %d / %d" % [few, trials])
	quit()
