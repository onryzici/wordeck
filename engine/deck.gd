extends RefCounted
# Deste oluşturma — src/engine/deck.js portu. Her harf bir kart: {id, char, enhancements}.

static func build_deck(bag: Dictionary) -> Array:
	var cards := []
	var id := 0
	for ch in bag.keys():
		for i in bag[ch]:
			cards.append({"id": id, "char": ch, "enhancements": []})
			id += 1
	return cards
