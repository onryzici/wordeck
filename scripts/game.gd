extends Control
# Oyun denetleyicisi — iki sütun düzen + JUICE (yanan/dönen canlı his).
# Mantık engine'de; bu katman okur/çizer/girişi iletir + animasyon oynatır.

const State = preload("res://engine/state.gd")
const Round = preload("res://engine/round.gd")
const Config = preload("res://data/config.gd")
const JokerActions = preload("res://engine/joker_actions.gd")
const Jokers = preload("res://data/jokers.gd")
const Shop = preload("res://engine/shop.gd")
const Economy = preload("res://engine/economy.gd")
const Enhancements = preload("res://data/enhancements.gd")
const Settings = preload("res://scripts/settings.gd")
const Bosses = preload("res://data/bosses.gd")
const Blinds = preload("res://data/blinds.gd")
const FlameBlock = preload("res://scripts/flame_block.gd")
const JokerCard = preload("res://scripts/joker_card.gd")
const TileCard = preload("res://scripts/tile_card.gd")
const Dictionary_ = preload("res://engine/dictionary.gd")
const Scoring = preload("res://engine/scoring.gd")
const WordTiers = preload("res://data/word_tiers.gd")
const LETTER_VALUES = preload("res://data/letter_values.gd")
const T = preload("res://scripts/theme.gd")

const TILE_W := 124
const TILE_H := 166
const TILE_GAP := 14
const LIFT := 32
const DECK_RESERVE := 140.0  # sağda deste yığını için ayrılan pay (el onun SOLUNA ortalanır)
const MAX_JOKERS := 5

signal request_menu  # main.gd dinler → ana menüye dön (kazan/kaybet ekranından)

var state: Dictionary
var selected_ids: Array = []
var hand_cards_by_id: Dictionary = {}
var tile_by_id: Dictionary = {}
var _busy := false
var _flame_on := false  # çip/çarpan alevi yalnız OYNA'dan sonra yanar (önizlemede değil)
var _pulse_tween: Tween = null
var _spark_tex: Texture2D
var _tile_font: FontFile
var _add_mat: CanvasItemMaterial
# Paket açma sekansı varlıkları (lazy — ilk paket açılışında kurulur)
var _atmo_shader: Shader = null
var _dissolve_shader: Shader = null
var _tilt_shader: Shader = null
var _dissolve_noise: NoiseTexture2D = null
var deck_holder: Control
var _sfx: AudioStreamPlayer
var _shuffle: AudioStream
var _ui_sfx: AudioStreamPlayer   # kart-seçme gibi kısa UI sesleri (shuffle'ı kesmesin)
var _card_move: AudioStream
var _blink: AudioStream           # puan gelirken harf "blink" sesi (kullanıcı ekledi)
var _coin_sfx: AudioStreamPlayer # puan toplama (collect) tıkları
var _collect: AudioStream        # tek puan varış tık'ı (prosedürel coin)
var _collect_big: AudioStream    # final toplam çan'ı (prosedürel)
var _coin_idx := 0               # ardışık coin → yükselen perde
var _bam := 0                    # ardışık katkı (op) → yükselen perdeli "bam"

# UI refs (sol panel)
var blind_header: Label
var _head_panel: PanelContainer  # blind ismi kutusu (shop modunda SHOP marquee olur)
var _head_sb_normal: StyleBox    # normal (brass) head stylebox — restore için
var _target_box: Control         # Hedef kutusu (shop modunda gizlenir)
var target_label: Label
var target_reward_label: Label   # Hedef kutusu "Ödül: $$$"
var blind_chip: Panel            # blind çipi (tür rengine göre renkli yuvarlak)
var blind_chip_icon: Label
var _chip_sb: StyleBoxFlat       # blind çipi stylebox (renk güncellenir)
var round_score_label: Label
var deck_count_label: Label
var tier_label: RichTextLabel  # kelime-tipi etiketi — dalgalı (Meksika dalgası) + belirir/kaybolur
var _tier_shown := false        # etiket şu an görünür mü (giriş/çıkış animasyonu için)
var chip_value: Label
var mult_value: Label
var _seal_cd_tw: Tween           # çip×çarpan "geriye sayarak sıfırlanma" tween'i (yeni el)
var chip_seal_panel: Control
var mult_seal_panel: Control
var plays_value: Label
var discards_value: Label
var _prev_plays := -1       # -1 azalma animasyonu için son değer
var _prev_discards := -1
var money_label: Label
var ante_label: Label
var round_value: Label
# sağ alan
var word_label: Label
var hint_label: Label
var word_panel: PanelContainer  # kelime tepsisi (geçerlide yeşil parıltı)
var boss_panel: PanelContainer  # patron turunda kısıtlama (SOL panelde)
var boss_name_label: Label
var boss_desc_label: Label
var _sidebar_sb: StyleBoxFlat    # sol panel arka stylebox (palete göre renklenir)
var _themed_sbs: Array = []      # palete göre renklenen iç paneller (stat/skor kutuları)
var _cur_themed: Color = Color("13362b")  # son uygulanan iç-panel tonu (FELT_800)
var _palette_tween: Tween
var _pal_mat: ShaderMaterial
var _pal_from: Array = []
var _pal_to: Array = []
var info_btn: Button
var menu_btn: Button
var hand_area: Control
var joker_box: HBoxContainer
var joker_caption: Label
var play_btn: Button
var disc_btn: Button
var shuffle_btn: Button
var _shuffle_sb: StyleBoxFlat     # yuvarlak shuffle butonu dolgusu (tur rengine göre renklenir)
var _shuffle_hover_sb: StyleBoxFlat   # hover (açılmış + büyük gölge)
var _shuffle_pressed_sb: StyleBoxFlat # basılı (koyu + küçük gölge)
var _shuffle_icon: TextureRect    # pixel-art shuffle ikonu
# ── Öğretici (ilk giriş, etkileşimli; ikon YOK, balon bağlamsal konumlanır) ──
signal _tut_continue              # bilgi balonunda İLERİ/ATLA → bekleyen postplay'i serbest bırak
var _tut_active := false
var _tut_mode := ""               # "blind" / "word" / "play" (gated faz hangi olayı bekliyor)
var _tut_layer: Control          # spotlight çerçeveleri + balon paneli
var _tut_frames: Array = []       # spotlight cutout: 4 kenar ColorRect (üst/alt/sol/sağ)
var _tut_panel: PanelContainer    # konuşma balonu (bağlamsal konumlanır)
var _tut_bubble_label: Label
var _tut_next_btn: Button
# efekt katmanı + sarsıntı kabı
var fx_layer: Node2D
var shaker: Control

# ── Trauma-tabanlı ekran sarsıntısı (Balatro hissi: trauma² × noise, zamanla decay) ──
# Olaylar trauma EKLER (_add_trauma); _process her kare offset uygular ve trauma'yı söndürür.
# Rastgele jitter DEĞİL — FastNoiseLite ile pürüzsüz, yönlü titreşim.
var _trauma := 0.0
var _shake_noise: FastNoiseLite
var _noise_t := 0.0
const SHAKE_MAX_OFFSET := 24.0  # trauma=1'de en büyük piksel kayması
const TRAUMA_DECAY := 1.7       # saniyedeki sönme hızı
const SHAKE_NOISE_SPEED := 16.0 # titreşim frekansı (gürültü örnekleme hızı)
# Katmanlı trauma şiddetleri (küçük→orta→büyük). Tek yerden ayarlanır.
const TRAUMA_TILE := 0.13   # normal harf taşı tetiklenince
const TRAUMA_CHIP_OP := 0.09  # çip katkısı (foil vb.)
const TRAUMA_MULT_OP := 0.34  # çarpan katkısı (joker/holo) — orta kick
const TRAUMA_COLLIDE := 0.55  # çip×çarpan çarpışması

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = T.make_theme(T.load_font())
	_tile_font = T.load_font()  # pixel font + outline (prompt: bold pixel everywhere)
	_spark_tex = _make_spark_tex()
	_shake_noise = FastNoiseLite.new()
	_shake_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_shake_noise.frequency = 1.0
	_add_mat = CanvasItemMaterial.new()
	_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	Settings.init()  # ses bus'ları + kalıcı ayarlar (idempotent; main de çağırır)
	_sfx = AudioStreamPlayer.new()
	_sfx.bus = "SFX"
	add_child(_sfx)
	_ui_sfx = AudioStreamPlayer.new()
	_ui_sfx.bus = "SFX"
	add_child(_ui_sfx)
	_coin_sfx = AudioStreamPlayer.new()
	_coin_sfx.bus = "SFX"
	add_child(_coin_sfx)
	_shuffle = _load_wav("res://assets/sounds/Thin Metal Card Deck Shuffle.wav")
	_card_move = _load_wav("res://assets/sounds/card move sound.wav")
	_blink = _load_wav("res://assets/sounds/Short Triple Blink Notification.wav")
	_collect = _make_tone_wav([880.0, 1320.0], 0.12, 16.0, 0.5)        # kısa coin tık'ı
	_collect_big = _make_tone_wav([660.0, 880.0, 1100.0, 1320.0], 0.34, 7.0, 0.55)  # final çan/arp
	Dictionary_.load_from_file("res://data/kelimeler.txt")
	_init_run()
	_build_ui()
	_refresh(false, false)  # menü açıkken sessiz/statik; OYNA → enter_session() canlandırır

# Taze RASTGELE seed'li yeni run kurar (her oyunda farklı kartlar). UI'ye dokunmaz.
func _init_run() -> void:
	randomize()
	var seed_str := "run-%s-%d" % [str(Time.get_unix_time_from_system()), randi()]
	state = State.create_state(seed_str)
	Round.start_run(state)
	for jid in Config.STARTING_JOKERS:  # başlangıç jokeri (şu an boş; denge için, bkz. sim)
		JokerActions.add_joker_by_id(state, jid)

# Menüden OYNA'ya geçince: TAZE run (yeni seed → yeni kartlar) + desteden geliş + shuffle sesi.
func enter_session() -> void:
	_tut_reset()  # önceki (yarım bırakılmış) öğretici kalıntısını temizle
	_reset_to_play_view()
	_init_run()
	_reset_flames()
	_animate_jokers = true  # oyuna girişte jokerler (varsa) canlı gelsin
	_refresh_hud()          # sol panel/joker (el SEÇ'te dağıtılır)
	_open_blind_select()    # önce blind seçim ekranı (Balatro)
	if not Settings.tutorial_done:
		await get_tree().create_timer(1.2).timeout  # giriş vortex'i bitsin, sonra öğretici (çakışmasın)
		if _tut_layer == null and not Settings.tutorial_done:
			_tut_start()    # ilk giriş → etkileşimli öğretici

# Alev değere göre yanar ama yalnız OYNA sonrası (_flame_on). Tur başında söndür.
func _reset_flames() -> void:
	_flame_on = false

func _set_seal_flame(_seal, _on: bool) -> void:
	pass

# Sıvı yüzeyin DALGA şiddetini (wobble_amp) değere göre yumuşakça sürer (canlı: değer = kaynama).
# Sakin bir taban hep vardır; OYNA sonrası değer büyüdükçe yüzey daha çok kaynar.
func _drive_seal_flame(seal) -> void:
	if not (seal and is_instance_valid(seal) and seal.has_meta("crown")):
		return
	var crown: ColorRect = seal.get_meta("crown")
	var lbl: Label = seal.get_meta("val_label")
	if lbl == null or not is_instance_valid(lbl):
		return
	var val := float(lbl.text) if lbl.text.is_valid_float() else 0.0
	var ref: float = seal.get_meta("val_ref", 90.0)
	# Alev YALNIZCA puan alırken (OYNA sonrası, _flame_on) belirir; normalde 0 (kutu sade).
	var target := 0.0
	if _flame_on and val > 1.0:
		target = clampf(0.68 + (val / ref) * 0.45, 0.0, 1.0)  # daha YÜKSEK/dolgun alev
	var cur: float = seal.get_meta("flame_i", 0.0)
	# Yükselirken çabuk, SÖNERKEN yavaş → "yavaşça sönüyor" hissi (ani gitmez)
	var rate := 0.12 if target > cur else 0.035
	cur = lerpf(cur, target, rate)
	if cur < 0.008:
		cur = 0.0  # tamamen sön (ani zıplama yok)
	seal.set_meta("flame_i", cur)
	(crown.material as ShaderMaterial).set_shader_parameter("intensity", cur)

# Dükkân/bitiş ekranından oyun görünümüne sıfırla.
func _reset_to_play_view() -> void:
	_shop_mode = false
	if shop_view:
		shop_view.visible = false
	if blind_view:
		blind_view.visible = false
	if play_view:
		play_view.visible = true
	if deck_holder:
		deck_holder.visible = true  # oyun alanına dönünce deste yine görünür
	_close_overlay()

# ── Düzen ──
func _build_ui() -> void:
	shaker = Control.new()
	shaker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shaker)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 22)
	shaker.add_child(margin)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 22)
	margin.add_child(cols)

	cols.add_child(_build_left_panel())

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 14)
	right.add_child(_build_joker_shelf())  # üstte HER ZAMAN (oyun + dükkân)
	# Orta-alt alan: OYUN görünümü ↔ DÜKKÂN görünümü (Balatro: sol panel+joker kalır, orta değişir)
	play_view = VBoxContainer.new()
	play_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	play_view.add_theme_constant_override("separation", 14)
	play_view.add_child(_build_word_board())
	play_view.add_child(_build_hand_row())
	play_view.add_child(_build_action_row())
	right.add_child(play_view)
	shop_view = VBoxContainer.new()
	shop_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_view.add_theme_constant_override("separation", 12)
	shop_view.visible = false
	right.add_child(shop_view)
	blind_view = VBoxContainer.new()   # BLIND SEÇİM görünümü (tahta-içi, Balatro)
	blind_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	blind_view.add_theme_constant_override("separation", 10)
	blind_view.visible = false
	right.add_child(blind_view)
	cols.add_child(right)

	shaker.add_child(_build_deck_stack())

	fx_layer = Node2D.new()
	add_child(fx_layer)  # her şeyin üstünde

func _build_deck_stack() -> Control:
	var holder := Control.new()
	deck_holder = holder
	# Kenardan DAHA UZAK (kullanıcı: "çok sağa yapışık") + biraz yukarı.
	holder.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	holder.offset_left = -198
	holder.offset_top = -252
	holder.offset_right = -78
	holder.offset_bottom = -116
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Temiz 3 katmanlı kart-arkası yığını (köşegen kayık → derinlik); "W taşı" KALDIRILDI.
	var top_back: Panel = null
	for i in 3:
		var back := Panel.new()
		back.add_theme_stylebox_override("panel", T.card_back())
		back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		back.offset_left = i * 5
		back.offset_top = -i * 5
		back.offset_right = i * 5
		back.offset_bottom = -i * 5
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(back)
		top_back = back
	# Üst kart: ince iç altın çerçeve (sade, okunur kimlik)
	var inner := Panel.new()
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color(0, 0, 0, 0.0)
	isb.set_corner_radius_all(9)
	isb.set_border_width_all(2)
	isb.border_color = Color(T.BRASS.r, T.BRASS.g, T.BRASS.b, 0.7)
	inner.add_theme_stylebox_override("panel", isb)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 8
	inner.offset_top = 8
	inner.offset_right = -8
	inner.offset_bottom = -8
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_back.add_child(inner)
	# Sayaç ROZETİ — sağ-alt köşede pirinç pill (Balatro destesi gibi "32/52")
	var badge := PanelContainer.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.07, 0.06, 0.05, 0.95)
	bsb.set_corner_radius_all(11)
	bsb.set_border_width_all(2)
	bsb.border_color = T.BRASS
	bsb.content_margin_left = 10
	bsb.content_margin_right = 10
	bsb.content_margin_top = 2
	bsb.content_margin_bottom = 2
	badge.add_theme_stylebox_override("panel", bsb)
	badge.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	badge.offset_top = -22
	badge.offset_bottom = 16
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deck_count_label = _label("0/0", 19, T.BRASS, T.OUTLINE, 3)
	badge.add_child(deck_count_label)
	holder.add_child(badge)
	return holder

func _label(text: String, size: int, color: Color = T.TEXT, outline: Color = T.OUTLINE, outline_size: int = -1) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	var os := outline_size if outline_size >= 0 else maxi(3, int(size / 9.0))
	l.add_theme_constant_override("outline_size", os)
	l.add_theme_color_override("font_outline_color", outline)
	return l

func _center(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

# Her HARFİ bağımsız dalgalandıran yazı (Balatro tarzı — biri aşağı biri yukarı).
# RichTextLabel [wave] efektini kullanır (kendi kendine animasyonlu). Font default theme'den (m6x11).
func _wavy_label(text: String, size: int, color: Color = T.TEXT, outline: Color = T.OUTLINE, amp: float = 8.0, freq: float = 4.0, outline_size: int = -1) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.clip_contents = false  # dalga dikeyde taşınca kırpılmasın
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_color_override("default_color", color)
	r.add_theme_color_override("font_outline_color", outline)
	var os := outline_size if outline_size >= 0 else maxi(3, int(size / 9.0))
	r.add_theme_constant_override("outline_size", os)
	# connected=1 + düşük freq → PÜRÜZSÜZ akan dalga (connected=0 zıplamalı/tık-tık duruyordu)
	r.text = "[center][wave amp=%d freq=%.1f connected=1]%s[/wave][/center]" % [int(amp), freq, text]
	return r

# ── SOL panel ──
func _build_left_panel() -> Control:
	var outer := PanelContainer.new()
	_sidebar_sb = T.felt_panel(T.SIDEBAR, T.LINE, 18)
	outer.add_theme_stylebox_override("panel", _sidebar_sb)  # palete göre renklenir
	outer.custom_minimum_size = Vector2(384, 0)
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 11)
	outer.add_child(v)

	var head := PanelContainer.new()
	_head_panel = head
	_head_sb_normal = T.button_filled(T.BRASS)
	head.add_theme_stylebox_override("panel", _head_sb_normal)
	blind_header = _center(_label("TUR 1", 30, T.INK, Color(1, 1, 1, 0.25), 0))
	blind_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(blind_header)
	v.add_child(head)

	_target_box = _build_target_box()  # Balatro "Score at least / Reward" tarzı hedef kutusu
	v.add_child(_target_box)
	v.add_child(_build_boss_panel())  # patron kısıtlaması (sadece patron turunda görünür)

	var score_panel := PanelContainer.new()
	var score_sb := T.felt_panel(T.FELT_700, T.LINE, 14)
	_themed_sbs.append(score_sb)  # palete göre renklensin
	score_panel.add_theme_stylebox_override("panel", score_sb)
	# TUR SKORU: etiket + sayı YAN YANA (kullanıcı).
	var sp := HBoxContainer.new()
	sp.alignment = BoxContainer.ALIGNMENT_CENTER
	sp.add_theme_constant_override("separation", 12)
	var ts_cap := _wavy_label("TUR SKORU", 17, T.TEXT_DIM, T.OUTLINE, 4.0, 5.0)
	ts_cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sp.add_child(ts_cap)
	round_score_label = _label("0", 50, Color.WHITE, T.CHIP_BADGE, 6)
	round_score_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sp.add_child(round_score_label)
	score_panel.add_child(sp)
	v.add_child(score_panel)

	# Kademe (kelime tipi) + çip×çarpan → KENDİ ALANINDA (Balatro skor kutusu gibi, çevreli kutu)
	var score_area := PanelContainer.new()
	var area_sb := T.felt_panel(T.FELT_800, T.LINE, 16)
	area_sb.content_margin_left = 6
	area_sb.content_margin_right = 6
	area_sb.content_margin_top = 8
	area_sb.content_margin_bottom = 10
	_themed_sbs.append(area_sb)  # palete göre renklensin
	score_area.add_theme_stylebox_override("panel", area_sb)
	var av := VBoxContainer.new()
	av.add_theme_constant_override("separation", 6)
	score_area.add_child(av)

	# Kelime tipi/seviye — BEYAZ + büyük punto (kendi alanının başlığı gibi)
	# Dalgalı (Meksika dalgası) etiket — başta gizli (kelime seçilince yumuşakça belirir)
	tier_label = _wavy_label("—", 38, Color.WHITE, T.OUTLINE, 6, 3.0)
	tier_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tier_label.modulate.a = 0.0
	av.add_child(tier_label)

	var crown_gap := Control.new()  # alev tacı için küçük pay (skorda kutu üstünde belirir)
	crown_gap.custom_minimum_size = Vector2(0, 10)
	av.add_child(crown_gap)

	var seals := HBoxContainer.new()
	seals.add_theme_constant_override("separation", 6)
	seals.alignment = BoxContainer.ALIGNMENT_CENTER
	chip_value = _center(_label("0", 52, Color.WHITE, T.CHIP_BADGE, 6))
	mult_value = _center(_label("1", 52, Color.WHITE, T.MULT, 6))
	# Daha GENİŞ + daha ALÇAK kutular (kullanıcı isteği)
	chip_seal_panel = _seal(chip_value, T.CHIP, Vector2(150, 74), 90.0)
	mult_seal_panel = _seal(mult_value, T.MULT, Vector2(150, 74), 14.0)
	seals.add_child(chip_seal_panel)
	seals.add_child(_center(_label("×", 50, T.TEXT)))  # çarpı işareti
	seals.add_child(mult_seal_panel)
	av.add_child(seals)
	v.add_child(score_area)

	# Alt blok — referans: solda 2 chunky buton, sağda etiket+girintili-değer panelleri.
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(bottom)

	var btns := VBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	btns.custom_minimum_size = Vector2(106, 0)
	info_btn = _chunky_btn("BİLGİ", T.MULT, Color.WHITE)
	menu_btn = _chunky_btn("MENÜ", T.ORANGE, T.INK)
	info_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_btn.pressed.connect(_on_info_btn)
	menu_btn.pressed.connect(_on_menu_btn)
	btns.add_child(info_btn)
	btns.add_child(menu_btn)
	bottom.add_child(btns)

	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 10)
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom.add_child(stats)

	plays_value = _center(_label("4", 54, T.CHIP_BADGE, T.OUTLINE, 5))
	discards_value = _center(_label("3", 54, T.MULT, T.OUTLINE, 5))
	money_label = _center(_label("$4", 60, T.BRASS, T.OUTLINE, 5))
	ante_label = _center(_label("1/8", 48, T.ORANGE, T.OUTLINE, 5))
	round_value = _center(_label("1", 50, T.ORANGE, T.OUTLINE, 5))

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 10)
	row1.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row1.add_child(_stat("HAK", plays_value))
	row1.add_child(_stat("DEĞİŞİM", discards_value))
	stats.add_child(row1)

	var money_stat := _stat("PARA", money_label)
	money_stat.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats.add_child(money_stat)

	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 10)
	row3.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row3.add_child(_stat("BÖLÜM", ante_label))
	row3.add_child(_stat("TUR", round_value))
	stats.add_child(row3)
	return outer

func _stat(caption: String, value_label: Label) -> Control:
	var p := PanelContainer.new()
	var stat_sb := T.stat_panel()
	_themed_sbs.append(stat_sb)  # palete göre renklensin (HAK/DEĞİŞİM/PARA/BÖLÜM/TUR)
	p.add_theme_stylebox_override("panel", stat_sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var cap := _wavy_label(caption, 22, T.TEXT_DIM, T.OUTLINE, 5.0, 3.0)  # akıcı dalga (her harf)
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inset := PanelContainer.new()
	inset.add_theme_stylebox_override("panel", T.stat_inset())
	inset.size_flags_vertical = Control.SIZE_EXPAND_FILL  # değer kutusu paneli doldursun
	# Değer ORTALI (konteyner ortalar) — hareket başlık dalgasından gelir, sayıya bob YOK (sağa kayma fix).
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inset.add_child(value_label)
	v.add_child(cap)
	v.add_child(inset)
	p.add_child(v)
	return p

var _living_labels: Array = []   # sürekli hafif oynaşan (wobble) yazılar

# Bir Control'ü "canlı" yap — sürekli hafif döner/nabız atar (Balatro yazı hissi). Zinciri döndürür.
func _living(node: Control, strength: float = 1.0) -> Control:
	node.set_meta("wob", strength)
	node.set_meta("wob_phase", _living_labels.size() * 0.8)
	_living_labels.append(node)
	return node

func _update_living_text(t: float) -> void:
	for i in range(_living_labels.size() - 1, -1, -1):
		var n = _living_labels[i]
		if not is_instance_valid(n):
			_living_labels.remove_at(i)
			continue
		var st: float = n.get_meta("wob", 1.0)
		var ph: float = n.get_meta("wob_phase", 0.0)
		# DİKEY bob (aşağı-yukarı), DÖNME YOK (kullanıcı). Taban y bir kez yakalanır.
		if not n.has_meta("base_y"):
			n.set_meta("base_y", n.position.y)
		var by: float = n.get_meta("base_y")
		var off: float = sin(t * 2.4 + ph) * 4.0 * st
		n.position.y = by + off

# Sayaç (HAK/DEĞİŞİM) azalınca üstünde "-N" belirip süzülerek kaybolur (Balatro tarzı).
func _float_minus(anchor: Control, amount: int, color: Color) -> void:
	if anchor == null or not is_instance_valid(anchor):
		return
	var lbl := _label("-%d" % amount, 34, color, T.OUTLINE, 4)
	lbl.z_index = 60
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)
	var c := _node_center(anchor)
	lbl.position = c + Vector2(-14, -10)
	lbl.pivot_offset = Vector2(14, 18)
	lbl.modulate.a = 0.0
	lbl.scale = Vector2(0.3, 0.3)
	lbl.rotation = deg_to_rad(-10)
	# Tok pop: büyüyerek belir → hafif sağa-yukarı yay → küçülüp sön (cansız düz yükselme DEĞİL)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(lbl, "scale", Vector2(1.25, 1.25), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(lbl, "modulate:a", 1.0, 0.1)
	t.tween_property(lbl, "rotation", deg_to_rad(6), 0.5)
	t.chain().tween_property(lbl, "scale", Vector2(0.85, 0.85), 0.5).set_trans(Tween.TRANS_SINE)
	var t2 := create_tween()
	t2.set_parallel(true)
	t2.tween_property(lbl, "position", lbl.position + Vector2(10, -52), 0.66).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t2.tween_property(lbl, "modulate:a", 0.0, 0.34).set_delay(0.3)
	t2.chain().tween_callback(lbl.queue_free)

func _chunky_btn(text: String, color: Color, fg: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_stylebox_override("normal", T.button_filled(color))
	b.add_theme_stylebox_override("hover", T.button_filled(color.lightened(0.08)))
	b.add_theme_stylebox_override("pressed", T.button_pressed(color))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b

func _seal(value_label: Label, color: Color, msize: Vector2, val_ref: float) -> Control:
	# Temiz DOLU kutu (eski radius) + ÜSTÜNDE PUAN ALIRKEN beliren blobby alev tacı.
	# Normalde alev YOK (kutu sade); OYNA'da değere göre belirir. Yazı/etiket yok, sadece sayı.
	var root := Control.new()
	root.custom_minimum_size = msize
	root.clip_contents = false  # alev kutu üstüne taşabilsin

	var box := Panel.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_stylebox_override("panel", T.seal(color))  # eski güzel radius (10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)

	# Alev tacı — kutunun hemen üstünde; intensity (boy) _drive_seal_flame'de PUAN'a göre sürülür.
	var crown_h := 56.0  # daha YÜKSEK alev (kullanıcı isteği)
	var inset := 12.0
	var crown := ColorRect.new()
	crown.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel keskin kalsın
	crown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crown.position = Vector2(inset, -crown_h + 3.0)  # tabanı kutu üst kenarına bitişik (dikişsiz)
	crown.size = Vector2(msize.x - inset * 2.0, crown_h)
	var fm := ShaderMaterial.new()
	fm.shader = load("res://shaders/box_flame.gdshader")
	fm.set_shader_parameter("flame_color", Color(color.r, color.g, color.b, 1.0))
	fm.set_shader_parameter("intensity", 0.0)  # başta alev YOK
	crown.material = fm
	root.add_child(crown)
	root.set_meta("crown", crown)
	root.set_meta("val_label", value_label)  # alev boyunu sürecek değer
	root.set_meta("val_ref", val_ref)        # bu değerde alev tam boy
	root.set_meta("flame_i", 0.0)            # başta 0; puanla yükselir

	# Sadece SAYI — kutu gövdesinde tam ortalı (ÇİP/ÇARPAN yazısı yok)
	value_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(value_label)
	return root

# ── SAĞ ──
func _build_joker_shelf() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	joker_caption = _label("JOKERLER 0/5", 20, T.TEXT_DIM)
	box.add_child(joker_caption)
	joker_box = HBoxContainer.new()
	joker_box.add_theme_constant_override("separation", 12)
	box.add_child(joker_box)
	return box

# Özel joker kart görselleri (tam-kart PNG, 122×150 oranında pixel-art). id → yol.
const JOKER_ART := {
	"anagram-seytani": "res://assets/images/jokers/anagram-seytani.png",
}

# Joker kart yüzü: özel görseli varsa tam-kart PNG (keskin pixel-art), yoksa stylebox+emoji düzeni.
func _joker_face(joker: Dictionary, rarity: Color) -> Control:
	var jid := String(joker.get("id", ""))
	if JOKER_ART.has(jid):
		var tex := TextureRect.new()
		tex.texture = load(JOKER_ART[jid])
		tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tex.offset_left = 3; tex.offset_top = 3; tex.offset_right = -3; tex.offset_bottom = -3  # kenar içinde
		tex.custom_minimum_size = Vector2(116, 144)
		tex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tex.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_SCALE
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel-art keskin kalsın
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Görselin köşeleri YUVARLANSIN (kare art → yuvarlak karta uysun)
		var rm := ShaderMaterial.new()
		rm.shader = load("res://shaders/card_round.gdshader")
		rm.set_shader_parameter("radius_px", 20.0)
		tex.material = rm
		return tex
	return _joker_inner(joker, rarity)

# Nadirliğe (sınıfa) göre kart parıltısı: çapraz kayan ışık bandı (tile_shimmer — sevilen efekt).
const JOKER_SHINE := {
	"uncommon": {"strength": 0.16, "speed": 0.45},
	"rare": {"strength": 0.26, "speed": 0.55},
	"legendary": {"strength": 0.40, "speed": 0.72},
}

# Kart üstüne nadirlik parıltısı overlay'i (yoksa null). Art kartlarda da çalışır (üstte süzülür).
func _joker_shine(rarity_str: String, accent: Color) -> ColorRect:
	if not Settings.particles_on or not JOKER_SHINE.has(rarity_str):
		return null
	var cfg: Dictionary = JOKER_SHINE[rarity_str]
	var r := ColorRect.new()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.offset_left = 3; r.offset_top = 3; r.offset_right = -3; r.offset_bottom = -3
	r.color = Color.WHITE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/tile_shimmer.gdshader")
	m.set_shader_parameter("tint", accent.lerp(Color.WHITE, 0.5))  # nadirlik tonu + parlak gloss
	m.set_shader_parameter("strength", float(cfg["strength"]))
	m.set_shader_parameter("speed", float(cfg["speed"]))
	m.set_shader_parameter("cells", 26.0)
	r.material = m
	return r

func _joker_card_sb(accent: Color, radius: int = 9) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = T.FELT_800
	s.set_corner_radius_all(radius)
	s.set_border_width_all(3)
	s.border_color = accent
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 4)
	s.content_margin_left = 5
	s.content_margin_right = 5
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	return s

# Joker isim plakası (üst): nadirlik renginde dolu şerit, koyu pixel yazı.
func _joker_plate_sb(accent: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = accent
	s.corner_radius_top_left = 6
	s.corner_radius_top_right = 6
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	s.content_margin_left = 3
	s.content_margin_right = 3
	return s

# Joker amblem kutusu (orta "art" alanı): nadirlik-tonlu koyu zemin + ince çerçeve.
func _joker_emblem_sb(accent: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = accent.darkened(0.66).lerp(Color("0e271f"), 0.4)  # nadirlik ipucu taşıyan koyu zemin
	s.corner_radius_bottom_left = 6
	s.corner_radius_bottom_right = 6
	s.set_border_width_all(2)
	s.border_color = Color(accent.r, accent.g, accent.b, 0.55)
	return s

func _make_joker_slot() -> Control:
	var p := Panel.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1, 1, 1, 0.03)  # neredeyse görünmez (soket hissi yok)
	s.set_corner_radius_all(10)
	s.set_border_width_all(1)
	s.border_color = Color(1, 1, 1, 0.07)
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = Vector2(122, 150)
	return p

func _make_joker_card(joker: Dictionary) -> Control:
	var rarity: Color = T.RARITY.get(joker.get("rarity", "common"), T.CARD_EDGE)
	var rstr := String(joker.get("rarity", "common"))
	var p := JokerCard.new()  # sürüklenebilir kart (yeniden sıralama)
	p.add_theme_stylebox_override("panel", _joker_card_sb(rarity))  # yuvarlak (9); art görseli de yuvarlanır
	p.custom_minimum_size = Vector2(122, 150)
	p.set_meta("jid", String(joker["id"]))  # skorlamada tetikleneni bulmak için
	p.tooltip_text = "%s\n%s\n(sürükleyerek sırala)" % [joker["name"], joker["description"]]
	# Sürükle-bırak: yalnız oyun modunda + 2+ joker varken (sıra strateji yaratır).
	p.jid = String(joker["id"])
	p.reorder_cb = _on_joker_reorder
	p.preview_cb = _joker_drag_preview
	p.draggable = not _shop_mode and state["run"]["jokers"].size() >= 2
	p.add_child(_joker_face(joker, rarity))
	var shine := _joker_shine(rstr, rarity)  # sınıfa (nadirlik) göre parıltı efekti
	if shine != null:
		p.add_child(shine)
	return p

# Joker kartının iç düzeni: ÜST isim plakası (nadirlik renkli) + ORTA amblem kutusu (büyük ikon).
# Ham emoji yerine "tasarlanmış kart" hissi. mouse_filter IGNORE → drag olayları dış karta ulaşır.
func _joker_inner(joker: Dictionary, rarity: Color) -> Control:
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Üst isim plakası (nadirlik renkli, alt kenarı koyu → "kabartma")
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", _joker_plate_sb(rarity))
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nm := _center(_label(String(joker["name"]).to_upper(), 11, T.INK, Color(1, 1, 1, 0.25), 1))
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size = Vector2(94, 0)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(nm)
	v.add_child(plate)

	# Amblem "art penceresi" — KATMANLI: koyu zemin + üst ışıltı (gloss) + büyük ikon.
	var emblem := Control.new()
	emblem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", _joker_emblem_sb(rarity))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem.add_child(bg)
	var sheen := Panel.new()         # üstte yumuşak parlama (cam/gloss hissi)
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(1, 1, 1, 0.09)
	ss.set_corner_radius_all(7)
	sheen.add_theme_stylebox_override("panel", ss)
	sheen.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	sheen.offset_left = 6
	sheen.offset_right = -6
	sheen.offset_top = 5
	sheen.offset_bottom = 34
	sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem.add_child(sheen)
	var ico := _label(joker.get("icon", "?"), 52, T.TEXT)
	ico.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ico.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ico.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem.add_child(ico)
	v.add_child(emblem)
	return v

# Joker sürüklerken görünen önizleme (yarı saydam küçük kart, mouse'u takip eder).
func _joker_drag_preview(jid: String) -> Control:
	var joker = Jokers.by_id(jid)
	var rarity: Color = T.CARD_EDGE
	if joker != null:
		rarity = T.RARITY.get(joker.get("rarity", "common"), T.CARD_EDGE)
	else:
		joker = {"name": "?", "icon": "?"}
	var prev := PanelContainer.new()
	prev.add_theme_stylebox_override("panel", _joker_card_sb(rarity))
	prev.custom_minimum_size = Vector2(122, 150)
	prev.modulate = Color(1, 1, 1, 0.9)
	prev.rotation = deg_to_rad(-4)
	prev.position = Vector2(-61, -75)  # imleci kartın ortasına hizala
	prev.add_child(_joker_face(joker, rarity))
	return prev

# Sürükle-bırak ile joker yeniden sıralama. target_jid kartına bırakıldı; after=true ise
# onun ARKASINA, false ise ÖNÜNE taşı. JokerActions.move_joker engine'i günceller (motor saf).
func _on_joker_reorder(from_jid: String, target_jid: String, after: bool) -> void:
	if from_jid == target_jid:
		return
	var jokers: Array = state["run"]["jokers"]
	var from := -1
	var target := -1
	for i in jokers.size():
		var id := String(jokers[i]["id"])
		if id == from_jid:
			from = i
		if id == target_jid:
			target = i
	if from == -1 or target == -1:
		return
	var insert_at := target + (1 if after else 0)
	if from < insert_at:  # kaldırma sonrası indeks kayar
		insert_at -= 1
	if insert_at == from:
		return
	JokerActions.move_joker(state, from_jid, insert_at)
	_animate_jokers = true  # yeni sırada zıplayarak yerleşsin
	_rebuild_jokers()
	_play_card_move()  # tık/yerleşme sesi

func _build_word_board() -> Control:
	# KELİME TAHTASI KALDIRILDI (kullanıcı: "kelime kur alanı olmasın"). Skor artık taşların
	# üstünde + sol panelde çözülür. Etiketler eski referanslarla uyum için GİZLİ tutulur.
	var holder := Control.new()
	holder.visible = false
	word_panel = PanelContainer.new()
	hint_label = _label("", 1)
	word_label = _label("", 1)
	holder.add_child(word_panel)
	holder.add_child(hint_label)
	holder.add_child(word_label)
	var spacer := Control.new()  # play_view'da ince dikey boşluk (joker rafı ile el arası nefes)
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.add_child(holder)
	return spacer

# Patron kutusu — SOL PANELDE (kullanıcı: banner değil sol menüde). Başka turlarda gizli.
# Hedef kutusu (Balatro "Score at least / Reward" tarzı):
# blind çipi (renkli yuvarlak) + HEDEF etiketi + büyük kırmızı hedef sayısı + Ödül $$$.
func _build_target_box() -> Control:
	var box := PanelContainer.new()
	var sb := T.felt_panel(T.FELT_800, T.LINE, 14)
	_themed_sbs.append(sb)
	box.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.alignment = BoxContainer.ALIGNMENT_CENTER

	# blind çipi — tür rengine göre renkli yuvarlak rozet
	blind_chip = Panel.new()
	blind_chip.custom_minimum_size = Vector2(66, 66)
	blind_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_chip_sb = StyleBoxFlat.new()
	_chip_sb.bg_color = T.BRASS
	_chip_sb.set_corner_radius_all(33)
	_chip_sb.set_border_width_all(4)
	_chip_sb.border_color = Color(0, 0, 0, 0.4)
	_chip_sb.shadow_color = Color(0, 0, 0, 0.4)
	_chip_sb.shadow_size = 5
	_chip_sb.shadow_offset = Vector2(0, 3)
	blind_chip.add_theme_stylebox_override("panel", _chip_sb)
	blind_chip_icon = _label("●", 30, T.INK)
	blind_chip_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blind_chip_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blind_chip_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	blind_chip_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blind_chip.add_child(blind_chip_icon)
	h.add_child(blind_chip)

	# sağ blok: HEDEF + büyük sayı + ödül (ortalı)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var cap := _label("HEDEF", 16, T.TEXT_DIM, T.OUTLINE, 3)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(cap)
	target_label = _label("60", 44, T.MULT, T.OUTLINE, 5)
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(target_label)
	target_reward_label = _label("Ödül: $", 15, T.BRASS)
	target_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(target_reward_label)
	h.add_child(col)

	box.add_child(h)
	return box

# Dükkanda sol panel tepesi: blind ismi/hedef yerine SHOP marquee (Balatro gibi).
func _set_shop_sidebar(on: bool) -> void:
	if _head_panel == null:
		return
	if on:
		_head_panel.add_theme_stylebox_override("panel", _marquee_box())  # kırmızı marquee
		_head_panel.custom_minimum_size = Vector2(0, 104)  # marquee daha yüksek (kullanıcı)
		blind_header.text = "DÜKKAN"  # şapkasız A (kullanıcı)
		blind_header.add_theme_color_override("font_color", Color(1.0, 0.86, 0.32))  # altın
		if _target_box != null:
			_target_box.visible = false
		if boss_panel != null:
			boss_panel.visible = false
	else:
		_head_panel.add_theme_stylebox_override("panel", _head_sb_normal)
		_head_panel.custom_minimum_size = Vector2(0, 0)
		blind_header.add_theme_color_override("font_color", T.INK)
		if _target_box != null:
			_target_box.visible = true
		# blind_header.text + boss görünürlüğü _refresh_hud / _update_boss_banner'da ayarlanır

func _build_boss_panel() -> Control:
	boss_panel = PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.32, 0.06, 0.05, 0.95)
	s.set_corner_radius_all(12)
	s.set_border_width_all(2)
	s.border_color = T.MULT
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	boss_panel.add_theme_stylebox_override("panel", s)
	boss_panel.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	boss_name_label = _center(_label("PATRON", 19, T.EMBER))
	boss_desc_label = _label("", 15, T.TEXT)
	boss_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boss_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(boss_name_label)
	v.add_child(boss_desc_label)
	boss_panel.add_child(v)
	return boss_panel

# Kelime tepsisi stylebox — koyu inset + kalın kenar; geçerlide yeşil parıltı.
func _board_sb(ready: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.03, 0.08, 0.06, 0.9)
	s.set_corner_radius_all(16)
	s.set_border_width_all(3)
	s.border_color = T.EMBER if ready else T.BRASS  # geçerlide sıcak ember (YEŞİL değil)
	s.content_margin_left = 44
	s.content_margin_right = 44
	s.content_margin_top = 16
	s.content_margin_bottom = 20
	if ready:
		s.shadow_color = Color(T.EMBER.r, T.EMBER.g, T.EMBER.b, 0.5)
		s.shadow_size = 14
	else:
		s.shadow_color = Color(0, 0, 0, 0.4)
		s.shadow_size = 8
		s.shadow_offset = Vector2(0, 4)
	return s

func _build_hand_row() -> Control:
	hand_area = Control.new()
	hand_area.custom_minimum_size = Vector2(0, TILE_H + LIFT + 8)
	hand_area.clip_contents = false
	hand_area.resized.connect(func(): _layout_hand(false))
	return hand_area

func _build_action_row() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	play_btn = Button.new()
	play_btn.text = "OYNA"
	play_btn.add_theme_font_size_override("font_size", 38)
	play_btn.add_theme_color_override("font_color", T.INK)
	play_btn.add_theme_stylebox_override("normal", T.button_filled(T.BRASS))
	play_btn.add_theme_stylebox_override("hover", T.button_filled(T.ORANGE))
	play_btn.add_theme_stylebox_override("pressed", T.button_pressed(T.BRASS))
	play_btn.add_theme_constant_override("outline_size", 0)
	play_btn.custom_minimum_size = Vector2(230, 0)
	play_btn.pressed.connect(_on_play)
	disc_btn = Button.new()
	disc_btn.text = "DEĞİŞTİR"
	disc_btn.add_theme_font_size_override("font_size", 34)
	disc_btn.add_theme_color_override("font_color", T.TEXT)
	disc_btn.add_theme_stylebox_override("normal", T.button_outline(T.CARD_FACE))
	var disc_hover := T.button_outline(T.ORANGE)  # OYNA gibi hover'da turuncuya döner + hafif dolgu
	disc_hover.bg_color = Color(T.CARD_FACE.r, T.CARD_FACE.g, T.CARD_FACE.b, 0.12)
	disc_btn.add_theme_stylebox_override("hover", disc_hover)
	disc_btn.add_theme_color_override("font_hover_color", T.TEXT)
	disc_btn.add_theme_stylebox_override("pressed", T.button_pressed(T.FELT_700))
	disc_btn.custom_minimum_size = Vector2(230, 0)
	disc_btn.pressed.connect(_on_discard)
	# KARIŞTIR (shuffle) — OYNA ile DEĞİŞTİR arasında, TAM YUVARLAK buton + pixel-art ikon.
	# Dolgu rengi tur paletine göre değişir (_style_shuffle, palette tween'inde lerp'lenir).
	shuffle_btn = Button.new()
	var ssz := 78.0
	shuffle_btn.custom_minimum_size = Vector2(ssz, ssz)
	var srad := int(ssz / 2.0)  # tam yuvarlak
	_shuffle_sb = _round_sb(T.FELT_HI, srad, 7, Vector2(0, 5))                    # normal: gölgeli
	_shuffle_hover_sb = _round_sb(T.FELT_HI.lightened(0.12), srad, 11, Vector2(0, 7))  # hover: açık + büyük gölge
	_shuffle_pressed_sb = _round_sb(T.FELT_HI.darkened(0.1), srad, 3, Vector2(0, 2))   # basılı: koyu + küçük gölge
	shuffle_btn.add_theme_stylebox_override("normal", _shuffle_sb)
	shuffle_btn.add_theme_stylebox_override("hover", _shuffle_hover_sb)
	shuffle_btn.add_theme_stylebox_override("pressed", _shuffle_pressed_sb)
	shuffle_btn.add_theme_constant_override("outline_size", 0)
	shuffle_btn.tooltip_text = "Harfleri karıştır"
	shuffle_btn.pivot_offset = Vector2(ssz, ssz) / 2.0  # ortadan ölçeklensin (hover kalkma)
	shuffle_btn.mouse_entered.connect(func(): _hover_lift(shuffle_btn, 1.1))
	shuffle_btn.mouse_exited.connect(func(): _hover_lift(shuffle_btn, 1.0))
	shuffle_btn.pressed.connect(_on_shuffle)
	# Pixel-art ikon — butonun ortasına (kemik rengi, çoğu palet tonunda okunur)
	_shuffle_icon = TextureRect.new()
	_shuffle_icon.texture = _make_shuffle_icon(T.CARD_FACE)
	_shuffle_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # crisp pixel
	_shuffle_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shuffle_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_shuffle_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shuffle_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pad := 20.0
	_shuffle_icon.offset_left = pad
	_shuffle_icon.offset_top = pad
	_shuffle_icon.offset_right = -pad
	_shuffle_icon.offset_bottom = -pad
	shuffle_btn.add_child(_shuffle_icon)
	h.add_child(play_btn)
	h.add_child(shuffle_btn)
	h.add_child(disc_btn)
	return h

func _px(img: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, col)

# Sağa bakan pixel ok başı (tip = sağ uç).
func _arrow_right(img: Image, tx: int, ty: int, col: Color) -> void:
	for k in range(0, 4):
		_px(img, tx - k, ty - k, col)
		_px(img, tx - k, ty + k, col)

# Pixel-art "karıştır" ikonu — iki şerit (üst-sol↘ ve alt-sol↗) ortada çaprazlanır,
# ikisi de sağda sağa-bakan ok başıyla biter (evrensel shuffle sembolü). Emoji DEĞİL.
func _make_shuffle_icon(col: Color) -> ImageTexture:
	var w := 16
	var h := 14
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# sol yatay uçlar (2px kalın)
	for x in range(1, 5):
		_px(img, x, 3, col); _px(img, x, 4, col)          # üst şerit
		_px(img, x, h - 5, col); _px(img, x, h - 4, col)  # alt şerit
	# çaprazlar (2px) — ~(4,3)↘(11,10) ve ~(4,10)↗(11,3)
	for i in range(0, 8):
		_px(img, 4 + i, 3 + i, col); _px(img, 4 + i, 3 + i + 1, col)            # ↘
		_px(img, 4 + i, (h - 4) - i, col); _px(img, 4 + i, (h - 4) - i - 1, col)  # ↗
	# sağ uçlarda ok başları (sağa bakar)
	_arrow_right(img, 13, 10, col)
	_arrow_right(img, 13, 3, col)
	return ImageTexture.create_from_image(img)

# Yuvarlak, gölgeli stylebox (shuffle butonu için).
func _round_sb(bg: Color, radius: int, shadow_size: int, shadow_off: Vector2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = shadow_size
	s.shadow_offset = shadow_off
	s.content_margin_left = 0
	s.content_margin_right = 0
	return s

# Hover'da hafif kalkma (büyüme) — diğer juice ile tutarlı.
func _hover_lift(node: Control, amount: float) -> void:
	if not is_instance_valid(node):
		return
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2(amount, amount), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Shuffle buton dolgusunu verilen renge çek (palette tween'inde lerp ile çağrılır).
# normal/hover/basılı tonlarını birlikte günceller.
func _style_shuffle(c: Color) -> void:
	if _shuffle_sb:
		_shuffle_sb.bg_color = c
	if _shuffle_hover_sb:
		_shuffle_hover_sb.bg_color = c.lightened(0.12)
	if _shuffle_pressed_sb:
		_shuffle_pressed_sb.bg_color = c.darkened(0.1)

# Harfleri RASTGELE diz (kozmetik — seçim sırası kelimeyi belirler, el sırası değil). + shuffle sesi.
func _on_shuffle() -> void:
	if _busy:
		return
	var hand: Array = state["round"]["hand"]
	# Fisher-Yates (run rng ile — determinizm korunur)
	var rng = state["run"]["rng"]
	for i in range(hand.size() - 1, 0, -1):
		var j := int(rng.next() * (i + 1))
		var tmp = hand[i]
		hand[i] = hand[j]
		hand[j] = tmp
	# hand_area çocuk sırasını state'e göre diz → _layout_hand yeni sırayla yerleştirir
	for i in hand.size():
		var id := int(hand[i]["id"])
		if tile_by_id.has(id):
			hand_area.move_child(tile_by_id[id], i)
	_play_shuffle()
	_layout_hand(true)

# ── Kemik taş ──
func _make_tile(card: Dictionary) -> Control:
	var tile := TileCard.new()  # sürüklenebilir (seçiliyken kelime sırasını değiştirir)
	tile.custom_minimum_size = Vector2(TILE_W, TILE_H)
	tile.size = Vector2(TILE_W, TILE_H)
	tile.pivot_offset = Vector2(TILE_W, TILE_H) / 2.0
	tile.set_meta("card_id", int(card["id"]))
	tile.set_meta("selected", false)
	tile.card_id = int(card["id"])
	tile.reorder_cb = _on_tile_reorder
	tile.preview_cb = _tile_drag_preview

	# visual = idle 3D float burada (layout/seçim dış tile'da, idle iç visual'da → çakışmaz)
	var visual := Control.new()
	visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visual.pivot_offset = Vector2(TILE_W, TILE_H) / 2.0
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(visual)
	tile.set_meta("visual", visual)

	var face := Panel.new()
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.add_theme_stylebox_override("panel", T.bone_tile())
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.add_child(face)

	var sheen := Panel.new()
	sheen.add_theme_stylebox_override("panel", T.tile_sheen())
	sheen.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	sheen.offset_left = 8
	sheen.offset_right = -8
	sheen.offset_top = 8
	sheen.offset_bottom = TILE_H * 0.42
	sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.add_child(sheen)

	var letter := _label(card["char"], 84, T.INK, Color("c9b68c", 0.9), 5)
	letter.add_theme_font_override("font", _tile_font)  # pixel taş fontu + açık kontur (kabartma)
	letter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.add_child(letter)

	var val := str(LETTER_VALUES.chips(card["char"]))
	visual.add_child(_corner_pip(val, true))
	visual.add_child(_corner_pip(val, false))

	# Geliştirme (foil/holo/poly/altın/cam) — renkli kenar + köşe sembolü
	var enh = card.get("enhancements", [])
	if not enh.is_empty():
		var e = Enhancements.by_id(enh[enh.size() - 1])
		var ecol := Color(e["color"])
		var glow := Panel.new()
		glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var gs := StyleBoxFlat.new()
		gs.bg_color = Color(ecol.r, ecol.g, ecol.b, 0.10)  # hafif tint
		gs.set_corner_radius_all(14)
		gs.set_border_width_all(4)
		gs.border_color = ecol
		glow.add_theme_stylebox_override("panel", gs)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual.add_child(glow)
		var badge := _label(e["symbol"], 30, ecol, T.OUTLINE, 4)
		badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		badge.offset_left = -40
		badge.offset_top = 3
		badge.offset_right = -6
		badge.offset_bottom = 40
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual.add_child(badge)
		# SÜREKLİ PARILTI (specular sweep) — enhancement renginde, glow değil
		var shim := ColorRect.new()
		shim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shim.offset_left = 7
		shim.offset_top = 7
		shim.offset_right = -7
		shim.offset_bottom = -7
		shim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		shim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var smat := ShaderMaterial.new()
		smat.shader = load("res://shaders/tile_shimmer.gdshader")
		smat.set_shader_parameter("tint", Color(ecol.r, ecol.g, ecol.b, 1.0))
		shim.material = smat
		visual.add_child(shim)
		tile.set_meta("enh_color", ecol)  # oynanınca renkli kıvılcım için

	tile.gui_input.connect(_on_tile_input.bind(int(card["id"])))
	return tile

# Sürekli hafif 3D float — kartlar "yaşıyor" hissi (Balatro tarzı).
func _process(_delta: float) -> void:
	# Trauma-tabanlı ekran sarsıntısı — erken return'lerden ÖNCE uygulanır (her zaman çalışsın).
	if shaker != null:
		if _trauma > 0.0:
			_noise_t += _delta
			var shake := _trauma * _trauma  # karesel: küçük trauma yumuşak, büyük trauma vurucu
			var s := _noise_t * SHAKE_NOISE_SPEED
			var nx := _shake_noise.get_noise_2d(s, 0.0)
			var ny := _shake_noise.get_noise_2d(0.0, s)
			shaker.position = Vector2(nx, ny) * (SHAKE_MAX_OFFSET * shake)
			_trauma = maxf(0.0, _trauma - TRAUMA_DECAY * _delta)
		elif shaker.position != Vector2.ZERO:
			shaker.position = Vector2.ZERO  # sıfıra otur (drift olmasın)
	var t := Time.get_ticks_msec() / 1000.0
	_update_living_text(t)  # başlık/önemli yazılar sürekli hafif oynaşır (Balatro hissi)
	_drive_seal_flame(chip_seal_panel)   # alev boyu = ÇİP değeri (canlı)
	_drive_seal_flame(mult_seal_panel)   # alev boyu = ÇARPAN değeri
	# Joker kartları sürekli hafif SÜZÜLÜR (yaşıyor hissi) — düz sağa-sola "silecek" DEĞİL:
	# yumuşak dikey float + çok az eğilme (farklı frekans + her kart farklı faz → organik).
	if joker_box:
		var jcards := joker_box.get_children()
		for i in jcards.size():
			var jc: Control = jcards[i]
			if not jc.has_meta("jid"):
				continue  # boş yuva süzülmez
			if jc.size != Vector2.ZERO:
				jc.pivot_offset = jc.size * 0.5
			var ph := i * 0.9
			# dikey bob (additif → HBox'ın koyduğu konumu bozmaz): geçen karenin offset'ini geri al
			var off := sin(t * 1.6 + ph) * 3.4
			var prev: float = jc.get_meta("bob_off", 0.0)
			jc.position.y += off - prev
			jc.set_meta("bob_off", off)
			jc.rotation = sin(t * 0.85 + ph * 1.3) * deg_to_rad(1.4)  # çok hafif eğilme (ayrı frekans)
	if hand_area == null:
		return
	var tiles := hand_area.get_children()
	for i in tiles.size():
		var tile: Control = tiles[i]
		var vis = tile.get_meta("visual", null)
		if vis == null:
			continue
		if tile.get_meta("selected", false):
			vis.position.y = lerp(vis.position.y, 0.0, 0.25)
			vis.rotation = lerp(vis.rotation, 0.0, 0.25)
		else:
			var ph := i * 0.65
			vis.position.y = sin(t * 1.7 + ph) * 4.5
			vis.rotation = sin(t * 1.1 + ph) * deg_to_rad(2.2)

func _corner_pip(val: String, top_left: bool) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := Vector2(44, 56)
	var l := _label(val, 32, T.BRASS)
	l.add_theme_font_override("font", _tile_font)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(l)
	if top_left:
		c.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		c.offset_left = 6
		c.offset_top = 4
		c.offset_right = 6 + box.x
		c.offset_bottom = 4 + box.y
	else:
		c.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		c.offset_left = -6 - box.x
		c.offset_top = -4 - box.y
		c.offset_right = -6
		c.offset_bottom = -4
		c.pivot_offset = box / 2.0
		c.rotation = PI  # 180° çevrik (kart gibi)
	return c

func _on_tile_input(event: InputEvent, card_id: int) -> void:
	if _busy:
		return
	var tile = tile_by_id.get(card_id, null)
	if tile == null:
		return
	var is_btn: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT) \
		or event is InputEventScreenTouch
	if not is_btn:
		return
	if event.pressed:
		tile.drag_started = false  # yeni basış → bayrağı sıfırla
	else:  # bırakma → sürükleme OLMADIYSA seç/bırak (sürükleme reorder yaptı)
		if tile.drag_started:
			tile.drag_started = false
			return
		_toggle_select(card_id)

func _toggle_select(card_id: int) -> void:
	_flame_on = false  # yeni kelime kurmaya başladın → alev söner (sonraki OYNA'da yine yanar)
	if selected_ids.has(card_id):
		selected_ids.erase(card_id)
		tile_by_id[card_id].set_meta("selected", false)
	else:
		selected_ids.append(card_id)
		tile_by_id[card_id].set_meta("selected", true)
		_pop(tile_by_id[card_id], 1.08)
	_play_card_move()
	_layout_hand(true)
	_update_word_display()
	if _tut_active:
		_tut_event("selection_changed")

# Kelime bölgesindeki taşı sürükle-bırakla yeniden sırala (kelime harf sırasını değiştirir).
func _on_tile_reorder(from_id: int, target_id: int, after: bool) -> void:
	if from_id == target_id:
		return
	var fi := selected_ids.find(from_id)
	var ti := selected_ids.find(target_id)
	if fi == -1 or ti == -1:
		return
	selected_ids.remove_at(fi)
	ti = selected_ids.find(target_id)  # kaldırma sonrası indeks
	var insert_at := ti + (1 if after else 0)
	selected_ids.insert(insert_at, from_id)
	_play_card_move()
	_layout_hand(true)
	_update_word_display()
	if _tut_active:
		_tut_event("selection_changed")

# Taş sürüklerken görünen önizleme (yarı saydam kemik taş + harf, mouse'u takip eder).
func _tile_drag_preview(id: int) -> Control:
	var card = hand_cards_by_id.get(id, null)
	var ch: String = String(card["char"]) if card != null else "?"
	var prev := Control.new()
	prev.custom_minimum_size = Vector2(TILE_W, TILE_H)
	prev.size = Vector2(TILE_W, TILE_H)
	prev.modulate = Color(1, 1, 1, 0.9)
	prev.rotation = deg_to_rad(-4)
	prev.position = -Vector2(TILE_W, TILE_H) / 2.0  # imleci ortaya hizala
	var face := Panel.new()
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.add_theme_stylebox_override("panel", T.bone_tile())
	prev.add_child(face)
	var letter := _label(ch, 84, T.INK, Color("c9b68c", 0.9), 5)
	letter.add_theme_font_override("font", _tile_font)
	letter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prev.add_child(letter)
	return prev

func _play_card_move() -> void:
	if _ui_sfx and _card_move:
		_ui_sfx.stream = _card_move
		_ui_sfx.play()

# ── El yerleşimi + dağıtım animasyonu ──
func _rebuild_hand(deal_in: bool, sound: bool = false) -> void:
	for c in hand_area.get_children():
		c.queue_free()
	tile_by_id.clear()
	hand_cards_by_id.clear()
	for card in state["round"]["hand"]:
		hand_cards_by_id[int(card["id"])] = card
		var tile := _make_tile(card)
		hand_area.add_child(tile)
		tile_by_id[int(card["id"])] = tile
	# Kabın GENİŞLİĞİ OTURANA kadar bekle (iki kare sabit) — yoksa _deal_in yanlış/sağdaki
	# hedefi yakalıyor ve taşlar sağda stack'leniyordu (bug). Sabitlik kontrolü tek kareden sağlam.
	await get_tree().process_frame
	var prev_w := -1.0
	var guard := 0
	while guard < 20:
		if not is_inside_tree():
			return
		var w := hand_area.size.x
		if w >= float(TILE_W) and absf(w - prev_w) < 0.5:
			break  # genişlik iki kare aynı → oturdu
		prev_w = w
		await get_tree().process_frame
		guard += 1
	_layout_hand(false)
	if deal_in:
		_deal_in(sound)

const WORD_ZONE_DY := 326.0  # seçili taşlar bu kadar YUKARI çıkar (biraz daha yukarı — kullanıcı)

func _layout_hand(animate: bool) -> void:
	var tiles := hand_area.get_children()
	if tiles.is_empty():
		return
	var avail := hand_area.size.x
	if avail < float(TILE_W):
		return  # kap hazır değil → bozuk yerleşim yapma
	var usable := avail - DECK_RESERVE  # sağdaki desteye yer bırak
	if usable < float(TILE_W):
		usable = avail
	# SEÇİLİ taşları (kelime SIRASINA göre) üst/orta bölgeye, kalanları alt sıraya ayır.
	var sel_tiles := []
	for id in selected_ids:
		if tile_by_id.has(id) and tile_by_id[id] in tiles:
			sel_tiles.append(tile_by_id[id])
	var un_tiles := []
	for t in tiles:
		if not (t in sel_tiles):
			un_tiles.append(t)
	_place_row(un_tiles, usable, float(LIFT), animate, false, TILE_GAP)            # alt: el (deste'ye yer)
	_place_row(sel_tiles, avail, float(LIFT) - WORD_ZONE_DY, animate, true, float(TILE_GAP))  # üst: kelime (tam ortalı, normal aralık)

# Bir taş sırasını yatayda ortala + yerleştir. center_w = ortalama genişliği, gap = taşlar arası boşluk.
func _place_row(row: Array, center_w: float, y: float, animate: bool, selected: bool, gap: float) -> void:
	var n := row.size()
	if n == 0:
		return
	var step := float(TILE_W) + gap
	if n > 1 and (n - 1) * step + TILE_W > center_w:
		step = (center_w - TILE_W) / (n - 1)
	var total := (n - 1) * step + TILE_W
	var start_x := maxf(0.0, (center_w - total) / 2.0)
	for i in n:
		var tile = row[i]
		tile.can_drag = selected  # yalnız kelime bölgesindeki taşlar sürüklenir
		var target := Vector2(start_x + i * step, y)
		var rot: float = deg_to_rad(-2.0) if selected else 0.0
		if animate:
			var tw := create_tween().set_parallel(true)
			tw.tween_property(tile, "position", target, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(tile, "rotation", rot, 0.2)
		else:
			tile.position = target
			tile.rotation = rot

func _deal_in(play_sound: bool) -> void:
	var tiles := hand_area.get_children()
	if tiles.is_empty():
		return
	# Kaynak = deste yığını (sağ-alt) → hand_area yerel koordinatı (kartlar desteden çıkar gibi).
	var src := Vector2(hand_area.size.x, hand_area.size.y * 0.5)
	if deck_holder and is_instance_valid(deck_holder):
		src = hand_area.get_global_transform().affine_inverse() * _node_center(deck_holder)
	for i in tiles.size():
		var tile: Control = tiles[i]
		var target := tile.position
		tile.position = src - tile.size * 0.5
		tile.modulate.a = 0.0
		tile.scale = Vector2(0.45, 0.45)
		tile.rotation = deg_to_rad(18.0)
		var delay := i * 0.06
		var tw := create_tween().set_parallel(true)
		tw.tween_property(tile, "position", target, 0.42).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(tile, "modulate:a", 1.0, 0.2).set_delay(delay)
		tw.tween_property(tile, "rotation", 0.0, 0.36).set_delay(delay)
		tw.tween_property(tile, "scale", Vector2.ONE, 0.36).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if play_sound:
		_play_shuffle()

func _play_shuffle() -> void:
	if _sfx and _shuffle:
		_sfx.stream = _shuffle
		_sfx.play()

# Oynama sonrası DIFF refill: oynanan taşlar sağa süzülür, kalanlar durur, SADECE yeni taşlar
# desteden dağıtılır (kullanıcı: "hepsi tekrar gelmiyor, adeti kadar kart geliyor").
func _refill_hand(played_tiles: Array, sound: bool) -> void:
	# 1) Oynanan taşları el alanından AYIR (layout'a karışmasın) → sağa süzüp sil.
	for t in played_tiles:
		if not is_instance_valid(t):
			continue
		var gp: Vector2 = t.global_position
		if t.get_parent() == hand_area:
			hand_area.remove_child(t)
			add_child(t)
			t.global_position = gp
		t.z_index = 4
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(t, "position:x", t.position.x + 560.0, 0.44).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(t, "modulate:a", 0.0, 0.4)
		tw.tween_property(t, "rotation", deg_to_rad(16.0), 0.44)
		tw.chain().tween_callback(t.queue_free)
	# 2) tile_by_id'den state.hand'de OLMAYANLARI (oynananlar) temizle.
	var hand_ids := {}
	for card in state["round"]["hand"]:
		hand_ids[int(card["id"])] = true
	for id in tile_by_id.keys():
		if not hand_ids.has(id):
			tile_by_id.erase(id)
			hand_cards_by_id.erase(id)
	# 3) Diff: kalan taşları TUT, yeni kartlar için taş oluştur; çocuk sırasını state'e göre diz.
	var new_tiles := []
	var ordered := []
	for card in state["round"]["hand"]:
		var id := int(card["id"])
		var tile: Control
		if tile_by_id.has(id):
			tile = tile_by_id[id]
		else:
			tile = _make_tile(card)
			hand_area.add_child(tile)
			tile_by_id[id] = tile
			hand_cards_by_id[id] = card
			new_tiles.append(tile)
		ordered.append(tile)
	for i in ordered.size():
		hand_area.move_child(ordered[i], i)
	await get_tree().process_frame
	_layout_hand_keep(new_tiles, sound)

# _layout_hand'in diff versiyonu: kalan taşlar yeni yerine KAYAR; yeni taşlar DESTEDEN dağıtılır.
func _layout_hand_keep(new_tiles: Array, sound: bool) -> void:
	var tiles := hand_area.get_children()
	var n := tiles.size()
	if n == 0:
		return
	var avail := hand_area.size.x
	if avail < float(TILE_W):
		return
	var usable := avail - DECK_RESERVE
	if usable < float(TILE_W):
		usable = avail
	var step := float(TILE_W + TILE_GAP)
	if n > 1 and (n - 1) * step + TILE_W > usable:
		step = (usable - TILE_W) / (n - 1)
	var total := (n - 1) * step + TILE_W
	var start_x := maxf(0.0, (usable - total) / 2.0)
	var base_y := float(LIFT)
	var src := Vector2(hand_area.size.x, hand_area.size.y * 0.5)
	if deck_holder and is_instance_valid(deck_holder):
		src = hand_area.get_global_transform().affine_inverse() * _node_center(deck_holder)
	var dealt := false
	for i in n:
		var tile = tiles[i]
		tile.can_drag = false  # oynama sonrası seçim yok → sürükleme kapalı
		var target := Vector2(start_x + i * step, base_y)  # hep taban
		if tile in new_tiles:
			tile.position = src - tile.size * 0.5
			tile.modulate = Color(1, 1, 1, 0.0)
			tile.scale = Vector2(0.45, 0.45)
			tile.rotation = deg_to_rad(18.0)
			var d := i * 0.05
			var tw := create_tween()
			tw.set_parallel(true)
			tw.tween_property(tile, "position", target, 0.42).set_delay(d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(tile, "modulate:a", 1.0, 0.2).set_delay(d)
			tw.tween_property(tile, "rotation", 0.0, 0.36).set_delay(d)
			tw.tween_property(tile, "scale", Vector2.ONE, 0.36).set_delay(d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			dealt = true
		else:
			var tw := create_tween()
			tw.set_parallel(true)
			tw.tween_property(tile, "position", target, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(tile, "rotation", 0.0, 0.2)
	if dealt and sound:
		_play_shuffle()

# WAV'ı import edilmiş kaynak olarak yükle (export'ta ham .wav pakete girmez; load() remap'le çalışır).
# Loop, müzik dosyalarında import seviyesinde (edit/loop_mode) ayarlıdır.
func _load_wav(path: String) -> AudioStream:
	var s: AudioStream = load(path)
	if s == null:
		push_error("WAV açılamadı: " + path)
	return s

# Prosedürel "coin/collect" sesi: verilen frekansları sırayla çalan, üstel sönümlü kısa ton.
# freqs: ardışık ton dizisi (yükselen → coin/arp hissi); decay: sönüm hızı; amp: genlik.
func _make_tone_wav(freqs: Array, dur: float, decay: float, amp: float) -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * dur)
	var seg := maxi(1, n / max(1, freqs.size()))
	var data := PackedByteArray()
	data.resize(n * 2)  # 16-bit mono
	for i in n:
		var t := float(i) / rate
		var fi := mini(freqs.size() - 1, i / seg)
		var f: float = freqs[fi]
		var env: float = exp(-t * decay)
		var sample: float = sin(TAU * f * t) * env * amp
		data.encode_s16(i * 2, int(clamp(sample, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.data = data
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	return w

func _play_collect(stream: AudioStream, pitch: float) -> void:
	if _coin_sfx and stream:
		_coin_sfx.stream = stream
		_coin_sfx.pitch_scale = pitch
		_coin_sfx.play()

# ── Kelime / geçerlilik / canlı önizleme ──
func _current_word() -> String:
	var w := ""
	for id in selected_ids:
		if hand_cards_by_id.has(id):
			w += hand_cards_by_id[id]["char"]
	return w

func _selected_cards() -> Array:
	var out := []
	for id in selected_ids:
		if hand_cards_by_id.has(id):
			out.append(hand_cards_by_id[id])
	return out

func _is_current_valid() -> bool:
	var cards := _selected_cards()
	if cards.size() < state["config"]["minWordLength"]:
		return false
	if not Dictionary_.is_valid_word(_current_word(), state["config"]["minWordLength"]):
		return false
	var boss = state["round"].get("boss", null)
	if boss != null and boss.has("validate"):
		if not boss["validate"].call(cards, state)["ok"]:
			return false
	return true

# Kelime-tipi etiketi: dalgalı (Meksika dalgası) bbcode + yumuşak belirme/kaybolma.
func _tier_bbcode(text: String) -> String:
	return "[center][wave amp=6 freq=3.0 connected=1]%s[/wave][/center]" % text

func _show_tier(text: String) -> void:
	tier_label.text = _tier_bbcode(text)
	if _tier_shown:
		return  # zaten görünür → sadece metin güncellendi (her taş seçiminde yeniden fade etme)
	_tier_shown = true
	# güzel giriş: fade-in + aşağıdan hafif yaylanarak büyüyerek otur (dalga zaten harf harf akar)
	tier_label.pivot_offset = tier_label.size * 0.5
	tier_label.scale = Vector2(0.84, 0.84)
	tier_label.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(tier_label, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(tier_label, "scale", Vector2.ONE, 0.34) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _hide_tier() -> void:
	if not _tier_shown:
		tier_label.modulate.a = 0.0
		return
	_tier_shown = false
	# güzel çıkış: fade-out + hafif küçülerek silinme
	tier_label.pivot_offset = tier_label.size * 0.5
	var tw := create_tween()
	tw.tween_property(tier_label, "modulate:a", 0.0, 0.26).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(tier_label, "scale", Vector2(0.9, 0.9), 0.26).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): tier_label.text = _tier_bbcode("—"))

# Kelime tahtası YOK → geçerlilik geri bildirimi OYNA butonunda (yeşil parlar + nabız) +
# canlı çip/çarpan önizlemesi sol panelde. Seçili taşlar geçerlide yeşil ışıldar.
func _update_word_display() -> void:
	# Oyuncu taş seçtiyse devam eden "geri sayım" animasyonunu kes (önizleme öncelikli).
	if _seal_cd_tw != null and _seal_cd_tw.is_valid():
		_seal_cd_tw.kill()
	var cards := _selected_cards()
	if _is_current_valid():
		var res := Scoring.score_word(state, cards, true)
		chip_value.text = str(res["chips"])
		mult_value.text = _fmt(res["mult"])
		_show_tier("%s  ·  ×%s" % [res["tier"]["label"], _fmt(res["tier"]["mult"])])
		_set_play_ready(true)
		_start_pulse()
	else:
		chip_value.text = "0"
		mult_value.text = "1"
		if cards.size() > 0:
			var t := WordTiers.tier_for(cards.size())
			_show_tier("%s  ·  ×%s" % [t["label"], _fmt(t["mult"])])
		else:
			_hide_tier()
		_set_play_ready(false)
		_stop_pulse()
	_tint_selected_tiles()

# OYNA butonu: geçerli kelimede YEŞİL (hazır), değilse pirinç (normal).
func _set_play_ready(ready: bool) -> void:
	if play_btn == null:
		return
	if ready:
		play_btn.add_theme_stylebox_override("normal", T.button_filled(T.GOOD))
		play_btn.add_theme_stylebox_override("hover", T.button_filled(T.GOOD.lightened(0.1)))
	else:
		play_btn.add_theme_stylebox_override("normal", T.button_filled(T.BRASS))
		play_btn.add_theme_stylebox_override("hover", T.button_filled(T.ORANGE))

# Seçili taşları geçerli kelimede hafif yeşile boyar (görsel onay).
func _tint_selected_tiles() -> void:
	var valid := _is_current_valid()
	for id in tile_by_id:
		var tile = tile_by_id[id]
		if not is_instance_valid(tile):
			continue
		var sel: bool = tile.get_meta("selected", false)
		var target := Color(0.7, 1.1, 0.8) if (sel and valid) else Color.WHITE
		tile.modulate = tile.modulate.lerp(target, 1.0)

func _start_pulse() -> void:
	_stop_pulse()
	play_btn.pivot_offset = play_btn.size / 2.0
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(play_btn, "scale", Vector2(1.05, 1.05), 0.45).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(play_btn, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)

func _stop_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
	if play_btn:
		play_btn.scale = Vector2.ONE

func _flash(color: Color) -> void:
	# Geçersiz oynama denemesi → OYNA butonu kırmızı yanıp söner.
	if play_btn == null:
		return
	play_btn.add_theme_stylebox_override("normal", T.button_filled(color))
	var tw := create_tween()
	tw.tween_interval(0.22)
	tw.tween_callback(_update_word_display)

# ── Aksiyonlar ──
func _on_play() -> void:
	if _busy:
		return
	if not _is_current_valid():
		_flash(T.MULT)
		return
	var fired: Array = []
	for id in selected_ids:
		if tile_by_id.has(id):
			fired.append(tile_by_id[id])
	var prev_score: int = state["round"]["score"]
	var res := Round.play_word(state, selected_ids.duplicate())
	if not res.get("ok", false):
		_flash(T.MULT)
		return
	selected_ids.clear()
	_busy = true
	_flame_on = true  # OYNA'ya basıldı → alev artık yanabilir (değere göre)
	_stop_pulse()
	_set_buttons(false)
	var _tut_guided: bool = _tut_active and _tut_mode == "play"  # SADECE rehberli OYNA basışı
	if _tut_guided:
		_tut_hide_for_action()  # skor animasyonu engelsiz görünsün (dim/balon gizlenir)
	await _score_sequence(res, fired, prev_score)
	if _tut_guided:
		await _tut_postplay()   # açıklama balonları BİTSİN, sonra won/dükkân akışı (sıra karışmaz)
	# Skor alındı → çip/çarpan alev tacı YANSIN (yeni tura kadar durur)
	_set_seal_flame(chip_seal_panel, true)
	_set_seal_flame(mult_seal_panel, true)
	_busy = false
	_set_buttons(true)
	if state["round"]["status"] == "won":
		hint_label.text = "TUR GEÇİLDİ!"
		word_label.text = "✦"
		word_label.add_theme_color_override("font_color", T.EMBER)
		await get_tree().create_timer(0.45).timeout
		_open_cash_out()
	elif state["run"]["status"] == "lost":
		await get_tree().create_timer(0.35).timeout
		_open_lose()
	else:
		# Oynanan taşlar sağa süzülür + SADECE kullanılan kadar yeni taş desteden gelir (kalanlar durur)
		_refresh_hud()  # sol panel/joker/sayaç güncelle (el'e dokunma — _refill_hand yapar)
		await _refill_hand(fired, true)
		# (çip×çarpan sıfırlaması artık _score_sequence sonunda — skor tur toplamına akar akmaz)
		_update_word_display()

func _on_discard() -> void:
	if _busy:
		return
	if selected_ids.is_empty():
		_flash(T.MULT)
		return
	var res := Round.discard_cards(state, selected_ids.duplicate())
	if not res.get("ok", false):
		_flash(T.MULT)
		return
	selected_ids.clear()
	_refresh(true, true)

func _set_buttons(on: bool) -> void:
	play_btn.disabled = not on
	disc_btn.disabled = not on

# ── JUICE: sıralı skor çözümü ──
func _score_sequence(res: Dictionary, fired: Array, prev_score: int) -> void:
	# ÖNİZLEME TABANINDAN DEVAM ET — OYNA'da 0×1'e düşmek YOK. Taban (harf çipleri + kademe +
	# deterministik jokerler) zaten önizlemede gösteriliyor; SADECE önizlemeyi AŞAN ekstralar
	# (rastgele jokerler vb.) tek tek üstüne eklenir. disp = ekranda gösterilen güncel değer.
	_coin_idx = 0
	_bam = 0
	var disp_chip := int(chip_value.text) if chip_value.text.is_valid_int() else 0
	var disp_mult := float(mult_value.text) if mult_value.text.is_valid_float() else float(res["tier"]["mult"])
	chip_value.text = str(disp_chip)
	mult_value.text = _fmt(disp_mult)
	var li := 0
	var run_chip := 0
	var run_mult := float(res["tier"]["mult"])
	for step in res["timeline"]:
		match step["kind"]:
			"letter":
				var tile: Control = null
				if li < fired.size() and is_instance_valid(fired[li]):
					tile = fired[li]
				li += 1
				var base := int(step["base"])
				var anchor: Vector2 = _node_center(chip_seal_panel)
				if tile != null:
					anchor = _node_center(tile) + Vector2(0, -tile.size.y * 0.5 - 26.0)
				# Taş "+N" baloncuğu + pop HER ZAMAN görünür (juice); kutu önizlemeden devam ettiği
				# için saymaz (sıfıra düşmez). Sadece önizlemeyi AŞARSA kutu da yükselir.
				if base != 0 and tile != null:
					_fire_tile(tile, base)
				run_chip += base
				if run_chip > disp_chip:  # taban önizlemeyi aştı (nadir/rastgele harf-çipi) → kutu da
					_count_label(chip_value, run_chip, 0.16)
					_pop(chip_seal_panel, 1.1)
					disp_chip = run_chip
				# Harf-üstü geliştirmeler (foil/holo/poly): baloncuk HER ZAMAN; kutu yalnız aşınca
				for op in step["ops"]:
					run_chip = _op_chip(op, run_chip)
					run_mult = _op_mult(op, run_mult)
					var ex: bool = run_chip > disp_chip or run_mult > disp_mult
					_show_op(op, anchor, run_chip, run_mult, ex)
					if ex:
						disp_chip = maxi(disp_chip, run_chip)
						disp_mult = maxf(disp_mult, run_mult)
					await get_tree().create_timer(0.3).timeout
				run_chip = int(step["chips"])
				run_mult = float(step["mult"])
				if base != 0 and tile != null:
					await get_tree().create_timer(0.18).timeout  # taşlar arası tempo
			"tier":
				run_chip = int(step["chips"])
				if run_chip > disp_chip:
					_count_label(chip_value, run_chip, 0.2)
					_pop(chip_seal_panel, 1.12)
					await get_tree().create_timer(0.32).timeout
					disp_chip = run_chip
			_:
				# Joker/patron adımı — önizlemede OLMAYAN (rastgele) etki tek tek "bam"lar.
				var jcard := _find_joker_card(String(step.get("id", "")))
				var src_pos := _node_center(mult_seal_panel) + Vector2(0, -52)
				if jcard != null:
					src_pos = _node_center(jcard) + Vector2(0, -jcard.size.y * 0.5 - 18.0)
				var juiced := false
				for op in step["ops"]:
					run_chip = _op_chip(op, run_chip)
					run_mult = _op_mult(op, run_mult)
					if run_chip > disp_chip or run_mult > disp_mult:
						if not juiced and jcard != null:
							_juice_joker(jcard)  # squash/stretch zıplama (karakter)
							_ember_burst(_node_center(jcard), 10, 2.6)
							juiced = true
						_show_op(op, src_pos, run_chip, run_mult)
						await get_tree().create_timer(0.34).timeout
						disp_chip = maxi(disp_chip, run_chip)
						disp_mult = maxf(disp_mult, run_mult)
				run_chip = int(step["chips"])
				run_mult = float(step["mult"])
	# Final: çip × çarpan patlaması
	chip_value.text = str(res["chips"])
	mult_value.text = _fmt(res["mult"])
	_pop(chip_seal_panel, 1.16)
	_pop(mult_seal_panel, 1.16)
	# ÇİP ve ÇARPAN kutuları "×" işaretinde çarpışsın → ardından GEÇİCİ büyük SLAM (turuncu kutu kalktı)
	await _collide_seals()
	var mid := (_node_center(chip_seal_panel) + _node_center(mult_seal_panel)) * 0.5  # çarpışma noktası
	_shake(min(11.0, 4.0 + res["score"] / 80.0), 0.38)
	_slam_score(mid, int(res["score"]))  # vurucu geçici SLAM (font + partikül + halka içeride)
	_play_collect(_collect_big, 1.0)  # final toplam çanı
	# (Kutlama yazısı KALDIRILDI — kullanıcı "kötü duruyor" dedi; _praise_banner artık çağrılmıyor)
	await get_tree().create_timer(0.35).timeout
	# TUR SKORU: skor "akarak" eklenir (count-up) + tok pop + kısa kor parlaması
	_count_label(round_score_label, int(state["round"]["score"]), 0.5)
	_pop(round_score_label, 1.45)
	_flash_color(round_score_label, T.EMBER, 0.45)
	_ember_burst(_node_center(round_score_label), 8, 2.6)
	# Skor tur toplamına AKTI → çip×çarpan kutuları O AN sıfırlansın (HER durumda; dükkana
	# gidince de boş kalsın). Alev _drive_seal_flame ile değer düşünce yavaşça azalarak söner.
	await get_tree().create_timer(0.18).timeout
	await _countdown_seals(0.42)
	_hide_tier()  # kelime-tipi etiketi de yumuşakça boşalsın (dükkana gidince "Orta ×2" kalmasın)

# Tek bir katkıyı (op) GÖSTER: uçan pill + ilgili damga (çip/çarpan) pop + kıvılcım +
# yükselen perdeli "bam" sesi + sayacı yeni değere akıt. run = op SONRASI değer.
# set_box=false → baloncuk + pop/kıvılcım/ses gösterilir AMA kutu değeri değişmez (önizleme tabanı
# zaten kutuda; baloncuk "juice" olarak görünür, kutu düşmez).
func _show_op(op: Dictionary, src_pos: Vector2, run_chip: int, run_mult: float, set_box: bool = true) -> void:
	var is_chip: bool = op.get("op", "") == "chip"
	# Katkı, ETKİ ETTİĞİ yerde (harf/joker üstü) karo'lu büyük puan + "ÇARPAN/ÇİP" etiketiyle (Balatro tarzı).
	_float_num(src_pos, _op_value(op), T.CHIP_BADGE if is_chip else T.MULT, "ÇİP" if is_chip else "ÇARPAN")
	if is_chip:
		if set_box:
			_count_label(chip_value, run_chip, 0.14)
		_pop(chip_seal_panel, 1.2)
		_ember_burst(_node_center(chip_seal_panel), 9, 2.4)
		_add_trauma(TRAUMA_CHIP_OP)  # çip katkısı: ufak
	else:
		if set_box:
			mult_value.text = _fmt(run_mult)
		_pop(mult_seal_panel, 1.22)
		_ember_burst(_node_center(mult_seal_panel), 11, 2.8)
		_add_trauma(TRAUMA_MULT_OP)  # çarpan katkısı: orta kick
	_bam_sound()

# op SONRASI çip değeri (görsel sayaç için engine matematiğini yansıtır).
func _op_chip(op: Dictionary, chip: int) -> int:
	if op.get("op", "") == "chip":
		return chip + int(op["n"])
	return chip

# op SONRASI çarpan değeri.
func _op_mult(op: Dictionary, mult: float) -> float:
	match op.get("op", ""):
		"mult": return mult + float(op["n"])
		"xmult": return mult * float(op["n"])
	return mult

# Ardışık katkılarda perdesi yükselen kısa "bam" (tatmin zinciri).
func _bam_sound() -> void:
	if _ui_sfx and _blink:
		_ui_sfx.stream = _blink
		_ui_sfx.pitch_scale = 1.0 + min(_bam * 0.07, 0.9)
		_ui_sfx.play()
	_bam += 1

func _fire_tile(tile: Control, gain: int) -> void:
	var tw := create_tween()
	tw.tween_property(tile, "scale", Vector2(1.22, 1.22), 0.08).set_trans(Tween.TRANS_BACK)
	tw.tween_property(tile, "scale", Vector2.ONE, 0.12)
	_ember_burst(_node_center(tile), 12, 3.0)
	# Geliştirilmiş taş (foil/holo/cam…) → ekstra RENKLİ kıvılcım (özel his)
	if tile.has_meta("enh_color"):
		_ember_burst(_node_center(tile), 14, 3.2, null, tile.get_meta("enh_color"))
	_add_trauma(TRAUMA_TILE)  # her taşta küçük his
	if _ui_sfx and _blink:           # harf "blink" sesi (kullanıcı ekledi) — her puan gelişinde
		_ui_sfx.stream = _blink
		_ui_sfx.pitch_scale = 1.0   # op zinciri perdeyi yükseltmiş olabilir → taban perdeye dön
		_ui_sfx.play()
	if gain > 0:
		_float_gain_on_tile(tile, gain)  # +N taşın TEPESİNDE belirir (sola uçmaz)

# Oynanan taşın TEPESİNDE Balatro tarzı BÜYÜK "+N" (beyaz, kalın koyu kontur) + mavi karo aksanı.
func _float_gain_on_tile(tile: Control, gain: int) -> void:
	if not is_instance_valid(tile):
		return
	var top := _node_center(tile) + Vector2(0.0, -tile.size.y * 0.5 - 16.0)
	_float_num(top, "+%d" % gain, T.CHIP_BADGE)

# Verilen KONUMDA karo'lu büyük puan ("+50" / "×1.5" / "+10"). color = karo rengi
# (çip → mavi, çarpan → kırmızı). Radiuslu pill DEĞİL — keskin karo + kalın puan.
func _float_num(top: Vector2, text: String, color: Color, label: String = "") -> void:
	var holder := Control.new()
	holder.z_index = 46
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	holder.position = top
	# KARO — büyük, ORTALI, DÜŞÜK opacity (pixel). ÖNCE gelir; puan ÜSTÜNE biner.
	var dia := Panel.new()
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color(color.r, color.g, color.b, 0.32)  # düşük opacity
	dsb.set_corner_radius_all(0)
	dsb.anti_aliasing = false
	dia.add_theme_stylebox_override("panel", dsb)
	var dsz := 66.0
	dia.size = Vector2(dsz, dsz)
	dia.position = Vector2(-dsz / 2.0, -dsz / 2.0)
	dia.pivot_offset = Vector2(dsz / 2.0, dsz / 2.0)
	dia.rotation = deg_to_rad(45.0)
	dia.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dia.modulate.a = 0.0
	dia.scale = Vector2(0.4, 0.4)
	holder.add_child(dia)
	# Puan — karonun TAM ÜSTÜNDE ortalı (yanında DEĞİL), beyaz kalın kontur, pixel font; SONRA gelir
	var lbl := _label(text, 46, Color.WHITE, Color(0.05, 0.03, 0.04), 6)
	lbl.add_theme_font_override("font", _tile_font)
	lbl.size = Vector2(140, 60)
	lbl.position = Vector2(-70, -30)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.modulate.a = 0.0
	holder.add_child(lbl)
	# "ÇARPAN" / "ÇİP" küçük etiketi (Balatro "X2 Mult" tarzı) — değerin ALTINDA, renk tonlu
	var slbl: Label = null
	if label != "":
		slbl = _label(label, 19, color.lerp(Color.WHITE, 0.25), Color(0.05, 0.03, 0.04), 4)
		slbl.add_theme_font_override("font", _tile_font)
		slbl.size = Vector2(150, 26)
		slbl.position = Vector2(-75, 26)
		slbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slbl.modulate.a = 0.0
		holder.add_child(slbl)
	# 1) ÖNCE karo: küçükten yaylanarak belir
	var dt := create_tween()
	dt.set_parallel(true)
	dt.tween_property(dia, "modulate:a", 1.0, 0.14)
	dt.tween_property(dia, "scale", Vector2(1.12, 1.12), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	dt.chain().tween_property(dia, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_SINE)
	# 2) SONRA puan: karonun üstünde belir
	var lt := create_tween()
	lt.tween_interval(0.2)
	lt.tween_property(lbl, "modulate:a", 1.0, 0.14)
	if slbl != null:
		lt.parallel().tween_property(slbl, "modulate:a", 1.0, 0.14)
	# 3) Birlikte yavaşça yüksel + sön
	var rt := create_tween()
	rt.tween_interval(0.55)
	rt.tween_property(holder, "position:y", top.y - 28.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	rt.parallel().tween_property(holder, "modulate:a", 0.0, 0.4).set_delay(0.12)
	rt.tween_callback(holder.queue_free)

func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * p0 + 2.0 * u * t * p1 + t * t * p2

# Joker kartını id ile bul (skor sırasında tetikleneni vurgulamak için).
func _find_joker_card(jid: String) -> Control:
	if jid == "" or joker_box == null:
		return null
	for c in joker_box.get_children():
		if c.has_meta("jid") and String(c.get_meta("jid")) == jid:
			return c
	return null

func _op_value(op: Dictionary) -> String:
	match op.get("op", ""):
		"chip": return "+%d" % int(op["n"])
		"mult": return "+%s" % _fmt(op["n"])
		"xmult": return "×%s" % _fmt(op["n"])
	return ""

func _op_label(op: Dictionary) -> String:
	return "ÇİP" if op.get("op", "") == "chip" else "ÇARPAN"

func _op_color(op: Dictionary) -> Color:
	return T.CHIP_BADGE if op.get("op", "") == "chip" else T.MULT

# Joker etkisi uçan etiket — PIXEL-ART kutu (keskin köşe, chunky kenar, AA yok), TEK temiz satır.
func _float_op_pill(global_pos: Vector2, value_text: String, label_text: String, color: Color) -> void:
	if value_text == "":
		return
	var holder := Control.new()
	holder.z_index = 36
	fx_layer.add_child(holder)
	var pill := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	# BORDERSIZ + renk-TONLU yarı saydam (flat solid değil) + yumuşak parıltı (neon değil, düşük alfa)
	sb.bg_color = Color(color.r * 0.28, color.g * 0.28, color.b * 0.34, 0.6)
	sb.set_corner_radius_all(15)
	sb.shadow_color = Color(color.r, color.g, color.b, 0.3)  # yumuşak muted glow
	sb.shadow_size = 14
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 5
	sb.content_margin_bottom = 7
	pill.add_theme_stylebox_override("panel", sb)
	# üst sheen (cam hissi — efektli derinlik)
	var sheen := Panel.new()
	var shsb := StyleBoxFlat.new()
	shsb.bg_color = Color(1, 1, 1, 0.08)
	shsb.corner_radius_top_left = 15
	shsb.corner_radius_top_right = 15
	sheen.add_theme_stylebox_override("panel", shsb)
	sheen.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	sheen.offset_bottom = 16
	sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Sadece DEĞER (×2 / +15) — "ÇARPAN/ÇİP" yazısı YOK; renk ayırt eder (kullanıcı)
	var txt := _label(value_text, 34, color.lerp(Color.WHITE, 0.35), T.OUTLINE, 5)
	pill.add_child(txt)
	holder.add_child(pill)
	pill.add_child(sheen)  # metnin üstünde ince ışıltı
	await get_tree().process_frame
	if not is_instance_valid(holder):
		return
	var hs := pill.size
	holder.pivot_offset = hs / 2.0
	holder.global_position = global_pos - hs / 2.0
	holder.scale = Vector2(0.4, 0.4)
	_ember_burst(global_pos, 9, 2.4)  # belirince kıvılcım (güzel efekt)
	var by := holder.position.y
	var tw := create_tween()
	tw.tween_property(holder, "scale", Vector2(1.16, 1.16), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(holder, "scale", Vector2(1.0, 1.0), 0.14)
	tw.tween_interval(0.45)  # okunur dursun
	tw.tween_property(holder, "position:y", by - 62.0, 0.55).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(holder, "modulate:a", 0.0, 0.55)
	tw.tween_callback(holder.queue_free)

# Uçan puan: harften patlar → yay çizip ÇİP kutusuna uçar → varınca kutu zıplar.
func _fly_score(start_global: Vector2, gain: int) -> void:
	var holder := Control.new()
	holder.z_index = 30
	fx_layer.add_child(holder)
	var pill := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.10, 0.78)  # yazının arkasında küçük koyu zemin
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	pill.add_theme_stylebox_override("panel", sb)
	var l := _label("+%d" % gain, 54, T.CHIP_BADGE, T.OUTLINE, 7)
	l.add_theme_font_override("font", _tile_font)
	pill.add_child(l)
	holder.add_child(pill)
	await get_tree().process_frame
	if not is_instance_valid(holder):
		return
	var hs := pill.size
	holder.pivot_offset = hs / 2.0
	var p0 := start_global - hs / 2.0
	holder.global_position = p0
	holder.scale = Vector2(0.2, 0.2)
	var target := _node_center(chip_seal_panel) - hs / 2.0
	var ctrl := (p0 + target) * 0.5 + Vector2(0.0, -130.0)
	_ember_burst(start_global, 8, 2.2)

	var fly := create_tween()
	# patlama gibi büyüyerek belir
	fly.tween_property(holder, "scale", Vector2(1.4, 1.4), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	fly.tween_property(holder, "scale", Vector2(1.05, 1.05), 0.08)
	fly.tween_interval(0.06)
	# yay çizerek çip kutusuna uç + küçül (paralel)
	fly.tween_method(func(k): holder.global_position = _bezier(p0, ctrl, target, k), 0.0, 1.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fly.parallel().tween_property(holder, "scale", Vector2(0.6, 0.6), 0.42)
	# varış: kutu zıpla + kıvılcım + yok et
	fly.tween_callback(_on_chip_arrive)
	fly.tween_property(holder, "modulate:a", 0.0, 0.1)
	fly.tween_callback(holder.queue_free)

func _on_chip_arrive() -> void:
	if chip_seal_panel and is_instance_valid(chip_seal_panel):
		_pop(chip_seal_panel, 1.16)
		_ember_burst(_node_center(chip_seal_panel), 8, 2.4)
	# collect tık'ı — ardışık varışlarda perde yükselir (ka-çing çing çing)
	_play_collect(_collect, 1.0 + min(_coin_idx * 0.05, 0.6))
	_coin_idx += 1

func _pop(node: Control, amount: float) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.pivot_offset = node.size / 2.0
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2(amount, amount), 0.08).set_trans(Tween.TRANS_BACK)
	tw.tween_property(node, "scale", Vector2.ONE, 0.14)

# Joker tetiklenince KARAKTERLİ zıplama: anticipation squash → stretch'le zıpla → in iniş → otur.
# (Sadece scale + position:y — _process joker rotasyonunu her kare ezdiği için rotasyona dokunmuyoruz.)
func _juice_joker(card: Control) -> void:
	if not is_instance_valid(card):
		return
	card.pivot_offset = card.size / 2.0
	var y0 := card.position.y
	var tw := create_tween()
	tw.tween_property(card, "scale", Vector2(1.2, 0.82), 0.06).set_trans(Tween.TRANS_QUAD)   # çömel (anticipation)
	tw.tween_property(card, "scale", Vector2(0.84, 1.24), 0.09).set_trans(Tween.TRANS_QUAD)  # uzayarak zıpla
	tw.parallel().tween_property(card, "position:y", y0 - 20.0, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2(1.14, 0.92), 0.08)                              # iniş squash
	tw.parallel().tween_property(card, "position:y", y0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(card, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK)          # otur

func _count_label(label: Label, to: int, dur: float) -> void:
	var from := int(label.text) if label.text.is_valid_int() else 0
	var tw := create_tween()
	tw.tween_method(func(v): label.text = str(int(round(v))), float(from), float(to), dur)

# Yeni ele geçerken çip×çarpan ANINDA 0/1 yapılmasın → geriye doğru HIZLICA sayıp insin (hoş).
# Oyuncu bu sırada taş seçerse _update_word_display tween'i öldürür (önizleme öncelikli).
func _countdown_seals(dur: float) -> void:
	var c_from := int(chip_value.text) if chip_value.text.is_valid_int() else 0
	var m_from := float(mult_value.text) if mult_value.text.is_valid_float() else 1.0
	if c_from <= 0 and m_from <= 1.0:
		return  # zaten sıfırda → animasyon gereksiz
	if _seal_cd_tw != null and _seal_cd_tw.is_valid():
		_seal_cd_tw.kill()
	_seal_cd_tw = create_tween()
	_seal_cd_tw.set_parallel(true)
	_seal_cd_tw.tween_method(func(v): chip_value.text = str(int(round(v))), float(c_from), 0.0, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	# Çarpan da YUVARLANMIŞ tam sayı gösterilir (ham float "0.9485845" gibi ondalık çıkmasın);
	# zaten 1'e iniyor → tam sayı adımları temiz durur.
	_seal_cd_tw.tween_method(func(v): mult_value.text = _fmt(round(v)), m_from, 1.0, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	# tween öldürülürse finished gelmez → güvenli olması için süreyi timer ile bekle
	await get_tree().create_timer(dur).timeout

# Etiketin yazı rengini kısa süre flash_color'a çevirip beyaza geri döndürür (parlama).
func _flash_color(label: Label, flash_color: Color, dur: float) -> void:
	if label == null or not is_instance_valid(label):
		return
	label.add_theme_color_override("font_color", flash_color)
	var tw := create_tween()
	tw.tween_method(func(c): label.add_theme_color_override("font_color", c), flash_color, Color.WHITE, dur)

func _node_center(node: Control) -> Vector2:
	return node.global_position + node.size / 2.0

# ── ÇİP × ÇARPAN çarpışması (final beat) ──
# Gerçek seal panelleri YERİNDE kalır (layout bozulmaz); iki "hayalet" rozet
# kutulardan ortadaki "×" noktasına kayıp çarpışır → kor patlaması + halka + trauma.
func _collide_seals() -> void:
	if not is_instance_valid(chip_seal_panel) or not is_instance_valid(mult_seal_panel):
		return
	var chip_c := _node_center(chip_seal_panel)
	var mult_c := _node_center(mult_seal_panel)
	var meet := (chip_c + mult_c) * 0.5  # "×" işaretinin bulunduğu orta nokta
	var g_chip := _seal_ghost(chip_c, chip_value.text, T.CHIP_BADGE)
	var g_mult := _seal_ghost(mult_c, "×" + mult_value.text, T.MULT)
	# 1) İçeri hızlanarak yaklaş (ease-in → çarpışma vurgusu)
	var dur := 0.24
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(g_chip, "global_position", meet - g_chip.size * 0.5, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(g_mult, "global_position", meet - g_mult.size * 0.5, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(g_chip, "scale", Vector2(1.18, 1.18), dur)
	tw.tween_property(g_mult, "scale", Vector2(1.18, 1.18), dur)
	await tw.finished
	# 2) ÇARPIŞMA: kor + halka + orta trauma
	_ember_burst(meet, 24, 3.6)
	_flash_ring(meet, 7.0, Color(T.EMBER.r, T.EMBER.g, T.EMBER.b, 0.85))
	_add_trauma(TRAUMA_COLLIDE)
	# 3) Hayaletler bir an punch yapıp sönsün
	var pt := create_tween()
	pt.set_parallel(true)
	pt.tween_property(g_chip, "scale", Vector2(1.45, 1.45), 0.08).set_trans(Tween.TRANS_BACK)
	pt.tween_property(g_mult, "scale", Vector2(1.45, 1.45), 0.08).set_trans(Tween.TRANS_BACK)
	pt.chain().tween_property(g_chip, "modulate:a", 0.0, 0.12)
	pt.parallel().tween_property(g_mult, "modulate:a", 0.0, 0.12)
	pt.chain().tween_callback(g_chip.queue_free)
	pt.tween_callback(g_mult.queue_free)
	await get_tree().create_timer(0.12).timeout

# Çarpışma için tek kullanımlık "rozet" hayaleti: dönük karo + büyük puan (fx_layer'da).
# center = global merkez; holder merkezi oraya oturur (tween global_position ile taşınır).
func _seal_ghost(center: Vector2, value_text: String, color: Color) -> Control:
	var holder := Control.new()
	holder.z_index = 48
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size = Vector2(120, 96)
	holder.pivot_offset = holder.size * 0.5
	fx_layer.add_child(holder)
	holder.global_position = center - holder.size * 0.5
	# karo zemin
	var dia := Panel.new()
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color(color.r, color.g, color.b, 0.42)
	dsb.set_corner_radius_all(0)
	dsb.anti_aliasing = false
	dia.add_theme_stylebox_override("panel", dsb)
	var dsz := 78.0
	dia.size = Vector2(dsz, dsz)
	dia.position = holder.size * 0.5 - Vector2(dsz, dsz) * 0.5
	dia.pivot_offset = Vector2(dsz, dsz) * 0.5
	dia.rotation = deg_to_rad(45.0)
	dia.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(dia)
	# puan
	var lbl := _label(value_text, 50, Color.WHITE, Color(0.05, 0.03, 0.04), 6)
	lbl.add_theme_font_override("font", _tile_font)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(lbl)
	return holder

# Turuncu TOPLAM kutusu kalktı → final sonucu EKRANDA geçici büyük SLAM ile göster:
# 2.0→0.95→1.0 patlama + count-up, kısa bekle, yükselip sön (fx_layer'da, kalıcı değil).
func _slam_score(center: Vector2, score: int) -> void:
	var lbl := _label("0", 84, Color.WHITE, T.EMBER, 10)
	# ÖNEMLİ: fx_layer bir Node2D → Control teması (font) MİRAS ALINMAZ. Oyunun ana sayı
	# fontunu (m6x11) elle ver ki çip/çarpan/tur-skoru ile TUTARLI olsun.
	lbl.add_theme_font_override("font", _tile_font)
	lbl.z_index = 50
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.size = Vector2(320, 120)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fx_layer.add_child(lbl)
	lbl.pivot_offset = lbl.size * 0.5
	lbl.global_position = center - lbl.size * 0.5

	# VURUCU çarpma anı: kor patlaması + halka + kısa parlak flash
	_ember_burst(center, clampi(score / 14 + 18, 18, 64), 3.6)
	_flash_ring(center, 7.0, Color(T.EMBER.r, T.EMBER.g, T.EMBER.b, 0.85))

	# SLAM: büyükten SERT otur (2.3→0.9→1.0) + parlak başlayıp normale dön
	lbl.scale = Vector2(2.3, 2.3)
	lbl.modulate = Color(1.5, 1.4, 1.2)
	var tw := create_tween()
	tw.tween_property(lbl, "scale", Vector2(0.9, 0.9), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate", Color.WHITE, 0.18)
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.10)
	_count_label(lbl, score, 0.28)

	var life := create_tween()  # kısa bekle → yüksel + sön → temizle
	life.tween_interval(0.7)
	life.tween_property(lbl, "global_position:y", lbl.global_position.y - 30.0, 0.4).set_trans(Tween.TRANS_SINE)
	life.parallel().tween_property(lbl, "modulate:a", 0.0, 0.35)
	life.tween_callback(lbl.queue_free)

# Eski API korunur: piksel "amount" → trauma'ya çevrilir (çağrı noktaları değişmez).
# Artık ani jitter değil; trauma birikip _process'te pürüzsüz sönerek uygulanır.
func _shake(amount: float, _dur: float) -> void:
	_add_trauma(clampf(amount / 14.0, 0.0, 0.85))

# Trauma ekle (0..1'e clamp). Ayar kapalıysa hiç birikmez.
func _add_trauma(amount: float) -> void:
	if not Settings.shake_on:
		return
	_trauma = clampf(_trauma + amount, 0.0, 1.0)

# ── Partikül (kor/alev) ──
func _make_spark_tex() -> Texture2D:
	# Yumuşak yuvarlak kıvılcım (sıcak kor hissi).
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.add_point(0.5, Color(1, 1, 1, 0.7))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 32
	tex.height = 32
	return tex

func _ember_burst(global_pos: Vector2, amount: int, max_scale: float, parent: Node = null, tint = null) -> void:
	if not Settings.particles_on:
		return
	var p := CPUParticles2D.new()
	(parent if parent != null else fx_layer).add_child(p)  # overlay üstünde göstermek için parent verilebilir
	p.global_position = global_pos
	p.texture = _spark_tex
	p.material = _add_mat  # additive → parlayan kor/alev
	p.one_shot = true
	p.emitting = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.55
	p.direction = Vector2(0, -1)
	p.spread = 180.0  # tam radyal saçılma (keskin patlama)
	p.gravity = Vector2(0, 360.0)  # kıvılcımlar hızla düşer
	p.initial_velocity_min = 160.0
	p.initial_velocity_max = 430.0
	p.damping_min = 80.0
	p.damping_max = 170.0
	p.scale_amount_min = max_scale * 0.25
	p.scale_amount_max = max_scale * 0.6
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 1.0))
	sc.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = sc
	var ramp := Gradient.new()
	if tint != null:
		# Renkli kıvılcım (geliştirilmiş taş tetiklemesi: foil mavi, holo mor, altın sarı…)
		var tc: Color = tint
		ramp.set_color(0, Color(1.0, 1.0, 1.0))  # beyaz çekirdek
		ramp.add_point(0.4, tc)
		ramp.set_color(1, Color(tc.r, tc.g, tc.b, 0.0))
	else:
		ramp.set_color(0, Color(1.0, 0.95, 0.75))  # sıcak beyaz çekirdek
		ramp.add_point(0.35, T.EMBER)
		ramp.add_point(0.75, T.MULT)
		ramp.set_color(1, Color(T.MULT.r, T.MULT.g, T.MULT.b, 0.0))
	p.color_ramp = ramp
	p.finished.connect(p.queue_free)

# Skorda kutunun ÜSTÜNDE (dışarıda, yukarıda) dalgalı SHADER alevi — sadece o an, sonra söner.
func _seal_flame_burst(panel: Control, color: Color, dur: float) -> void:
	if not Settings.particles_on or panel == null or not is_instance_valid(panel):
		return
	var w := panel.size.x
	var fh := 64.0
	var c := _node_center(panel)
	var fr := ColorRect.new()
	fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fr.size = Vector2(w, fh)
	fr.position = Vector2(c.x - w / 2.0, c.y - panel.size.y / 2.0 - fh)  # tabanı kutu üst kenarı
	fr.z_index = 20
	var fm := ShaderMaterial.new()
	fm.shader = load("res://shaders/box_flame.gdshader")
	fm.set_shader_parameter("flame_color", Color(color.r, color.g, color.b, 0.85))
	fm.set_shader_parameter("intensity", 1.0)
	fr.material = fm
	fr.modulate.a = 0.0
	fx_layer.add_child(fr)
	var tw := create_tween()
	tw.tween_property(fr, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(dur)
	tw.tween_property(fr, "modulate:a", 0.0, 0.32).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(fr.queue_free)

# ── (eski) partikül alevi — artık kullanılmıyor; _seal_flame_burst geçti ──
func _seal_flame(panel: Control, base: Color, tip: Color, amount: int, dur: float) -> void:
	if not Settings.particles_on:
		return
	if panel == null or not is_instance_valid(panel):
		return
	var p := CPUParticles2D.new()
	p.texture = _spark_tex
	p.material = _add_mat  # additive → parlayan kor
	p.amount = amount
	p.lifetime = 0.7
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(panel.size.x * 0.42, 5)
	p.direction = Vector2(0, -1)
	p.spread = 18.0
	p.gravity = Vector2(0, -120.0)  # yüksel (alev)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 95.0
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.62
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.5))
	sc.add_point(Vector2(0.22, 1.0))
	sc.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = sc
	var ramp := Gradient.new()
	ramp.set_color(0, Color(tip.r, tip.g, tip.b, 0.0))
	ramp.add_point(0.18, Color(1.0, 0.96, 0.8))  # sıcak beyaz çekirdek
	ramp.add_point(0.55, tip)
	ramp.set_color(1, Color(base.r, base.g, base.b, 0.0))
	p.color_ramp = ramp
	fx_layer.add_child(p)
	var c := _node_center(panel)
	p.position = Vector2(c.x, c.y + panel.size.y * 0.5 - 6)
	p.emitting = true
	await get_tree().create_timer(dur).timeout
	if is_instance_valid(p):
		p.emitting = false
		await get_tree().create_timer(p.lifetime).timeout
		if is_instance_valid(p):
			p.queue_free()

# Merkez parlama (büyük skor anı) — genişleyip sönen sıcak hale.
func _flash_ring(global_pos: Vector2, target_scale: float, color: Color) -> void:
	var s := Sprite2D.new()
	fx_layer.add_child(s)
	s.texture = _spark_tex
	s.material = _add_mat
	s.global_position = global_pos
	s.modulate = color
	s.scale = Vector2(0.3, 0.3)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(s, "scale", Vector2(target_scale, target_scale), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(s.queue_free)

func _fmt(n) -> String:
	if typeof(n) == TYPE_FLOAT and n == floor(n):
		return str(int(n))
	return str(n)

func _praise_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", T.load_font())  # m6x11 pixel
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.02))
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

# ── Kutlama banner'ı (uzun/iyi kelimede motive edici animasyonlu yazı + partikül) ──
func _praise_banner(score: int, target: int, word_len: int) -> void:
	var ratio := float(score) / maxf(1.0, float(target))
	var hype := 0
	if ratio >= 1.0: hype = 4
	elif ratio >= 0.55: hype = 3
	elif ratio >= 0.32: hype = 2
	elif ratio >= 0.16: hype = 1
	# Uzun kelime motivasyonu (kullanıcı: "uzun kelimelerde")
	if word_len >= 8: hype = maxi(hype, 4)
	elif word_len >= 6: hype = maxi(hype, 3)
	elif word_len >= 5: hype = maxi(hype, 2)
	if hype == 0:
		return
	var labels := ["", "GÜZEL!", "SÜPER!", "MUHTEŞEM!", "İNANILMAZ!"]
	var palette := [T.TEXT, T.GOOD, T.CHIP_BADGE, T.ORANGE, T.EMBER]
	var col: Color = palette[hype]
	var vp := get_viewport_rect().size
	var pos := Vector2(vp.x * 0.58, vp.y * 0.30)

	var size := 66 + hype * 18
	# Gölge-katmanlı: arkada koyu kopya → derinlik (düz görünmesin); EĞİK DEĞİL.
	var holder := Control.new()
	holder.z_index = 41
	fx_layer.add_child(holder)
	# Renkli arkaplan band (yazıdan biraz büyük → ağırlık/derinlik, düz görünmesin)
	var back := Panel.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.05, 0.025, 0.03, 0.55)
	bsb.set_corner_radius_all(18)
	bsb.set_border_width_all(3)
	bsb.border_color = Color(col.r, col.g, col.b, 0.85)
	bsb.shadow_color = Color(col.r, col.g, col.b, 0.35)
	bsb.shadow_size = 14
	back.add_theme_stylebox_override("panel", bsb)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(back)
	var shadow := _praise_label(labels[hype], size, Color(0.05, 0.02, 0.02, 0.85))
	shadow.position = Vector2(5, 7)
	holder.add_child(shadow)
	var main := _praise_label(labels[hype], size, col)
	holder.add_child(main)
	await get_tree().process_frame  # boyut otursun
	if not is_instance_valid(holder):
		return
	var ls := main.size
	shadow.custom_minimum_size = ls
	back.position = Vector2(-26, -6)
	back.size = ls + Vector2(52, 14)
	holder.pivot_offset = ls / 2.0
	holder.global_position = pos - ls / 2.0
	holder.scale = Vector2(0.3, 0.3)
	holder.modulate.a = 0.0
	var base_y := holder.position.y

	var tw := create_tween()
	tw.tween_property(holder, "scale", Vector2(1.42, 1.42), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(holder, "modulate:a", 1.0, 0.12)
	tw.tween_property(holder, "scale", Vector2(1.0, 1.0), 0.14).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(0.5)
	tw.tween_property(holder, "position:y", base_y - 66.0, 0.45).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(holder, "modulate:a", 0.0, 0.45)
	tw.tween_callback(holder.queue_free)

	_ember_burst(pos, 18 + hype * 14, 3.0 + hype * 0.4)
	_flash_ring(pos, 6.0 + hype * 1.2, Color(col.r, col.g, col.b, 0.7))  # her seviyede parlama
	if hype >= 3:
		_shake(5.0 + hype * 2.0, 0.4)
		_play_collect(_collect_big, 1.0 + (hype - 3) * 0.18)

# ── Demo ──
func _demo_permute(a: Array) -> Array:
	if a.size() <= 1:
		return [a]
	var out := []
	for i in a.size():
		var rest: Array = a.duplicate()
		rest.remove_at(i)
		for p in _demo_permute(rest):
			var perm := [a[i]]
			perm.append_array(p)
			out.append(perm)
	return out

func _demo_find(hand: Array):
	var max_len: int = min(5, hand.size())
	for length in range(max_len, 1, -1):
		var res = _demo_rec(hand, 0, [], length)
		if res != null:
			return res
	return null

func _demo_rec(hand: Array, start: int, pick: Array, length: int):
	if pick.size() == length:
		for p in _demo_permute(pick):
			var w := ""
			for idx in p:
				w += hand[idx]["char"]
			if Dictionary_.is_valid_word(w, 2):
				var ids := []
				for idx in p:
					ids.append(int(hand[idx]["id"]))
				return ids
		return null
	for i in range(start, hand.size()):
		var np: Array = pick.duplicate()
		np.append(i)
		var r = _demo_rec(hand, i + 1, np, length)
		if r != null:
			return r
	return null

func demo_select_valid() -> void:
	var found = _demo_find(state["round"]["hand"])
	if found == null:
		return
	selected_ids = found
	for id in found:
		if tile_by_id.has(id):
			tile_by_id[id].set_meta("selected", true)
	_layout_hand(false)
	_update_word_display()

func demo_play() -> void:
	_on_play()

# Debug: hedefi yükselt → kelime oyna ama tur BİTMESİN (diff-refill görsel doğrulama).
func demo_play_refill() -> void:
	state["round"]["target"] = 999999
	demo_select_valid()
	_on_play()

# ── State → görsel ──
func _refresh(deal_in: bool, sound: bool = false) -> void:
	_refresh_hud()
	_rebuild_hand(deal_in, sound)
	_update_word_display()

# Sol panel + joker rafı + sayaçlar (el'e DOKUNMAZ → diff-refill bunu ayrı kullanır).
func _refresh_hud() -> void:
	var run: Dictionary = state["run"]
	var round_d: Dictionary = state["round"]
	_set_shop_sidebar(false)  # oyun modunda normal blind/hedef göster
	blind_header.text = String(round_d["blind"]["name"]).to_upper()
	target_label.text = str(round_d["target"])
	var bt := String(round_d["blind"].get("type", "small"))
	var rew := int(round_d["blind"].get("reward", 1))
	target_reward_label.text = "Ödül: " + "$".repeat(clampi(rew, 1, 6))
	# blind çipi tür rengine göre: tur1=yeşil, tur2=altın, patron=kırmızı
	var bc: Color = T.GOOD if bt == "small" else (T.BRASS if bt == "big" else T.MULT)
	if _chip_sb:
		_chip_sb.bg_color = bc
	if blind_chip_icon:
		blind_chip_icon.text = "💀" if bt == "boss" else "●"
		blind_chip_icon.add_theme_color_override("font_color", T.INK if bt != "boss" else Color.WHITE)
	round_score_label.text = str(round_d["score"])
	money_label.text = "$%d" % run["money"]
	plays_value.text = str(round_d["playsLeft"])
	if _prev_plays >= 0 and round_d["playsLeft"] < _prev_plays:
		_float_minus(plays_value, _prev_plays - round_d["playsLeft"], T.MULT)
	_prev_plays = round_d["playsLeft"]
	discards_value.text = str(round_d["discardsLeft"])
	if _prev_discards >= 0 and round_d["discardsLeft"] < _prev_discards:
		_float_minus(discards_value, _prev_discards - round_d["discardsLeft"], T.CHIP_BADGE)
	_prev_discards = round_d["discardsLeft"]
	ante_label.text = "%d/8" % run["ante"]
	if round_value:
		round_value.text = str(run["blindIndex"] + 1)
	if deck_count_label:
		deck_count_label.text = "%d/%d" % [round_d["pool"].size(), run["deck"].size()]
	joker_caption.text = "JOKERLER %d/%d" % [run["jokers"].size(), MAX_JOKERS]
	_update_boss_banner()
	_rebuild_jokers()

func _update_boss_banner() -> void:
	_apply_blind_palette()
	if boss_panel == null:
		return
	var round_d: Dictionary = state["round"]
	var boss = round_d.get("boss", null)
	var is_boss: bool = round_d["blind"].get("type", "") == "boss" and boss != null
	boss_panel.visible = is_boss
	if is_boss:
		boss_name_label.text = "%s  %s" % [boss.get("icon", "💀"), String(boss["name"]).to_upper()]
		boss_desc_label.text = boss["description"]
		_pop(boss_panel, 1.05)

# Her tur arka planı farklı renk; patronlarda kırmızı (kullanıcı tercihi).
const COOL_PALETTES := [
	[Color(0.055, 0.165, 0.133), Color(0.106, 0.275, 0.227), Color(0.18, 0.43, 0.35)],  # yeşil
	[Color(0.04, 0.11, 0.18), Color(0.07, 0.22, 0.34), Color(0.12, 0.40, 0.52)],        # mavi
	[Color(0.10, 0.06, 0.18), Color(0.18, 0.12, 0.30), Color(0.34, 0.22, 0.50)],        # mor
	[Color(0.05, 0.14, 0.13), Color(0.08, 0.26, 0.24), Color(0.14, 0.44, 0.40)],        # teal
	[Color(0.15, 0.10, 0.04), Color(0.26, 0.17, 0.07), Color(0.44, 0.30, 0.12)],        # amber
	[Color(0.085, 0.085, 0.10), Color(0.17, 0.17, 0.20), Color(0.30, 0.30, 0.36)],      # charcoal (Balatro koyu)
]
const BOSS_PALETTE := [Color(0.17, 0.03, 0.03), Color(0.33, 0.07, 0.05), Color(0.55, 0.13, 0.10)]

func _palette_for_current() -> Array:
	if state["round"]["blind"].get("type", "") == "boss":
		return BOSS_PALETTE
	var idx: int = (int(state["run"]["ante"]) - 1) * 2 + int(state["run"]["blindIndex"])
	return COOL_PALETTES[idx % COOL_PALETTES.size()]

# Arka plan + sol paneli yeni palete YUMUŞAK geçirir (pat değil — kullanıcı tercihi).
func _apply_blind_palette() -> void:
	var bg = get_parent().get_node_or_null("Background")
	if bg == null or not (bg.material is ShaderMaterial):
		return
	_pal_mat = bg.material
	var target := _palette_for_current()
	var to_side: Color = (target[0] as Color)  # sol panel = palet deep tonu (belirgin)
	var to_themed: Color = (target[1] as Color).darkened(0.15)  # iç paneller = palet felt tonu
	var fs: Color = _sidebar_sb.bg_color if _sidebar_sb else T.SIDEBAR
	var sh_from: Color = _shuffle_sb.bg_color if _shuffle_sb else T.FELT_HI
	_pal_from = [
		_pal_mat.get_shader_parameter("color_deep"),
		_pal_mat.get_shader_parameter("color_felt"),
		_pal_mat.get_shader_parameter("color_high"),
		fs,
		_cur_themed,
		sh_from,
	]
	# shuffle butonu = paletin "high" tonu (en belirgin) — biraz canlandır
	_pal_to = [target[0], target[1], target[2], to_side, to_themed, (target[2] as Color).lightened(0.06)]
	_cur_themed = to_themed
	if _palette_tween and _palette_tween.is_valid():
		_palette_tween.kill()
	_palette_tween = create_tween()
	_palette_tween.tween_method(_palette_step, 0.0, 1.0, 0.85).set_trans(Tween.TRANS_SINE)

func _palette_step(t: float) -> void:
	if _pal_mat == null:
		return
	_pal_mat.set_shader_parameter("color_deep", (_pal_from[0] as Color).lerp(_pal_to[0], t))
	_pal_mat.set_shader_parameter("color_felt", (_pal_from[1] as Color).lerp(_pal_to[1], t))
	_pal_mat.set_shader_parameter("color_high", (_pal_from[2] as Color).lerp(_pal_to[2], t))
	if _sidebar_sb:
		_sidebar_sb.bg_color = (_pal_from[3] as Color).lerp(_pal_to[3], t)
	var tc := (_pal_from[4] as Color).lerp(_pal_to[4], t)
	for sb in _themed_sbs:
		sb.bg_color = tc
	if _shuffle_sb and _pal_from.size() > 5:
		_style_shuffle((_pal_from[5] as Color).lerp(_pal_to[5], t))

func _rebuild_jokers() -> void:
	for c in joker_box.get_children():
		c.queue_free()
	var jokers: Array = state["run"]["jokers"]
	var anim_i := 0
	for i in MAX_JOKERS:
		if i < jokers.size():
			var card: Control
			if _shop_mode:
				card = _sellable_joker_card(jokers[i])  # dükkânda tıkla → SAT
			else:
				card = _make_joker_card(jokers[i])
			joker_box.add_child(card)
			if _animate_jokers:
				_pop_in_joker(card, anim_i)
				anim_i += 1
		else:
			joker_box.add_child(_make_joker_slot())
	_animate_jokers = false

# Joker kartı zıplayarak belirir (soket değil, canlı). HBox pozisyonu ezdiği için scale+alpha.
func _pop_in_joker(card: Control, order: int) -> void:
	card.pivot_offset = Vector2(61, 75)
	card.modulate.a = 0.0
	card.scale = Vector2(0.45, 0.45)
	var delay := order * 0.06
	var tw := create_tween().set_parallel(true)
	tw.tween_property(card, "modulate:a", 1.0, 0.2).set_delay(delay)
	tw.tween_property(card, "scale", Vector2.ONE, 0.34).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ════════════════ 5e: DÜKKÂN / KAZAN / KAYBET ════════════════
var play_view: VBoxContainer    # oyun görünümü (kelime tahtası + el + aksiyonlar)
var shop_view: VBoxContainer    # dükkân görünümü (tahta içinde, Balatro tarzı)
var blind_view: VBoxContainer   # blind seçim görünümü (tahta içinde, Balatro)
var _shop_mode := false         # dükkândayken üst jokerler tıkla→SAT olur
var _animate_jokers := false    # bir sonraki _rebuild_jokers'ta kartlar zıplayarak gelsin
var overlay: Control            # kazan/kaybet ekranı (tam ekran)
var overlay_card: VBoxContainer
var _overlay_dim: ColorRect     # arka karartma (game-over'da kırmızı tint)
var _overlay_panel: PanelContainer
var _shop_reward = null
var _shop_msg := ""             # son satın alma sonucu (örn. "A harfin YALDIZ oldu")
var _shop_tags: Array = []      # fiyat etiketleri — layout sonrası ortalanır (call_deferred)
var _shop_shelves: Control = null  # dükkân rafları (öğretici turu konumlaması için)
var _shop_next_btn: Button = null  # "SONRAKİ TUR" butonu (öğretici turu için)
var _marquee_node: Control = null  # SHOP marquee (ampuller layout sonrası dizilir)

func _ensure_overlay() -> void:
	if overlay and is_instance_valid(overlay):
		return
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 100  # dükkân fiyat etiketleri (z_index=5) gibi öğelerin ÜSTÜNDE kalsın
	add_child(overlay)  # fx_layer'dan SONRA → her şeyin üstünde
	_overlay_dim = ColorRect.new()
	_overlay_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_dim.color = Color(0.02, 0.01, 0.0, 0.7)
	overlay.add_child(_overlay_dim)
	# Panel CenterContainer'da DEĞİL → elle ortalanır ki aşağıdan yaylanarak gelsin (_present_overlay).
	_overlay_panel = PanelContainer.new()
	_overlay_panel.add_theme_stylebox_override("panel", T.felt_panel(T.SIDEBAR, T.BRASS, 20))
	overlay.add_child(_overlay_panel)
	var panel := _overlay_panel
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 40)
	pad.add_theme_constant_override("margin_right", 40)
	pad.add_theme_constant_override("margin_top", 26)
	pad.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(pad)
	overlay_card = VBoxContainer.new()
	overlay_card.add_theme_constant_override("separation", 14)
	pad.add_child(overlay_card)

func _clear_overlay() -> void:
	_ensure_overlay()
	_theme_overlay(Color(0.02, 0.01, 0.0, 0.7), T.BRASS)  # varsayılan (info/pause/dükkân ödülü)
	for c in overlay_card.get_children():
		c.queue_free()

# Overlay panelini AŞAĞIDAN yaylanarak getir + karartmayı yumuşakça aç (Balatro juice).
# İçerik eklendikten SONRA çağrılır (panel boyutu için bir kare beklenir).
func _present_overlay() -> void:
	_ensure_overlay()
	overlay.visible = true
	_overlay_dim.modulate.a = 0.0
	_overlay_panel.modulate.a = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	var sz := _overlay_panel.size
	var screen := overlay.size
	var cx := (screen.x - sz.x) * 0.5
	var cy := (screen.y - sz.y) * 0.5
	_overlay_panel.pivot_offset = sz * 0.5
	_overlay_panel.position = Vector2(cx, cy + 300.0)  # ekranın altından başla
	_overlay_panel.scale = Vector2(0.9, 0.9)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_overlay_dim, "modulate:a", 1.0, 0.22)
	t.tween_property(_overlay_panel, "modulate:a", 1.0, 0.2)
	t.tween_property(_overlay_panel, "position:y", cy, 0.52).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_overlay_panel, "scale", Vector2.ONE, 0.52).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Overlay arka karartma + panel kenar rengi (game-over kırmızı, kazanç altın).
func _theme_overlay(dim_color: Color, border_color: Color) -> void:
	if _overlay_dim and is_instance_valid(_overlay_dim):
		_overlay_dim.color = dim_color
	if _overlay_panel and is_instance_valid(_overlay_panel):
		_overlay_panel.add_theme_stylebox_override("panel", T.felt_panel(T.SIDEBAR, border_color, 20))

func _close_overlay() -> void:
	if overlay and is_instance_valid(overlay):
		overlay.visible = false

# ── CASH OUT (tur sonu ödül dökümü — dükkândan ÖNCE, Balatro tarzı) ──
func _open_cash_out() -> void:
	var round_d: Dictionary = state["round"]
	# Önizleme (toplamadan) — para TOPLA'ya basınca artar (dükkân toplar).
	var reward: Dictionary = Economy.blind_reward(round_d["blind"], round_d, state["run"]["money"])
	_clear_overlay()
	_theme_overlay(Color(0.03, 0.12, 0.07, 0.82), T.GOOD)  # yeşil/altın kazanç teması
	overlay_card.add_child(_wavy_label("TUR GEÇİLDİ!", 30, T.GOOD, T.OUTLINE, 6.0, 3.0))
	# BÜYÜK TURUNCU "TOPLA" BANNER (Balatro "Cash Out" — chunky 3D pill, koyu yazı)
	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", T.button_filled(T.ORANGE))
	var brow := HBoxContainer.new()
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	brow.add_theme_constant_override("separation", 14)
	brow.add_child(_center(_label("TOPLA", 40, T.INK, Color(1, 1, 1, 0.25), 3)))
	# altın para rozeti
	var coin := PanelContainer.new()
	var coinsb := StyleBoxFlat.new()
	coinsb.bg_color = T.BRASS
	coinsb.set_corner_radius_all(10)
	coinsb.border_width_bottom = 4
	coinsb.border_color = T.BRASS.darkened(0.4)
	coinsb.content_margin_left = 16
	coinsb.content_margin_right = 16
	coinsb.content_margin_top = 2
	coinsb.content_margin_bottom = 2
	coin.add_theme_stylebox_override("panel", coinsb)
	coin.add_child(_center(_label("$%d" % reward["total"], 44, T.INK, Color(1, 1, 1, 0.3), 3)))
	brow.add_child(coin)
	banner.add_child(brow)
	overlay_card.add_child(banner)
	var gap0 := Control.new()
	gap0.custom_minimum_size = Vector2(0, 4)
	overlay_card.add_child(gap0)
	# Ödül dökümü (her satır: etiket .... +$Y altın PILL)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", T.stat_inset())
	panel.custom_minimum_size = Vector2(460, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 9)
	var rows := [
		["Tur ödülü", reward["base"]],
		["Kalan hak  ×%d" % round_d["playsLeft"], reward["leftover"]],
		["Faiz  (her $5 → $1)", reward["interest"]],
	]
	for r in rows:
		var line := HBoxContainer.new()
		var name_l := _label(String(r[0]), 19, T.TEXT)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(name_l)
		line.add_child(_gold_pill("+$%d" % int(r[1])))
		v.add_child(line)
	panel.add_child(v)
	overlay_card.add_child(panel)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	overlay_card.add_child(gap)
	var go := _chunky_btn("DÜKKANA GİT  →", T.GOOD, T.INK)
	go.custom_minimum_size = Vector2(0, 58)
	go.pressed.connect(_on_cash_out_continue)
	overlay_card.add_child(go)
	_present_overlay()
	_coin_juice()  # belirince altın kıvılcım

# Altın değer pill'i (cash out dökümü) — koyu yazı, altın yuvarlak zemin.
func _gold_pill(text: String) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = T.BRASS
	sb.set_corner_radius_all(9)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(_label(text, 19, T.INK))
	return p

# Cash out belirince altın kıvılcım yağmuru (juice).
func _coin_juice() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not (_overlay_panel and is_instance_valid(_overlay_panel)):
		return
	var c := _node_center(_overlay_panel)
	_ember_burst(c + Vector2(0, -_overlay_panel.size.y * 0.25), 18, 3.2)

func _on_cash_out_continue() -> void:
	_close_overlay()
	_go_to_shop()

# Dükkana gidiş geçişi: YUMUŞAK kararma → dükkan kurulur → hafif ölçek-pop ile belirir.
# (Girdap/vortex artık SADECE oyun başlangıcında — main.gd. Bu "diğer ekran" geçişi sakin/akıcı.)
func _go_to_shop() -> void:
	if _busy:
		_open_shop()
		return
	_busy = true
	var cover := ColorRect.new()
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	cover.color = Color(0.03, 0.07, 0.055)  # koyu keçe (saf siyah değil → sıcak his)
	cover.modulate.a = 0.0
	cover.z_index = 95  # board içeriğinin üstünde, overlay'in (100) altında
	add_child(cover)
	_play_card_move()  # whoosh
	# 1) Yumuşak kararma (ekran koyu keçeye süzülür)
	var tin := create_tween()
	tin.tween_property(cover, "modulate:a", 1.0, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tin.finished
	# 2) Görünümü kapalıyken değiştir
	_open_shop()
	await get_tree().process_frame     # dükkan layout otursun
	# 3) Dükkan hafif ölçek-pop ile açılır + örtü yumuşakça kalkar (girdap yok, akıcı)
	shop_view.pivot_offset = shop_view.size * 0.5
	shop_view.scale = Vector2(0.965, 0.965)
	var tout := create_tween()
	tout.set_parallel(true)
	tout.tween_property(cover, "modulate:a", 0.0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tout.tween_property(shop_view, "scale", Vector2.ONE, 0.48).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tout.chain().tween_callback(cover.queue_free)
	tout.tween_callback(func(): _busy = false)
	_add_trauma(0.06)                  # çok hafif "yerleşme" vurgusu

# ── BLIND SEÇİM EKRANI (Balatro "Choose your next Blind") — TAHTA-İÇİ uzun kolonlar ──
func _open_blind_select() -> void:
	_shop_mode = false
	play_view.visible = false
	shop_view.visible = false
	blind_view.visible = true
	if deck_holder:
		deck_holder.visible = true  # deste blind seçiminde de görünür (kullanıcı)
	for c in blind_view.get_children():
		c.queue_free()
	var title := _wavy_label("SIRADAKİ TURU SEÇ", 28, T.BRASS, T.OUTLINE, 7.0, 3.0)
	title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN  # sola hizalı (kolonlar solda)
	blind_view.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN  # SOLDAN başla (sol boş kalmasın — kullanıcı)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var cur: int = state["run"]["blindIndex"]
	for i in Blinds.BLINDS.size():
		row.add_child(_blind_column(Blinds.BLINDS[i], i, cur))
	blind_view.add_child(row)
	_animate_blind_columns(row)

# Sütunlar sırayla aşağıdan yaylanarak gelir (juice).
func _animate_blind_columns(row: Control) -> void:
	await get_tree().process_frame
	var i := 0
	for col in row.get_children():
		col.pivot_offset = col.size / 2.0  # scale merkezi (springy giriş)
		col.modulate.a = 0.0
		col.position.y += 52.0
		col.scale = Vector2(0.86, 0.86)
		var d := i * 0.09
		var tw := create_tween().set_parallel(true)
		tw.tween_property(col, "modulate:a", 1.0, 0.22).set_delay(d)
		# yaylanarak yüksel + büyü (squash/stretch + overshoot)
		tw.tween_property(col, "position:y", col.position.y - 52.0, 0.46).set_delay(d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(col, "scale", Vector2.ONE, 0.46).set_delay(d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# GEÇİLDİ damgası: gecikmeli "slap" (büyükten sert otur)
		if col.has_meta("stamp"):
			var st: Control = col.get_meta("stamp")
			if is_instance_valid(st):
				st.pivot_offset = st.size / 2.0
				st.scale = Vector2(2.2, 2.2)
				st.modulate.a = 0.0
				var stw := create_tween().set_parallel(true)
				stw.tween_property(st, "modulate:a", 1.0, 0.12).set_delay(d + 0.32)
				stw.tween_property(st, "scale", Vector2.ONE, 0.22).set_delay(d + 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		i += 1

# Tek blind KOLONU (uzun dikey panel): üstte SEÇ, isim sekmesi, ikon rozeti, hedef+ödül, "veya", altta ATLA.
func _blind_column(blind: Dictionary, i: int, cur: int) -> Control:
	var accent := Color(blind["color"])
	var active: bool = (i == cur)
	var done: bool = (i < cur)
	var col := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = T.FELT_800 if active else Color(T.FELT_800.r, T.FELT_800.g, T.FELT_800.b, 0.6)
	# ÜST köşe yuvarlak, ALT köşe KESKİN → dibe yapışık (kullanıcı: "alt tarafı olmasın")
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	sb.border_width_left = 4 if active else 2
	sb.border_width_right = 4 if active else 2
	sb.border_width_top = 4 if active else 2
	sb.border_width_bottom = 0  # alt kenar yok (yapışık)
	sb.border_color = accent if active else Color(accent.r, accent.g, accent.b, 0.35)
	# Aktif kolon vurgusu: kalın kenarlık + renk (glow YOK — kullanıcı glow istemiyor).
	# Boss aktifse kenarlık KIRMIZI (tehdit hissi, glow'suz).
	if active and blind["type"] == "boss":
		sb.set_border_width_all(5)
		sb.border_width_bottom = 0
		sb.border_color = T.MULT
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	col.add_theme_stylebox_override("panel", sb)
	col.custom_minimum_size = Vector2(300, 0)  # daha geniş (kullanıcı)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	# 1) ÜST: SEÇ butonu (aktif) / boş yer
	if active:
		var sel := _chunky_btn("SEÇ", T.BRASS, T.INK)
		sel.custom_minimum_size = Vector2(0, 50)
		sel.pressed.connect(_on_blind_select)
		v.add_child(sel)
	else:
		var ph := Control.new()
		ph.custom_minimum_size = Vector2(0, 50)
		v.add_child(ph)
	# 2) İSİM SEKMESİ (renkli yuvarlak tab)
	var tab := PanelContainer.new()
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = accent.darkened(0.15)
	tsb.set_corner_radius_all(8)
	tsb.content_margin_left = 10
	tsb.content_margin_right = 10
	tsb.content_margin_top = 4
	tsb.content_margin_bottom = 4
	tab.add_theme_stylebox_override("panel", tsb)
	var tname := String(blind["name"]).to_upper()
	if blind["type"] == "boss":
		tname = "PATRON"
		if active and state["round"].get("boss", null) != null:
			tname = String(state["round"]["boss"]["name"]).to_upper()
	tab.add_child(_center(_label(tname, 22, Color(1, 1, 1, 0.95), T.OUTLINE, 3)))
	v.add_child(tab)
	# 3) İKON ROZETİ (renkli daire + blind ikonu)
	var badge := Panel.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = accent.darkened(0.1)
	bsb.set_corner_radius_all(48)
	bsb.set_border_width_all(3)
	bsb.border_color = accent.lightened(0.25)
	badge.add_theme_stylebox_override("panel", bsb)
	badge.custom_minimum_size = Vector2(86, 86)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var bico: String = {"small": "✨", "big": "⭐", "boss": "💀"}.get(blind["type"], "✨")
	var bil := _label(bico, 40, Color(1, 1, 1, 0.95), T.OUTLINE, 4)
	bil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bil.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bil.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(bil)
	v.add_child(_center_h(badge))
	# 4) Patron kısıtlaması (aktif patron)
	if blind["type"] == "boss" and active and state["round"].get("boss", null) != null:
		var bd := _center(_label(String(state["round"]["boss"]["description"]), 13, T.MULT))
		bd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bd.custom_minimum_size = Vector2(196, 0)
		v.add_child(bd)
	# 5) SKOR/ÖDÜL koyu inset panel (referans: "Score at least" + çip ikonu + turuncu sayı + $$$)
	var info := PanelContainer.new()
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color(0.05, 0.10, 0.08, 0.85)
	isb.set_corner_radius_all(12)
	isb.content_margin_left = 12
	isb.content_margin_right = 12
	isb.content_margin_top = 10
	isb.content_margin_bottom = 10
	info.add_theme_stylebox_override("panel", isb)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 4)
	iv.alignment = BoxContainer.ALIGNMENT_CENTER
	iv.add_child(_center(_label("EN AZ", 14, Color(1, 1, 1, 0.85))))
	# çip ikonu (küçük beyaz daire) + hedef sayısı (turuncu, iri)
	var hr := HBoxContainer.new()
	hr.alignment = BoxContainer.ALIGNMENT_CENTER
	hr.add_theme_constant_override("separation", 8)
	var coin := Panel.new()
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.92, 0.95, 1.0)
	csb.set_corner_radius_all(16)
	coin.add_theme_stylebox_override("panel", csb)
	coin.custom_minimum_size = Vector2(24, 24)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hr.add_child(coin)
	hr.add_child(_label("%d" % Round.target_for_blind(state, blind), 36, T.ORANGE, T.OUTLINE, 5))
	iv.add_child(hr)
	var dollars := "$".repeat(clampi(int(blind["reward"]), 1, 6))
	iv.add_child(_center(_label("Ödül:  %s" % dollars, 17, T.BRASS)))
	info.add_child(iv)
	v.add_child(info)
	# 6) alt: durum / ATLA
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	if done:
		pass  # geçilmiş kolon → büyük "GEÇİLDİ" damgası (aşağıda overlay, animate'te slap)
	elif active and blind["type"] != "boss":
		v.add_child(_center(_label("— veya —", 14, T.TEXT_DIM)))
		var skip := _chunky_btn("🏷  ATLA", T.MULT, Color.WHITE)
		skip.add_theme_font_size_override("font_size", 22)
		skip.custom_minimum_size = Vector2(0, 44)
		skip.pressed.connect(_on_blind_skip)
		v.add_child(skip)
	elif not active:
		v.add_child(_center(_label("SIRADA", 15, T.TEXT_DIM)))
	col.add_child(v)
	# GEÇİLDİ damgası (overlay) — done kolonda büyük, döndürülmüş; _animate'te "slap" olur
	if done:
		var stamp := _label("GEÇİLDİ", 36, Color(1, 1, 1, 0.95), Color(0.10, 0.05, 0.05, 0.95), 6)
		stamp.add_theme_font_override("font", _tile_font)
		stamp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stamp.rotation = deg_to_rad(-12.0)
		stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(stamp)
		col.set_meta("stamp", stamp)
	if not active:
		col.modulate.a = 0.7  # geçili/sıradaki sönük
	return col

func _on_blind_select() -> void:
	blind_view.visible = false
	play_view.visible = true
	if deck_holder:
		deck_holder.visible = true
	_reset_flames()
	if _tut_active:
		_tut_event("blind_selected")
	# Yeni el dağıtılırken önceki turun çip×çarpanı (ör. 41×24) ANINDA 0/1 olmasın →
	# el gelirken seals PARALEL olarak geriye sayıp 0/1'e insin. _refresh'i elle sıralıyoruz
	# ki içindeki _update_word_display sayımı anında ezmesin (bayat board flaşı da olmaz).
	_refresh_hud()
	_rebuild_hand(true, true)        # el SEÇ'te dağıtılır (desteden gelir + shuffle)
	await _countdown_seals(0.34)     # seals geriye sayarak 0/1 (el dağıtımıyla aynı anda)
	_update_word_display()

func _on_blind_skip() -> void:
	var r := Round.skip_blind(state)
	if not r.get("ok", false):
		return
	_play_card_move()
	_refresh_hud()           # para/blind güncelle
	_open_blind_select()     # yeni blind için seçim ekranını tekrar göster

# ── DÜKKÂN (tahta-içi, Balatro tarzı: sol panel+joker rafı kalır, orta alan değişir) ──
func _open_shop() -> void:
	_shop_reward = Round.collect_blind_reward(state)  # ödülü topla (bir kez, idempotent)
	_shop_msg = ""
	Shop.generate_shop(state)
	_shop_mode = true
	hint_label.text = ""
	word_label.text = "—"
	play_view.visible = false
	blind_view.visible = false
	shop_view.visible = true
	if deck_holder:
		deck_holder.visible = false  # deste dükkânda gizli (oyun alanına ait)
	money_label.text = "$%d" % state["run"]["money"]
	_set_shop_sidebar(true)  # sol panel tepesi → SHOP marquee
	_rebuild_jokers()  # üst jokerler artık tıkla → SAT
	_build_shop_ui()
	if _tut_active and _tut_mode == "await_shop":
		_tut_shop_tour()  # öğretici: dükkân anlatımı (turu geçip dükkâna ilk girişte)

# Arcade marquee kutusu (Balatro "SHOP" — kırmızı dolgu, kalın koyu kenar).
func _marquee_box() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = T.MULT
	s.set_corner_radius_all(8)
	s.border_width_left = 4
	s.border_width_right = 4
	s.border_width_top = 4
	s.border_width_bottom = 6
	s.border_color = Color(0.09, 0.04, 0.03)
	s.content_margin_top = 22
	s.content_margin_bottom = 24
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.shadow_color = Color(0, 0, 0, 0.4)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 4)
	return s

# Dükkân kartı stylebox — basılı kart hissi (az yuvarlak, kalın kenar, gölge).
func _card_sb(accent: Color, hi: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = T.FELT_700 if hi else T.FELT_800
	s.set_corner_radius_all(8)
	s.set_border_width_all(3)
	s.border_color = accent
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 7
	s.shadow_offset = Vector2(0, 5)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s

func _build_shop_ui() -> void:
	for c in shop_view.get_children():
		c.queue_free()
	_shop_tags = []

	# (SHOP marquee artık SOL PANELDE — _set_shop_sidebar; merkezde tekrar etmez)
	if _shop_reward:
		var sub := "Tur geçildi!   +$%d   (taban %d · hak %d · faiz %d)" % [
			_shop_reward["total"], _shop_reward["base"], _shop_reward["leftover"], _shop_reward["interest"]]
		shop_view.add_child(_center(_label(sub, 15, T.TEXT_DIM)))
	if _shop_msg != "":
		shop_view.add_child(_center(_label(_shop_msg, 16, T.EMBER)))

	var shop = state["run"]["shop"]

	# ── TEZGAH (tray) — felt'ten biraz açık, kalın koyu kenar, yuvarlak ──
	var tray := PanelContainer.new()
	tray.add_theme_stylebox_override("panel", _shop_tray_sb())
	tray.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_view.add_child(tray)
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 16)
	tray.add_child(trow)

	# Sol kenar aksiyon butonları: SONRAKİ TUR (kırmızı) + YENİLE (yeşil)
	var acol := VBoxContainer.new()
	acol.add_theme_constant_override("separation", 12)
	acol.custom_minimum_size = Vector2(146, 0)
	var nb := _chunky_btn("SONRAKİ\nTUR  →", T.MULT, Color.WHITE)
	nb.custom_minimum_size = Vector2(0, 96)
	nb.pressed.connect(_on_next_blind)
	acol.add_child(nb)
	_shop_next_btn = nb  # öğretici turu için referans
	var can_rr: bool = state["run"]["money"] >= shop["rerollCost"]
	var rr := _chunky_btn("YENİLE\n$%d" % shop["rerollCost"], T.GOOD if can_rr else T.FELT_700, T.INK)
	rr.custom_minimum_size = Vector2(0, 74)
	rr.disabled = not can_rr
	rr.pressed.connect(_on_reroll)
	acol.add_child(rr)
	trow.add_child(acol)

	# Raflar
	var shelves := VBoxContainer.new()
	shelves.add_theme_constant_override("separation", 14)
	shelves.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shelves.size_flags_vertical = Control.SIZE_EXPAND_FILL
	trow.add_child(shelves)
	_shop_shelves = shelves  # öğretici turu için referans

	var bc = state["run"]["boosterChoices"]
	var ec = state["run"].get("enhancerChoices", null)
	var pending = state["run"].get("pendingEnhancement", null)
	if bc != null or ec != null or pending != null:
		shelves.add_child(_build_shop_selection(bc, ec, pending))
	else:
		shelves.add_child(_build_shelf(_shop_joker_slots(shop)))   # RAF 1: jokerler
		shelves.add_child(_build_shelf(_shop_pack_slots(shop)))    # RAF 2: kupon + paketler

	call_deferred("_position_shop_overlays")

# ── SHOP marquee: ampul sıralı, altın "SHOP" + el-yazısı alt başlık ──
func _build_marquee() -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _marquee_box())
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	v.add_child(_bulb_row(11))
	var s := _center(_label("SHOP", 46, Color(1.0, 0.82, 0.28), Color(0.30, 0.14, 0.03), 6))
	s.add_theme_font_override("font", _tile_font)
	v.add_child(s)
	v.add_child(_center(_label("Run'ını geliştir!", 17, Color(1.0, 0.93, 0.78))))
	v.add_child(_bulb_row(11))
	box.add_child(v)
	return box

# Ampul sırası — küçük parlak yuvarlak noktalar (marquee kenarı hissi).
func _bulb_row(n: int) -> Control:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 13)
	for i in n:
		var b := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1.0, 0.95, 0.78)
		sb.set_corner_radius_all(5)
		sb.shadow_color = Color(1.0, 0.85, 0.4, 0.6)  # yumuşak altın ışıma
		sb.shadow_size = 5
		b.add_theme_stylebox_override("panel", sb)
		b.custom_minimum_size = Vector2(8, 8)
		h.add_child(b)
	return h

func _shop_tray_sb() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.085, 0.16, 0.135)   # felt'ten biraz açık
	s.set_corner_radius_all(16)
	s.set_border_width_all(3)
	s.border_color = Color(0.02, 0.05, 0.04)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 8
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 16
	s.content_margin_bottom = 16
	return s

# Raf — içe gömük koyu şerit (item'lar burada oturur).
func _shelf_recess() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0.24)
	s.set_corner_radius_all(12)
	s.border_color = Color(1, 1, 1, 0.05)
	s.set_border_width_all(1)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 14
	s.content_margin_bottom = 12
	return s

func _build_shelf(items: Array) -> Control:
	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel", _shelf_recess())
	strip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for it in items:
		row.add_child(it)
	strip.add_child(row)
	return strip

func _shop_joker_slots(shop) -> Array:
	var out := []
	for j in shop["jokers"]:
		var can_buy: bool = state["run"]["money"] >= j["cost"] and state["run"]["jokers"].size() < MAX_JOKERS
		var tip := "%s\n[%s]" % [j["description"], j.get("rarity", "common")]
		out.append(_priced_slot(_joker_visual(j), 150, 184, "$%d" % j["cost"], can_buy, _on_buy_joker.bind(j["id"]), tip))
	if out.is_empty():
		out.append(_center_v(_label("(jokerler tükendi)", 16, T.TEXT_DIM)))
	return out

func _shop_pack_slots(shop) -> Array:
	var out := []
	var can_boost: bool = (not shop["booster"]["used"]) and state["run"]["money"] >= shop["booster"]["cost"]
	out.append(_priced_slot(_pack_visual("HARF\nPAKETİ", "desteye +1 harf", T.GOOD),
		150, 184, "$%d" % shop["booster"]["cost"], can_boost, _on_buy_booster, "3 harften 1'ini destene ekle"))
	# KUPON — harf paketinin YANINDA (kullanıcı); sürükle-bırak/tıkla satın alma korunur.
	if shop["voucher"] != null:
		out.append(_voucher_card(shop["voucher"]))
	var enh = shop.get("enhancer", null)
	if enh != null:
		var can_enh: bool = (not enh["used"]) and state["run"]["money"] >= enh["cost"]
		out.append(_priced_slot(_pack_visual("CİLA\nPAKETİ", "foil / holo / poly…", T.CHIP),
			150, 184, "$%d" % enh["cost"], can_enh, _on_buy_enhancer, "Bir harfine kalıcı geliştirme"))
	return out

# Item görseli + üstte poke-up altın FİYAT ETİKETİ + tıklama alanı. Balatro imzası.
func _priced_slot(card: Control, w: int, h: int, price: String, can_buy: bool, on_buy: Callable, tip: String) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(w, h + 16)
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.offset_top = 16
	if not can_buy:
		card.modulate = Color(1, 1, 1, 0.5)
	root.add_child(card)
	var hit := Button.new()
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit.offset_top = 16
	hit.disabled = not can_buy
	hit.tooltip_text = tip
	hit.pressed.connect(on_buy)
	root.add_child(hit)
	var tag := _price_tag(price, can_buy)
	root.add_child(tag)
	_shop_tags.append({"tag": tag, "slot": root})
	return root

# Fiyat etiketi — koyu yuvarlak "tab", altın $N (kıyafet fiyat etiketi gibi).
func _price_tag(price: String, can_buy: bool) -> Control:
	var tag := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.11, 0.08, 0.04)
	s.set_corner_radius_all(7)
	s.set_border_width_all(2)
	s.border_color = Color(0.04, 0.02, 0.01)
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 2)
	s.content_margin_left = 11
	s.content_margin_right = 11
	s.content_margin_top = 2
	s.content_margin_bottom = 3
	tag.add_theme_stylebox_override("panel", s)
	tag.z_index = 5
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _label(price, 22, T.BRASS if can_buy else T.TEXT_DIM, Color(0.05, 0.03, 0.0), 4)
	l.add_theme_font_override("font", _tile_font)
	tag.add_child(l)
	return tag

# Layout sonrası: fiyat etiketlerini slot tepesine ortala (poke-up).
func _position_shop_overlays() -> void:
	for e in _shop_tags:
		var tag = e["tag"]
		var slot = e["slot"]
		if not is_instance_valid(tag) or not is_instance_valid(slot):
			continue
		tag.position = Vector2((slot.size.x - tag.size.x) * 0.5, 16.0 - tag.size.y * 0.6)

# Joker kartı görseli (parşömen yüzey, nadirlik kenarı).
func _joker_visual(j: Dictionary) -> Control:
	var rarity: Color = T.RARITY.get(j.get("rarity", "common"), T.CARD_EDGE)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _item_sb(rarity, T.CARD_FACE))
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 6)
	vb.add_child(_center(_label(j.get("icon", "?"), 50, T.INK)))
	var nm := _center(_label(j["name"], 17, Color(0.20, 0.12, 0.04)))
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size = Vector2(132, 0)
	vb.add_child(nm)
	card.add_child(vb)
	return card

# Paket görseli (foil torba hissi — renkli, parlak, krem yazı).
func _pack_visual(title: String, sub: String, accent: Color) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _item_sb(accent.lightened(0.15), accent.darkened(0.12)))
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 8)
	var t := _center(_label(title, 22, Color(1, 0.97, 0.88), Color(0.06, 0.04, 0.02), 5))
	t.custom_minimum_size = Vector2(132, 0)
	vb.add_child(t)
	vb.add_child(_center(_label(sub, 13, Color(1, 0.97, 0.88, 0.8))))
	card.add_child(vb)
	return card

# Kupon yuvası — içe gömük mor kuyu + (yanal) etiket + bilet kartı + fiyat etiketi.
# KUPON kartı (Balatro üst "extra" satın alma spotu — mor bilet, SÜRÜKLE-BIRAK ile satın al).
# Tıkla = al; sürükleyip bırak = al. Sürükleme top_level ile imleci takip eder.
func _voucher_card(v: Dictionary) -> Control:
	var can_v: bool = state["run"]["money"] >= v["cost"]
	var root := Control.new()
	root.custom_minimum_size = Vector2(172, 188 + 16)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.tooltip_text = v["description"]

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _item_sb(T.LILAC.lightened(0.15), T.LILAC.darkened(0.42)))
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.offset_top = 16
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not can_v:
		card.modulate = Color(1, 1, 1, 0.5)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 5)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_center(_label("KUPON", 12, T.LILAC.lerp(Color.WHITE, 0.4))))
	vb.add_child(_center(_label("◈", 42, Color(1, 0.97, 0.88))))
	var nm := _center(_label(String(v["name"]).to_upper(), 15, Color(1, 0.97, 0.88), Color(0.06, 0.04, 0.02), 4))
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size = Vector2(132, 0)
	vb.add_child(nm)
	card.add_child(vb)
	root.add_child(card)

	var tag := _price_tag("$%d" % v["cost"], can_v)
	root.add_child(tag)
	_shop_tags.append({"tag": tag, "slot": root})

	if can_v:
		root.gui_input.connect(_voucher_input.bind(root))
	return root

var _vdrag := {}
func _voucher_input(event: InputEvent, root: Control) -> void:
	if not is_instance_valid(root):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_vdrag = {"down": true, "active": false, "m0": root.get_global_mouse_position(), "p0": root.global_position}
		else:
			var was_active: bool = _vdrag.get("active", false)
			var was_down: bool = _vdrag.get("down", false)
			_vdrag = {}
			if was_active or was_down:
				if was_active:
					root.top_level = false
				_play_card_move()
				_on_buy_voucher()  # tıkla VEYA sürükle-bırak → satın al (shop UI yeniden kurulur)
	elif event is InputEventMouseMotion and _vdrag.get("down", false):
		var d: Vector2 = root.get_global_mouse_position() - _vdrag["m0"]
		if not _vdrag.get("active", false) and d.length() > 8.0:
			_vdrag["active"] = true
			root.top_level = true
			root.z_index = 80
		if _vdrag.get("active", false):
			root.global_position = _vdrag["p0"] + d

# Item kart stylebox — parlak sticker hissi (kalın koyu kenar, alt gölge).
func _item_sb(border: Color, bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(10)
	s.set_border_width_all(3)
	s.border_color = border.darkened(0.25)
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 4)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s

# Seçim alt-akışları (harf paketi / cila paketi / cila→harf) — rafın içinde gösterilir.
func _build_shop_selection(bc, ec, pending) -> Control:
	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel", _shelf_recess())
	strip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 12)
	prow.alignment = BoxContainer.ALIGNMENT_CENTER
	if bc != null:
		prow.add_child(_center_v(_label("HARF\nSEÇ →", 20, T.GOOD)))
		for ch in bc:
			var lb := _chunky_btn(ch, T.CARD_FACE, T.INK)
			lb.custom_minimum_size = Vector2(86, 110)
			lb.add_theme_font_size_override("font_size", 44)
			lb.pressed.connect(_on_choose_letter.bind(ch))
			prow.add_child(lb)
	elif pending != null:
		var pe = Enhancements.by_id(pending)
		var pcol := Color(pe["color"])
		prow.add_child(_center_v(_label("%s\nNEREYE? →" % String(pe["name"]).to_upper(), 18, pcol)))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 7)
		flow.add_theme_constant_override("v_separation", 7)
		flow.custom_minimum_size = Vector2(540, 0)
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for entry in _deck_letter_counts():
			var ch: String = entry["char"]
			var lb := _chunky_btn(ch, T.CARD_FACE, T.INK)
			lb.custom_minimum_size = Vector2(60, 72)
			lb.add_theme_font_size_override("font_size", 34)
			lb.tooltip_text = "“%s” (deste: ×%d) — %s ekle" % [ch, entry["count"], pe["name"]]
			lb.pressed.connect(_on_apply_enh_to_letter.bind(ch))
			flow.add_child(lb)
		prow.add_child(flow)
	elif ec != null:
		prow.add_child(_center_v(_label("CİLA\nSEÇ →", 20, T.LILAC)))
		for eid in ec:
			prow.add_child(_enh_choice_card(eid))
	strip.add_child(prow)
	return strip

# Geliştirme seçim kartı (Cila Paketi açılınca): sembol + isim + açıklama, tıkla → uygula.
func _enh_choice_card(eid: String) -> Control:
	var e = Enhancements.by_id(eid)
	var accent := Color(e["color"])
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 6)
	vb.add_child(_center(_label(e["symbol"], 46, accent)))
	vb.add_child(_center(_label(String(e["name"]).to_upper(), 16, accent)))
	var d := _center(_label(e["desc"], 13, T.TEXT_DIM))
	d.custom_minimum_size = Vector2(150, 0)
	vb.add_child(d)
	return _shop_card(accent, vb, "SEÇ", true, _on_choose_enhancement.bind(eid), e["desc"])

# Tek satırı yatayda ortalar (marquee için).
func _center_h(node: Control) -> Control:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(node)
	return h

func _center_v(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

# Genel dükkân kartı: görünüm PanelContainer + üstte şeffaf tıklama butonu + altın fiyat etiketi.
func _shop_card(accent: Color, content: Control, price_text: String, can_buy: bool, on_buy: Callable, tip: String) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_sb(accent, false))
	card.custom_minimum_size = Vector2(162, 196)
	card.add_child(content)
	var hit := Button.new()
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.disabled = not can_buy
	hit.tooltip_text = tip
	hit.pressed.connect(on_buy)
	card.add_child(hit)  # içeriğin ÜSTÜNDE → tıklamayı yakalar
	if not can_buy:
		card.modulate = Color(1, 1, 1, 0.5)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	if price_text != "":
		col.add_child(_center(_label(price_text, 26, T.BRASS if can_buy else T.TEXT_DIM, T.OUTLINE, 5)))
	col.add_child(card)
	return col

func _shop_joker_card(joker: Dictionary) -> Control:
	var rarity: Color = T.RARITY.get(joker.get("rarity", "common"), T.CARD_EDGE)
	var can_buy: bool = state["run"]["money"] >= joker["cost"] and state["run"]["jokers"].size() < MAX_JOKERS
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 8)
	vb.add_child(_center(_label(joker.get("icon", "?"), 54, T.TEXT)))
	var nm := _center(_label(joker["name"], 18, T.BRASS))
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size = Vector2(146, 0)
	vb.add_child(nm)
	var tip := "%s\n[%s]" % [joker["description"], joker.get("rarity", "common")]
	return _shop_card(rarity, vb, "$%d" % joker["cost"], can_buy, _on_buy_joker.bind(joker["id"]), tip)

# Paket/kupon kartı içeriği (emoji yok — daha "basılı kart").
func _pack_content(title: String, sub: String, accent: Color) -> Control:
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 8)
	var t := _center(_label(title, 22, accent))
	t.custom_minimum_size = Vector2(146, 0)
	vb.add_child(t)
	vb.add_child(_center(_label(sub, 14, T.TEXT_DIM)))
	return vb

# Üst raftaki joker — dükkân modunda tıkla → SAT (Balatro: jokerler hep üstte, oradan satılır).
func _sellable_joker_card(joker: Dictionary) -> Control:
	var b := Button.new()
	var rarity = T.RARITY.get(joker.get("rarity", "common"), T.CARD_EDGE)
	b.add_theme_stylebox_override("normal", T.felt_panel(T.FELT_700, rarity, 16))
	b.add_theme_stylebox_override("hover", T.felt_panel(T.FELT_800, T.MULT, 16))
	b.add_theme_stylebox_override("pressed", T.felt_panel(T.FELT_800, T.MULT, 16))
	b.custom_minimum_size = Vector2(98, 120)
	b.add_theme_font_size_override("font_size", 38)
	b.text = joker.get("icon", "?")
	b.tooltip_text = "%s — tıkla SAT: $%d\n%s" % [joker["name"], max(1, int(joker["cost"] / 2)), joker["description"]]
	b.pressed.connect(_on_sell_joker.bind(joker["id"]))
	return b

func _after_shop_change() -> void:
	money_label.text = "$%d" % state["run"]["money"]
	joker_caption.text = "JOKERLER %d/%d — tıkla → SAT" % [state["run"]["jokers"].size(), MAX_JOKERS]
	_animate_jokers = true  # alınan/satılan sonrası jokerler zıplayarak yerleşsin
	_rebuild_jokers()
	_build_shop_ui()

func _on_buy_joker(id: String) -> void:
	if Shop.buy_joker(state, id).get("ok", false):
		_play_card_move()
		_after_shop_change()

func _on_sell_joker(id: String) -> void:
	if Shop.sell_joker(state, id).get("ok", false):
		_play_card_move()
		_after_shop_change()

func _on_reroll() -> void:
	if Shop.reroll(state).get("ok", false):
		_play_shuffle()
		_after_shop_change()

# ══ BOOSTER PAKET AÇMA SEKANSI (Balatro tarzı: giriş→yırtılma→yelpaze→seçim→yanma) ══
# kind: "letter" (choices = harf string'leri) | "enh" (choices = enhancement id'leri).
# Tam ekran overlay; seçim yapılınca chosen uçar, kalanlar YANAR, sonra ilgili handler çağrılır.
func _open_pack_sequence(choices, kind: String) -> void:
	if choices == null or (choices is Array and choices.is_empty()):
		_after_shop_change()
		return
	_ensure_pack_assets()
	var center := size * 0.5
	# Overlay katmanları: dim (alt) → atmo (CRT/vinyet/rim) → hold (kartlar) → seqfx (partikül, üst)
	var ov := Control.new()
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(ov)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	ov.add_child(dim)
	# Atmosfer: zarif koyu vinyet + ince CRT tarama çizgileri (renkli parıltı yok)
	if Settings.particles_on:
		var atmo := ColorRect.new()
		atmo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		atmo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var amat := ShaderMaterial.new()
		amat.shader = _atmo_shader
		amat.set_shader_parameter("intensity", 0.0)
		atmo.material = amat
		ov.add_child(atmo)
		create_tween().tween_method(
			func(v): amat.set_shader_parameter("intensity", v), 0.0, 1.0, 0.35)
	var hold := Control.new()
	hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(hold)
	var seqfx := Node2D.new()
	ov.add_child(seqfx)  # en üstte → partiküller kartların önünde
	create_tween().tween_property(dim, "color", Color(0, 0, 0, 0.8), 0.25)

	# 1) GİRİŞ — kapalı paket aşağıdan uçar, overshoot, oturur (squash/stretch)
	var pack := _pack_sealed_card(kind)
	hold.add_child(pack)
	pack.pivot_offset = pack.size * 0.5
	var pack_home := center - pack.size * 0.5
	pack.position = pack_home + Vector2(0, 540)
	pack.scale = Vector2(0.7, 0.7)
	_play_card_move()  # whoosh
	var e1 := create_tween().set_parallel(true)
	e1.tween_property(pack, "position", pack_home, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	e1.tween_property(pack, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await e1.finished
	_add_trauma(0.18)
	var sq := create_tween()
	sq.tween_property(pack, "scale", Vector2(1.12, 0.9), 0.07)
	sq.tween_property(pack, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK)
	await sq.finished
	# 2) BEKLEME — kısa bob
	var bob := create_tween()
	bob.tween_property(pack, "position:y", pack_home.y - 10.0, 0.22).set_trans(Tween.TRANS_SINE)
	bob.tween_property(pack, "position:y", pack_home.y, 0.22).set_trans(Tween.TRANS_SINE)
	await bob.finished
	# 3) YIRTILMA — flash + konfeti/ember + paket büyüyüp kaybolur
	_ember_burst(center, 46, 4.0, seqfx)
	_add_trauma(0.4)
	_play_collect(_collect, 1.0)
	var flash := ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 1, 1, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(flash)
	var ft := create_tween()
	ft.tween_property(flash, "color:a", 0.45, 0.06)
	ft.tween_property(flash, "color:a", 0.0, 0.22)
	ft.tween_callback(flash.queue_free)
	var tr := create_tween().set_parallel(true)
	tr.tween_property(pack, "scale", Vector2(1.5, 1.5), 0.16)
	tr.tween_property(pack, "modulate:a", 0.0, 0.16)
	await tr.finished
	if is_instance_valid(pack):
		pack.queue_free()
	# 4) YELPAZE — kartlar paket merkezinden yaylanarak yaya açılır (stagger).
	#    Her kart = stillenmiş panel'in snapshot'ı → fake-3D eğim materyalli TextureRect
	#    (Balatro tarzı: imlece doğru 3B eğilir).
	var n: int = choices.size()
	var spacing := 174.0
	var cards: Array = []
	for i in n:
		var src := _pack_overlay_card(kind, choices[i])  # stillenmiş panel (ağaca eklenmez)
		var csize: Vector2 = src.size
		var tex := await _render_to_texture(src, csize)
		var card := TextureRect.new()
		card.texture = tex
		card.size = csize
		card.stretch_mode = TextureRect.STRETCH_SCALE
		card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _tilt_shader != null and tex != null:
			var tmat := ShaderMaterial.new()
			tmat.shader = _tilt_shader
			tmat.set_shader_parameter("rect_size", csize)
			tmat.set_shader_parameter("x_rot", 0.0)
			tmat.set_shader_parameter("y_rot", 0.0)
			card.material = tmat
		hold.add_child(card)
		card.pivot_offset = csize * 0.5
		var off := i - (n - 1) / 2.0
		var tpos := Vector2(center.x + off * spacing, center.y + off * off * 10.0) - csize * 0.5
		var trot := off * 0.12
		card.position = center - csize * 0.5
		card.scale = Vector2(0.3, 0.3)
		var d := i * 0.06
		var ct := create_tween().set_parallel(true)
		ct.tween_property(card, "position", tpos, 0.42).set_delay(d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ct.tween_property(card, "scale", Vector2.ONE, 0.42).set_delay(d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ct.tween_property(card, "rotation", trot, 0.42).set_delay(d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		cards.append(card)
		var hit := Button.new()
		hit.flat = true
		hit.focus_mode = Control.FOCUS_NONE
		hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card.add_child(hit)
		hit.mouse_entered.connect(_pack_card_hover.bind(card, trot, true))
		hit.mouse_exited.connect(_pack_card_hover.bind(card, trot, false))
		hit.gui_input.connect(_pack_card_tilt.bind(card))
		hit.pressed.connect(_resolve_pack_pick.bind(ov, seqfx, cards, card, choices[i], kind))
	# "X'TEN 1 SEÇ" başlığı yukarıda belirir
	var sel := _label("%d'TEN 1 SEÇ" % n, 32, T.BRASS, T.OUTLINE, 6)
	sel.add_theme_font_override("font", _tile_font)
	sel.size = Vector2(420, 50)
	sel.position = Vector2(center.x - 210.0, center.y - 230.0)
	sel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sel.modulate.a = 0.0
	hold.add_child(sel)
	create_tween().tween_property(sel, "modulate:a", 1.0, 0.3).set_delay(0.2)

# Kapalı paket görseli (giriş için).
func _pack_sealed_card(kind: String) -> Control:
	var card := Panel.new()
	card.size = Vector2(154, 200)
	var accent := T.GOOD if kind == "letter" else T.CHIP
	var sb := StyleBoxFlat.new()
	sb.bg_color = accent.darkened(0.12)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(4)
	sb.border_color = accent.lightened(0.2)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 6)
	card.add_theme_stylebox_override("panel", sb)
	var l := _label("HARF\nPAKETİ" if kind == "letter" else "CİLA\nPAKETİ", 26, Color.WHITE, T.OUTLINE, 5)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(l)
	return card

# Yelpaze kartı (seçenek): harf büyük / enhancement sembol+isim+açıklama.
func _pack_overlay_card(kind: String, choice) -> Control:
	var card := Panel.new()
	card.size = Vector2(128, 172)
	var sb := StyleBoxFlat.new()
	var accent: Color
	if kind == "letter":
		sb.bg_color = T.CARD_FACE
		accent = T.BRASS
	else:
		var e = Enhancements.by_id(choice)
		accent = Color(e["color"])
		sb.bg_color = T.FELT_700
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(3)
	sb.border_color = accent
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 4)
	card.add_theme_stylebox_override("panel", sb)
	if kind == "letter":
		var l := _label(String(choice), 66, T.INK)
		l.add_theme_font_override("font", _tile_font)
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(l)
	else:
		var e = Enhancements.by_id(choice)
		var vb := VBoxContainer.new()
		vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 6)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(_center(_label(String(e["symbol"]), 44, accent)))
		vb.add_child(_center(_label(String(e["name"]).to_upper(), 15, accent)))
		var d := _center(_label(String(e["desc"]), 12, T.TEXT_DIM))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(118, 0)
		vb.add_child(d)
		card.add_child(vb)
	return card

# Yelpaze kartı hover: büyü + 2B yelpaze açısını düzleş (glow YOK).
# Çıkışta 3B eğim de yaylanarak sıfıra döner (Balatro hissi).
func _pack_card_hover(card: Control, base_rot: float, on: bool) -> void:
	if not is_instance_valid(card):
		return
	var t := create_tween().set_parallel(true)
	t.tween_property(card, "scale", Vector2(1.12, 1.12) if on else Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK)
	t.tween_property(card, "rotation", 0.0 if on else base_rot, 0.12)
	if not on:
		var mat := card.material as ShaderMaterial
		if mat != null:
			var cx: float = mat.get_shader_parameter("x_rot")
			var cy: float = mat.get_shader_parameter("y_rot")
			t.tween_method(func(v): mat.set_shader_parameter("x_rot", v), cx, 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_method(func(v): mat.set_shader_parameter("y_rot", v), cy, 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Yelpaze kartı: imleç konumuna göre fake-3D eğim (Balatro kartı gibi imlece eğilir).
func _pack_card_tilt(event: InputEvent, card: Control) -> void:
	if not is_instance_valid(card) or not (event is InputEventMouseMotion):
		return
	var mat := card.material as ShaderMaterial
	if mat == null:
		return
	var sz: Vector2 = card.size
	var lx := clampf(event.position.x / maxf(sz.x, 1.0), 0.0, 1.0)
	var ly := clampf(event.position.y / maxf(sz.y, 1.0), 0.0, 1.0)
	var max_deg := 16.0
	mat.set_shader_parameter("y_rot", (lx * 2.0 - 1.0) * max_deg)   # yatay → y ekseni
	mat.set_shader_parameter("x_rot", -(ly * 2.0 - 1.0) * max_deg)  # dikey → x ekseni

# Seçim: chosen pop+uç, kalanlar YAN, overlay kapanır, sonra ilgili handler.
func _resolve_pack_pick(ov: Control, seqfx: Node2D, cards: Array, chosen: Control, choice, kind: String) -> void:
	if not is_instance_valid(ov) or ov.get_meta("done", false):
		return
	ov.set_meta("done", true)
	_add_trauma(0.3)
	for c in cards:
		if not is_instance_valid(c):
			continue
		if c == chosen:
			_ember_burst(_node_center(c), 24, 3.0, seqfx)
			var pt := create_tween().set_parallel(true)
			pt.tween_property(c, "scale", Vector2(1.25, 1.25), 0.1).set_trans(Tween.TRANS_BACK)
			pt.tween_property(c, "rotation", 0.0, 0.1)
			pt.chain().tween_property(c, "position:y", c.position.y - 90.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			pt.parallel().tween_property(c, "modulate:a", 0.0, 0.3).set_delay(0.12)
		else:
			_burn_card(c, seqfx)
	await get_tree().create_timer(0.85).timeout
	if is_instance_valid(ov):
		var ot := create_tween()
		ot.tween_property(ov, "modulate:a", 0.0, 0.25)
		await ot.finished
		if is_instance_valid(ov):
			ov.queue_free()
	# Seçimi uygula (state + shop yeniden kurulur)
	if kind == "letter":
		_on_choose_letter(String(choice))
	else:
		_on_choose_enhancement(String(choice))

# Kartı YAK: yükselen ateş közleri + savrulan kül + GERÇEK edge-dissolve (kenardan kül olma).
func _burn_card(card: Control, seqfx: Node2D) -> void:
	if not is_instance_valid(card):
		return
	var c := _node_center(card)
	var ext := card.size * 0.45
	if Settings.particles_on:
		# 1) ATEŞ közleri — karttan yukarı yükselir, sıcak beyaz→turuncu→koyu
		var fire := CPUParticles2D.new()
		seqfx.add_child(fire)
		fire.global_position = c
		fire.texture = _spark_tex
		fire.material = _add_mat  # additive ateş (glow halo değil — kor partikülü)
		fire.one_shot = true
		fire.emitting = true
		fire.explosiveness = 0.55
		fire.amount = 34
		fire.lifetime = 0.6
		fire.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		fire.emission_rect_extents = Vector2(ext.x, ext.y)
		fire.direction = Vector2(0, -1)
		fire.spread = 24.0
		fire.gravity = Vector2(0, -150.0)  # yüksel
		fire.initial_velocity_min = 60.0
		fire.initial_velocity_max = 170.0
		fire.scale_amount_min = 0.25
		fire.scale_amount_max = 0.6
		var fr := Gradient.new()
		fr.set_color(0, Color(1.0, 0.95, 0.7))
		fr.add_point(0.4, T.EMBER)
		fr.add_point(0.8, T.MULT)
		fr.set_color(1, Color(0.15, 0.05, 0.02, 0.0))
		fire.color_ramp = fr
		fire.finished.connect(fire.queue_free)
		# 2) KÜL pulları — koyu, savrulup yavaşça yükselip kaybolur
		var ash := CPUParticles2D.new()
		seqfx.add_child(ash)
		ash.global_position = c
		ash.texture = _spark_tex
		ash.one_shot = true
		ash.emitting = true
		ash.explosiveness = 0.7
		ash.amount = 16
		ash.lifetime = 0.95
		ash.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		ash.emission_rect_extents = Vector2(ext.x, ext.y)
		ash.direction = Vector2(0, -1)
		ash.spread = 55.0
		ash.gravity = Vector2(0, -34.0)
		ash.initial_velocity_min = 26.0
		ash.initial_velocity_max = 90.0
		ash.damping_min = 20.0
		ash.damping_max = 60.0
		ash.scale_amount_min = 0.14
		ash.scale_amount_max = 0.3
		var ar := Gradient.new()
		ar.set_color(0, Color(0.16, 0.13, 0.12, 0.9))
		ar.set_color(1, Color(0.10, 0.08, 0.08, 0.0))
		ash.color_ramp = ar
		ash.finished.connect(ash.queue_free)
	# 3) KART: burn-edge dissolve. Kart zaten dokulu TextureRect → eğim materyalini
	#    dissolve shader'ıyla değiştir, dissolve_value 1→0 ile kenardan içe doğru kül et.
	var tcard := card as TextureRect
	if _dissolve_shader == null or tcard == null or tcard.texture == null:
		# Fallback: kararıp büzülerek sön
		var tf := create_tween()
		tf.tween_property(card, "modulate", Color(0.18, 0.10, 0.06, 1.0), 0.16)
		tf.tween_property(card, "modulate:a", 0.0, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tf.parallel().tween_property(card, "scale", Vector2(0.55, 0.18), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tf.chain().tween_callback(card.queue_free)
		return
	for ch in tcard.get_children():
		if ch is Button:  # tıklama alanını kapat
			ch.queue_free()
	var mat := ShaderMaterial.new()
	mat.shader = _dissolve_shader
	mat.set_shader_parameter("dissolve_texture", _dissolve_noise)
	mat.set_shader_parameter("dissolve_value", 1.0)
	tcard.material = mat
	var dt := create_tween()
	dt.tween_method(func(v): mat.set_shader_parameter("dissolve_value", v), 1.0, 0.0, 0.7).set_ease(Tween.EASE_IN)
	dt.tween_callback(tcard.queue_free)

# Paket sekansı varlıklarını (shader + gürültü) ilk açılışta kur.
func _ensure_pack_assets() -> void:
	if _atmo_shader == null:
		_atmo_shader = load("res://shaders/pack_atmosphere.gdshader")
	if _dissolve_shader == null:
		_dissolve_shader = load("res://shaders/card_dissolve.gdshader")
	if _tilt_shader == null:
		_tilt_shader = load("res://shaders/card_tilt_3d.gdshader")
	if _dissolve_noise == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.06  # daha ince kül (iri blob değil)
		var nt := NoiseTexture2D.new()
		nt.width = 256
		nt.height = 256
		nt.seamless = true
		nt.noise = n
		_dissolve_noise = nt

# Bir Control'ü offscreen SubViewport'ta tek kare render edip ImageTexture döndür.
# (Stretch modundan bağımsız; UV 0..1 temiz olsun diye dissolve buradan beslenir.)
func _render_to_texture(node: Control, sizepx: Vector2) -> ImageTexture:
	var w := int(ceil(maxf(sizepx.x, 1.0)))
	var h := int(ceil(maxf(sizepx.y, 1.0)))
	var vp := SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	vp.add_child(node)
	await RenderingServer.frame_post_draw
	var tex: ImageTexture = null
	var img := vp.get_texture().get_image()
	if img != null:
		tex = ImageTexture.create_from_image(img)
	vp.queue_free()
	return tex

func _on_buy_booster() -> void:
	if Shop.buy_booster(state).get("ok", false):
		money_label.text = "$%d" % state["run"]["money"]
		_open_pack_sequence(state["run"]["boosterChoices"], "letter")

func _on_choose_letter(ch: String) -> void:
	if Shop.choose_booster_letter(state, ch).get("ok", false):
		_play_card_move()
		_shop_msg = "%s harfi destene katıldı." % ch
		_after_shop_change()

func _on_buy_enhancer() -> void:
	if Shop.buy_enhancer(state).get("ok", false):
		money_label.text = "$%d" % state["run"]["money"]
		_open_pack_sequence(state["run"].get("enhancerChoices", null), "enh")

func _on_choose_enhancement(eid: String) -> void:
	# Geliştirmeyi seç → beklemeye al; sonra oyuncu hangi harfe uygulanacağını seçer (agency v2).
	var r := Shop.choose_enhancement(state, eid)
	if r.get("ok", false):
		_play_card_move()
		var e = Enhancements.by_id(eid)
		_shop_msg = "%s nereye? Bir harf seç." % String(e["name"]).to_upper()
		_after_shop_change()

func _on_apply_enh_to_letter(ch: String) -> void:
	var eid = state["run"].get("pendingEnhancement", null)
	var r := Shop.apply_enhancement_to_letter(state, ch)
	if r.get("ok", false):
		_play_card_move()
		var e = Enhancements.by_id(eid)
		_shop_msg = "“%s” harfin %s oldu! (%s)" % [r["char"], String(e["name"]).to_upper(), e["desc"]]
		_after_shop_change()

# Destedeki benzersiz harfler + adetleri (cila hedef seçici için). Harf sırasına göre.
func _deck_letter_counts() -> Array:
	var counts := {}
	for c in state["run"]["deck"]:
		var ch: String = c["char"]
		counts[ch] = int(counts.get(ch, 0)) + 1
	var keys: Array = counts.keys()
	keys.sort()
	var out := []
	for k in keys:
		out.append({"char": k, "count": counts[k]})
	return out

func _on_buy_voucher() -> void:
	if Shop.buy_voucher(state).get("ok", false):
		_after_shop_change()

func _on_next_blind() -> void:
	_shop_mode = false
	var res := Round.proceed_to_next_blind(state)
	if res.get("runWon", false):
		_open_win()
		return
	# Dükkân görünümünden OYUN görünümüne dön (sol panel + joker rafı kalır)
	shop_view.visible = false
	play_view.visible = true
	if deck_holder:
		deck_holder.visible = true  # yeni turda deste yine görünür
	word_label.add_theme_color_override("font_color", T.TEXT)
	_reset_flames()  # yeni tur → alev sıfırla (skorla tekrar yanar)
	_refresh_hud()              # sol panel/joker güncelle
	_open_blind_select()        # blind seçim ekranı (el SEÇ'te dağıtılır)

# ── KAZAN / KAYBET ──
func _open_win() -> void:
	_clear_overlay()
	_theme_overlay(Color(0.10, 0.07, 0.0, 0.78), T.BRASS)
	overlay_card.add_child(_wavy_label("KAZANDIN! 🏆", 52, T.BRASS, T.OUTLINE, 10.0, 2.6, 6))
	overlay_card.add_child(_center(_label("Tüm bölümleri geçtin.", 22, T.EMBER)))
	_add_run_stats()
	_add_end_buttons(true)
	_present_overlay()

func _open_lose() -> void:
	if _tut_active:
		_tut_finish()  # öğretici sırasında kaybedildi → asılı kalmasın
	_clear_overlay()
	_theme_overlay(Color(0.22, 0.02, 0.02, 0.82), T.MULT)  # KIRMIZI game-over teması
	overlay_card.add_child(_wavy_label("OYUN BİTTİ", 56, T.MULT, T.OUTLINE, 11.0, 2.6, 6))
	_add_run_stats()
	_add_end_buttons(false)
	_present_overlay()

# Balatro tarzı istatistik ızgarası — etiketli kutular (2 sütun) + "yenilen" bilgisi.
func _add_run_stats() -> void:
	var run: Dictionary = state["run"]
	var stats: Dictionary = run.get("stats", {})
	var defeated := String(state["round"]["blind"]["name"]) if run["status"] == "lost" else "—"
	var best := "%s · %d" % [stats.get("bestWord", "—"), stats.get("bestScore", 0)]
	if String(stats.get("bestWord", "")) == "":
		best = "—"
	# {etiket, değer, renk}
	var cells := [
		["En İyi El", best, T.BRASS],
		["Yenilen", defeated.to_upper(), T.MULT],
		["Oynanan Kelime", str(stats.get("words", 0)), T.CHIP_BADGE],
		["Atılan Harf", str(stats.get("discards", 0)), T.CHIP_BADGE],
		["Satın Alınan", str(stats.get("bought", 0)), T.GOOD],
		["Reroll", str(stats.get("rerolls", 0)), T.GOOD],
		["Bölüm", "%d / %d" % [run["ante"], state["config"]["maxAnte"]], T.ORANGE],
		["Tur", str(run["blindIndex"] + 1), T.ORANGE],
		["Kalan Para", "$%d" % run["money"], T.BRASS],
		["Toplam Joker", str(run["jokers"].size()), T.LILAC],
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	for cell in cells:
		grid.add_child(_stat_cell(cell[0], cell[1], cell[2]))
	overlay_card.add_child(grid)
	# Seed (uzun olabilir) — ızgaranın altında tam genişlik, küçük, sığar.
	var seed_lbl := _center(_label("Seed: %s" % String(run["seed"]), 13, T.TEXT_DIM))
	seed_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	seed_lbl.custom_minimum_size = Vector2(468, 0)
	overlay_card.add_child(seed_lbl)

# Tek istatistik kutusu: koyu inset + üstte etiket + altta renkli değer.
func _stat_cell(caption: String, value: String, color: Color) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", T.stat_inset())
	p.custom_minimum_size = Vector2(228, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	var cap := _label(caption.to_upper(), 14, T.TEXT_DIM)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var val := _label(value, 26, color, T.OUTLINE, 3)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(cap)
	v.add_child(val)
	p.add_child(v)
	return p

func _add_end_buttons(won: bool) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	overlay_card.add_child(gap)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var retry := _chunky_btn("TEKRAR DENE", T.GOOD, T.INK)
	retry.custom_minimum_size = Vector2(0, 60)
	retry.pressed.connect(_on_restart)
	var menu := _chunky_btn("ANA MENÜ", T.ORANGE, T.INK)
	menu.custom_minimum_size = Vector2(0, 60)
	menu.pressed.connect(_on_back_to_menu)
	row.add_child(retry)
	row.add_child(menu)
	overlay_card.add_child(row)

func _on_restart() -> void:
	_reset_to_play_view()
	_init_run()
	_refresh(true, true)

func _on_back_to_menu() -> void:
	_close_overlay()
	request_menu.emit()

const INFO_TEXT := "Harf taşlarından geçerli TÜRKÇE kelime kur → OYNA.\nSkor = ÇİP × ÇARPAN. Uzun kelime + jokerler skoru patlatır.\nHer turun HEDEF puanı var. Kelime HAKKIN + DEĞİŞİM hakkın sınırlı (değişim hak harcamaz).\nKullanılmayan harfler elde kalır. Patron turlarında özel kısıtlama olur."

# BİLGİ butonu: kurallar + aktif patron kısıtlaması
func _on_info_btn() -> void:
	if _busy:
		return
	_clear_overlay()
	overlay_card.add_child(_center(_label("BİLGİ", 40, T.EMBER, T.OUTLINE, 5)))
	var round_d: Dictionary = state["round"]
	var boss = round_d.get("boss", null)
	if round_d["blind"].get("type", "") == "boss" and boss != null:
		var bp := PanelContainer.new()
		bp.add_theme_stylebox_override("panel", T.felt_panel(Color(0.30, 0.06, 0.05, 0.9), T.MULT, 12))
		var bl := _label("⚠ PATRON — %s\n%s" % [String(boss["name"]).to_upper(), boss["description"]], 19, T.TEXT)
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bl.custom_minimum_size = Vector2(560, 0)
		bp.add_child(bl)
		overlay_card.add_child(bp)
	var body := _label(INFO_TEXT, 19, T.TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(580, 0)
	overlay_card.add_child(body)
	var close := _chunky_btn("KAPAT", T.BRASS, T.INK)
	close.custom_minimum_size = Vector2(0, 56)
	close.pressed.connect(_close_overlay)
	overlay_card.add_child(close)
	_present_overlay()

# MENÜ butonu: duraklat (devam / ana menü)
func _on_menu_btn() -> void:
	if _busy:
		return
	_clear_overlay()
	overlay_card.add_child(_center(_label("DURAKLATILDI", 40, T.BRASS, T.OUTLINE, 5)))
	overlay_card.add_child(_center(_label("Run devam ediyor.", 18, T.TEXT_DIM)))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	overlay_card.add_child(gap)
	var resume := _chunky_btn("DEVAM ET", T.GOOD, T.INK)
	resume.custom_minimum_size = Vector2(320, 58)
	resume.pressed.connect(_close_overlay)
	overlay_card.add_child(resume)
	var to_menu := _chunky_btn("ANA MENÜ (run'ı bırak)", T.ORANGE, T.INK)
	to_menu.custom_minimum_size = Vector2(320, 58)
	to_menu.pressed.connect(_on_back_to_menu)
	overlay_card.add_child(to_menu)
	_present_overlay()

# ── Test/yakalama kancaları (main.gd --shop / --lose) ──
func demo_open_shop() -> void:
	state["round"]["score"] = state["round"]["target"]
	state["round"]["status"] = "won"
	_open_shop()

func demo_blind_select() -> void:
	_open_blind_select()

# Debug: dükkânı CİLA HARF SEÇİCİ açık göster (agency v2 görsel doğrulama).
func demo_enh_picker() -> void:
	state["round"]["score"] = state["round"]["target"]
	state["round"]["status"] = "won"
	_open_shop()
	state["run"]["money"] = 99
	var r := Shop.buy_enhancer(state)
	var first: String = r["choices"][0]  # rastgele seçeneklerden ilki (foil havuzda olmayabilir)
	Shop.choose_enhancement(state, first)
	_after_shop_change()

func demo_open_lose() -> void:
	state["run"]["status"] = "lost"
	_open_lose()

func demo_cash_out() -> void:
	state["round"]["score"] = state["round"]["target"]
	state["round"]["status"] = "won"
	state["round"]["playsLeft"] = 2
	_open_cash_out()

func demo_enhance() -> void:
	var hand: Array = state["round"]["hand"]
	var kinds := ["foil", "holo", "poly", "golden", "glass"]
	for i in mini(hand.size(), kinds.size()):
		hand[i]["enhancements"] = [kinds[i]]
	_rebuild_hand(false, false)

func demo_boss() -> void:
	state["round"]["blind"] = {"type": "boss", "name": "Patron", "mult": 2.0}  # const'a yazma
	state["round"]["boss"] = Bosses.by_id("uzun-yol")
	_update_boss_banner()

# Debug: rafa 4 joker ekle (sürükle-bırak yeniden sıralamayı görsel doğrulamak için).
func demo_jokers() -> void:
	for jid in ["katip", "unlu-uyumu", "z-faktoru", "cevher", "banker"]:
		JokerActions.add_joker_by_id(state, jid)
	_animate_jokers = true
	_refresh(false, false)


# ════════════════ ÖĞRETİCİ (ilk giriş, etkileşimli; ikon YOK) ════════════════
# YAPTIRARAK öğretir: tur seç → kelime kur → OYNA → (skor) açıklama balonları.
# Balon o adımın İLGİLENDİRDİĞİ öğenin yanına konumlanır (bağlamsal) ve o öğeyi spotlight eder.
# Sadece ilk açılışta; ATLA her an kapatır. Skor sonrası balonlar won→dükkan akışından ÖNCE
# _on_play'i bekletir (await _tut_postplay) → "TUR GEÇİLDİ" ile sıra karışmaz.
# Konumlamada ÖNEMLİ: yeni el ASENKRON dağıtıldığından hedef rect'i bekleyip TAZE alırız.

func _tut_start() -> void:
	if _tut_active:
		return
	_tut_active = true
	_tut_build_layer()
	_tut_layer.modulate.a = 0.0
	create_tween().tween_property(_tut_layer, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tut_goto_blind()

func _tut_build_layer() -> void:
	_tut_layer = Control.new()
	_tut_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tut_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tut_layer.z_index = 70
	add_child(_tut_layer)
	_tut_frames = []
	for i in 4:
		var fr := ColorRect.new()
		fr.color = Color(0.02, 0.01, 0.0, 1.0)
		fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tut_layer.add_child(fr)
		_tut_frames.append(fr)
	# Konuşma balonu (bağlamsal konumlanır)
	_tut_panel = PanelContainer.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color("f4ead2")
	bsb.set_corner_radius_all(14)
	bsb.set_border_width_all(4)
	bsb.border_color = Color("2a1c0e")
	bsb.shadow_color = Color(0, 0, 0, 0.5)
	bsb.shadow_size = 10
	bsb.shadow_offset = Vector2(0, 6)
	bsb.content_margin_left = 20
	bsb.content_margin_right = 20
	bsb.content_margin_top = 16
	bsb.content_margin_bottom = 16
	_tut_panel.add_theme_stylebox_override("panel", bsb)
	_tut_panel.visible = false
	_tut_layer.add_child(_tut_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	_tut_panel.add_child(vb)
	_tut_bubble_label = _label("", 23, Color("2a1c0e"), Color("f4ead2"), 0)
	_tut_bubble_label.add_theme_font_override("font", T.load_font())
	_tut_bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tut_bubble_label.custom_minimum_size = Vector2(360, 0)
	vb.add_child(_tut_bubble_label)
	_tut_next_btn = _chunky_btn("İLERİ →", T.GOOD, T.INK)
	_tut_next_btn.custom_minimum_size = Vector2(0, 52)
	_tut_next_btn.pressed.connect(func(): emit_signal("_tut_continue"))
	vb.add_child(_tut_next_btn)
	var skip := _chunky_btn("Öğreticiyi atla", T.FELT_700, T.TEXT)
	skip.add_theme_font_size_override("font_size", 17)
	skip.custom_minimum_size = Vector2(0, 36)
	skip.pressed.connect(_tut_finish)
	vb.add_child(skip)

# ── Faz 1: gated adımlar (olay bekler, buton yok) ──
func _tut_goto_blind() -> void:
	_tut_mode = "blind"
	# blind ekranı serbest tıklanmalı → dim YOK, blok YOK; balon kolonların üstünde
	await _tut_present("Hoş geldin! 👋\nBaşlamak için bir TUR seç.",
		func(): return _tut_node_rect(blind_view), "above", 0.0, false, false)

func _tut_goto_word() -> void:
	_tut_mode = "word"
	await _tut_present("Harflere dokunarak bir KELİME kur.\nGeçerli olunca OYNA yeşil yanar.",
		func(): return _tut_node_rect(hand_area), "above", 0.6, true, false)

func _tut_goto_play() -> void:
	_tut_mode = "play"
	await _tut_present("Hazır! Şimdi OYNA'ya bas 👇",
		func(): return _tut_node_rect(hand_area).merge(_tut_node_rect(play_btn)), "above", 0.6, true, false)

func _tut_event(name: String) -> void:
	if not _tut_active:
		return
	if _tut_mode == "blind" and name == "blind_selected":
		_tut_goto_word()
	elif _tut_mode == "word" and name == "selection_changed" and _is_current_valid():
		_tut_goto_play()

# OYNA'ya basıldı → skor animasyonu engelsiz görünsün (öğretici geçici gizlenir).
func _tut_hide_for_action() -> void:
	if _tut_layer != null:
		_tut_layer.visible = false

# ── Faz 2: skor sonrası açıklama balonları (won/dükkan akışından ÖNCE; awaitable) ──
func _tut_postplay() -> void:
	if not _tut_active or _tut_layer == null:
		return
	_tut_mode = ""
	_tut_layer.visible = true
	await _tut_info("ÇİP × ÇARPAN = kazandığın PUAN!\nSol üstte TUR SKORU yükseldi.",
		func(): return _tut_node_rect(chip_seal_panel).merge(_tut_node_rect(mult_seal_panel)), "right")
	if not _tut_active: return
	await _tut_info("İşine yaramayan harfleri DEĞİŞTİR ile\natıp yenilerini çekebilirsin (hakkın sınırlı).",
		func(): return _tut_node_rect(disc_btn), "above")
	if not _tut_active: return
	await _tut_info("Hedef PUANA ulaşana dek kelime\noynamaya devam et. Hedefi aşınca\nTUR GEÇİLİR ve DÜKKAN açılır! 👇",
		null, "center", "TAMAM")
	if not _tut_active: return
	# Bitirme YOK — dükkan açılınca devam (turu geçmek birkaç el sürebilir).
	_tut_mode = "await_shop"
	if _tut_layer != null:
		_tut_layer.visible = false  # dükkana kadar normal oyna (engel yok)

# Dükkan turu: turu geçip dükkana İLK girişte (await_shop) → dükkanı anlat, sonra bitir.
func _tut_shop_tour() -> void:
	if not _tut_active or _tut_layer == null:
		return
	_tut_mode = "shop"
	await get_tree().create_timer(0.7).timeout  # dükkan açılış geçişi otursun
	if not _tut_active or _tut_layer == null:
		return
	await _tut_info("İşte DÜKKAN! 👑\nKazandığın parayla güçlenirsin.\nJOKER al — her kelimede otomatik\nbonus verir, puanını KATLAR.",
		func(): return _tut_node_rect(_shop_shelves), "above")
	if not _tut_active: return
	await _tut_info("Paketlerden yeni HARF / CİLA çek.\nVitrin kötüyse YENİLE ile değiştir.",
		func(): return _tut_node_rect(_shop_shelves), "above")
	if not _tut_active: return
	await _tut_info("Hazır olunca SONRAKİ TUR ile\ndevam et. İyi oyunlar! 👑",
		func(): return _tut_node_rect(_shop_next_btn), "right", "BAŞLA!")
	_tut_finish()

# Bilgi balonu: ilgili öğeyi spotlight + balon, oyuncu İLERİ/ATLA'ya basana kadar BEKLE.
func _tut_info(text: String, rect_fn, place: String, btn: String = "İLERİ →") -> void:
	if not _tut_active or _tut_layer == null:
		return
	await _tut_present(text, rect_fn, place, 0.62, rect_fn != null, true, btn)
	if not _tut_active or _tut_layer == null:
		return
	await _tut_continue  # İLERİ veya ATLA

# Tek noktadan sunum: (gerekirse layout bekle) → TAZE rect → spotlight/dim + bağlamsal konum.
# rect_fn: Callable döndüren Rect2 (null → merkez, dim tam). spotlight: rect deliğini aç.
func _tut_present(text: String, rect_fn, place: String, alpha: float, spotlight: bool, btn_visible: bool, btn: String = "İLERİ →") -> void:
	if _tut_layer == null:
		return
	_tut_layer.visible = true
	_tut_panel.visible = false  # konumlanana kadar gizle (sol-üstte flaş olmasın)
	_tut_bubble_label.text = text
	_tut_next_btn.visible = btn_visible
	if btn_visible:
		_tut_next_btn.text = btn
	# Layout otursun (yeni el async) + balon boyutu (yeni metin) hesaplansın
	await get_tree().create_timer(0.18).timeout
	if _tut_layer == null or not is_instance_valid(_tut_layer):
		return
	await get_tree().process_frame
	if _tut_layer == null or not is_instance_valid(_tut_layer):
		return
	var rect: Rect2 = rect_fn.call() if rect_fn != null else Rect2()
	# Karartma / spotlight
	if alpha <= 0.01:
		_tut_set_cutout(Rect2(), 0.0, false)  # dim yok, her yer tıklanır (blind)
	elif spotlight and rect.size != Vector2.ZERO:
		_tut_set_cutout(rect.grow(16), alpha, true)
	else:
		_tut_set_cutout(Rect2(), alpha, true)
	# Balonu bağlamsal konumla + göster
	_tut_position_panel(rect, place)
	_tut_panel.visible = true

func _tut_position_panel(rect: Rect2, place: String) -> void:
	var W: float = _tut_layer.size.x
	var H: float = _tut_layer.size.y
	var bs: Vector2 = _tut_panel.size
	var gap := 26.0
	var pos: Vector2
	if rect.size == Vector2.ZERO:
		pos = Vector2((W - bs.x) * 0.5, (H - bs.y) * 0.5)
	else:
		match place:
			"above": pos = Vector2(rect.get_center().x - bs.x * 0.5, rect.position.y - bs.y - gap)
			"below": pos = Vector2(rect.get_center().x - bs.x * 0.5, rect.end.y + gap)
			"right": pos = Vector2(rect.end.x + gap, rect.get_center().y - bs.y * 0.5)
			"left": pos = Vector2(rect.position.x - bs.x - gap, rect.get_center().y - bs.y * 0.5)
			_: pos = Vector2((W - bs.x) * 0.5, (H - bs.y) * 0.5)
	pos.x = clampf(pos.x, 16.0, max(16.0, W - bs.x - 16.0))
	pos.y = clampf(pos.y, 16.0, max(16.0, H - bs.y - 16.0))
	_tut_panel.position = pos

func _tut_node_rect(n) -> Rect2:
	if n != null and is_instance_valid(n) and n is Control:
		return (n as Control).get_global_rect()
	return Rect2()

# Spotlight cutout: hedefin etrafını 4 kenarla karart, ORTASI delik. rect boşsa tüm ekran.
func _tut_set_cutout(rect: Rect2, alpha: float, block: bool) -> void:
	if _tut_layer == null:
		return
	var W: float = _tut_layer.size.x
	var H: float = _tut_layer.size.y
	var rects: Array
	if rect.size == Vector2.ZERO:
		rects = [Rect2(0, 0, W, H), Rect2(), Rect2(), Rect2()]
	else:
		var x0: float = clampf(rect.position.x, 0, W)
		var y0: float = clampf(rect.position.y, 0, H)
		var x1: float = clampf(rect.end.x, 0, W)
		var y1: float = clampf(rect.end.y, 0, H)
		rects = [Rect2(0, 0, W, y0), Rect2(0, y1, W, H - y1), Rect2(0, y0, x0, y1 - y0), Rect2(x1, y0, W - x1, y1 - y0)]
	for i in 4:
		var fr: ColorRect = _tut_frames[i]
		fr.position = rects[i].position
		fr.size = rects[i].size
		fr.color.a = alpha
		fr.mouse_filter = Control.MOUSE_FILTER_STOP if block else Control.MOUSE_FILTER_IGNORE

func _tut_finish() -> void:
	if not _tut_active:
		return
	_tut_active = false
	_tut_mode = ""
	emit_signal("_tut_continue")  # bekleyen _tut_info varsa serbest bırak (soft-lock yok)
	if _tut_layer != null and is_instance_valid(_tut_layer):
		_tut_layer.queue_free()
	_tut_layer = null
	Settings.tutorial_done = true
	Settings.save()

# Yarım bırakılmış öğreticiyi temizle (menüye dönüp tekrar girince taze başlasın).
# tutorial_done'a DOKUNMAZ → bitmediyse sonraki girişte yine gösterilir.
func _tut_reset() -> void:
	_tut_active = false
	_tut_mode = ""
	emit_signal("_tut_continue")
	if _tut_layer != null and is_instance_valid(_tut_layer):
		_tut_layer.queue_free()
	_tut_layer = null
