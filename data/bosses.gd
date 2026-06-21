extends RefCounted
# Patron kısıtlamaları — src/data/bosses.js portu. VERİ-GÜDÜMLÜ:
#  - onStart(state): tur başında bir kez
#  - validate(cards, state) -> {ok, reason}: kelime oynanmadan ÖNCE blok
#  - hooks.onWordScored(ctx): skorlama cezası (jokerlerden SONRA)
# validate/onStart fonksiyonları HER ZAMAN (cards, state) / (state) imzasıyla çağrılır.

const Self = preload("res://data/bosses.gd")

const LOCKABLE := ["K", "L", "N", "R", "T", "M", "S", "B", "D", "Y", "Ç", "Ş", "Z", "G", "H", "P"]

static func _pick_n(arr: Array, n: int, rng: Object) -> Array:
	var pool: Array = arr.duplicate()
	var out := []
	while out.size() < n and pool.size() > 0:
		var idx := int(rng.next() * pool.size())
		out.append(pool[idx])
		pool.remove_at(idx)
	return out

static func all() -> Array:
	return [
		{"id": "uzun-yol", "name": "Uzun Yol", "icon": "📏",
			"description": "Kelimeler en az 5 harf olmalı.",
			"dealer": {"minLen": 5},
			"validate": Self._v_uzun_yol},
		{"id": "tekel", "name": "Tekel", "icon": "⛓️",
			"description": "Aynı harf bir kelimede 2'den fazla kullanılamaz.",
			"dealer": {"maxRepeat": 2},
			"validate": Self._v_tekel},
		{"id": "acgozlu", "name": "Açgözlü", "icon": "💰",
			"description": "Bu turda değişim (atma) hakkın yok.",
			"onStart": Self._s_acgozlu},
		{"id": "darbogaz", "name": "Darboğaz", "icon": "⏳",
			"description": "Bu turda bir kelime hakkın eksik.",
			"onStart": Self._s_darbogaz},
		{"id": "kisirlik", "name": "Kısırlık", "icon": "🌵",
			"description": "İlk oynadığın kelime sayılmaz (0 puan).",
			"hooks": {"onWordScored": Self._h_kisirlik}},
		{"id": "vergi", "name": "Vergi", "icon": "⚖️",
			"description": "Her kelimede çarpanın yarısı vergi olarak alınır (×0.5).",
			"hooks": {"onWordScored": Self._h_vergi}},
		{"id": "sansur", "name": "Sansür", "icon": "🚫",
			"description": "Rastgele 3 harf bu turda kilitli (kullanılamaz).",
			"dealer": {"banLocked": true},
			"onStart": Self._s_sansur,
			"validate": Self._v_sansur},
		{"id": "maraton", "name": "Maraton", "icon": "🏔️",
			"description": "Hedef bu turda %30 daha yüksek.",
			"onStart": Self._s_maraton},
		{"id": "lanet", "name": "Lanet", "icon": "💀",
			"description": "Her kelimeden 25 Çip eksilir.",
			"hooks": {"onWordScored": Self._h_lanet}},
		{"id": "buzul", "name": "Buzul", "icon": "🧊",
			"description": "Her kelimede çipler yarıya iner.",
			"hooks": {"onWordScored": Self._h_buzul}},
		{"id": "cendere", "name": "Cendere", "icon": "🗜️",
			"description": "Tek uzunlukta (3,5,7…) kelimeler ×0.5 çarpan.",
			"hooks": {"onWordScored": Self._h_cendere}},
		{"id": "yanki", "name": "Yankı", "icon": "🔁",
			"description": "Bir kelimeyi bu turda iki kez oynayamazsın.",
			"validate": Self._v_yanki},
	]

# ── validate gövdeleri (cards, state) → {ok, reason?} ──
static func _v_uzun_yol(cards: Array, _state) -> Dictionary:
	return {"ok": true} if cards.size() >= 5 else {"ok": false, "reason": "uzunYol"}

static func _v_tekel(cards: Array, _state) -> Dictionary:
	var c := {}
	for card in cards:
		c[card["char"]] = c.get(card["char"], 0) + 1
		if c[card["char"]] > 2: return {"ok": false, "reason": "tekel"}
	return {"ok": true}

static func _v_sansur(cards: Array, state) -> Dictionary:
	var locked = state["round"].get("lockedChars", null)
	if locked != null:
		for c in cards:
			if locked.has(c["char"]): return {"ok": false, "reason": "sansur"}
	return {"ok": true}

static func _v_yanki(cards: Array, state) -> Dictionary:
	var word := ""
	for c in cards: word += c["char"]
	return {"ok": false, "reason": "yanki"} if state["round"]["wordsPlayed"].has(word) else {"ok": true}

# ── onStart gövdeleri (state) ──
static func _s_acgozlu(state) -> void:
	state["round"]["discardsLeft"] = 0

static func _s_darbogaz(state) -> void:
	state["round"]["playsLeft"] = max(1, state["round"]["playsLeft"] - 1)

static func _s_sansur(state) -> void:
	var picked := _pick_n(LOCKABLE, 3, state["run"]["rng"])
	var s := {}
	for ch in picked: s[ch] = true
	state["round"]["lockedChars"] = s

static func _s_maraton(state) -> void:
	state["round"]["target"] = int(round(state["round"]["target"] * 1.3))

# ── hooks.onWordScored gövdeleri ──
static func _h_kisirlik(ctx) -> void:
	if ctx.state["round"]["wordsPlayed"].size() == 0:
		ctx.chips = 0
		ctx.mult = 0.0

static func _h_vergi(ctx) -> void:
	ctx.x_mult(0.5)

static func _h_lanet(ctx) -> void:
	ctx.add_chips(-25)
	if ctx.chips < 0: ctx.chips = 0

static func _h_buzul(ctx) -> void:
	ctx.chips = int(floor(ctx.chips * 0.5))

static func _h_cendere(ctx) -> void:
	if ctx.cards.size() % 2 == 1: ctx.x_mult(0.5)

# Seed'li rng ile bir patron seç.
static func pick_boss(rng: Object) -> Dictionary:
	var bosses := all()
	return bosses[int(rng.next() * bosses.size())]

static func by_id(id: String):
	for b in all():
		if b["id"] == id:
			return b
	return null
