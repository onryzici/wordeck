extends SceneTree
# Denge simülasyonu — GERÇEK Godot motoruyla (62 joker dahil) açgözlü oyuncu oynar.
# scripts/sim-balance.mjs portu; Godot ana hat olduğu için ölçüm burada yapılır (tek doğruluk kaynağı).
# Çalıştır: tools/godot.exe --path godot --headless --script res://tests/sim_balance.gd -- 80
# (Geliştirmeler [foil/holo…] modellenMEZ — JS sim gibi; joker-eğrisi tuning için yeterli.)

const State = preload("res://engine/state.gd")
const Round = preload("res://engine/round.gd")
const Dictionary_ = preload("res://engine/dictionary.gd")
const Scoring = preload("res://engine/scoring.gd")
const Shop = preload("res://engine/shop.gd")
const JokerActions = preload("res://engine/joker_actions.gd")
const LetterValues = preload("res://data/letter_values.gd")
const WordTiers = preload("res://data/word_tiers.gd")
const Config = preload("res://data/config.gd")

var idx: Array = []          # {word, len, counts, score} skora göre azalan
const CAND := 12             # her oyunda denenecek en iyi aday sayısı
const TYPE_TR := {"small": "Tur 1 ", "big": "Tur 2 ", "boss": "Patron"}
const ORDER := {"small": 0, "big": 1, "boss": 2}

func _tr_upper(s: String) -> String:
	var out := ""
	for ch in s:
		if ch == "i": out += "İ"
		elif ch == "ı": out += "I"
		else: out += ch.to_upper()
	return out

func _init() -> void:
	Dictionary_.load_from_file("res://data/kelimeler.txt")
	var words = Dictionary_.get_word_set()
	for w in words.keys():
		var u := _tr_upper(w)
		var n := u.length()
		if n < 2 or n > 8:
			continue
		var counts := {}
		var chip_sum := 0
		for ch in u:
			counts[ch] = counts.get(ch, 0) + 1
			chip_sum += LetterValues.chips(ch)
		var t := WordTiers.tier_for(n)
		var score: int = (chip_sum + int(t["bonusChips"])) * int(t["mult"])
		idx.append({"word": u, "len": n, "counts": counts, "score": score})
	idx.sort_custom(func(a, b): return a["score"] > b["score"])
	print("Sözlük: ", words.size(), " kelime, oynanabilir indeks (2-8): ", idx.size())
	print("config: targetBase=%d anteGrowth=%.2f hand=%d plays=%d disc=%d jokerHavuzu=%d\n"
		% [Config.TARGET_BASE, Config.ANTE_GROWTH, Config.HAND_SIZE, Config.BASE_PLAYS,
		   Config.BASE_DISCARDS, preload("res://data/jokers.gd").all().size()])

	var args := OS.get_cmdline_user_args()
	var n := 80
	if args.size() > 0 and args[0].is_valid_int():
		n = args[0].to_int()
	_run_pass("JOKERSİZ açgözlü (alt sınır)", n, false, false)
	_run_pass("NAİF — joker alır ama sinerjisiz seçer", n, true, false)
	_run_pass("YETENEKLİ — joker alır + sinerji kelimesi (tavan)", n, true, true)
	quit(0)

func _hand_counts(hand: Array) -> Dictionary:
	var c := {}
	for card in hand:
		c[card["char"]] = c.get(card["char"], 0) + 1
	return c

func _playable(word: Dictionary, hc: Dictionary) -> bool:
	for ch in word["counts"]:
		if hc.get(ch, 0) < word["counts"][ch]:
			return false
	return true

func _ids_for_word(hand: Array, word: Dictionary) -> Array:
	var need: Dictionary = word["counts"].duplicate()
	var ids := []
	for card in hand:
		var ch = card["char"]
		if need.get(ch, 0) > 0:
			ids.append(card["id"])
			need[ch] -= 1
	return ids

func _cards_for_ids(hand: Array, ids: Array) -> Array:
	var by_id := {}
	for c in hand:
		by_id[c["id"]] = c
	var out := []
	for i in ids:
		out.append(by_id[i])
	return out

func _top_candidates(hand: Array, n: int) -> Array:
	var hc := _hand_counts(hand)
	var out := []
	for w in idx:
		if _playable(w, hc):
			out.append(w)
			if out.size() >= n:
				break
	return out

# Bir turu açgözlü oyna; skilled=true → adayları gerçek skora (joker sinerjisi) göre sırala.
func _play_round(state: Dictionary, skilled: bool) -> void:
	var round_d: Dictionary = state["round"]
	var guard := 0
	while round_d["status"] == "playing" and round_d["playsLeft"] > 0 and guard < 30:
		guard += 1
		var cands := _top_candidates(round_d["hand"], CAND)
		if skilled and state["run"]["jokers"].size() > 0:
			var scored := []
			for c in cands:
				var ids := _ids_for_word(round_d["hand"], c)
				var cards := _cards_for_ids(round_d["hand"], ids)
				var sc: int = int(Scoring.score_word(state, cards, true)["score"])
				scored.append({"c": c, "sc": sc})
			scored.sort_custom(func(a, b): return a["sc"] > b["sc"])
			cands = []
			for x in scored:
				cands.append(x["c"])
		var played := false
		for c in cands:
			var ids := _ids_for_word(round_d["hand"], c)
			if Round.play_word(state, ids).get("ok", false):
				played = true
				break
		if not played:
			if round_d["discardsLeft"] > 0:
				var sorted_hand: Array = round_d["hand"].duplicate()
				sorted_hand.sort_custom(func(a, b): return LetterValues.chips(a["char"]) < LetterValues.chips(b["char"]))
				var drop := []
				for i in mini(4, sorted_hand.size()):
					drop.append(sorted_hand[i]["id"])
				Round.discard_cards(state, drop)
			else:
				break

# Dükkân: uygun en pahalı jokeri al (güç vekili), zenginse reroll, 5 slotu doldur.
func _do_shop(state: Dictionary) -> void:
	Shop.generate_shop(state)
	var shop: Dictionary = state["run"]["shop"]
	var safety := 0
	while safety < 12 and state["run"]["jokers"].size() < 5:
		safety += 1
		var aff := []
		for j in shop["jokers"]:
			if j["cost"] <= state["run"]["money"]:
				aff.append(j)
		aff.sort_custom(func(a, b): return a["cost"] > b["cost"])
		if aff.size() > 0:
			Shop.buy_joker(state, aff[0]["id"])
		elif state["run"]["money"] >= shop["rerollCost"] + 5:
			if not Shop.reroll(state).get("ok", false):
				break
		else:
			break

func _simulate_run(seed: int, rows: Array, with_jokers: bool, skilled: bool) -> Dictionary:
	var state := State.create_state(str(seed))
	Round.start_run(state)
	var guard := 0
	while state["run"]["status"] == "playing" and guard < 40:
		guard += 1
		var ante: int = state["run"]["ante"]
		var btype: String = state["round"]["blind"]["type"]
		var target: int = state["round"]["target"]
		_play_round(state, skilled)
		var passed: bool = state["round"]["status"] == "won"
		rows.append({"ante": ante, "type": btype, "target": target,
			"score": state["round"]["score"], "passed": passed})
		if not passed:
			break
		Round.collect_blind_reward(state)
		if with_jokers:
			_do_shop(state)
		if Round.proceed_to_next_blind(state).get("runWon", false):
			break
	return state

func _median(a: Array) -> int:
	if a.is_empty():
		return 0
	var s := a.duplicate()
	s.sort()
	var m := s.size() / 2
	if s.size() % 2 == 1:
		return int(s[m])
	return int(round((s[m - 1] + s[m]) / 2.0))

func _run_pass(label: String, n: int, with_jokers: bool, skilled: bool) -> void:
	var rows := []
	var wins := 0
	var reached := {}
	for s in n:
		var st := _simulate_run(1000 + s, rows, with_jokers, skilled)
		if st["run"]["status"] == "won":
			wins += 1
		var a: int = min(8, st["run"]["ante"])
		reached[a] = reached.get(a, 0) + 1
	var groups := {}
	for r in rows:
		var k := "%d|%s" % [r["ante"], r["type"]]
		if not groups.has(k):
			groups[k] = []
		groups[k].append(r)
	var keys: Array = groups.keys()
	keys.sort_custom(func(a, b):
		var pa = a.split("|"); var pb = b.split("|")
		if int(pa[0]) != int(pb[0]): return int(pa[0]) < int(pb[0])
		return ORDER[pa[1]] < ORDER[pb[1]])
	print("\n=== ", label, " (", n, " run) ===")
	print("Ante | Tur    | Hedef  | Medyan | Skor/Hed | Geçme% | n")
	print("-----+--------+--------+--------+----------+--------+----")
	for k in keys:
		var g: Array = groups[k]
		var parts = k.split("|")
		var target: int = g[0]["target"]
		var scores := []
		var pass_n := 0
		for r in g:
			scores.append(r["score"])
			if r["passed"]: pass_n += 1
		var med := _median(scores)
		var ratio := float(med) / float(max(1, target))
		var pr := int(round(100.0 * pass_n / g.size()))
		print("  %s  | %s | %s | %s | %s | %s%% | %d"
			% [parts[0], TYPE_TR[parts[1]], str(target).lpad(6),
			   str(med).lpad(6), ("%.2f" % ratio).lpad(8), str(pr).lpad(5), g.size()])
	var line := "Erişilen ante:  "
	for a in range(1, 9):
		if reached.has(a):
			line += "A%d:%d%%  " % [a, int(round(100.0 * reached[a] / n))]
	print(line)
	print("Tüm oyunu kazanma: %d/%d (%d%%)" % [wins, n, int(round(100.0 * wins / n))])
