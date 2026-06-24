extends RefCounted
# Başlangıç destesi dağılımı — src/data/letterBag.js portu.
# Anahtar: Türkçe BÜYÜK harf, değer: adet. (Sıra deterministik kart id'si için önemli.)

const BAG := {
	"A": 5, "E": 4, "İ": 3, "I": 2, "O": 2, "U": 2, "Ö": 1, "Ü": 1,
	"B": 2, "C": 1, "Ç": 1, "D": 2, "F": 1, "G": 1, "Ğ": 1, "H": 1, "J": 1,
	"K": 3, "L": 3, "M": 2, "N": 3, "P": 1, "R": 3, "S": 2, "Ş": 1, "T": 3,
	"V": 1, "Y": 2, "Z": 1,
}

# İngilizce torba — İngilizce KELİME KURMAYA göre ayarlı (oynanabilirlik). Toplam ~63 taş.
# Eski torba %45 ünlü + S yalnız 2 + yaygın ünsüzler tek + ölü harfler (Q/X) → eller ünlü-ağırlıklı,
# kelime kurmak zordu. Yeni dengede: ~%37 ünlü (8 taşlık elde ~3 ünlü/5 ünsüz), S/R/T/N/L/D bol,
# orta ünsüzler (G/C/M/P/H/B) çift, en ölü harfler Q ve X ÇIKARILDI (J/Z/K kısa-yüksek kelime için kaldı).
const BAG_EN := {
	"E": 8, "A": 6, "I": 4, "O": 3, "U": 2,            # 23 ünlü (~%37)
	"S": 4, "R": 4, "T": 4, "N": 3, "L": 3, "D": 3,    # bol yaygın ünsüz (özellikle S — İngilizce'de kritik)
	"G": 2, "C": 2, "M": 2, "P": 2, "H": 2, "B": 2,    # orta sıklık ünsüzler çift
	"F": 1, "V": 1, "W": 1, "Y": 1, "K": 1, "J": 1, "Z": 1,  # nadirler tekli (Q ve X yok)
}

# Dil bayrağı (sunum katmanı set eder). Varsayılan "tr" → motor testleri korunur.
static var _lang := "tr"

static func set_lang(l: String) -> void:
	_lang = l

static func bag() -> Dictionary:
	return BAG_EN if _lang == "en" else BAG
