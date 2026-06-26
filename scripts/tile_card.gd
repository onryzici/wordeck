extends Control
# Harf taşı + mixandjam JUICE:
#  • hover → kalkma + büyüme + fareye lean + giriş PUNCH (hızlı wobble)
#  • idle → hafif sway/bob ("kart yaşıyor")
#  • SERBEST SÜRÜKLEME (hand taşları): kap → fareyi takip eder, hıza göre yana yatar → bırak → geri oturur
# Transformlar İÇ "visual"e uygulanır → layout/seçim bozulmaz. Seçili taşlar native DnD ile reorder olur (değişmedi).

var card_id: int = -1
var reorder_cb: Callable
var preview_cb: Callable
var can_drag := false        # yalnız seçili (kelime) taşlar → native DnD reorder
var drag_started := false    # bu basışta sürükleme oldu mu (tap-seçimden ayırmak için)

var visual: Control
var tilt_mat: ShaderMaterial   # card_tilt_3d → gerçek 3D perspektif eğim
var shadow: Control            # derinlik gölgesi (kalkınca/seçilince)
var _shadow := 0.0
var _hover := false
var _lift := 0.0
var _tilt := Vector2.ZERO
var _punch := 0.0            # giriş punch (0..1, söner)
var _dragging := false       # native DnD (reorder) sırasında

# serbest sürükleme durumu (hand taşları)
var _free := false
var _press := false
var _press_pos := Vector2.ZERO
var _vel := Vector2.ZERO

func _ready() -> void:
	if has_meta("visual"):
		visual = get_meta("visual")
	if has_meta("tilt_mat"):
		tilt_mat = get_meta("tilt_mat")
	if has_meta("shadow"):
		shadow = get_meta("shadow")
		if shadow != null:
			var sz2: Vector2 = custom_minimum_size if custom_minimum_size.x > 0.0 else size
			shadow.set_anchors_preset(Control.PRESET_TOP_LEFT)
			shadow.size = sz2
			shadow.position = Vector2.ZERO
			shadow.pivot_offset = sz2 * 0.5
	if visual != null:
		var sz: Vector2 = custom_minimum_size if custom_minimum_size.x > 0.0 else size
		visual.set_anchors_preset(Control.PRESET_TOP_LEFT)
		visual.size = sz
		visual.position = Vector2.ZERO
		visual.pivot_offset = sz * 0.5
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(func(): _hover = false)
	set_process(visual != null)

func _on_enter() -> void:
	_hover = true
	_punch = 1.0   # giriş wobble

func _process(delta: float) -> void:
	if visual == null or not is_visible_in_tree():
		return
	_punch = move_toward(_punch, 0.0, delta * 3.2)

	var tgt_pos := Vector2.ZERO
	var tgt_scale := Vector2.ONE
	var tgt_rot := 0.0

	if _free:
		# Fareyi takip et + hıza göre yana yat (mixandjam FollowRotation)
		var m := get_global_mouse_position() - global_position - size * 0.5
		var prev := visual.position
		tgt_pos = m + Vector2(0.0, -12.0)
		_vel = _vel.lerp(tgt_pos - prev, delta * 20.0)
		tgt_scale = Vector2(1.18, 1.18)
		tgt_rot = deg_to_rad(clampf(_vel.x * 0.5, -26.0, 26.0))
		z_index = 30
		if tilt_mat != null:   # sürüklerken 3D düz (z-dönme zaten lean veriyor)
			tilt_mat.set_shader_parameter("y_rot", 0.0)
			tilt_mat.set_shader_parameter("x_rot", 0.0)
	else:
		_lift = move_toward(_lift, 1.0 if (_hover and not _dragging) else 0.0, delta * 9.0)
		var target := Vector2.ZERO
		if _hover and not _dragging and size.x > 0.0:
			var off := (get_local_mouse_position() - size * 0.5) / (size * 0.5)
			target = Vector2(clampf(off.x, -1.0, 1.0), clampf(off.y, -1.0, 1.0))
		_tilt = _tilt.lerp(target, delta * 14.0)
		var t := Time.get_ticks_msec() / 1000.0
		var idle := 1.0 - _lift
		var sway := sin(t * 1.35 + float(card_id) * 0.7) * 1.6 * idle
		var bob := sin(t * 1.15 + float(card_id) * 1.1) * 1.6 * idle
		var ps := sin(_punch * PI) * 0.14            # punch: scale overshoot
		var pr := sin(_punch * PI * 3.0) * 6.0 * _punch  # punch: hızlı dönme wobble
		tgt_pos = Vector2(0.0, -18.0 * _lift + bob)
		tgt_scale = Vector2.ONE * (1.0 + 0.13 * _lift + ps)
		tgt_rot = deg_to_rad(sway + pr)   # 2D lean YOK → eğim 3D shader'da
		z_index = 6 if (_hover and not _dragging) else 0
		if tilt_mat != null:
			# GERÇEK 3D: kart imlece doğru öne/arkaya yatar (y_rot yatay, x_rot dikey)
			tilt_mat.set_shader_parameter("y_rot", -_tilt.x * 26.0 * _lift)
			tilt_mat.set_shader_parameter("x_rot", _tilt.y * 26.0 * _lift)

	# yumuşak takip (drag bırakınca pürüzsüz geri oturur)
	var k := clampf(delta * (26.0 if _free else 16.0), 0.0, 1.0)
	visual.position = visual.position.lerp(tgt_pos, k)
	visual.scale = visual.scale.lerp(tgt_scale, k)
	visual.rotation = lerp_angle(visual.rotation, tgt_rot, k)

	# DERİNLİK GÖLGESİ — kart kalkınca / seçilince / sürüklenince altında belirir
	if shadow != null:
		var sel: bool = has_meta("selected") and bool(get_meta("selected"))
		var raise_t := maxf(_lift, 1.0 if (sel or _free) else 0.0)
		_shadow = move_toward(_shadow, raise_t, delta * 8.0)
		shadow.modulate.a = _shadow * 0.85
		shadow.position = Vector2(_shadow * 4.0, _shadow * 16.0)
		shadow.scale = Vector2.ONE * (1.0 + _shadow * 0.05)

# Serbest sürükleme — sadece HAND taşları (can_drag false). Tap'ı bozmaz (eşik aşılınca başlar).
func _gui_input(event: InputEvent) -> void:
	if can_drag:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press = true
			_press_pos = get_global_mouse_position()
		else:
			_press = false
			_free = false   # _process yumuşak geri oturtur
	elif event is InputEventMouseMotion and _press and not _free:
		if get_global_mouse_position().distance_to(_press_pos) > 10.0:
			_free = true
			drag_started = true   # release'te tap-seçim FIRE etmesin
			_vel = Vector2.ZERO

func _get_drag_data(_pos: Vector2):
	if not can_drag:
		return null
	drag_started = true
	_dragging = true
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
		_dragging = false
