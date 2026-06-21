extends PanelContainer
# Sürüklenebilir joker kartı — yeniden sıralama (Balatro çekirdeği: joker sırası strateji).
# Native Godot drag-and-drop kullanır (_get_drag_data/_can_drop_data/_drop_data); böylece
# kaynak kart yerinde kalır, bir önizleme sürüklenir, bırakınca veri tek seferde güncellenir.

var jid: String = ""
var reorder_cb: Callable      # game.gd._on_joker_reorder(from_jid, target_jid, after)
var preview_cb: Callable      # game.gd._joker_drag_preview(jid) -> Control
var draggable := false        # yalnız OYUN modunda + 2+ joker varken sürüklenir

func _get_drag_data(_pos: Vector2):
	if not draggable:
		return null
	modulate.a = 0.35  # kaynak kart sürüklenirken soluklaşır
	if preview_cb.is_valid():
		var pv = preview_cb.call(jid)
		if pv != null:
			set_drag_preview(pv)
	return {"joker_reorder": true, "jid": jid}

func _can_drop_data(_pos: Vector2, data) -> bool:
	return draggable and data is Dictionary and data.get("joker_reorder", false) \
		and String(data.get("jid", "")) != jid

func _drop_data(at_position: Vector2, data) -> void:
	# Bırakılan yarı: sol yarı → bu kartın ÖNÜNE, sağ yarı → ARKASINA ekle.
	var after: bool = at_position.x > size.x * 0.5
	if reorder_cb.is_valid():
		reorder_cb.call(String(data["jid"]), jid, after)

func _notification(what: int) -> void:
	# Sürükleme bittiğinde (nereye bırakılırsa bırakılsın) solukluğu geri al.
	if what == NOTIFICATION_DRAG_END:
		modulate.a = 1.0
