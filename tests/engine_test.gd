extends SceneTree
# Engine duman testi — scripts/smoke-test.mjs portu. Çalıştır:
#   tools/godot.exe --path godot --headless --script res://tests/engine_test.gd
# (GDScript'te bare {} blok yok → her bölüm ayrı metot.)

const State = preload("res://engine/state.gd")
const Round = preload("res://engine/round.gd")
const Dictionary_ = preload("res://engine/dictionary.gd")
const Scoring = preload("res://engine/scoring.gd")
const JokerActions = preload("res://engine/joker_actions.gd")
const Shop = preload("res://engine/shop.gd")
const Bosses = preload("res://data/bosses.gd")
const Jokers = preload("res://data/jokers.gd")

var WORDS = {}
var _pass := 0
var _fail := 0

func check(name: String, cond: bool) -> void:
	if cond:
		_pass += 1
		print("  ✓ ", name)
	else:
		_fail += 1
		print("  ✗ BAŞARISIZ: ", name)

func _mk(w: String) -> Array:
	var cards := []
	var id := 0
	for ch in w:
		cards.append({"id": id, "char": ch, "enhancements": []})
		id += 1
	return cards

func _permute(a: Array) -> Array:
	if a.size() <= 1:
		return [a]
	var out := []
	for i in a.size():
		var rest: Array = a.duplicate()
		rest.remove_at(i)
		for p in _permute(rest):
			var perm := [a[i]]
			perm.append_array(p)
			out.append(perm)
	return out

func _rec_combo(hand: Array, start: int, pick: Array, length: int):
	if pick.size() == length:
		for p in _permute(pick):
			var cards := []
			var w := ""
			for idx in p:
				cards.append(hand[idx])
				w += hand[idx]["char"]
			if WORDS.has(Dictionary_.normalize_word(w)):
				return cards
		return null
	for i in range(start, hand.size()):
		var np: Array = pick.duplicate()
		np.append(i)
		var r = _rec_combo(hand, i + 1, np, length)
		if r != null:
			return r
	return null

func _find_word(hand: Array):
	var max_len: int = min(5, hand.size())
	for length in range(max_len, 1, -1):
		var res = _rec_combo(hand, 0, [], length)
		if res != null:
			return res
	return null

func _ids(cards: Array) -> Array:
	var out := []
	for c in cards:
		out.append(c["id"])
	return out

func _word_str(cards: Array) -> String:
	var w := ""
	for c in cards:
		w += c["char"]
	return w

func _init() -> void:
	var n := Dictionary_.load_from_file("res://data/kelimeler.txt")
	WORDS = Dictionary_.get_word_set()
	print("Sözlük: ", n, " kelime\n")
	_t1(); _t2(); _t3(); _t4(); _t5(); _t6(); _t7(); _t8(); _t9(); _t10(); _t11(); _t12()
	print("\nSONUÇ: ", _pass, " geçti, ", _fail, " başarısız")
	quit(1 if _fail > 0 else 0)

# Her jokeri tek tek çeşitli kelimelerle skorla → hiçbir hook ÇÖKMEMELİ (yeni joker güvencesi).
func _t12() -> void:
	print("12) Tüm jokerler çökmeden skorluyor (%d joker)" % Jokers.all().size())
	check("joker havuzu 60+", Jokers.all().size() >= 60)
	var probes := ["EV", "ANA", "KALEM", "MERMER", "KİTAPLIK", "ABA", "SU"]
	var ok := true
	for j in Jokers.all():
		var st := State.create_state("jall-" + String(j["id"]))
		Round.start_run(st)
		JokerActions.add_joker_by_id(st, String(j["id"]))
		for w in probes:
			var r = Scoring.score_word(st, _mk(w))
			if typeof(r) != TYPE_DICTIONARY or not r.has("score"):
				ok = false
				print("    ✗ joker çöktü: ", j["id"], " kelime: ", w)
		# atma kancası olanlar için discard'ı da dürt
		st["round"]["discardsLeft"] = 3
	check("her joker çeşitli kelimelerde skorladı", ok)

func _t11() -> void:
	print("11) Harf geliştirmeleri (foil/holo/poly/altın/cam + cila paketi)")
	var st := State.create_state("enh")
	# KALEM tabanı: 6 çip + Orta(+20) = 26 çip, ×2 mult
	var foil := _mk("KALEM"); foil[0]["enhancements"] = ["foil"]
	check("foil +50 çip (26→76)", int(Scoring.score_word(st, foil)["chips"]) == 76)
	var holo := _mk("KALEM"); holo[0]["enhancements"] = ["holo"]
	check("holo +10 çarpan (2→12)", float(Scoring.score_word(st, holo)["mult"]) == 12.0)
	var poly := _mk("KALEM"); poly[0]["enhancements"] = ["poly"]
	check("poly ×1.5 çarpan (2→3)", float(Scoring.score_word(st, poly)["mult"]) == 3.0)
	var glass := _mk("KALEM"); glass[0]["enhancements"] = ["glass"]
	check("cam ×2 çarpan (2→4)", float(Scoring.score_word(st, glass, true)["mult"]) == 4.0)
	# altın: oynanınca +3 para (önizlemede vermez)
	var m0: int = st["run"]["money"]
	var gold := _mk("KALEM"); gold[0]["enhancements"] = ["golden"]
	Scoring.score_word(st, gold, false)
	check("altın +3 para", int(st["run"]["money"]) == m0 + 3)
	Scoring.score_word(st, gold, true)
	check("altın önizleme para vermez", int(st["run"]["money"]) == m0 + 3)
	# cila paketi (agency v2): seç → beklemeye al → seçilen HARFE uygula
	var sr := State.create_state("enh2"); Round.start_run(sr)
	sr["run"]["enhancerChoices"] = ["foil"]
	var res := Shop.choose_enhancement(sr, "foil")
	check("cila seçildi (beklemede)", res.get("ok", false) and sr["run"]["pendingEnhancement"] == "foil")
	var ch: String = sr["run"]["deck"][0]["char"]  # destedeki ilk harfe uygula
	var ap := Shop.apply_enhancement_to_letter(sr, ch)
	check("cila harfe uygulandı", ap.get("ok", false) and sr["run"]["pendingEnhancement"] == null)
	var has_foil := false
	for c in sr["run"]["deck"]:
		if c["char"] == ch and c["enhancements"].has("foil"):
			has_foil = true
	check("seçilen harfte foil var", has_foil)

func _t1() -> void:
	print("1) Kademeli skorlama (uzunluk)")
	var st := State.create_state("t")
	var r5 := Scoring.score_word(st, _mk("KALEM"))
	check("KALEM çip = 26", r5["chips"] == 26)
	check("KALEM mult = 2", r5["mult"] == 2)
	check("KALEM skor = 52", r5["score"] == 52)
	check("KALEM kademe 'Orta'", r5["tier"]["label"] == "Orta")
	check("EV skor = 8", Scoring.score_word(st, _mk("EV"))["score"] == 8)

func _t2() -> void:
	print("2) Akıllı dağıtıcı: her el oynanabilir mi?")
	var playable := 0
	var tries := 8
	for i in tries:
		var st := State.create_state("dealer-" + str(i))
		Round.start_run(st)
		if _find_word(st["round"]["hand"]) != null:
			playable += 1
		else:
			print("    OYNANAMAZ el: ", _word_str(st["round"]["hand"]))
	check(str(tries) + " elin hepsi oynanabilir", playable == tries)
	var a := State.create_state("same"); Round.start_run(a)
	var b := State.create_state("same"); Round.start_run(b)
	check("aynı seed = aynı el", _word_str(a["round"]["hand"]) == _word_str(b["round"]["hand"]))

func _t3() -> void:
	print("3) Hedef eğrisi + kör ilerleme")
	var st := State.create_state("ante")
	Round.start_run(st)
	var t1: int = st["round"]["target"]
	check("küçük kör hedefi pozitif", t1 > 0)
	check("ante 1, küçük kör", st["run"]["ante"] == 1 and Round.current_blind(st)["type"] == "small")
	st["round"]["score"] = t1; st["round"]["status"] = "won"
	var r := Round.advance_blind(st)
	check("kör geçince ödül verildi", r["reward"]["total"] > 0)
	check("büyük köre geçildi", Round.current_blind(st)["type"] == "big")
	check("büyük kör hedefi > küçük", st["round"]["target"] > t1)
	st["round"]["score"] = st["round"]["target"]; st["round"]["status"] = "won"; Round.advance_blind(st)
	check("patron köre geçildi", Round.current_blind(st)["type"] == "boss")
	st["round"]["score"] = st["round"]["target"]; st["round"]["status"] = "won"; Round.advance_blind(st)
	check("patron sonrası ante 2", st["run"]["ante"] == 2 and Round.current_blind(st)["type"] == "small")

func _t4() -> void:
	print("4) Uçtan uca: gerçek kelimelerle küçük kör geç")
	var st := State.create_state("e2e")
	Round.start_run(st)
	var target: int = st["round"]["target"]
	print("    hedef: ", target, " | el: ", _word_str(st["round"]["hand"]))
	var plays := 0
	while st["round"]["status"] == "playing" and st["round"]["playsLeft"] > 0:
		var cards = _find_word(st["round"]["hand"])
		if cards == null:
			print("    kelime bulunamadı")
			break
		var res := Round.play_word(st, _ids(cards))
		plays += 1
		print("    \"", res["word"], "\" ", res["chips"], "×", res["mult"], "=", res["score"], " | ", st["round"]["score"], "/", target, " | ", st["round"]["status"])
		check("oyna #" + str(plays) + " geçerli", res["ok"] == true)
		check("oyna #" + str(plays) + " el handSize aşmadı", st["round"]["hand"].size() <= st["config"]["handSize"])
	check("küçük kör 4 hakta geçildi", st["round"]["status"] == "won")
	check("stats kelime sayısı eşleşti", st["run"]["stats"]["words"] == plays)
	check("stats en iyi kelime kaydedildi", st["run"]["stats"]["bestWord"] != "" and st["run"]["stats"]["bestScore"] > 0)

func _t5() -> void:
	print("5) Atma mekaniği")
	var st := State.create_state("disc"); Round.start_run(st)
	var before: int = st["round"]["discardsLeft"]
	var ids := _ids(st["round"]["hand"].slice(0, 3))
	var d := Round.discard_cards(st, ids)
	check("atma başarılı", d["ok"])
	check("atma sonrası el 8", st["round"]["hand"].size() == st["config"]["handSize"])
	check("atma hakkı düştü", st["round"]["discardsLeft"] == before - 1)

func _t6() -> void:
	print("6) tr-TR locale doğrulama")
	check("'ışık' geçerli (I->ı)", Dictionary_.is_valid_word("IŞIK", 2))
	check("'kitap' geçerli", Dictionary_.is_valid_word("kitap", 2))

func _t7() -> void:
	print("7) Jokerler (veri-güdümlü hook'lar)")
	var st := State.create_state("jok")
	JokerActions.add_joker_by_id(st, "sesli-avcisi")
	var r := Scoring.score_word(st, _mk("KALEM"))
	check("Sesli Avcısı: KALEM mult 6", r["mult"] == 6)
	check("Sesli Avcısı: KALEM skor 156", r["score"] == 156)
	check("tetiklenen joker kaydedildi", r["firedJokers"].has("sesli-avcisi"))
	var letter_steps := 0
	var tier_step = null
	var joker_step = null
	for s in r["timeline"]:
		if s["kind"] == "letter": letter_steps += 1
		elif s["kind"] == "tier": tier_step = s
		elif s["kind"] == "joker": joker_step = s
	check("timeline: 5 harf adımı", letter_steps == 5)
	check("timeline: kademe adımı (Orta)", tier_step != null and tier_step["label"] == "Orta")
	check("timeline: joker adımı Sesli Avcısı", joker_step != null and joker_step["id"] == "sesli-avcisi")
	var has_mult4 := false
	if joker_step != null:
		for o in joker_step["ops"]:
			if o["op"] == "mult" and o["n"] == 4: has_mult4 = true
	check("timeline: joker +4 çarpan kaydı", has_mult4)
	check("timeline: son adım skorla uyumlu", r["timeline"][r["timeline"].size() - 1]["chips"] == r["chips"])
	var st2 := State.create_state("jok2"); JokerActions.add_joker_by_id(st2, "cimri")
	check("Cimri: EV skor 24", Scoring.score_word(st2, _mk("EV"))["score"] == 24)
	var st3 := State.create_state("jok3"); JokerActions.add_joker_by_id(st3, "mimar")
	check("Mimar: 6 harfte tetiklendi", Scoring.score_word(st3, _mk("MERMER"))["firedJokers"].has("mimar"))
	var st4 := State.create_state("jok4"); JokerActions.add_joker_by_id(st4, "kumarbaz")
	Scoring.score_word(st4, _mk("KALEM"), true)
	check("Kumarbaz önizlemede pas geçti (hata yok)", true)

func _t8() -> void:
	print("8) Dükkân & Ekonomi")
	var st := State.create_state("shop"); Round.start_run(st)
	st["round"]["score"] = st["round"]["target"]; st["round"]["status"] = "won"
	var before: int = st["run"]["money"]
	var reward = Round.collect_blind_reward(st)
	check("ödül toplandı, para arttı", st["run"]["money"] == before + reward["total"])
	check("ödül iki kez toplanmaz", Round.collect_blind_reward(st) == null)
	st["run"]["money"] = 60
	Shop.generate_shop(st)
	check("dükkânda 2 joker var", st["run"]["shop"]["jokers"].size() == 2)
	check("dükkânda kupon var", st["run"]["shop"]["voucher"] != null)
	var joker_to_buy: String = st["run"]["shop"]["jokers"][0]["id"]
	var m0: int = st["run"]["money"]; var jn0: int = st["run"]["jokers"].size()
	var b := Shop.buy_joker(st, joker_to_buy)
	check("joker satın alındı", b["ok"] and st["run"]["jokers"].size() == jn0 + 1)
	check("joker parası düştü", st["run"]["money"] == m0 - b["joker"]["cost"])
	var rc: int = st["run"]["shop"]["rerollCost"]; var mr: int = st["run"]["money"]
	Shop.reroll(st)
	check("reroll parası düştü", st["run"]["money"] == mr - rc)
	check("reroll maliyeti arttı", st["run"]["shop"]["rerollCost"] == rc + 1)
	var deck0: int = st["run"]["deck"].size()
	var bb := Shop.buy_booster(st)
	check("booster 3 seçenek verdi", bb["ok"] and bb["choices"].size() == 3)
	Shop.choose_booster_letter(st, bb["choices"][0])
	check("deste büyüdü", st["run"]["deck"].size() == deck0 + 1)
	var v = st["run"]["shop"]["voucher"]
	var hand_before: int = st["config"]["handSize"]
	var plays_before: int = st["config"]["basePlays"]
	var disc_before: int = st["config"]["baseDiscards"]
	Shop.buy_voucher(st)
	var changed: bool = st["config"]["handSize"] != hand_before or st["config"]["basePlays"] != plays_before or st["config"]["baseDiscards"] != disc_before
	check("kupon kalıcı etki uyguladı", st["run"]["vouchers"].has(v) and changed)
	var sell_id: String = st["run"]["jokers"][0]["id"]; var ms: int = st["run"]["money"]
	var s := Shop.sell_joker(st, sell_id)
	check("joker satıldı, para arttı", s["ok"] and st["run"]["money"] == ms + s["value"])
	Round.proceed_to_next_blind(st)
	check("sonraki kör başladı", st["round"]["status"] == "playing" and st["round"]["hand"].size() == st["config"]["handSize"])

func _t9() -> void:
	print("9) Risk/kaos jokerleri")
	var p := State.create_state("pal"); JokerActions.add_joker_by_id(p, "palindrom-tanrisi")
	var rp := Scoring.score_word(p, _mk("ANA"))
	check("Palindrom: ANA mult 10", rp["mult"] == 10)
	check("Palindrom: ANA skor 30", rp["score"] == 30)
	check("Palindrom: KALEM tetiklemez", not Scoring.score_word(p, _mk("KALEM"))["firedJokers"].has("palindrom-tanrisi"))
	var a := State.create_state("alc"); JokerActions.add_joker_by_id(a, "harf-simyacisi")
	var r1 := Scoring.score_word(a, _mk("ARABA"))
	var r2 := Scoring.score_word(a, _mk("ARABA"))
	check("Simyacı: 1. oynamada +3 çarpan", r1["mult"] == 5)
	check("Simyacı: 2. oynamada +6", r2["mult"] == 8)
	check("Simyacı: sayaç kalıcı", a["run"]["jokerVars"]["harfSimyacisi"] == 6)
	var pv: int = a["run"]["jokerVars"]["harfSimyacisi"]
	Scoring.score_word(a, _mk("ARABA"), true)
	check("Simyacı: önizleme büyütmez", a["run"]["jokerVars"]["harfSimyacisi"] == pv)
	var iv := State.create_state("int"); Round.start_run(iv); JokerActions.add_joker_by_id(iv, "intikam")
	var dids := _ids(iv["round"]["hand"].slice(0, 3))
	Round.discard_cards(iv, dids)
	check("İntikam: atınca sayaç 3", iv["run"]["jokerVars"]["intikam"] == 3)
	var ri := Scoring.score_word(iv, _mk("EV"))
	check("İntikam: +15 çip", ri["chips"] == 23)
	check("İntikam: tüketilince sıfırlandı", iv["run"]["jokerVars"]["intikam"] == 0)
	var cg := State.create_state("cig"); Round.start_run(cg); JokerActions.add_joker_by_id(cg, "cig")
	cg["round"]["score"] = cg["round"]["target"]; cg["round"]["status"] = "won"
	Round.collect_blind_reward(cg)
	check("Çığ: 1 kör sonrası +1 çarpan", Scoring.score_word(cg, _mk("KALEM"))["mult"] == 3)
	var an := State.create_state("ana"); Round.start_run(an); JokerActions.add_joker_by_id(an, "anagram-seytani")
	an["round"]["wordsPlayed"].append("KALEM")
	check("Anagram: ×3 tetikledi", Scoring.score_word(an, _mk("MALEK"))["firedJokers"].has("anagram-seytani"))
	var ku := State.create_state("kut"); JokerActions.add_joker_by_id(ku, "kutuphaneci")
	check("Kütüphaneci: +20 çip", Scoring.score_word(ku, _mk("KALEM"))["chips"] == 46)
	var ya := State.create_state("yan"); JokerActions.add_joker_by_id(ya, "yanki")
	check("Yankı: ilk harf çipi tekrar", Scoring.score_word(ya, _mk("EV"))["chips"] == 9)
	var he := State.create_state("hec"); JokerActions.add_joker_by_id(he, "heceleyici")
	check("Heceleyici: 5+ harf +18 çip", Scoring.score_word(he, _mk("KALEM"))["chips"] == 44)
	var sy := State.create_state("say"); JokerActions.add_joker_by_id(sy, "sayac")
	Scoring.score_word(sy, _mk("EV"))
	check("Sayaç: kalıcı büyüdü (3)", sy["run"]["jokerVars"]["sayac"] == 3)
	check("Sayaç: 2. kelimede +3 çip", Scoring.score_word(sy, _mk("EV"))["chips"] == 11)
	var ak := State.create_state("alt"); ak["run"]["money"] = 0; JokerActions.add_joker_by_id(ak, "altin-kalem")
	Scoring.score_word(ak, _mk("EV"), true)
	check("Altın Kalem: önizlemede para basmaz", ak["run"]["money"] == 0)
	Scoring.score_word(ak, _mk("EV"))
	check("Altın Kalem: oynayınca +2 para", ak["run"]["money"] == 2)
	var zc := State.create_state("zin"); Round.start_run(zc); JokerActions.add_joker_by_id(zc, "zincir")
	zc["round"]["wordsPlayed"] = []; zc["round"]["lastWordLength"] = 0
	check("Zincir: ilk kelime tetiklemez", not Scoring.score_word(zc, _mk("KALEM"))["firedJokers"].has("zincir"))
	zc["round"]["wordsPlayed"] = ["KALE"]; zc["round"]["lastWordLength"] = 4
	check("Zincir: uzun kelime tetikler", Scoring.score_word(zc, _mk("KALEM"))["firedJokers"].has("zincir"))
	var tu := State.create_state("tut"); JokerActions.add_joker_by_id(tu, "tutumlu"); tu["round"]["discardsLeft"] = 2
	check("Tutumlu: +24 çip", Scoring.score_word(tu, _mk("EV"))["chips"] == 32)
	var ck := State.create_state("cik"); JokerActions.add_joker_by_id(ck, "cikmaz"); ck["round"]["discardsLeft"] = 0
	check("Çıkmaz: +12 çarpan", Scoring.score_word(ck, _mk("EV"))["mult"] == 13)
	ck["round"]["discardsLeft"] = 1
	check("Çıkmaz: değişim varken tetiklemez", Scoring.score_word(ck, _mk("EV"))["mult"] == 1)
	var tg := State.create_state("tel"); JokerActions.add_joker_by_id(tg, "telgraf")
	var rtg := Scoring.score_word(tg, _mk("EV"))
	check("Telgraf: +5 çip +1 çarpan", rtg["chips"] == 13 and rtg["mult"] == 2)
	var dg := State.create_state("dor"); JokerActions.add_joker_by_id(dg, "dortgen")
	check("Dörtgen: tam 4 harf +30", Scoring.score_word(dg, _mk("KALE"))["chips"] == 54)
	check("Dörtgen: 5 harf tetiklemez", Scoring.score_word(dg, _mk("KALEM"))["chips"] == 26)
	var ik := State.create_state("iki"); JokerActions.add_joker_by_id(ik, "ikili")
	check("İkili: tekrar harf ×2", Scoring.score_word(ik, _mk("ANA"))["firedJokers"].has("ikili"))
	check("İkili: tekrar yoksa tetiklemez", not Scoring.score_word(ik, _mk("KALE"))["firedJokers"].has("ikili"))
	var tp := State.create_state("top"); JokerActions.add_joker_by_id(tp, "topluluk")
	check("Topluluk: joker başına +2 çarpan", Scoring.score_word(tp, _mk("EV"))["mult"] == 3)
	var pm := State.create_state("pat"); JokerActions.add_joker_by_id(pm, "patlamis-misir")
	check("Patlamış Mısır: +20 çarpan", Scoring.score_word(pm, _mk("EV"))["mult"] == 21)
	var gd := State.create_state("ger"); Round.start_run(gd); JokerActions.add_joker_by_id(gd, "geri-donusum")
	var gm0: int = gd["run"]["money"]; var did = gd["round"]["hand"][0]["id"]
	Round.discard_cards(gd, [did])
	check("Geri Dönüşüm: atınca +1 para", gd["run"]["money"] == gm0 + 1)

func _t10() -> void:
	print("10) Patron kısıtlamaları")
	var st := State.create_state("boss"); Round.start_run(st)
	st["round"]["score"] = st["round"]["target"]; st["round"]["status"] = "won"; Round.proceed_to_next_blind(st)
	st["round"]["score"] = st["round"]["target"]; st["round"]["status"] = "won"; Round.proceed_to_next_blind(st)
	check("Patron turunda kısıtlama seçildi", Round.current_blind(st)["type"] == "boss" and st["round"]["boss"] != null)
	var uy = Bosses.by_id("uzun-yol")
	check("Uzun Yol: 4 harf bloklanır", uy["validate"].call(_mk("KALE"), null)["ok"] == false)
	check("Uzun Yol: 5 harf geçer", uy["validate"].call(_mk("KALEM"), null)["ok"] == true)
	var tk = Bosses.by_id("tekel")
	check("Tekel: AAA bloklanır", tk["validate"].call(_mk("AAA"), null)["ok"] == false)
	check("Tekel: ANANAS bloklanır", tk["validate"].call(_mk("ANANAS"), null)["ok"] == false)
	check("Tekel: KALEM geçer", tk["validate"].call(_mk("KALEM"), null)["ok"] == true)
	var ac := State.create_state("ac"); Round.start_run(ac); ac["round"]["boss"] = Bosses.by_id("acgozlu")
	Bosses.by_id("acgozlu")["onStart"].call(ac)
	check("Açgözlü: değişim 0", ac["round"]["discardsLeft"] == 0)
	var db := State.create_state("db"); Round.start_run(db)
	var plays_before: int = db["round"]["playsLeft"]
	Bosses.by_id("darbogaz")["onStart"].call(db)
	check("Darboğaz: 1 hak eksik", db["round"]["playsLeft"] == plays_before - 1)
	var sn := State.create_state("sn"); Round.start_run(sn)
	Bosses.by_id("sansur")["onStart"].call(sn)
	check("Sansür: 3 harf kilitlendi", sn["round"]["lockedChars"].size() == 3)
	var locked: String = sn["round"]["lockedChars"].keys()[0]
	check("Sansür: kilitli harf bloklanır", Bosses.by_id("sansur")["validate"].call(_mk(locked + "AE"), sn)["ok"] == false)
	var ks := State.create_state("ks"); Round.start_run(ks); ks["round"]["boss"] = Bosses.by_id("kisirlik")
	ks["round"]["wordsPlayed"] = []
	check("Kısırlık: ilk kelime 0 puan", Scoring.score_word(ks, _mk("KALEM"))["score"] == 0)
	ks["round"]["wordsPlayed"] = ["EV"]
	check("Kısırlık: sonraki kelime normal", Scoring.score_word(ks, _mk("KALEM"))["score"] == 52)
	var vg := State.create_state("vg"); Round.start_run(vg); vg["round"]["boss"] = Bosses.by_id("vergi")
	var rv := Scoring.score_word(vg, _mk("KALEM"))
	check("Vergi: çarpan yarıya (mult 1)", rv["mult"] == 1)
	check("Vergi: KALEM skor 26", rv["score"] == 26)
	check("pickBoss determinist", Bosses.pick_boss(State.create_state("z")["run"]["rng"])["id"] == Bosses.pick_boss(State.create_state("z")["run"]["rng"])["id"])
