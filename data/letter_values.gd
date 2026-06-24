extends RefCounted
# Harf çip değerleri (Kelimelik puanları) — src/data/letterValues.js portu.
# Anahtarlar Türkçe BÜYÜK harf. "İ" (1 çip) ile "I" (2 çip) FARKLI harflerdir.

const VALUES := {
	"A": 1, "E": 1, "İ": 1, "K": 1, "L": 1, "N": 1, "R": 1, "T": 1,
	"I": 2, "M": 2, "O": 2, "S": 2, "U": 2,
	"B": 3, "D": 3, "Y": 3, "Ü": 3,
	"C": 4, "Ç": 4, "Ş": 4, "Z": 4,
	"G": 5, "H": 5, "P": 5,
	"F": 7, "Ö": 7, "V": 7,
	"Ğ": 8,
	"J": 10,
}

# İngilizce harf değerleri (Scrabble standardı — Türkçe'deki 1..10 kademe yapısını yansıtır).
const VALUES_EN := {
	"A": 1, "E": 1, "I": 1, "O": 1, "U": 1, "L": 1, "N": 1, "S": 1, "T": 1, "R": 1,
	"D": 2, "G": 2,
	"B": 3, "C": 3, "M": 3, "P": 3,
	"F": 4, "H": 4, "V": 4, "W": 4, "Y": 4,
	"K": 5,
	"J": 8, "X": 8,
	"Q": 10, "Z": 10,
}

# Dil bayrağı (sunum katmanı set eder). Varsayılan "tr" → motor testleri korunur.
static var _lang := "tr"

static func set_lang(l: String) -> void:
	_lang = l

static func chips(ch: String) -> int:
	if _lang == "en":
		return VALUES_EN.get(ch, 0)
	return VALUES.get(ch, 0)
