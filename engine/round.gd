extends RefCounted
# Kör/ante akışı — src/engine/round.js portu. Saf mantık.

const Dealer = preload("res://engine/dealer.gd")
const Scoring = preload("res://engine/scoring.gd")
const Dictionary_ = preload("res://engine/dictionary.gd")
const TurkishCase = preload("res://engine/turkish_case.gd")
const Blinds = preload("res://data/blinds.gd")
const Economy = preload("res://engine/economy.gd")
const Hooks = preload("res://engine/hooks.gd")
const Bosses = preload("res://data/bosses.gd")
const Ctx = preload("res://engine/ctx.gd")

static func current_blind(state: Dictionary) -> Dictionary:
	return Blinds.BLINDS[state["run"]["blindIndex"]]

static func _round_constraint(state: Dictionary) -> Dictionary:
	var c := {"minLen": state["config"]["minWordLength"], "maxRepeat": Dealer.INF_REPEAT, "bannedChars": null}
	var boss = state["round"].get("boss", null)
	if boss == null:
		return c
	var d = boss.get("dealer", null)
	if d == null:
		return c
	if d.has("minLen"):
		c["minLen"] = d["minLen"]
	if d.has("maxRepeat"):
		c["maxRepeat"] = d["maxRepeat"]
	if d.get("banLocked", false) and state["round"]["lockedChars"] != null:
		var banned := {}
		for ch in state["round"]["lockedChars"].keys():
			banned[TurkishCase.tr_lower(ch)] = true
		c["bannedChars"] = banned
	return c

static func _compute_target(state: Dictionary, blind: Dictionary) -> int:
	var c = state["config"]
	return int(round(c["targetBase"] * pow(c["anteGrowth"], state["run"]["ante"] - 1) * blind["mult"]))

static func start_blind(state: Dictionary) -> void:
	var round_d: Dictionary = state["round"]
	var run: Dictionary = state["run"]
	var config: Dictionary = state["config"]
	var blind := current_blind(state)
	round_d["blind"] = blind
	round_d["target"] = _compute_target(state, blind)
	round_d["score"] = 0
	round_d["playsLeft"] = config["basePlays"]
	round_d["discardsLeft"] = config["baseDiscards"]
	round_d["pool"] = run["deck"].duplicate()
	round_d["hand"] = []
	round_d["lastWordLength"] = 0
	round_d["wordsPlayed"] = []
	round_d["status"] = "playing"
	round_d["lastReward"] = null
	round_d["rewardCollected"] = false
	round_d["boss"] = null
	round_d["lockedChars"] = null
	if blind["type"] == "boss":
		var boss := Bosses.pick_boss(run["rng"])
		round_d["boss"] = boss
		if boss.has("onStart"):
			boss["onStart"].call(state)
	Dealer.deal_to_hand(round_d["hand"], round_d["pool"], config["handSize"], run["rng"], config["dealer"], _round_constraint(state))

static func start_run(state: Dictionary) -> void:
	state["run"]["ante"] = 1
	state["run"]["blindIndex"] = 0
	state["run"]["money"] = state["config"]["startMoney"]
	state["run"]["status"] = "playing"
	start_blind(state)

# Verilen id kümesindeki kartları diziden çıkar (cam kırılması).
static func _remove_ids(arr: Array, idset: Dictionary) -> void:
	for i in range(arr.size() - 1, -1, -1):
		if idset.has(int(arr[i]["id"])):
			arr.remove_at(i)

static func _ids_to_cards(hand: Array, ids: Array) -> Array:
	var out := []
	for id in ids:
		for c in hand:
			if c["id"] == id:
				out.append(c)
				break
	return out

static func _remove_from_hand(hand: Array, ids: Array) -> Array:
	var idset := {}
	for id in ids:
		idset[id] = true
	var removed := []
	for c in hand:
		if idset.has(c["id"]):
			removed.append(c)
	for i in range(hand.size() - 1, -1, -1):
		if idset.has(hand[i]["id"]):
			hand.remove_at(i)
	return removed

static func _update_status(state: Dictionary) -> void:
	var round_d: Dictionary = state["round"]
	if round_d["score"] >= round_d["target"]:
		round_d["status"] = "won"
	elif round_d["playsLeft"] <= 0:
		round_d["status"] = "lost"
		state["run"]["status"] = "lost"

# selectedIds: oyuncunun dizdiği SIRA ile. ok=false ise hak HARCANMAZ.
static func play_word(state: Dictionary, selected_ids: Array) -> Dictionary:
	var round_d: Dictionary = state["round"]
	var config: Dictionary = state["config"]
	var run: Dictionary = state["run"]
	if round_d["status"] != "playing":
		return {"ok": false, "reason": "bitti"}
	if round_d["playsLeft"] <= 0:
		return {"ok": false, "reason": "hakYok"}
	var cards := _ids_to_cards(round_d["hand"], selected_ids)
	if cards.size() < config["minWordLength"]:
		return {"ok": false, "reason": "kısa"}
	var word := ""
	for c in cards:
		word += c["char"]
	if not Dictionary_.is_valid_word(word, config["minWordLength"]):
		return {"ok": false, "reason": "gecersiz", "word": word}
	var boss = round_d.get("boss", null)
	if boss != null and boss.has("validate"):
		var v = boss["validate"].call(cards, state)
		if not v["ok"]:
			return {"ok": false, "reason": v.get("reason", "")}

	var result := Scoring.score_word(state, cards)
	round_d["score"] += result["score"]
	round_d["playsLeft"] -= 1
	round_d["lastWordLength"] = cards.size()
	round_d["wordsPlayed"].append(word)

	# Kırılan cam kartları desteden (ve pool'dan) KALICI sil
	var broken: Array = result.get("broken", [])
	if not broken.is_empty():
		var bset := {}
		for bid in broken:
			bset[bid] = true
		_remove_ids(run["deck"], bset)
		_remove_ids(round_d["pool"], bset)
		run["deckSize"] = run["deck"].size()

	var stats: Dictionary = run["stats"]
	stats["words"] += 1
	if result["score"] > stats["bestScore"]:
		stats["bestScore"] = result["score"]
		stats["bestWord"] = word

	_remove_from_hand(round_d["hand"], selected_ids)
	Dealer.deal_to_hand(round_d["hand"], round_d["pool"], config["handSize"], run["rng"], config["dealer"], _round_constraint(state))
	_update_status(state)

	var ret := {"ok": true, "word": word}
	for k in result:
		ret[k] = result[k]
	return ret

static func discard_cards(state: Dictionary, selected_ids: Array) -> Dictionary:
	var round_d: Dictionary = state["round"]
	var config: Dictionary = state["config"]
	var run: Dictionary = state["run"]
	if round_d["status"] != "playing":
		return {"ok": false, "reason": "bitti"}
	if round_d["discardsLeft"] <= 0:
		return {"ok": false, "reason": "atmaYok"}
	if selected_ids.size() == 0:
		return {"ok": false, "reason": "seçimYok"}
	var removed := _remove_from_hand(round_d["hand"], selected_ids)
	round_d["pool"].append_array(removed)
	round_d["discardsLeft"] -= 1
	run["stats"]["discards"] = run["stats"].get("discards", 0) + removed.size()
	var ctx = Ctx.new()
	ctx.state = state
	ctx.cards = removed
	ctx.count = removed.size()
	Hooks.run_hooks(state, "onDiscard", ctx)
	Dealer.deal_to_hand(round_d["hand"], round_d["pool"], config["handSize"], run["rng"], config["dealer"], _round_constraint(state))
	return {"ok": true}

static func collect_blind_reward(state: Dictionary):
	var round_d: Dictionary = state["round"]
	var run: Dictionary = state["run"]
	if round_d["status"] != "won" or round_d["rewardCollected"]:
		return null
	var reward := Economy.blind_reward(round_d["blind"], round_d, run["money"])
	run["money"] += reward["total"]
	round_d["lastReward"] = reward
	round_d["rewardCollected"] = true
	run["jokerVars"]["blindsPassed"] = run["jokerVars"].get("blindsPassed", 0) + 1
	return reward

static func proceed_to_next_blind(state: Dictionary) -> Dictionary:
	var round_d: Dictionary = state["round"]
	var run: Dictionary = state["run"]
	var config: Dictionary = state["config"]
	if round_d["blind"]["type"] == "boss":
		run["ante"] += 1
		run["blindIndex"] = 0
	else:
		run["blindIndex"] += 1
	if run["ante"] > config["maxAnte"]:
		run["status"] = "won"
		return {"runWon": true}
	start_blind(state)
	return {"runWon": false}

# Blind ATLA (yalnız small/big) — oynamadan sonraki blind'e geç. Küçük "atlama" bonusu verir.
static func skip_blind(state: Dictionary) -> Dictionary:
	var round_d: Dictionary = state["round"]
	var run: Dictionary = state["run"]
	if round_d["blind"]["type"] == "boss":
		return {"ok": false, "reason": "patronAtlanmaz"}
	var bonus := 2  # atlama ödülü (basit "tag" — cilalama sonra)
	run["money"] += bonus
	run["blindIndex"] += 1
	start_blind(state)
	return {"ok": true, "bonus": bonus}

# Verilen ante'deki bir blind tipinin hedefini hesapla (seçim ekranı için).
static func target_for_blind(state: Dictionary, blind: Dictionary) -> int:
	return _compute_target(state, blind)

static func advance_blind(state: Dictionary) -> Dictionary:
	if state["round"]["status"] != "won":
		return {"ok": false}
	var reward = collect_blind_reward(state)
	var res := proceed_to_next_blind(state)
	return {"ok": true, "reward": reward, "runWon": res["runWon"]}
