extends RefCounted
# Kalıcı REKORLAR — run'lar arası en iyi sonuçlar. Settings ile aynı statik kalıp
# (user://records.cfg). SADECE sunum/meta: oyun mantığına (engine/) dokunmaz; run sonunda
# state'ten OKUYUP karşılaştırır. main.gd ve game.gd preload eder: Records.init() (idempotent).

const PATH := "user://records.cfg"

static var best_score := 0       # en yüksek tek-el (kelime) skoru
static var best_word := ""       # o skoru yapan kelime (gösterim için)
static var furthest_ante := 0    # ulaşılan en ileri bölüm (1..8)
static var wins := 0             # toplam galibiyet
static var runs := 0             # toplam tamamlanan run (kazan+kaybet)
static var _ready := false

static func init() -> void:
	if _ready:
		return
	_ready = true
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		best_score = cf.get_value("records", "bestScore", best_score)
		best_word = cf.get_value("records", "bestWord", best_word)
		furthest_ante = cf.get_value("records", "furthestAnte", furthest_ante)
		wins = cf.get_value("records", "wins", wins)
		runs = cf.get_value("records", "runs", runs)

static func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("records", "bestScore", best_score)
	cf.set_value("records", "bestWord", best_word)
	cf.set_value("records", "furthestAnte", furthest_ante)
	cf.set_value("records", "wins", wins)
	cf.set_value("records", "runs", runs)
	cf.save(PATH)

# Run sonunda çağrılır. Mevcut rekorları kırarsa günceller + kaydeder.
# Dönen sözlük, bu run'da KIRILAN rekorların anahtarlarını içerir (uç ekranda vurgu için):
# {"best_score": true, "furthest_ante": true}.
static func submit(stats: Dictionary, ante: int, won: bool) -> Dictionary:
	init()
	var fresh := {}
	var s := int(stats.get("bestScore", 0))
	if s > best_score:
		best_score = s
		best_word = String(stats.get("bestWord", ""))
		fresh["best_score"] = true
	if ante > furthest_ante:
		furthest_ante = ante
		fresh["furthest_ante"] = true
	if won:
		wins += 1
	runs += 1
	save()
	return fresh
