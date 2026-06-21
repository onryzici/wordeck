extends Control
# Sürüklenebilir harf taşı — SEÇİLİ (kelime bölgesi) taşlar drag-drop ile yeniden sıralanır.
# Tap (gui_input) seçimi yapar; native DnD (_get_drag_data) sadece can_drag iken sıralamayı değiştirir.

var card_id: int = -1
var reorder_cb: Callable    # game._on_tile_reorder(from_id, target_id, after)
var preview_cb: Callable    # game._tile_drag_preview(id) -> Control
var can_drag := false       # yalnız seçili taşlar (ortadaki kelime) sürüklenir
var drag_started := false   # bu basışta sürükleme başladı mı (tap-seçimi ayırmak için)

func _get_drag_data(_pos: Vector2):
	if not can_drag:
		return null
	drag_started = true  # bu bir SÜRÜKLEME → release'te seçim toggle'lanmasın
	modulate.a = 0.4
	if preview_cb.is_valid():
		var pv = preview_cb.call(card_id)
		if pv != null:
			set_drag_preview(pv)
	return {"tile_reorder": true, "id": card_id}

func _can_drop_data(_pos: Vector2, data) -> bool:
	return can_drag and data is Dictionary and data.get("tile_reorder", false) \
		and int(data.get("id", -1)) != card_id

func _drop_data(at_position: Vector2, data) -> void:
	var after: bool = at_position.x > size.x * 0.5
	if reorder_cb.is_valid():
		reorder_cb.call(int(data["id"]), card_id, after)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate.a = 1.0
