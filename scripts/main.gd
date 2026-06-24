extends Control

# Ana sahne / akış kontrolü:
#  - Background : keçe girdap shader (oyun arka planı)
#  - Game       : oyun ekranı (başta gizli; OYNA'da açılır)
#  - menu_root  : Wordeck ANA MENÜSÜ — turuncu-kırmızı akışkan arka plan + müzik
#  - CRT        : en üstte post-process
# `-- --capture` ile çalıştırılırsa menü atlanır, oyun gösterilip ekran görüntüsü kaydedilir.
# `-- --capture --menu` ile menü ekranı yakalanır (görsel doğrulama).

const T = preload("res://scripts/theme.gd")
const Settings = preload("res://scripts/settings.gd")
const Jokers = preload("res://data/jokers.gd")
const Records = preload("res://scripts/records.gd")

const RULES_TEXT := "Elindeki harf taşlarından geçerli bir TÜRKÇE kelime kur, OYNA'ya bas.\n\nSkor = ÇİP × ÇARPAN. Uzun kelimeler ve jokerler skoru patlatır.\n\nHer turun bir HEDEF puanı var; tutturursan geçersin. Sınırlı kelime HAKKIN ve harf DEĞİŞİM hakkın var — değiştirmek hak harcamaz.\n\nKullanmadığın harfler elinde kalır; deste 8'e tamamlanır. Asıl strateji: şimdi mi oynasam, yoksa harf tutup daha büyük kombo mu kursam?"

@onready var background: ColorRect = $Background
@onready var game = $Game  # untyped: _load_wav/enter_session gibi dinamik çağrılar için

var menu_root: Control
var menu_bg: ColorRect
var help_overlay: Control
var music: AudioStreamPlayer        # menü müziği
# Oyun-içi müzik = DURUM tabanlı cross-fade (normal / boss / dükkan). İki player arasında
# yumuşak geçiş; bir durumun dosyası yoksa "normal"e düşer → bugün tek parçayla da çalışır,
# boss/dükkan dosyaları eklenince otomatik devreye girer. (Onur ayrı parça ekleyecek.)
var _gm_players: Array[AudioStreamPlayer] = []  # [a, b] cross-fade çifti
var _gm_active := 0                  # şu an çalan player indeksi
var _gm_state := ""                  # aktif müzik durumu (normal/boss/shop)
var _gm_path := ""                   # aktif çalan dosya yolu (gereksiz restart'ı önler)
var fade: ColorRect            # girdap geçiş katmanı (menü ↔ oyun)
var _fade_mat: ShaderMaterial  # vortex_transition shader materyali
var hero: Control              # merkez yelpaze taşları (hafif sallanır)

var settings_overlay: Control
var collection_overlay: Control
var records_overlay: Control

func _ready() -> void:
	randomize()
	Settings.init()  # ses bus'ları + kalıcı ayarları yükle/uygula
	Records.init()   # kalıcı rekorlar (ana menü rozeti)
	get_viewport().size_changed.connect(_update_aspect)
	_build_menu()
	_build_fade()   # girdap geçişi ÖNCE eklenir → CRT'nin ALTINDA kalır
	# BackBufferCopy: CRT'nin, girdabın ÇIKTISINI örneklemesini garantiler (iki screen-texture
	# shader üst üste → üstteki alttakini görsün diye aralarına taze backbuffer kopyası şart).
	var bb := BackBufferCopy.new()
	bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	bb.z_index = 1000  # CRT'nin (1001) hemen altında → tüm yüksek-z içeriği taze kopyalar
	add_child(bb)
	_add_crt()      # CRT EN ÜSTTE: girdap dahil her şeyi post-process eder (geçişte kaybolmaz)
	_update_aspect()
	game.visible = false
	background.visible = false  # başlangıçta menü açık → oyun girdabı render olmasın
	menu_root.visible = true
	game.request_menu.connect(_on_request_menu)  # kazan/kaybet → ana menü
	game.music_state.connect(_on_music_state)    # boss/dükkan/normal → müzik geçişi

	var args := OS.get_cmdline_user_args()
	var capturing := args.has("--capture")
	# Demo bayraklarından biri var mı? (capture'sız CANLI gösterim için de kullanılır)
	var has_demo := false
	for f in ["--demo", "--play", "--shop", "--lose", "--enh", "--boss", "--jokers", "--enhpick", "--cashout", "--refill", "--blind"]:
		if args.has(f):
			has_demo = true

	# Demo akışı: capture modunda VEYA capture'sız canlı (--menu hariç) çalışır → oyun açılır, kapanmaz.
	if (capturing and not args.has("--menu")) or (has_demo and not capturing):
		_reveal_game()
		if args.has("--demo") or args.has("--play"):
			game.demo_select_valid()
		if args.has("--play"):
			await get_tree().create_timer(0.3).timeout
			game.demo_play()
		if args.has("--shop"):
			game.demo_open_shop()
		if args.has("--lose"):
			game.demo_open_lose()
		if args.has("--enh"):
			game.demo_enhance()
		if args.has("--boss"):
			game.demo_boss()
		if args.has("--jokers"):
			game.demo_jokers()
		if args.has("--enhpick"):
			game.demo_enh_picker()
		if args.has("--cashout"):
			game.demo_cash_out()
		if args.has("--refill"):
			game.demo_play_refill()
		if args.has("--blind"):
			game.demo_blind_select()

	if capturing:
		if args.has("--settings"):
			_on_settings_pressed()
		var wait := 4.0 if args.has("--late") else 1.4
		await get_tree().create_timer(wait).timeout
		var img := get_viewport().get_texture().get_image()
		print("capture_result=", img.save_png("res://capture.png"))
		get_tree().quit()
		return

	if has_demo:
		return  # canlı demo açıldı (menüye düşme / menü müziği başlatma)

	# Normal akış: menü görünür + müzik çalar.
	_play_music()

# ── Ana menü kurulumu ──
func _build_menu() -> void:
	menu_root = Control.new()
	menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(menu_root)

	# Balatro tarzı akışkan boya arka plan (balatro_bg shader) — KENDİ sıcak paletimizle:
	# lav-kırmızı ↔ altın, derin koyu keçe. (Balatro'nun kırmızı/mavisi değil, bizim tarzımız.)
	menu_bg = ColorRect.new()
	menu_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_bg.color = Color.WHITE  # shader COLOR'u yazar
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/balatro_bg.gdshader")
	mat.set_shader_parameter("colour_1", Color("9c3b2e"))   # MAT tuğla kırmızı (lav, daha az parlak)
	mat.set_shader_parameter("colour_2", Color("2a2a30"))   # CHARCOAL (altın yerine)
	mat.set_shader_parameter("colour_3", Color("0d0a0a"))   # derin koyu warm
	mat.set_shader_parameter("spin_rotation_speed", 1.0)
	mat.set_shader_parameter("move_speed", 4.0)            # sakin akış
	mat.set_shader_parameter("contrast", 2.6)             # daha az kontrast = daha mat
	mat.set_shader_parameter("lighting", 0.22)            # düşük ışık = mat görünüm
	mat.set_shader_parameter("spin_amount", 0.26)
	mat.set_shader_parameter("is_rotating", true)
	menu_bg.material = mat
	menu_root.add_child(menu_bg)

	# BAŞLIK = harf taşları (WORDECK) — ayrı metin logo YOK (tekrar olmasın); taşlar logonun kendisi
	_build_hero()

	# ── ALT YATAY BUTON ÇUBUĞU (Balatro tarzı) ──
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 16)
	bar.offset_top = -116
	bar.offset_bottom = -38
	menu_root.add_child(bar)

	var play_btn := _bar_button("OYNA", T.CHIP, Color.WHITE)
	play_btn.pressed.connect(_on_play_pressed)
	bar.add_child(play_btn)
	var set_btn := _bar_button("AYARLAR", T.BRASS, T.INK)
	set_btn.pressed.connect(_on_settings_pressed)
	bar.add_child(set_btn)
	var coll_btn := _bar_button("KOLEKSİYON", T.LILAC, Color.WHITE)
	coll_btn.pressed.connect(_on_collection_pressed)
	bar.add_child(coll_btn)
	var rec_btn := _bar_button("REKORLAR", T.EMBER, T.INK)
	rec_btn.pressed.connect(_on_records_pressed)
	bar.add_child(rec_btn)
	var help_btn := _bar_button("NASIL OYNANIR", T.GOOD, T.INK)
	help_btn.pressed.connect(_on_help_pressed)
	bar.add_child(help_btn)
	var quit_btn := _bar_button("ÇIKIŞ", T.MULT, Color.WHITE)
	quit_btn.pressed.connect(_on_quit_pressed)
	bar.add_child(quit_btn)

	# Sürüm (sağ-üst) + atıf (sol-alt).
	var ver := _menu_label("v0.1 · erken erişim", 16, T.TEXT_DIM)
	ver.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver.offset_left = -260
	ver.offset_right = -16
	ver.offset_top = 12
	menu_root.add_child(ver)

	var credit := _menu_label("müzik: alexrockbeat · yazı tipi: m6x11 / Daniel Linssen", 14, T.TEXT_DIM)
	credit.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	credit.offset_left = 18
	credit.offset_top = -26
	credit.offset_right = 600
	menu_root.add_child(credit)

func _bar_button(text: String, bg: Color, fg: Color) -> Button:
	var b := _menu_button(text, bg, fg)
	b.custom_minimum_size = Vector2(0, 66)
	b.add_theme_font_size_override("font_size", 28)
	# Tüm durumlarda aynı iç boşluk (hover'da boyut zıplamasın)
	for st in [["normal", bg], ["hover", bg.lightened(0.1)], ["pressed", bg]]:
		var sb := T.button_filled(st[1]) if st[0] != "pressed" else T.button_pressed(bg)
		sb.content_margin_left = 26
		sb.content_margin_right = 26
		b.add_theme_stylebox_override(st[0], sb)
	return b

func _menu_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", T.load_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", T.OUTLINE)
	l.add_theme_constant_override("outline_size", 4)
	return l

# ── REKORLAR ekranı (alt çubuk butonu) ──
func _on_records_pressed() -> void:
	_build_records()
	records_overlay.visible = true

func _build_records() -> void:
	if records_overlay and is_instance_valid(records_overlay):
		records_overlay.queue_free()
	records_overlay = Control.new()
	records_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(records_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	records_overlay.add_child(dim)

	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	records_overlay.add_child(cc)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", T.felt_panel(T.SIDEBAR, T.BRASS, 18))
	cc.add_child(panel)

	var pad := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(m, 24)
	panel.add_child(pad)

	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(520, 0)
	vb.add_theme_constant_override("separation", 14)
	pad.add_child(vb)

	vb.add_child(_menu_label("🏆 REKORLAR", 40, T.EMBER))

	if Records.best_score <= 0:
		var none := _menu_label("Henüz rekor yok.\nBir run tamamla, burada belirsin!", 22, T.TEXT_DIM)
		vb.add_child(none)
	else:
		var best_val := "%d" % Records.best_score
		if Records.best_word != "":
			best_val += "  (%s)" % Records.best_word
		for row in [
				["En İyi El", best_val, T.BRASS],
				["En İleri Bölüm", "%d / 8" % Records.furthest_ante, T.ORANGE],
				["Galibiyet", "%d" % Records.wins, T.GOOD],
				["Oynanan Run", "%d" % Records.runs, T.CHIP_BADGE]]:
			vb.add_child(_record_row(row[0], row[1], row[2]))

	var close := _bar_button("KAPAT", T.BRASS, T.INK)
	close.pressed.connect(func(): if records_overlay: records_overlay.visible = false)
	vb.add_child(close)

# Rekor satırı: koyu inset, solda etiket + sağda renkli değer.
func _record_row(caption: String, value: String, color: Color) -> Control:
	var p := PanelContainer.new()
	var sb := T.felt_panel(T.FELT_800, T.LINE, 10)
	p.add_theme_stylebox_override("panel", sb)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 14)
	pad.add_theme_constant_override("margin_right", 14)
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_bottom", 8)
	p.add_child(pad)
	var h := HBoxContainer.new()
	pad.add_child(h)
	var cap := _menu_label(caption, 22, T.TEXT_DIM)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(cap)
	var val := _menu_label(value, 24, color)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(val)
	return p

func _menu_button(text: String, bg: Color, fg: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(360, 68)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", T.load_font())
	b.add_theme_font_size_override("font_size", 34)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_outline_color", T.OUTLINE)
	b.add_theme_constant_override("outline_size", 4)
	b.add_theme_stylebox_override("normal", T.button_filled(bg))
	b.add_theme_stylebox_override("hover", T.button_filled(bg.lightened(0.10)))
	b.add_theme_stylebox_override("pressed", T.button_pressed(bg))
	return b

# Menü içeriği için yarı saydam koyu çerçeve (odak + derinlik).
func _menu_backdrop() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.05, 0.01, 0.01, 0.42)
	s.set_corner_radius_all(26)
	s.set_border_width_all(2)
	s.border_color = Color(T.BRASS.r, T.BRASS.g, T.BRASS.b, 0.45)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 18
	return s

# ── BAŞLIK = GLYPHIX logosu (hafif bükeylik + nefes + motion blur + gölge) ──
func _build_hero() -> void:
	hero = Control.new()
	hero.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hero.offset_top = -20   # ekran ortasına yakın (artık çok yukarıda değil); butonlar altta
	hero.offset_bottom = -20
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_root.add_child(hero)

	var tex: Texture2D = game._load_png("res://assets/images/glyphix.png")
	if tex == null:
		return   # logo yüklenemediyse menü logosuz açılır (çökme yok)
	var lw := 680.0   # daha büyük başlık
	var lh := lw * 1277.0 / 3001.0   # logonun gerçek oranı (UV temiz eşlensin → warp düzgün)
	var pos := Vector2(-lw * 0.5, -lh * 0.5)  # merkeze

	# GÖLGE (arkada): YUMUŞAK disk-blur'lu koyu silüet (keskin kopya değil) — ayrı gölge shader'ı,
	# ama AYNI warp parametreleriyle → logoyla hizalı bükülür.
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/logo_shadow.gdshader")
	var shadow := _logo_rect(tex, lw, lh, sm)
	shadow.position = pos + Vector2(7, 12)
	shadow.set_meta("by", shadow.position.y)
	hero.add_child(shadow)

	# ANA LOGO (önde) — warp + motion blur + matlık
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/logo_fx.gdshader")
	var logo := _logo_rect(tex, lw, lh, m)
	logo.position = pos
	logo.set_meta("by", logo.position.y)
	hero.add_child(logo)

func _logo_rect(tex: Texture2D, lw: float, lh: float, m: ShaderMaterial) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE  # texture doğal boyutunu DAYATMASIN (yoksa dev olur)
	r.size = Vector2(lw, lh)
	r.custom_minimum_size = Vector2(lw, lh)
	r.pivot_offset = Vector2(lw * 0.5, lh * 0.5)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.material = m
	return r

func _process(_delta: float) -> void:
	# GLYPHIX logosu + gölgesi hafifçe süzülür/sallanır (birlikte → offset korunur).
	if hero == null or menu_root == null or not menu_root.visible:
		return
	var tt := Time.get_ticks_msec() / 1000.0
	var bob := sin(tt * 1.1) * 6.0
	var rot := sin(tt * 0.6) * deg_to_rad(0.9)  # çok hafif sallanma
	for i in hero.get_child_count():
		var c: Control = hero.get_child(i)
		c.position.y = float(c.get_meta("by", 0.0)) + bob
		c.rotation = rot

# ── Siyah geçiş katmanı ──
func _build_fade() -> void:
	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0.02, 0.01, 0.0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Girdap/karadelik geçişi: ekran burgulanıp merkeze çekilerek siyaha çöker
	_fade_mat = ShaderMaterial.new()
	_fade_mat.shader = load("res://shaders/vortex_transition.gdshader")
	_fade_mat.set_shader_parameter("progress", 0.0)
	fade.material = _fade_mat
	fade.visible = false  # boştayken kapalı (her kare ekran örneklemesin)
	add_child(fade)  # CRT'den ÖNCE → CRT girdabın üstünde kalır (geçişte CRT kaybolmaz)

func _set_fade_progress(v: float) -> void:
	if _fade_mat != null:
		_fade_mat.set_shader_parameter("progress", v)

# ── Akış: menü → oyun ──
func _on_play_pressed() -> void:
	# 1) Girdaba çekil (+ müziği kıs) → 2) sahneyi değiştir → 3) girdaptan oyuna çık.
	# Kara deliğe çekiliş (içerik merkeze akar → siyah)
	fade.material = _fade_mat
	_set_fade_progress(0.0)
	fade.modulate.a = 1.0
	fade.visible = true
	var tw := create_tween()
	tw.tween_method(_set_fade_progress, 0.0, 1.0, 1.05).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	if music and music.playing:
		tw.parallel().tween_property(music, "volume_db", -40.0, 1.05)
	await tw.finished
	if music:
		music.stop()
	_play_game_music()  # oyuna girince 8-bit müzik başlar
	_reveal_game()
	game.enter_session()
	# kısa bekleme: kartlar desteden gelmeye başlasın, sonra YUMUŞAK fade-in ile aç
	await get_tree().create_timer(0.12).timeout
	_reveal_from_black(0.9)

func _reveal_game() -> void:
	menu_root.visible = false
	game.visible = true
	background.visible = true  # oyun girdabı yalnız oyunda render olsun (menüde menü bg örtüyordu → boşa)

# Oyundan (kazan/kaybet ekranı) ana menüye dönüş — girdap geçiş + müzik.
func _on_request_menu() -> void:
	fade.material = _fade_mat
	_set_fade_progress(0.0)
	fade.modulate.a = 1.0
	fade.visible = true
	var tw := create_tween()
	tw.tween_method(_set_fade_progress, 0.0, 1.0, 0.95).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	await tw.finished
	game.visible = false
	background.visible = false  # menüde oyun girdabı render olmasın (menü bg örtüyor → görünmez kazanç)
	menu_root.visible = true
	menu_root.modulate.a = 1.0
	_stop_game_music()  # oyun müziğini durdur, menü müziğine dön
	if music:
		music.play()
	else:
		_play_music()
	_reveal_from_black(0.85)

# TERS kara delik: yeni ekran girdaptan açılarak gelir (progress 1→0). Düz siyah yok.
func _reveal_from_black(dur: float) -> void:
	await get_tree().process_frame  # yeni ekran bir kare otursun (warp'ı temiz örneklesin)
	var tw := create_tween()
	tw.tween_method(_set_fade_progress, 1.0, 0.0, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	fade.visible = false
	_set_fade_progress(0.0)
	fade.modulate.a = 1.0

func _on_quit_pressed() -> void:
	get_tree().quit()

# ── Nasıl oynanır overlay ──
func _on_help_pressed() -> void:
	if help_overlay == null:
		_build_help()
	help_overlay.visible = true

func _build_help() -> void:
	help_overlay = Control.new()
	help_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(help_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	help_overlay.add_child(dim)

	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	help_overlay.add_child(cc)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", T.felt_panel(T.SIDEBAR, T.BRASS, 18))
	cc.add_child(panel)

	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(680, 0)
	vb.add_theme_constant_override("separation", 16)
	panel.add_child(vb)

	vb.add_child(_menu_label("NASIL OYNANIR", 40, T.EMBER))

	var body := Label.new()
	body.text = RULES_TEXT
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_override("font", T.load_font())
	body.add_theme_font_size_override("font_size", 22)
	body.add_theme_color_override("font_color", T.TEXT)
	vb.add_child(body)

	var close := _menu_button("KAPAT", T.BRASS, T.INK)
	close.pressed.connect(func(): help_overlay.visible = false)
	vb.add_child(close)

# ── AYARLAR ──
func _on_settings_pressed() -> void:
	_build_settings()
	settings_overlay.visible = true

func _build_settings() -> void:
	if settings_overlay and is_instance_valid(settings_overlay):
		settings_overlay.queue_free()
	settings_overlay = Control.new()
	settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(settings_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	settings_overlay.add_child(dim)

	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_overlay.add_child(cc)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", T.felt_panel(T.SIDEBAR, T.BRASS, 18))
	cc.add_child(panel)

	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(560, 0)
	vb.add_theme_constant_override("separation", 16)
	panel.add_child(vb)

	vb.add_child(_menu_label("AYARLAR", 40, T.EMBER))
	vb.add_child(_setting_row("Müzik Sesi", _make_slider(Settings.music_vol, "music")))
	vb.add_child(_setting_row("Efekt Sesi", _make_slider(Settings.sfx_vol, "sfx")))
	vb.add_child(_setting_row("Ekran Sarsıntısı", _make_toggle(Settings.shake_on, "shake")))
	vb.add_child(_setting_row("Partiküller", _make_toggle(Settings.particles_on, "particles")))
	vb.add_child(_setting_row("Tam Ekran", _make_toggle(Settings.fullscreen, "fullscreen")))

	var close := _bar_button("KAPAT", T.BRASS, T.INK)
	close.pressed.connect(_on_close_settings)
	vb.add_child(close)

func _on_close_settings() -> void:
	if settings_overlay:
		settings_overlay.visible = false

# ── KOLEKSİYON (joker galerisi) ──
# Nadirlik gruplu, kaydırılabilir vitrin. Kartlar oyun-içi joker kartıyla AYNI görünür
# (art/amblem + foil), game.build_showcase_card ile üretilir → tek kaynak, sapma yok.
const _RARITY_ORDER := ["common", "uncommon", "rare", "legendary"]
const _RARITY_TR := {
	"common": "SIRADAN", "uncommon": "SIRA DIŞI", "rare": "NADİR", "legendary": "EFSANEVİ",
}

func _on_collection_pressed() -> void:
	_build_collection()
	collection_overlay.visible = true
	_animate_collection_in()

func _build_collection() -> void:
	if collection_overlay and is_instance_valid(collection_overlay):
		collection_overlay.queue_free()
	collection_overlay = Control.new()
	collection_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(collection_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.62)
	collection_overlay.add_child(dim)

	# Neredeyse tam ekran panel (62 kart için yer lazım) — kenarlarda nefes payı.
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(m, 70)
	for m in ["margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 44)
	collection_overlay.add_child(margin)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", T.felt_panel(T.SIDEBAR, T.BRASS, 18))
	margin.add_child(panel)

	var pad := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(m, 24)
	panel.add_child(pad)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	pad.add_child(vb)

	# ── Başlık şeridi: KOLEKSİYON + toplam sayaç + KAPAT ──
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	var title := _menu_label("KOLEKSİYON", 40, T.EMBER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.add_child(title)
	var jokers := Jokers.all()
	var count := _menu_label("%d JOKER" % jokers.size(), 24, T.TEXT_DIM)
	count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(count)
	var close := _bar_button("KAPAT", T.BRASS, T.INK)
	close.pressed.connect(_on_close_collection)
	head.add_child(close)
	vb.add_child(head)

	# ── Kaydırılabilir, nadirlik gruplu vitrin ──
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 22)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	# Jokerleri nadirliğe göre kümele (veri sırasını koru).
	var by_rarity := {}
	for j in jokers:
		var r := String(j.get("rarity", "common"))
		if not by_rarity.has(r):
			by_rarity[r] = []
		by_rarity[r].append(j)

	for rarity in _RARITY_ORDER:
		if not by_rarity.has(rarity):
			continue
		var group: Array = by_rarity[rarity]
		var accent: Color = T.RARITY.get(rarity, T.CARD_EDGE)
		# Bölüm başlığı: renkli nokta + nadirlik adı + adet
		var sec := HBoxContainer.new()
		sec.add_theme_constant_override("separation", 10)
		var dot := Panel.new()
		var ds := StyleBoxFlat.new()
		ds.bg_color = accent
		ds.set_corner_radius_all(9)
		dot.add_theme_stylebox_override("panel", ds)
		dot.custom_minimum_size = Vector2(18, 18)
		var dotwrap := CenterContainer.new()
		dotwrap.add_child(dot)
		sec.add_child(dotwrap)
		var sh := _menu_label("%s  ·  %d" % [_RARITY_TR.get(rarity, rarity), group.size()], 26, accent)
		sh.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		sec.add_child(sh)
		list.add_child(sec)
		# Kartlar — otomatik sarmalı akış
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 16)
		flow.add_theme_constant_override("v_separation", 18)
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for j in group:
			flow.add_child(_collection_cell(j))
		list.add_child(flow)

func _collection_cell(joker: Dictionary) -> Control:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 5)
	cell.custom_minimum_size = Vector2(150, 0)
	cell.add_child(game.build_showcase_card(joker))  # oyun-içiyle birebir aynı kart görseli
	var nm := _menu_label(String(joker.get("name", "?")), 17, T.TEXT)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size = Vector2(150, 0)
	cell.add_child(nm)
	return cell

func _animate_collection_in() -> void:
	collection_overlay.modulate.a = 0.0
	await get_tree().process_frame  # layout otursun → pivot/size geçerli
	if not is_instance_valid(collection_overlay):
		return
	var panel: Control = collection_overlay.get_child(1)  # MarginContainer (panel sarmalayıcı)
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.965, 0.965)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(collection_overlay, "modulate:a", 1.0, 0.16)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_close_collection() -> void:
	if collection_overlay:
		collection_overlay.visible = false

func _setting_row(label_text: String, control: Control) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	var l := _menu_label(label_text, 22, T.TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(control)
	return h

func _make_slider(value: float, kind: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(220, 26)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var vl := _menu_label("%d%%" % int(round(value * 100.0)), 18, T.BRASS)
	vl.custom_minimum_size = Vector2(64, 0)
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	s.value_changed.connect(_on_slider_changed.bind(kind, vl))
	h.add_child(s)
	h.add_child(vl)
	return h

func _on_slider_changed(v: float, kind: String, vl: Label) -> void:
	vl.text = "%d%%" % int(round(v * 100.0))
	if kind == "music":
		Settings.music_vol = v
	elif kind == "sfx":
		Settings.sfx_vol = v
	Settings.apply_audio()
	Settings.save()

func _make_toggle(value: bool, kind: String) -> Button:
	var b := _menu_button("AÇIK" if value else "KAPALI", T.GOOD if value else T.FELT_700, T.INK)
	b.custom_minimum_size = Vector2(150, 50)
	b.add_theme_font_size_override("font_size", 24)
	b.set_meta("val", value)
	b.set_meta("kind", kind)
	b.pressed.connect(_on_toggle_pressed.bind(b))
	return b

func _on_toggle_pressed(b: Button) -> void:
	var nv := not bool(b.get_meta("val"))
	b.set_meta("val", nv)
	b.text = "AÇIK" if nv else "KAPALI"
	b.add_theme_stylebox_override("normal", T.button_filled(T.GOOD if nv else T.FELT_700))
	b.add_theme_stylebox_override("hover", T.button_filled((T.GOOD if nv else T.FELT_700).lightened(0.1)))
	match String(b.get_meta("kind")):
		"shake": Settings.shake_on = nv
		"particles": Settings.particles_on = nv
		"fullscreen":
			Settings.fullscreen = nv
			Settings.apply_video()
	Settings.save()

# Global kısayol: F11 veya Alt+Enter ile her yerden tam ekran aç/kapa (ayarla senkron).
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_F11 or (k.keycode == KEY_ENTER and k.alt_pressed):
			Settings.fullscreen = not Settings.fullscreen
			Settings.apply_video()
			Settings.save()
			get_viewport().set_input_as_handled()

# ── Müzik ──
func _play_music() -> void:
	music = _make_music("res://assets/sounds/alexrockbeat_this-sport_main-01_full.wav", -4.0)
	music.play()

# Loop'lu müzik player'ı üret (WAV ham bayttan; bus=Music → Ayarlar sesi kontrol eder).
func _make_music(path: String, vol: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	add_child(p)
	# Loop import seviyesinde ayarlı (edit/loop_mode=1); load() loop'lu stream döndürür.
	var stream: AudioStream = game._load_wav(path)
	p.stream = stream
	p.bus = "Music"
	p.volume_db = vol
	return p

# Oyun-içi müzik: durum tabanlı, cross-fade'li (menüden ayrı; menüye dönünce durur).
# Durum→dosya eşlemesi. Boss/dükkan dosyaları HENÜZ yoksa "normal"e düşülür (aşağıya bak).
const GAME_TRACKS := {
	"normal": "res://assets/sounds/8-bit Game Music.wav",
	"boss":   "res://assets/sounds/music_arcade.mp3",  # 8-Bit Arcade (gergin arcade)
	"shop":   "res://assets/sounds/music_shop.mp3",    # 8-bit oyun müziği 25 sn versiyonu (sakin dükkan)
}
const GAME_TRACK_VOL := {"normal": -6.0, "boss": -5.0, "shop": -8.0}

func _ensure_game_music() -> void:
	if not _gm_players.is_empty():
		return
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -40.0
		add_child(p)
		_gm_players.append(p)

# Dosya yoksa "normal"e düş → bir durumun parçası eksikse oyun sessiz kalmaz.
# MP3 ham bayttan yüklenir (editör import'u gerekmez); WAV import'lu olduğu için ResourceLoader.
func _resolve_track(state: String) -> String:
	var path: String = GAME_TRACKS.get(state, GAME_TRACKS["normal"])
	var ok := FileAccess.file_exists(path) if path.to_lower().ends_with(".mp3") else ResourceLoader.exists(path)
	return path if ok else GAME_TRACKS["normal"]

# Müzik parçasını yükle: MP3 → ham bayttan AudioStreamMP3 (loop'lu, import'suz; bkz. _load_png
# felsefesi — bu makinede editör import'u çöküyor). WAV → mevcut import'lu yükleyici.
func _load_music_track(path: String) -> AudioStream:
	if path.to_lower().ends_with(".mp3"):
		if not FileAccess.file_exists(path):
			return null
		var s := AudioStreamMP3.new()
		s.data = FileAccess.get_file_as_bytes(path)
		s.loop = true
		return s
	return game._load_wav(path)

# Oyun-içi müzik durumunu ayarla → yumuşak cross-fade. Aynı dosya zaten çalıyorsa
# (ör. boss dosyası yoksa boss→normal aynı parçada kalır) kesintisiz devam eder.
func set_game_music_state(state: String) -> void:
	_gm_state = state
	_ensure_game_music()
	var path := _resolve_track(state)
	if path == _gm_path and _gm_players[_gm_active].playing:
		return  # aynı dosya zaten çalıyor → restart yok, kesinti yok
	var stream: AudioStream = _load_music_track(path)
	if stream == null:
		return
	var vol: float = GAME_TRACK_VOL.get(state, -6.0)
	var nxt := 1 - _gm_active
	var newp := _gm_players[nxt]
	var oldp := _gm_players[_gm_active]
	newp.stream = stream
	newp.volume_db = -40.0
	newp.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(newp, "volume_db", vol, 0.8).set_trans(Tween.TRANS_SINE)
	if oldp.playing:
		tw.tween_property(oldp, "volume_db", -40.0, 0.8).set_trans(Tween.TRANS_SINE)
		tw.chain().tween_callback(oldp.stop)
	_gm_active = nxt
	_gm_path = path

func _stop_game_music() -> void:
	for p in _gm_players:
		p.stop()
	_gm_state = ""
	_gm_path = ""

# game.gd music_state sinyali → durum geçişi (boss/shop/normal).
func _on_music_state(state: String) -> void:
	set_game_music_state(state)

# Oyuna girişte müzik başlat (normal durum).
func _play_game_music() -> void:
	set_game_music_state("normal")

# ── CRT + arka plan ──
func _add_crt() -> void:
	# CRT overlay — en üstte (Background+Game+menu'den SONRA) → screen texture'ı örnekler.
	var crt := ColorRect.new()
	crt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# EN ÜST z_index: dükkan perdesi (z=95), overlay (z=100) gibi yüksek-z öğeler bile
	# CRT'yi örtmesin (z_index ağaç sırasını ezer → CRT hepsinin üstünde kalmalı).
	crt.z_index = 1001
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/crt.gdshader")
	crt.material = mat
	add_child(crt)

func _update_aspect() -> void:
	var size := get_viewport().get_visible_rect().size
	var aspect: float = size.x / max(size.y, 1.0)
	if background and background.material is ShaderMaterial:
		(background.material as ShaderMaterial).set_shader_parameter("aspect", aspect)
	if menu_bg and menu_bg.material is ShaderMaterial:
		(menu_bg.material as ShaderMaterial).set_shader_parameter("aspect", aspect)
