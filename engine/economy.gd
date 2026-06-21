extends RefCounted
# Ekonomi — src/engine/economy.js portu. Körü geçince para ödülü.
# (JS gibi modül sabitlerini okur; voucher 'faizci' state.config'i değiştirse de
#  bu hesap orijinal CONFIG sabitlerini kullanır — birebir port.)

const Config = preload("res://data/config.gd")

static func blind_reward(blind: Dictionary, round_d: Dictionary, money: int) -> Dictionary:
	var base: int = blind["reward"]
	var leftover: int = round_d["playsLeft"] * Config.REWARD_PER_LEFTOVER_PLAY
	var interest: int = min(Config.INTEREST_CAP, int(money / float(Config.INTEREST_PER)))
	return {"base": base, "leftover": leftover, "interest": interest, "total": base + leftover + interest}
