extends RefCounted
# Dükkân — src/engine/shop.js portu. Joker al/sat, reroll, harf paketi, kupon.

const Jokers = preload("res://data/jokers.gd")
const Vouchers = preload("res://data/vouchers.gd")
const JokerActions = preload("res://engine/joker_actions.gd")
const Enhancements = preload("res://data/enhancements.gd")

const SHOP_JOKER_COUNT := 2
const REROLL_BASE := 5
const BOOSTER_COST := 4
const BOOSTER_OPTIONS := 3
const ENHANCER_COST := 5
const ENHANCER_OPTIONS := 3
const BOOSTER_LETTERS := ["A", "E", "İ", "I", "O", "U", "K", "L", "N", "R", "T", "M", "S", "B", "D", "Y"]

static func _pick_n(arr: Array, n: int, rng: Object) -> Array:
	var pool: Array = arr.duplicate()
	var out := []
	while out.size() < n and pool.size() > 0:
		var idx := int(rng.next() * pool.size())
		out.append(pool[idx])
		pool.remove_at(idx)
	return out

static func _owned_ids(list: Array) -> Dictionary:
	var d := {}
	for x in list:
		d[x["id"]] = true
	return d

static func _available(all_items: Array, owned: Dictionary) -> Array:
	var out := []
	for x in all_items:
		if not owned.has(x["id"]):
			out.append(x)
	return out

static func generate_shop(state: Dictionary) -> Dictionary:
	var rng = state["run"]["rng"]
	var avail_j := _available(Jokers.all(), _owned_ids(state["run"]["jokers"]))
	var avail_v := _available(Vouchers.all(), _owned_ids(state["run"]["vouchers"]))
	state["run"]["shop"] = {
		"jokers": _pick_n(avail_j, SHOP_JOKER_COUNT, rng),
		"booster": {"id": "harf-paketi", "name": "Harf Paketi", "cost": BOOSTER_COST, "used": false},
		"enhancer": {"id": "cila-paketi", "name": "Cila Paketi", "cost": ENHANCER_COST, "used": false},
		"voucher": _pick_n(avail_v, 1, rng)[0] if avail_v.size() > 0 else null,
		"rerollCost": REROLL_BASE,
	}
	state["run"]["boosterChoices"] = null
	state["run"]["enhancerChoices"] = null
	state["run"]["pendingEnhancement"] = null
	return state["run"]["shop"]

static func reroll(state: Dictionary) -> Dictionary:
	var shop = state["run"]["shop"]
	if shop == null or state["run"]["money"] < shop["rerollCost"]:
		return {"ok": false}
	state["run"]["money"] -= shop["rerollCost"]
	var avail_j := _available(Jokers.all(), _owned_ids(state["run"]["jokers"]))
	shop["jokers"] = _pick_n(avail_j, SHOP_JOKER_COUNT, state["run"]["rng"])
	shop["rerollCost"] += 1
	state["run"]["stats"]["rerolls"] = state["run"]["stats"].get("rerolls", 0) + 1
	return {"ok": true}

static func buy_joker(state: Dictionary, joker_id: String) -> Dictionary:
	var shop = state["run"]["shop"]
	if shop == null:
		return {"ok": false, "reason": "yok"}
	var idx := -1
	for i in shop["jokers"].size():
		if shop["jokers"][i]["id"] == joker_id:
			idx = i
			break
	if idx == -1:
		return {"ok": false, "reason": "yok"}
	var joker = shop["jokers"][idx]
	if state["run"]["jokers"].size() >= JokerActions.MAX_JOKERS:
		return {"ok": false, "reason": "slotDolu"}
	if state["run"]["money"] < joker["cost"]:
		return {"ok": false, "reason": "para"}
	state["run"]["money"] -= joker["cost"]
	state["run"]["jokers"].append(joker)
	shop["jokers"].remove_at(idx)
	state["run"]["stats"]["bought"] = state["run"]["stats"].get("bought", 0) + 1
	return {"ok": true, "joker": joker}

static func sell_joker(state: Dictionary, joker_id: String) -> Dictionary:
	var js: Array = state["run"]["jokers"]
	var i := -1
	for k in js.size():
		if js[k]["id"] == joker_id:
			i = k
			break
	if i == -1:
		return {"ok": false}
	var joker = js[i]
	var value: int = max(1, int(joker["cost"] / 2))
	js.remove_at(i)
	state["run"]["money"] += value
	return {"ok": true, "value": value}

static func buy_booster(state: Dictionary) -> Dictionary:
	var shop = state["run"]["shop"]
	if shop == null or shop["booster"]["used"]:
		return {"ok": false, "reason": "yok"}
	if state["run"]["money"] < shop["booster"]["cost"]:
		return {"ok": false, "reason": "para"}
	state["run"]["money"] -= shop["booster"]["cost"]
	shop["booster"]["used"] = true
	state["run"]["boosterChoices"] = _pick_n(BOOSTER_LETTERS, BOOSTER_OPTIONS, state["run"]["rng"])
	return {"ok": true, "choices": state["run"]["boosterChoices"]}

static func choose_booster_letter(state: Dictionary, ch: String) -> Dictionary:
	var choices = state["run"]["boosterChoices"]
	if choices == null or not choices.has(ch):
		return {"ok": false}
	state["run"]["deck"].append({"id": state["run"]["nextCardId"], "char": ch, "enhancements": []})
	state["run"]["nextCardId"] += 1
	state["run"]["deckSize"] = state["run"]["deck"].size()
	state["run"]["boosterChoices"] = null
	return {"ok": true}

# Cila Paketi: satın al → 3 geliştirme seçeneği üret
static func buy_enhancer(state: Dictionary) -> Dictionary:
	var shop = state["run"]["shop"]
	if shop == null or shop["enhancer"]["used"]:
		return {"ok": false, "reason": "yok"}
	if state["run"]["money"] < shop["enhancer"]["cost"]:
		return {"ok": false, "reason": "para"}
	state["run"]["money"] -= shop["enhancer"]["cost"]
	shop["enhancer"]["used"] = true
	var ids := []
	for e in Enhancements.all():
		ids.append(e["id"])
	state["run"]["enhancerChoices"] = _pick_n(ids, ENHANCER_OPTIONS, state["run"]["rng"])
	return {"ok": true, "choices": state["run"]["enhancerChoices"]}

# Geliştirmeyi seç → BEKLEMEYE al (oyuncu sonra hangi harfe uygulanacağını seçer — agency v2).
static func choose_enhancement(state: Dictionary, eid: String) -> Dictionary:
	var choices = state["run"]["enhancerChoices"]
	if choices == null or not choices.has(eid):
		return {"ok": false}
	state["run"]["pendingEnhancement"] = eid
	state["run"]["enhancerChoices"] = null
	return {"ok": true, "enh": eid}

# Bekleyen geliştirmeyi seçilen HARFE uygula (o harften bir karta; geliştirmesi olmayanı tercih et).
static func apply_enhancement_to_letter(state: Dictionary, ch: String) -> Dictionary:
	var eid = state["run"].get("pendingEnhancement", null)
	if eid == null:
		return {"ok": false}
	var deck: Array = state["run"]["deck"]
	var target = null
	for c in deck:  # o harften, bu geliştirmeye sahip OLMAYAN ilk kart
		if c["char"] == ch and not c["enhancements"].has(eid):
			target = c
			break
	if target == null:  # hepsinde varsa: o harften herhangi biri
		for c in deck:
			if c["char"] == ch:
				target = c
				break
	if target == null:
		return {"ok": false}
	target["enhancements"].append(eid)
	state["run"]["pendingEnhancement"] = null
	return {"ok": true, "char": ch, "enh": eid}

static func buy_voucher(state: Dictionary) -> Dictionary:
	var shop = state["run"]["shop"]
	if shop == null or shop["voucher"] == null:
		return {"ok": false, "reason": "yok"}
	var v = shop["voucher"]
	if state["run"]["money"] < v["cost"]:
		return {"ok": false, "reason": "para"}
	state["run"]["money"] -= v["cost"]
	state["run"]["vouchers"].append(v)
	v["apply"].call(state)
	shop["voucher"] = null
	return {"ok": true, "voucher": v}
