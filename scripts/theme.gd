extends RefCounted
# KEÇE & KEMİK renk paleti — TEK doğruluk kaynağı (mobile/DESIGN.md + theme.ts ile senkron).
# NEON YOK; sıcak kemik taşlar ↔ soğuk keçe masa, tek parlak an = ember.

const BG_DEEP := Color("0e2a22")    # felt-900 en koyu keçe zemin
const FELT_800 := Color("13362b")   # felt-800 panel yüzeyi
const FELT_700 := Color("1b463a")   # felt-700 yükseltilmiş yüzey
const FELT := Color("1b463a")       # masa keçe
const FELT_HI := Color("2d6e50")    # açık keçe vurgu
const TEXT_DIM := Color(0.949, 0.918, 0.839, 0.55)  # sönük kemik yazı
const LINE := Color(0.949, 0.918, 0.839, 0.14)      # ince ayraç
const CARD_FACE := Color("f2ead6")  # kemik taş yüzeyi
const CARD_EDGE := Color("c9b68c")  # taş kenarı
const INK := Color("171410")        # mürekkep harf
const TEXT := Color("f2ead6")       # kemik yazı
const BRASS := Color("e8b84a")      # altın sarısı (canlı)
const ORANGE := Color("e0742a")     # yanık turuncu (sıcak vurgu)
const OUTLINE := Color("160d06", 0.9)  # yazı koyu konturu (okunurluk)
const SIDEBAR := Color("10241d")    # koyu mat sidebar
const CHIP := Color("3f8fcc")       # çip = canlı mürekkep-mavi
const CHIP_BADGE := Color("6fb6e0") # çip ışıma (soğuk)
const MULT := Color("dd3f30")       # çarpan = canlı kırmızı
const EMBER := Color("ffb24a")      # tek parlak an (skor)
const GOOD := Color("5fb061")       # geçerli/başarı yeşili
const LILAC := Color("7e6ba8")      # efsane joker
const SHADOW := Color("0a1f19")     # gölge

# Nadirlik → renk (joker kenarı)
const RARITY := {
	"common": Color("8aa6b4"),
	"uncommon": Color("5e8c9c"),
	"rare": Color("b23a2e"),
	"legendary": Color("c9a24b"),
}

# Font: m6x11plus (Balatro'nun fontu; tok pixel, tam Türkçe, ticari serbest+atıf).
# Crisp pixel için antialiasing kapalı.
static func load_font() -> FontFile:
	var f := FontFile.new()
	f.data = FileAccess.get_file_as_bytes("res://assets/fonts/m6x11plus.ttf")
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return f

# TAŞ harfi fontu: PaytoneOne (kalın/net — pixel font taşta okunmuyordu).
static func load_tile_font() -> FontFile:
	var f := FontFile.new()
	f.data = FileAccess.get_file_as_bytes("res://assets/fonts/PaytoneOne.ttf")
	return f

static func make_theme(font: FontFile) -> Theme:
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = 28
	return t

# Taş üstü "lamba parlaması" (üstte hafif beyaz sheen, üst köşeler yuvarlak).
static func tile_sheen() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1, 1, 1, 0.16)
	s.corner_radius_top_left = 10
	s.corner_radius_top_right = 10
	s.corner_radius_bottom_left = 2
	s.corner_radius_bottom_right = 2
	return s

# Boş joker yuvası (faint pirinç konturlu keçe yuva).
static func empty_slot() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.078, 0.16, 0.13, 0.55)
	s.set_corner_radius_all(16)
	s.set_border_width_all(2)
	s.border_color = Color(0.788, 0.635, 0.294, 0.30)  # brass faint
	return s

# Keçe panel stili (yuvarlatılmış, ince pirinç kenar, gölge hissi).
static func felt_panel(bg: Color = FELT, border: Color = CARD_EDGE, radius: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(2)
	s.border_color = border
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 4)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s

# Kemik taş stili.
static func bone_tile(face: Color = CARD_FACE, border: Color = CARD_EDGE, radius: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = face
	s.set_corner_radius_all(radius)
	s.border_width_top = 2
	s.border_width_left = 2
	s.border_width_right = 4
	s.border_width_bottom = 5  # alt-sağ deboss (kabartma hissi)
	s.border_color = border
	s.shadow_color = Color(0.04, 0.12, 0.10, 0.55)  # keçeye düşen sıcak-koyu gölge
	s.shadow_size = 16
	s.shadow_offset = Vector2(0, 10)
	return s

# Radiuslu-kare skor damgası (çip/çarpan; yuvarlak DEĞİL, × glifi YOK).
static func seal(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(10)
	s.set_border_width_all(2)
	s.border_color = Color(1, 1, 1, 0.18)
	s.shadow_color = Color(0, 0, 0, 0.4)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 3)
	return s

# Chunky pill buton — sert ALT kenar (koyu ton) = basılı 3D his (gradyan yok).
static func button_filled(bg: Color = BRASS) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(18)
	s.border_width_bottom = 6
	s.border_color = bg.darkened(0.4)
	s.shadow_color = Color(0, 0, 0, 0.3)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 4)
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 12
	s.content_margin_bottom = 14
	return s

# Basılı hali — alt kenar incelir + içerik aşağı kayar (tuşa basılmış gibi).
static func button_pressed(bg: Color = BRASS) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg.darkened(0.08)
	s.set_corner_radius_all(18)
	s.border_width_bottom = 2
	s.border_color = bg.darkened(0.4)
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 16
	s.content_margin_bottom = 10
	return s

# Stat paneli (etiket+girintili değer) — koyu yuvarlak blok, sert alt kenar.
static func stat_panel() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("1c3a30")
	s.set_corner_radius_all(12)
	s.border_width_bottom = 4
	s.border_color = Color("0a1f19")
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 6
	s.content_margin_bottom = 8
	return s

# Girintili (recessed) değer kutusu — çok koyu, içeri gömük his.
static func stat_inset() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("0b1a15")
	s.set_corner_radius_all(8)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	return s

# Kart arkası (deste yığını) — koyu kırmızı + pirinç çerçeve.
static func card_back() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("8f2f28")
	s.set_corner_radius_all(12)
	s.set_border_width_all(3)
	s.border_width_bottom = 5
	s.border_color = BRASS
	s.shadow_color = Color(0.04, 0.12, 0.10, 0.5)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 5)
	return s

static func button_outline(border: Color = CARD_FACE) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.14, 0.11, 0.55)
	s.set_corner_radius_all(18)
	s.set_border_width_all(2)
	s.border_width_bottom = 5
	s.border_color = border
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 12
	s.content_margin_bottom = 14
	return s
