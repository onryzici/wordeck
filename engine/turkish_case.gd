extends RefCounted
# Türkçe-bilinçli küçük harf — src/engine/turkishCase.js portu. ICU'ya bağımsız.
# Sadece KÜÇÜLTME (kartlar BÜYÜK, sözlük küçük).

const LOWER := {
	"İ": "i", "I": "ı",
	"Ç": "ç", "Ş": "ş", "Ğ": "ğ", "Ü": "ü", "Ö": "ö",
}

# Dil bayrağı (sunum katmanı set eder). "en" → düz lowercase ("I"→"i", Türkçe haritası atlanır).
# Varsayılan "tr" → motor testleri Türkçe davranışı korur.
static var _lang := "tr"

static func set_lang(l: String) -> void:
	_lang = l

static func tr_lower(s: String) -> String:
	if _lang == "en":
		return s.to_lower()  # İngilizce: "I"→"i", Türkçe özel küçültme yok
	var out := ""
	for ch in s:
		if LOWER.has(ch):
			out += LOWER[ch]
		else:
			out += ch.to_lower()
	return out
