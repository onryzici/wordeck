extends RefCounted
# Seed'li RNG — src/engine/rng.js portu (xmur3 hash + mulberry32).
# JS'in 32-bit davranışı (Math.imul, >>> unsigned shift) maskelerle birebir taklit
# edilir → aynı seed = aynı dizi (determinizm). Bir RNG durumu = bu sınıfın örneği;
# next() [0,1) döndürür. (JS'te closure'du; burada nesne.)

const Self = preload("res://engine/rng.gd")

const MASK := 0xFFFFFFFF

var a: int = 0  # 32-bit unsigned durum

static func _imul(x: int, y: int) -> int:
	# Math.imul: düşük 32 bit çarpım. x,y < 2^32 → çarpım < 2^64 (GDScript int 64-bit).
	return (x * y) & MASK

static func make_rng(seed_str) -> Object:
	var s := str(seed_str)
	var h := (1779033703 ^ s.length()) & MASK
	for i in s.length():
		h = _imul(h ^ s.unicode_at(i), 3432918353)
		h = (((h << 13) & MASK) | (h >> 19)) & MASK
	# hashSeed closure'ının İLK çağrısı (mulberry32 seed'i):
	h = _imul(h ^ (h >> 16), 2246822507)
	h = _imul(h ^ (h >> 13), 3266489909)
	h = (h ^ (h >> 16)) & MASK
	var r: Object = Self.new()
	r.a = h & MASK
	return r

func next() -> float:
	a = (a + 0x6D2B79F5) & MASK
	var t := _imul(a ^ (a >> 15), 1 | a)
	t = ((t + _imul(t ^ (t >> 7), 61 | t)) & MASK) ^ t
	t = t & MASK
	return float((t ^ (t >> 14)) & MASK) / 4294967296.0

static func rand_int(rng: Object, n: int) -> int:
	return int(rng.next() * n)

# Diziyi yerinde karıştırır (Fisher-Yates), seed'li RNG ile.
static func shuffle(arr: Array, rng: Object) -> Array:
	for i in range(arr.size() - 1, 0, -1):
		var j := rand_int(rng, i + 1)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
	return arr
