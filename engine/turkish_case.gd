extends RefCounted
# Türkçe-bilinçli küçük harf — src/engine/turkishCase.js portu. ICU'ya bağımsız.
# Sadece KÜÇÜLTME (kartlar BÜYÜK, sözlük küçük).

const LOWER := {
	"İ": "i", "I": "ı",
	"Ç": "ç", "Ş": "ş", "Ğ": "ğ", "Ü": "ü", "Ö": "ö",
}

static func tr_lower(s: String) -> String:
	var out := ""
	for ch in s:
		if LOWER.has(ch):
			out += LOWER[ch]
		else:
			out += ch.to_lower()
	return out
