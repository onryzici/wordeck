extends RefCounted
# Kelime uzunluğu kademeleri — src/data/wordTiers.js portu.

const TIERS := [
	{"min": 2, "max": 3, "bonusChips": 0, "mult": 1, "label": "Kısa"},
	{"min": 4, "max": 5, "bonusChips": 20, "mult": 2, "label": "Orta"},
	{"min": 6, "max": 7, "bonusChips": 40, "mult": 3, "label": "Uzun"},
	{"min": 8, "max": 1000000, "bonusChips": 60, "mult": 4, "label": "Destansı"},
]

static func tier_for(length: int) -> Dictionary:
	for t in TIERS:
		if length >= t["min"] and length <= t["max"]:
			return t
	return TIERS[0]
