extends RefCounted
# Oyun sabitleri — src/data/config.js portu. defaults() her çağrıda TAZE kopya verir
# (state.config voucher'larla kalıcı değişebilir; orijinal sabitler bozulmamalı).

const HAND_SIZE := 8
const BASE_PLAYS := 4
const BASE_DISCARDS := 3
const MIN_WORD_LENGTH := 2
const BASE_MULT := 1

const MAX_ANTE := 8
const TARGET_BASE := 42   # 48→42: ilk turda %30 erken-ölüm vardı (sim N=120)
const ANTE_GROWTH := 2.05 # 2.0→2.05: düşen tabanı telafi eder, geç oyunu korur

const START_MONEY := 4
const INTEREST_PER := 5
const INTEREST_CAP := 5
const REWARD_PER_LEFTOVER_PLAY := 1

# Başlangıç jokeri: BOŞ (kullanıcı tercihi — ilk tur jokersiz de geçilir). Mekanizma durur;
# ileride denge için doldurulabilir. Oyun katmanında uygulanır (motor/testler saf kalsın).
const STARTING_JOKERS := []

const DEFAULT_SEED := "wordtro-001"

static func defaults() -> Dictionary:
	return {
		"handSize": HAND_SIZE,
		"basePlays": BASE_PLAYS,
		"baseDiscards": BASE_DISCARDS,
		"minWordLength": MIN_WORD_LENGTH,
		"baseMult": BASE_MULT,
		"maxAnte": MAX_ANTE,
		"targetBase": TARGET_BASE,
		"anteGrowth": ANTE_GROWTH,
		"startingJokers": STARTING_JOKERS.duplicate(),
		"startMoney": START_MONEY,
		"interestPer": INTEREST_PER,
		"interestCap": INTEREST_CAP,
		"rewardPerLeftoverPlay": REWARD_PER_LEFTOVER_PLAY,
		"dealer": {
			"maxAttempts": 24,
			"minWords": 6,
			"qualityCap": 12,
			"targetVowelRatio": 0.4,
			"vowelTolerance": 0.12,
			"vowelPenaltyWeight": 8,
		},
		"defaultSeed": DEFAULT_SEED,
	}
