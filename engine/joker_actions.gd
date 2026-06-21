extends RefCounted
# Joker ekleme/çıkarma/sıralama — src/engine/jokerActions.js portu.

const Jokers = preload("res://data/jokers.gd")

const MAX_JOKERS := 5

static func add_joker(state: Dictionary, joker) -> bool:
	if joker == null or state["run"]["jokers"].size() >= MAX_JOKERS:
		return false
	state["run"]["jokers"].append(joker)
	return true

static func add_joker_by_id(state: Dictionary, id: String) -> bool:
	return add_joker(state, Jokers.by_id(id))

static func remove_joker(state: Dictionary, id: String) -> void:
	var js: Array = state["run"]["jokers"]
	for i in js.size():
		if js[i]["id"] == id:
			js.remove_at(i)
			return

static func add_random_joker(state: Dictionary):
	if state["run"]["jokers"].size() >= MAX_JOKERS:
		return null
	var owned := {}
	for j in state["run"]["jokers"]:
		owned[j["id"]] = true
	var pool := []
	for j in Jokers.all():
		if not owned.has(j["id"]):
			pool.append(j)
	if pool.is_empty():
		return null
	var idx := int(state["run"]["rng"].next() * pool.size())
	var joker = pool[idx]
	state["run"]["jokers"].append(joker)
	return joker

static func move_joker(state: Dictionary, id: String, to_index: int) -> void:
	var jokers: Array = state["run"]["jokers"]
	var from := -1
	for i in jokers.size():
		if jokers[i]["id"] == id:
			from = i
			break
	if from == -1:
		return
	var j = jokers[from]
	jokers.remove_at(from)
	var idx: int = max(0, min(to_index, jokers.size()))
	jokers.insert(idx, j)
