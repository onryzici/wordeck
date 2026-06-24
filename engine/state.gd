extends RefCounted
# Tek doğruluk kaynağı (game state) — src/engine/state.js portu. Saf veri + rng nesnesi.

const Config = preload("res://data/config.gd")
const LetterBag = preload("res://data/letter_bag.gd")
const Rng = preload("res://engine/rng.gd")
const Deck = preload("res://engine/deck.gd")

static func create_state(seed_str = null) -> Dictionary:
	var s: String = seed_str if seed_str != null else Config.DEFAULT_SEED
	var deck := Deck.build_deck(LetterBag.bag())  # dil-duyarlı (tr/en torba)
	return {
		"run": {
			"ante": 1,
			"blindIndex": 0,
			"money": Config.START_MONEY,
			"deck": deck,
			"deckSize": deck.size(),
			"jokers": [],
			"jokerVars": {},
			"stats": {"words": 0, "bestWord": "", "bestScore": 0, "discards": 0, "bought": 0, "rerolls": 0},
			"vouchers": [],
			"shop": null,
			"boosterChoices": null,
			"nextCardId": deck.size(),
			"seed": s,
			"rng": Rng.make_rng(s),
			"status": "playing",
		},
		"round": {
			"blind": null,
			"boss": null,
			"lockedChars": null,
			"target": 0,
			"score": 0,
			"playsLeft": Config.BASE_PLAYS,
			"discardsLeft": Config.BASE_DISCARDS,
			"pool": [],
			"hand": [],
			"lastWordLength": 0,
			"wordsPlayed": [],
			"status": "playing",
			"lastReward": null,
			"rewardCollected": false,
		},
		"config": Config.defaults(),
	}
