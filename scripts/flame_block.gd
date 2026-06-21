extends Control
# Balatro-tarzı "glossy gummy + alev tepeli" çip/çarpan bloğu — TAMAMEN _draw ile (gerçek path).
# Davranış: başta alev YOK; skor alınca flaming=true → alev belirir, yeni tura kadar durur.
# Katman sırası: koyu kontur → renkli gradient gövde → gloss → (alev: kontur→gradient→iç çekirdek→ember)

const FLAME_H := 44.0                         # üstte alev alanı yüksekliği (blok hep altta)
const OUT := Color(0.06, 0.035, 0.045)        # koyu sticker konturu

# asimetrik diller: c=merkez(0..1), hh=yükseklik(0..1), ww=genişlik
const TONGUES := [
	{"c": 0.20, "hh": 0.60, "ww": 0.20},
	{"c": 0.42, "hh": 1.00, "ww": 0.16},
	{"c": 0.61, "hh": 0.72, "ww": 0.15},
	{"c": 0.80, "hh": 0.90, "ww": 0.18},
	{"c": 0.50, "hh": 0.42, "ww": 0.36},
]

var base_color := Color("3fa9f5")
var flaming := false
var _t := 0.0

func _ready() -> void:
	resized.connect(queue_redraw)

func set_flaming(v: bool) -> void:
	if flaming == v:
		return
	flaming = v
	queue_redraw()

func _process(delta: float) -> void:
	if flaming:
		_t += delta
		queue_redraw()  # titreşim/ember

func _draw() -> void:
	var w := size.x
	var h := size.y
	var block_top := FLAME_H
	var bh := h - FLAME_H

	# ── GÖVDE (glossy gummy: üst köşe küçük, alt köşe çok yuvarlak) ──
	var r_top := minf(15.0, w * 0.16)
	var r_bot := minf(bh * 0.52, w * 0.34)
	var body := _rounded_rect(Rect2(3, block_top, w - 6, bh - 3), r_top, r_bot, 6)
	_draw_outline(body, 5.0)  # önce koyu kontur
	var body_cols := _grad_colors(body, block_top, block_top + bh, base_color.lightened(0.22), base_color.darkened(0.24))
	draw_polygon(body, body_cols)
	# gloss highlight (üst-sol yumuşak parlama)
	draw_colored_polygon(_ellipse(Vector2(w * 0.36, block_top + bh * 0.30), w * 0.26, bh * 0.15, 16), Color(1, 1, 1, 0.22))

	# ── ALEV (sadece flaming) ──
	if flaming:
		var max_h := FLAME_H + 5.0
		var base_y := block_top + 2.0
		var fl := _flame_poly(w, base_y, max_h)
		_draw_outline(fl, 5.0)
		var fl_cols := _grad_colors(fl, base_y - max_h, base_y, base_color.lightened(0.55), base_color)
		draw_polygon(fl, fl_cols)
		# iç çekirdek (daha kısa, açık ton)
		draw_colored_polygon(_flame_poly(w, base_y, max_h * 0.58), base_color.lightened(0.45))
		_draw_embers(w, base_y - max_h)

func _draw_embers(w: float, top_y: float) -> void:
	var seeds := [Vector2(w * 0.30, 0.0), Vector2(w * 0.62, 0.45), Vector2(w * 0.46, 0.78)]
	for e in seeds:
		var p := fmod(_t * 0.8 + e.y, 1.0)
		var pos := Vector2(e.x, top_y - 2.0 - p * 16.0)
		var a := (1.0 - p) * 0.85
		draw_circle(pos, 4.2, Color(OUT.r, OUT.g, OUT.b, a))            # kontur
		draw_circle(pos, 2.8, Color(base_color.lightened(0.55), a))     # parlak çekirdek

# ── geometri yardımcıları ──
func _arc(pts: PackedVector2Array, c: Vector2, r: float, a0: float, a1: float, seg: int) -> void:
	for i in seg + 1:
		var a := lerpf(a0, a1, float(i) / float(seg))
		pts.append(c + Vector2(cos(a), sin(a)) * r)

func _rounded_rect(rect: Rect2, rt: float, rb: float, seg: int) -> PackedVector2Array:
	var p := PackedVector2Array()
	var x0 := rect.position.x
	var y0 := rect.position.y
	var x1 := x0 + rect.size.x
	var y1 := y0 + rect.size.y
	_arc(p, Vector2(x0 + rt, y0 + rt), rt, PI, PI * 1.5, seg)        # üst-sol
	_arc(p, Vector2(x1 - rt, y0 + rt), rt, -PI * 0.5, 0.0, seg)      # üst-sağ
	_arc(p, Vector2(x1 - rb, y1 - rb), rb, 0.0, PI * 0.5, seg)       # alt-sağ
	_arc(p, Vector2(x0 + rb, y1 - rb), rb, PI * 0.5, PI, seg)        # alt-sol
	return p

func _flame_poly(w: float, base_y: float, max_h: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2(4, base_y))
	var n := 46
	for i in n + 1:
		var fx := float(i) / float(n)
		pts.append(Vector2(fx * w, base_y - _flame_h(fx) * max_h))
	pts.append(Vector2(w - 4, base_y))
	return pts

func _flame_h(fx: float) -> float:
	var hh := 0.0
	for tg in TONGUES:
		var c := float(tg["c"])
		var ww := float(tg["ww"])
		var d := absf(fx - c) / ww
		if d < 1.0:
			var bump := 0.5 * (1.0 + cos(d * PI))                    # YUVARLAK uç
			var flick := 1.0 + 0.10 * sin(_t * 7.0 + c * 25.0)       # titreşim
			hh = maxf(hh, float(tg["hh"]) * bump * flick)
	return hh

func _ellipse(c: Vector2, rx: float, ry: float, seg: int) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in seg:
		var a := TAU * float(i) / float(seg)
		p.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return p

func _grad_colors(pts: PackedVector2Array, y_top: float, y_bot: float, c_top: Color, c_bot: Color) -> PackedColorArray:
	var cols := PackedColorArray()
	for pt in pts:
		var f := clampf((pt.y - y_top) / maxf(1.0, y_bot - y_top), 0.0, 1.0)
		cols.append(c_top.lerp(c_bot, f))
	return cols

func _draw_outline(pts: PackedVector2Array, width: float) -> void:
	if pts.is_empty():
		return
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, OUT, width, false)
