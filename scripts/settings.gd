extends RefCounted
# Kalıcı oyun ayarları — statik (oturum boyu) + user://settings.cfg'ye yazılır.
# Ses = AudioServer "Music"/"SFX" bus'ları (oyuncular bu bus'lara bağlanır).
# main.gd ve game.gd preload eder: Settings.init() (idempotent), Settings.music_vol vb.

const PATH := "user://settings.cfg"

static var music_vol := 0.7      # 0..1
static var sfx_vol := 0.9        # 0..1
static var shake_on := true      # ekran sarsıntısı
static var particles_on := true  # partikül/kor efektleri
static var fullscreen := false
static var tutorial_done := false  # ilk-giriş öğreticisi gösterildi mi (bir kez)
static var _ready := false

static func init() -> void:
	if _ready:
		return
	_ready = true
	_ensure_buses()
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		music_vol = cf.get_value("audio", "music", music_vol)
		sfx_vol = cf.get_value("audio", "sfx", sfx_vol)
		shake_on = cf.get_value("juice", "shake", shake_on)
		particles_on = cf.get_value("juice", "particles", particles_on)
		fullscreen = cf.get_value("video", "fullscreen", fullscreen)
		tutorial_done = cf.get_value("progress", "tutorialDone", tutorial_done)
	apply_audio()
	apply_video()

static func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "music", music_vol)
	cf.set_value("audio", "sfx", sfx_vol)
	cf.set_value("juice", "shake", shake_on)
	cf.set_value("juice", "particles", particles_on)
	cf.set_value("video", "fullscreen", fullscreen)
	cf.set_value("progress", "tutorialDone", tutorial_done)
	cf.save(PATH)

static func _ensure_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")

static func apply_audio() -> void:
	_set_bus("Music", music_vol)
	_set_bus("SFX", sfx_vol)

static func _set_bus(bus_name: String, vol: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, vol <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(0.0001, vol)))

static func apply_video() -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
