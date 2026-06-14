extends Node

## サウンド管理シングルトン（autoload 名: Audio）。
## 効果音(SE)は外部アセット無しでも鳴るよう、起動時に簡単な波形を手続き生成する。
## BGM は assets/audio に .ogg/.wav を置けば再生され、無ければ何もしない。

const SAMPLE_RATE := 22050

# SE 定義： name -> {freq, dur(秒), vol(0-1), square(矩形波か)}
const SE_DEFS := {
	"select": {"freq": 660.0, "dur": 0.06, "vol": 0.25, "square": true},
	"attack": {"freq": 200.0, "dur": 0.12, "vol": 0.35, "square": false},
	"hit":    {"freq": 130.0, "dur": 0.12, "vol": 0.40, "square": true},
	"grow":   {"freq": 880.0, "dur": 0.16, "vol": 0.30, "square": false},
	"fuse":   {"freq": 520.0, "dur": 0.28, "vol": 0.35, "square": false},
	"coin":   {"freq": 1040.0, "dur": 0.08, "vol": 0.25, "square": true},
	"win":    {"freq": 784.0, "dur": 0.35, "vol": 0.35, "square": false},
	"lose":   {"freq": 120.0, "dur": 0.5, "vol": 0.40, "square": false},
}

const POOL_SIZE := 8
const SETTINGS_PATH := "user://settings.json"

var _cache := {}                      # name -> AudioStreamWAV
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _bgm_player: AudioStreamPlayer
var _current_bgm := ""

# 設定値（0.0〜1.0）。settings.json に永続化。
var master_volume := 1.0
var bgm_volume := 0.7
var se_volume := 0.9
var fullscreen := false

func _ready() -> void:
	# SE 用のプレイヤープール。
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	# BGM 用プレイヤー。
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Master"
	add_child(_bgm_player)
	# SE を事前生成。
	for se_name in SE_DEFS:
		var d: Dictionary = SE_DEFS[se_name]
		_cache[se_name] = _make_tone(d["freq"], d["dur"], d["vol"], d["square"])
	load_settings()
	_apply_settings()

func play_se(se_name: String) -> void:
	if not _cache.has(se_name):
		return
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.volume_db = _to_db(se_volume)
	player.stream = _cache[se_name]
	player.play()

# --- 設定（音量・フルスクリーン）-------------------------------------------

## 線形音量(0-1)を dB へ。0は実質ミュート。
func _to_db(v: float) -> float:
	return -80.0 if v <= 0.001 else linear_to_db(v)

func _apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, _to_db(master_volume)) # マスターバス(0)
	_bgm_player.volume_db = _to_db(bgm_volume)
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)

func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, _to_db(master_volume))
	save_settings()

func set_bgm_volume(v: float) -> void:
	bgm_volume = clampf(v, 0.0, 1.0)
	_bgm_player.volume_db = _to_db(bgm_volume)
	save_settings()

func set_se_volume(v: float) -> void:
	se_volume = clampf(v, 0.0, 1.0)
	save_settings()

func set_fullscreen(value: bool) -> void:
	fullscreen = value
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
	save_settings()

func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	master_volume = clampf(float(parsed.get("master", master_volume)), 0.0, 1.0)
	bgm_volume = clampf(float(parsed.get("bgm", bgm_volume)), 0.0, 1.0)
	se_volume = clampf(float(parsed.get("se", se_volume)), 0.0, 1.0)
	fullscreen = bool(parsed.get("fullscreen", fullscreen))

func save_settings() -> void:
	var data := {"master": master_volume, "bgm": bgm_volume, "se": se_volume, "fullscreen": fullscreen}
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

## BGM を再生（同じ曲なら何もしない）。ファイルが無ければ無音。
func play_bgm(path: String) -> void:
	if _current_bgm == path and _bgm_player.playing:
		return
	if not ResourceLoader.exists(path):
		_current_bgm = ""
		_bgm_player.stop()
		return
	var stream := load(path)
	if stream is AudioStream:
		# ループ再生（インポート設定でループ未指定でもなるべくループさせる）。
		if stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		_bgm_player.stream = stream
		_bgm_player.play()
		_current_bgm = path

# --- 波形生成 ---------------------------------------------------------------

func _make_tone(freq: float, dur: float, vol: float, square: bool) -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(count * 2) # 16bit モノラル
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := 1.0 - float(i) / float(count) # 線形ディケイで「ポッ」と減衰
		var phase := sin(TAU * freq * t)
		var s := (1.0 if phase >= 0.0 else -1.0) if square else phase
		var sample := int(clampf(s * env * vol, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream
