extends RefCounted
# Skorlama — src/engine/scoring.js portu. score = chips × mult. Sıralı timeline üretir.

const LetterValues = preload("res://data/letter_values.gd")
const WordTiers = preload("res://data/word_tiers.gd")
const Hooks = preload("res://engine/hooks.gd")
const Ctx = preload("res://engine/ctx.gd")
const Enhancements = preload("res://data/enhancements.gd")

static func _word_of(cards: Array) -> String:
	var w := ""
	for c in cards:
		w += c["char"]
	return w

# preview=true: canlı önizleme — rastgele/yan-etkili jokerler pas geçer.
static func score_word(state: Dictionary, cards: Array, preview: bool = false) -> Dictionary:
	var tier: Dictionary = WordTiers.tier_for(cards.size())
	var ctx = Ctx.new()
	ctx.chips = 0
	ctx.mult = float(tier["mult"])
	ctx.tier = tier
	ctx.word = _word_of(cards)
	ctx.cards = cards
	ctx.state = state
	ctx.preview = preview
	var timeline := []
	ctx._timeline = timeline

	# 1 + 2) harf çipleri ve her harf için onLetterScored
	for card in cards:
		var base: int = LetterValues.chips(card["char"])
		ctx.chips += base
		var op_start: int = ctx._ops.size()
		ctx.card = card
		Enhancements.apply_letter(ctx, card)  # foil/holo/poly/golden/glass (harf-üstü)
		Hooks.run_hooks(state, "onLetterScored", ctx)
		ctx.card = null
		timeline.append({
			"kind": "letter", "char": card["char"], "base": base,
			"ops": ctx._ops.slice(op_start), "chips": ctx.chips, "mult": ctx.mult,
		})

	# 3) kelime uzunluğu kademesi taban çipi
	ctx.chips += tier["bonusChips"]
	timeline.append({
		"kind": "tier", "label": tier["label"], "base": tier["bonusChips"],
		"ops": [], "chips": ctx.chips, "mult": ctx.mult,
	})

	# 4) tüm kelime için onWordScored (jokerler soldan sağa)
	Hooks.run_hooks(state, "onWordScored", ctx)

	# 5) score = chips × mult
	var score: int = int(round(ctx.chips * ctx.mult))
	return {
		"chips": ctx.chips, "mult": ctx.mult, "score": score,
		"timeline": timeline, "tier": tier, "firedJokers": ctx._fired.keys(),
		"broken": ctx._broken,  # kırılan cam kart id'leri
	}
