extends RefCounted
# Kuponlar — src/data/vouchers.js portu. apply() state.config'i kalıcı değiştirir.

const Self = preload("res://data/vouchers.gd")

static func all() -> Array:
	return [
		{"id": "bol-el", "name": "Bol El", "cost": 10, "icon": "✋",
			"description": "El boyutu kalıcı +1 (8 → 9 harf).", "apply": Self._apply_bol_el},
		{"id": "ekstra-hak", "name": "Ekstra Hak", "cost": 12, "icon": "🎟️",
			"description": "Kelime hakkı kalıcı +1 (her turda).", "apply": Self._apply_ekstra_hak},
		{"id": "bol-atma", "name": "Bol Atma", "cost": 8, "icon": "♻️",
			"description": "Atma hakkı kalıcı +1 (her turda).", "apply": Self._apply_bol_atma},
		{"id": "faizci", "name": "Faizci", "cost": 10, "icon": "🏦",
			"description": "Faiz tavanı +3 (daha çok tasarruf geliri).", "apply": Self._apply_faizci},
	]

static func _apply_bol_el(state) -> void:
	state["config"]["handSize"] += 1

static func _apply_ekstra_hak(state) -> void:
	state["config"]["basePlays"] += 1

static func _apply_bol_atma(state) -> void:
	state["config"]["baseDiscards"] += 1

static func _apply_faizci(state) -> void:
	state["config"]["interestCap"] += 3

static func by_id(id: String):
	for v in all():
		if v["id"] == id:
			return v
	return null
