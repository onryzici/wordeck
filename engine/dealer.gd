extends RefCounted
# Akıllı dağıtıcı (AI) — src/engine/dealer.js portu. Seed'li, deterministik sezgisel
# arama: oynanabilir + dengeli eller verir; patron kısıtlaması varsa DAİMA kısıt-uygun
# bir kelime kurulabilen el garanti eder.

const Rng = preload("res://engine/rng.gd")
const Dictionary_ = preload("res://engine/dictionary.gd")
const TurkishCase = preload("res://engine/turkish_case.gd")

const TR_VOWELS := {"A": true, "E": true, "I": true, "İ": true, "O": true, "Ö": true, "U": true, "Ü": true}
const INF_REPEAT := 1000000

static var _cached_candidates = null
static var _cached_for_size := -1

static func _build_candidates(hand_size: int) -> Array:
	if _cached_candidates != null and _cached_for_size == hand_size:
		return _cached_candidates
	var word_set = Dictionary_.get_word_set()
	var list := []
	for w in word_set:
		var n: int = w.length()
		if n < 2 or n > hand_size:
			continue
		var counts := {}
		for ch in w:
			counts[ch] = counts.get(ch, 0) + 1
		list.append({"len": n, "counts": counts})
	_cached_candidates = list
	_cached_for_size = hand_size
	return list

static func _letter_counts(cards: Array) -> Dictionary:
	var counts := {}
	var total := 0
	for c in cards:
		var ch := TurkishCase.tr_lower(c["char"])
		counts[ch] = counts.get(ch, 0) + 1
		total += 1
	return {"counts": counts, "total": total}

static func _count_formable(cards: Array, candidates: Array, cap: int) -> int:
	var lc := _letter_counts(cards)
	var counts: Dictionary = lc["counts"]
	var total: int = lc["total"]
	var n := 0
	for cand in candidates:
		if cand["len"] > total:
			continue
		var ok := true
		for ch in cand["counts"]:
			if counts.get(ch, 0) < cand["counts"][ch]:
				ok = false
				break
		if ok:
			n += 1
			if n >= cap:
				return n
	return n

static func _candidate_ok(cand: Dictionary, constraint: Dictionary) -> bool:
	if cand["len"] < constraint["minLen"]:
		return false
	if constraint["maxRepeat"] < INF_REPEAT:
		for ch in cand["counts"]:
			if cand["counts"][ch] > constraint["maxRepeat"]:
				return false
	if constraint.get("bannedChars", null) != null:
		for ch in cand["counts"]:
			if constraint["bannedChars"].has(ch):
				return false
	return true

static func _count_formable_constrained(cards: Array, candidates: Array, constraint: Dictionary, cap: int) -> int:
	var lc := _letter_counts(cards)
	var counts: Dictionary = lc["counts"]
	var total: int = lc["total"]
	var n := 0
	for cand in candidates:
		if cand["len"] > total:
			continue
		if not _candidate_ok(cand, constraint):
			continue
		var ok := true
		for ch in cand["counts"]:
			if counts.get(ch, 0) < cand["counts"][ch]:
				ok = false
				break
		if ok:
			n += 1
			if n >= cap:
				return n
	return n

static func _constraint_active(c) -> bool:
	if c == null:
		return false
	var banned = c.get("bannedChars", null)
	return c["minLen"] > 2 or (banned != null and banned.size() > 0) or c["maxRepeat"] < INF_REPEAT

static func _pick_constraint_draw(hand: Array, pool: Array, need: int, constraint: Dictionary, candidates: Array, rng: Object):
	var hand_counts: Dictionary = _letter_counts(hand)["counts"]
	var pool_by_char := {}
	for c in pool:
		var ch := TurkishCase.tr_lower(c["char"])
		if not pool_by_char.has(ch):
			pool_by_char[ch] = []
		pool_by_char[ch].append(c)
	for cand in candidates:
		if not _candidate_ok(cand, constraint):
			continue
		var feasible := true
		var extra := 0
		for ch in cand["counts"]:
			var have: int = hand_counts.get(ch, 0)
			var avail: int = pool_by_char[ch].size() if pool_by_char.has(ch) else 0
			if cand["counts"][ch] > have + avail:
				feasible = false
				break
			extra += max(0, cand["counts"][ch] - have)
		if not feasible or extra > need:
			continue
		var draw := []
		var used := {}
		var pool_copy := {}
		for ch in pool_by_char:
			pool_copy[ch] = pool_by_char[ch].duplicate()
		var ok_build := true
		for ch in cand["counts"]:
			var need_ch: int = max(0, cand["counts"][ch] - hand_counts.get(ch, 0))
			while need_ch > 0:
				var arr = pool_copy.get(ch, null)
				if arr == null or arr.is_empty():
					ok_build = false
					break
				var card = arr.pop_front()
				draw.append(card)
				used[card["id"]] = true
				need_ch -= 1
			if not ok_build:
				break
		if not ok_build:
			continue
		var rest := []
		for c in pool:
			if not used.has(c["id"]):
				rest.append(c)
		Rng.shuffle(rest, rng)
		for c in rest:
			if draw.size() >= need:
				break
			draw.append(c)
		if draw.size() >= need:
			return draw.slice(0, need)
	return null

static func _vowel_ratio(cards: Array) -> float:
	if cards.size() == 0:
		return 0.0
	var v := 0
	for c in cards:
		if TR_VOWELS.has(c["char"]):
			v += 1
	return float(v) / cards.size()

static func _score_hand(cards: Array, candidates: Array, cfg: Dictionary) -> Dictionary:
	var words := _count_formable(cards, candidates, cfg["qualityCap"])
	var vr := _vowel_ratio(cards)
	var penalty: float = abs(vr - cfg["targetVowelRatio"]) * cfg["vowelPenaltyWeight"]
	return {"words": words, "vr": vr, "score": words - penalty}

# hand ve pool'u MUTASYONA uğratır. Deterministik (rng).
static func deal_to_hand(hand: Array, pool: Array, hand_size: int, rng: Object, cfg: Dictionary, constraint) -> void:
	var need: int = min(hand_size - hand.size(), pool.size())
	if need <= 0:
		return
	var candidates := _build_candidates(hand_size)
	var active := _constraint_active(constraint)
	var max_attempts: int = cfg["maxAttempts"] * 2 if active else cfg["maxAttempts"]

	var best = null
	for attempt in max_attempts:
		var shuffled: Array = pool.duplicate()
		Rng.shuffle(shuffled, rng)
		var draw: Array = shuffled.slice(0, need)
		var full: Array = hand.duplicate()
		full.append_array(draw)
		var q := _score_hand(full, candidates, cfg)
		var constrained: int = _count_formable_constrained(full, candidates, constraint, 1) if active else 1
		var cand := {"draw": draw, "q": q, "constrained": constrained}

		var better := false
		if best == null:
			better = true
		elif active and cand["constrained"] >= 1 and best["constrained"] < 1:
			better = true
		elif (not active or ((cand["constrained"] >= 1) == (best["constrained"] >= 1))) and q["score"] > best["q"]["score"]:
			better = true
		if better:
			best = cand

		var vowel_ok: bool = abs(q["vr"] - cfg["targetVowelRatio"]) <= cfg["vowelTolerance"]
		if q["words"] >= cfg["minWords"] and vowel_ok and constrained >= 1:
			best = cand
			break

	if active and best["constrained"] < 1:
		var forced = _pick_constraint_draw(hand, pool, need, constraint, candidates, rng)
		if forced != null:
			var full2: Array = hand.duplicate()
			full2.append_array(forced)
			best = {"draw": forced, "q": _score_hand(full2, candidates, cfg), "constrained": 1}

	var chosen := {}
	for c in best["draw"]:
		chosen[c["id"]] = true
	for i in range(pool.size() - 1, -1, -1):
		if chosen.has(pool[i]["id"]):
			pool.remove_at(i)
	hand.append_array(best["draw"])
