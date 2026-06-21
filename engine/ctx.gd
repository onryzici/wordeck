extends RefCounted
# Skorlama bağlamı — src/engine/scoring.js'teki makeContext + addChips/addMult/xMult.
# Jokerler/patronlar bunun üstünden skoru güvenle değiştirir; her işlem _ops'a kaydedilir
# (görsel zaman çizelgesi için). chips = int, mult = float (xMult 0.5/1.5 olabilir).

var chips: int = 0
var mult: float = 1.0
var tier: Dictionary = {}
var word: String = ""
var cards: Array = []
var state: Dictionary = {}
var preview: bool = false
var card = null  # onLetterScored sırasında aktif harf
var count: int = 0  # onDiscard: atılan harf sayısı
var _fired: Dictionary = {}  # tetiklenen joker id'leri (set)
var _ops: Array = []  # sıralı işlem kaydı: {op, n}
var _timeline = null  # Array veya null
var _broken: Array = []  # bu kelimede kırılan cam kart id'leri (play_word desteden siler)

func add_chips(n) -> void:
	chips += int(n)
	_ops.append({"op": "chip", "n": n})

func add_mult(n) -> void:
	mult += float(n)
	_ops.append({"op": "mult", "n": n})

func x_mult(n) -> void:
	mult *= float(n)
	_ops.append({"op": "xmult", "n": n})
