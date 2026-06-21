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

static func chips(ch: String) -> int:
	return VALUES.get(ch, 0)
