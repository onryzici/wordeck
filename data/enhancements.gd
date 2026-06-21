extends RefCounted
# Harf geliştirmeleri (Balatro foil/holo/poly muadili) — VERİ + efekt.
# Skorlamada her kartın `enhancements` dizisi için apply_letter çağrılır (scoring.gd).
# Kalıcı: run.deck kartına eklenir; pool=deck.duplicate() shallow olduğu için el/pool'a yansır.

# id → tanım (sembol UI'de köşe rozeti, color tint/kenar).
const DEFS := {
	"foil":   {"name": "Yaldız",     "symbol": "◆", "color": "#6fb6e0", "desc": "+50 Çip"},
	"holo":   {"name": "Holografik", "symbol": "✦", "color": "#b86bd6", "desc": "+10 Çarpan"},
	"poly":   {"name": "Polikrom",   "symbol": "❋", "color": "#e8b84a", "desc": "×1.5 Çarpan"},
	"golden": {"name": "Altın",      "symbol": "₺", "color": "#e8b84a", "desc": "Oynanınca +3 Para"},
	"glass":  {"name": "Cam",        "symbol": "❖", "color": "#9fe0d6", "desc": "×2 Çarpan, %25 kırılır"},
}

const ORDER := ["foil", "holo", "poly", "golden", "glass"]

static func all() -> Array:
	var out := []
	for id in ORDER:
		var d: Dictionary = DEFS[id].duplicate()
		d["id"] = id
		out.append(d)
	return out

static func by_id(id):
	if DEFS.has(id):
		var d: Dictionary = DEFS[id].duplicate()
		d["id"] = id
		return d
	return null

# Bir kartın TÜM geliştirmelerini skorlamada uygula (scoring.gd harf döngüsünden).
# ops ctx._ops'a yazılır → timeline → skor sekansı uçan rozet gösterir.
static func apply_letter(ctx, card) -> void:
	var enh = card.get("enhancements", [])
	if enh.is_empty():
		return
	for eid in enh:
		match eid:
			"foil":
				ctx.add_chips(50)
			"holo":
				ctx.add_mult(10)
			"poly":
				ctx.x_mult(1.5)
			"golden":
				if not ctx.preview:
					ctx.state["run"]["money"] += 3
			"glass":
				ctx.x_mult(2)
				# %25 kır: skorlamada işaretle, play_word desteden siler (önizlemede asla)
				if not ctx.preview and ctx.state["run"]["rng"].next() < 0.25:
					ctx._broken.append(int(card["id"]))
