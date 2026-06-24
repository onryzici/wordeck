extends RefCounted
# Başlangıç destesi dağılımı — src/data/letterBag.js portu.
# Anahtar: Türkçe BÜYÜK harf, değer: adet. (Sıra deterministik kart id'si için önemli.)

const BAG := {
	"A": 5, "E": 4, "İ": 3, "I": 2, "O": 2, "U": 2, "Ö": 1, "Ü": 1,
	"B": 2, "C": 1, "Ç": 1, "D": 2, "F": 1, "G": 1, "Ğ": 1, "H": 1, "J": 1,
	"K": 3, "L": 3, "M": 2, "N": 3, "P": 1, "R": 3, "S": 2, "Ş": 1, "T": 3,
	"V": 1, "Y": 2, "Z": 1,
}

# İngilizce torba — Türkçe'nin yapısını yansıtır (toplam 56 taş, ~25 sesli),
# İngilizce harf frekansına göre uyarlanmış (E en bol, Q/X/Z/J nadir).
const BAG_EN := {
	"E": 8, "A": 6, "I": 5, "O": 4, "U": 2,
	"N": 3, "R": 3, "T": 3, "L": 2, "S": 2, "D": 2, "G": 2,
	"B": 1, "C": 1, "M": 1, "P": 1, "F": 1, "H": 1, "V": 1, "W": 1, "Y": 1,
	"K": 1, "J": 1, "X": 1, "Q": 1, "Z": 1,
}

# Dil bayrağı (sunum katmanı set eder). Varsayılan "tr" → motor testleri korunur.
static var _lang := "tr"

static func set_lang(l: String) -> void:
	_lang = l

static func bag() -> Dictionary:
	return BAG_EN if _lang == "en" else BAG
