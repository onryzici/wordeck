extends RefCounted
# Türkçe sözlük yükleme + doğrulama — src/engine/dictionary.js portu.
# WORDS bir Dictionary'dir, set gibi kullanılır (anahtar = kelime, O(1) kontrol).

const TurkishCase = preload("res://engine/turkish_case.gd")

static var WORDS = null

static func normalize_word(word: String) -> String:
	return TurkishCase.tr_lower(word.strip_edges())

static func load_from_text(text: String) -> int:
	WORDS = {}
	for line in text.split("\n"):
		var w := normalize_word(line)
		if w.length() > 0:
			WORDS[w] = true
	return WORDS.size()

static func load_from_file(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Sözlük açılamadı: " + path)
		return 0
	var text := f.get_as_text()
	f.close()
	return load_from_text(text)

static func is_loaded() -> bool:
	return WORDS != null

static func get_word_set():
	if WORDS == null:
		push_error("Sözlük henüz yüklenmedi.")
	return WORDS

static func is_valid_word(word: String, min_len: int = 2) -> bool:
	if WORDS == null:
		push_error("Sözlük henüz yüklenmedi.")
		return false
	var w := normalize_word(word)
	return w.length() >= min_len and WORDS.has(w)
