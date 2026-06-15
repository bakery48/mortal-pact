extends Node

## ラン全体の状態を保持するシングルトン（autoload 名: Run）。
## デッキ・HP・所持金・マップ進行をシーンをまたいで管理する。
## デッキはカード実体を保持するため、成長・老化・子孫がバトル間で持続する。

const STARTING_HP := 65
const STARTING_GOLD := 50
const DECK_LIMIT := 40        # デッキ上限（スキルカード枚数）
const SHOP_CARD_COST := 50
const REST_HEAL_RATIO := 0.3  # 休憩で最大HPの30%回復

const SCENE_MAP := "res://scenes/map/map.tscn"
const SCENE_BATTLE := "res://scenes/battle/battle.tscn"
const SCENE_REWARD := "res://scenes/ui/reward.tscn"
const SCENE_SHOP := "res://scenes/ui/shop.tscn"
const SCENE_RESULT := "res://scenes/ui/result.tscn"
const SCENE_SETTINGS := "res://scenes/ui/settings.tscn"
const SCENE_TITLE := "res://scenes/ui/title.tscn"
const SCENE_LEGACY := "res://scenes/ui/legacy.tscn"
const SCENE_CODEX := "res://scenes/ui/codex.tscn"

const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 3 # 全体デフレで数値が変わったため更新

## 図鑑（出会った魔物の記録）。ランをまたいで永続。
const UNLOCK_PATH := "user://unlocks.json"
## 引き継ぎ（死亡時に選んだ次ランの初期デッキ）。次ラン開始時に1度だけ消費。
const CARRYOVER_PATH := "user://carryover.json"
## ランの初期デッキ体数。
const START_DECK_SIZE := 6

enum NodeType { BATTLE_ZAKO, BATTLE_ELITE, BATTLE_BOSS, REST_SHOP }

var deck: Array[MonsterData] = []
var player_max_hp := STARTING_HP
var player_hp := STARTING_HP
var gold := STARTING_GOLD
var current_floor := 1

var map_rows: Array = []       # 行ごとのノード配列（分岐マップのグラフ）
var current_row := -1          # 現在クリア済みノードの行（-1=未開始）
var current_col := 0           # 現在クリア済みノードの列
var current_encounter := {}    # 戦闘シーンへ渡す敵パラメータ
var last_result := ""          # "clear" / "lose"
var settings_return := SCENE_TITLE # 設定画面から戻る先

## 図鑑：出会った魔物名 → true。ランをまたいで永続。
var unlocked: Dictionary = {}

func _ready() -> void:
	load_unlocks()
	# セーブがあれば自動的に続きから、無ければ新しいランを開始。
	if has_save():
		if not load_game():
			start_new_run()
	elif deck.is_empty():
		start_new_run()

# --- ランの初期化 -----------------------------------------------------------

func start_new_run() -> void:
	current_floor = 1
	player_max_hp = roundi(STARTING_HP * MonsterData.POWER_SCALE)
	player_hp = player_max_hp
	gold = STARTING_GOLD
	deck.assign(_build_starting_deck())
	# 初期デッキの魔物は図鑑に解放しておく。
	for m in deck:
		record_unlock(m.monster_name)
	_build_map()
	current_row = -1
	current_col = 0

## 初期デッキを組む。前ランからの引き継ぎがあればそれを使い（幼体リセット済み）、
## START_DECK_SIZE 未満なら不足分をデフォルト初期種で補充する。引き継ぎは1度消費する。
func _build_starting_deck() -> Array[MonsterData]:
	var result: Array[MonsterData] = _load_carryover()
	if result.is_empty():
		return DeckManager.load_monster_resources()
	if result.size() < START_DECK_SIZE:
		var names := {}
		for m in result:
			names[m.monster_name] = true
		for d in DeckManager.load_monster_resources():
			if result.size() >= START_DECK_SIZE:
				break
			if not names.has(d.monster_name):
				names[d.monster_name] = true
				result.append(d)
	_consume_carryover()
	return result

func next_floor() -> void:
	current_floor += 1
	player_hp = mini(player_max_hp, player_hp + roundi(20 * MonsterData.POWER_SCALE)) # フロア移動で少し回復
	_build_map()
	current_row = -1
	current_col = 0
	get_tree().change_scene_to_file(SCENE_MAP)

func restart_run() -> void:
	start_new_run()
	get_tree().change_scene_to_file(SCENE_MAP)

## タイトルの「つづきから」：セーブを読み込んでマップへ。
func continue_game() -> void:
	if has_save():
		load_game()
	get_tree().change_scene_to_file(SCENE_MAP)

## タイトルの「はじめから」：セーブを消して新しいランを開始。
func new_game() -> void:
	delete_save()
	restart_run()

# 各行の構成：選べるノード種別の候補と、ノード数の範囲[min,max]。
const _MAP_LAYOUT := [
	{"types": ["zako"], "count": [2, 3]},
	{"types": ["zako"], "count": [2, 3]},
	{"types": ["zako", "rest"], "count": [3, 3]},
	{"types": ["elite", "zako"], "count": [2, 3]},
	{"types": ["rest"], "count": [2, 2]},
	{"types": ["elite", "zako"], "count": [2, 3]},
	{"types": ["boss"], "count": [1, 1]},
]

## 分岐マップ（行×ノードのグラフ）を生成する。
func _build_map() -> void:
	map_rows = []
	for spec in _MAP_LAYOUT:
		var count := randi_range(int(spec["count"][0]), int(spec["count"][1]))
		var types := spec["types"] as Array
		var row: Array = []
		for c in range(count):
			row.append(_make_node(String(types.pick_random())))
		# 「休憩」が選択肢にある行は、必ず1つは休憩ノードを保証する。
		if "rest" in types:
			var has_rest := false
			for node in row:
				if int(node["type"]) == NodeType.REST_SHOP:
					has_rest = true
					break
			if not has_rest:
				row[randi() % row.size()] = _make_node("rest")
		map_rows.append(row)
	_connect_rows()

## 隣り合う行をエッジで接続する（next に次行の列インデックスを持たせる）。
func _connect_rows() -> void:
	for r in range(map_rows.size() - 1):
		var cr: int = map_rows[r].size()
		var cr1: int = map_rows[r + 1].size()
		for c in range(cr):
			var t := 0
			if cr1 > 1:
				t = roundi(float(c) * (cr1 - 1) / float(maxi(1, cr - 1))) if cr > 1 else int(cr1 / 2)
			var nexts: Array = [t]
			# 50%で隣のノードへも分岐。
			if randf() < 0.5:
				var nb := clampi(t + (1 if randf() < 0.5 else -1), 0, cr1 - 1)
				if nb not in nexts:
					nexts.append(nb)
			map_rows[r][c]["next"] = nexts
		# 次行の全ノードに入口があることを保証。
		var incoming := {}
		for c in range(cr):
			for nc in map_rows[r][c]["next"]:
				incoming[nc] = true
		for j in range(cr1):
			if not incoming.has(j):
				var best := 0
				if cr1 > 1:
					best = roundi(float(j) * (cr - 1) / float(maxi(1, cr1 - 1))) if cr > 1 else 0
				best = clampi(best, 0, cr - 1)
				if j not in map_rows[r][best]["next"]:
					map_rows[r][best]["next"].append(j)

func _make_node(kind: String) -> Dictionary:
	match kind:
		"zako":
			return _battle_node(NodeType.BATTLE_ZAKO, _zako_group(), 25)
		"elite":
			return _battle_node(NodeType.BATTLE_ELITE, _elite_group(), 55)
		"boss":
			return _battle_node(NodeType.BATTLE_BOSS, [EnemyDatabase.random_boss()], 120)
		_:
			return _rest_node()

## 雑魚ノードの敵編成。序盤フロアは数を抑える（floor1:1〜2体 / floor2以降:1〜3体）。
func _zako_group() -> Array:
	var max_count := 2 if current_floor <= 1 else 3
	var group: Array = []
	for i in range(randi_range(1, max_count)):
		group.append(EnemyDatabase.random_zako())
	return group

## エリートノードの敵編成（エリート1体、50%でお供の雑魚1体）。
func _elite_group() -> Array:
	var group: Array = [EnemyDatabase.random_elite()]
	if randf() < 0.5:
		group.append(EnemyDatabase.random_zako())
	return group

## 敵編成（複数体）を、フロアに応じてスケールしたバトルノードに変換する。
func _battle_node(type: NodeType, enemies: Array, reward_gold: int) -> Dictionary:
	var scale := (1.0 + 0.25 * float(current_floor - 1)) * MonsterData.POWER_SCALE # フロア強化＋全体デフレ
	var scaled: Array = []
	var is_boss := false
	for enemy in enemies:
		var scaled_pattern: Array = []
		for move in enemy["pattern"]:
			scaled_pattern.append({
				"type": move["type"],
				"value": maxi(1, roundi(int(move["value"]) * scale)),
			})
		scaled.append({
			"name": enemy["name"],
			"max_hp": roundi(int(enemy["max_hp"]) * scale),
			"pattern": scaled_pattern,
			"element": enemy.get("element", MonsterData.Element.NONE),
			"is_boss": enemy.get("is_boss", false),
		})
		if enemy.get("is_boss", false):
			is_boss = true
	var label: String = scaled[0]["name"]
	if scaled.size() > 1:
		label += "他%d体" % (scaled.size() - 1)
	return {
		"type": type,
		"name": label,
		"enemies": scaled,
		"gold": reward_gold,
		"is_boss": is_boss,
		"next": [],
	}

func _rest_node() -> Dictionary:
	return {"type": NodeType.REST_SHOP, "name": "休憩 / ショップ", "next": []}

# --- マップ進行 -------------------------------------------------------------

func current_node() -> Dictionary:
	if current_row < 0 or current_row >= map_rows.size():
		return {}
	var row: Array = map_rows[current_row]
	if current_col < 0 or current_col >= row.size():
		return {}
	return row[current_col]

func node_at(row: int, col: int) -> Dictionary:
	if row < 0 or row >= map_rows.size():
		return {}
	var r: Array = map_rows[row]
	if col < 0 or col >= r.size():
		return {}
	return r[col]

## 次に進入できる行インデックス（-1始まりなので 0、以降は現在行+1）。
func next_row_index() -> int:
	return current_row + 1

## 次に進入できる列インデックス一覧（int）。
func reachable_cols() -> Array:
	var cols: Array = []
	if current_row < 0:
		var first: Array = map_rows[0] if not map_rows.is_empty() else []
		for i in range(first.size()):
			cols.append(i)
	else:
		for nc in current_node().get("next", []):
			cols.append(int(nc))
	return cols

func is_run_complete() -> bool:
	return current_row >= map_rows.size() - 1 and current_row >= 0 and bool(current_node().get("is_boss", false))

## マップで選んだノードに進入する。
func choose_node(row: int, col: int) -> void:
	if row != next_row_index() or col not in reachable_cols():
		return
	current_row = row
	current_col = col
	var node := current_node()
	if int(node["type"]) == NodeType.REST_SHOP:
		get_tree().change_scene_to_file(SCENE_SHOP)
	else:
		current_encounter = node
		get_tree().change_scene_to_file(SCENE_BATTLE)

## ノード完了後の遷移：ボスならクリア、そうでなければマップへ。
func go_after_node() -> void:
	if is_run_complete():
		last_result = "clear"
		get_tree().change_scene_to_file(SCENE_RESULT)
	else:
		get_tree().change_scene_to_file(SCENE_MAP)

# --- バトル結果 -------------------------------------------------------------

func on_battle_won(hp: int) -> void:
	# デッキ（モンスター）の成長・消滅・合体は戦闘中に直接反映済み。HPと報酬のみ処理。
	player_hp = hp
	# 勝利ごとに少し回復（休憩まで遠い序盤の消耗を緩和）。
	player_hp = mini(player_max_hp, player_hp + roundi(player_max_hp * 0.12))
	if current_encounter.has("gold"):
		gold += int(current_encounter["gold"])
	get_tree().change_scene_to_file(SCENE_REWARD)

func on_battle_lost() -> void:
	player_hp = 0
	last_result = "lose"
	# 死亡＝ラン終了。次ランへ引き継ぐ魔物を選ぶ「継承」画面へ。
	# 進行セーブは消す（ランは終わったので「つづきから」対象外）。
	delete_save()
	get_tree().change_scene_to_file(SCENE_LEGACY)

# --- デッキ操作（報酬・ショップ用） -----------------------------------------

## デッキの総スキルカード枚数（各モンスターの所持コマンド数の合計）。
func deck_card_count() -> int:
	var n := 0
	for m in deck:
		n += m.commands.size()
	return n

## skill_count 枚を追加してもデッキ上限以内か。
func can_add(skill_count: int) -> bool:
	return deck_card_count() + skill_count <= DECK_LIMIT

func add_card(card: MonsterData) -> bool:
	if not can_add(card.commands.size()):
		return false
	deck.append(card)
	return true

func rest_heal() -> int:
	var amount := roundi(player_max_hp * REST_HEAL_RATIO)
	var before := player_hp
	player_hp = mini(player_max_hp, player_hp + amount)
	return player_hp - before

# --- セーブ / ロード ---------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

## 現在のラン状態を user:// に JSON で保存する（ノード間の安全な地点で呼ぶ）。
func save_game() -> void:
	var deck_data: Array = []
	for m in deck:
		deck_data.append(m.to_dict())
	var data := {
		"version": SAVE_VERSION,
		"player_max_hp": player_max_hp,
		"player_hp": player_hp,
		"gold": gold,
		"current_floor": current_floor,
		"current_row": current_row,
		"current_col": current_col,
		"map_rows": map_rows,
		"deck": deck_data,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

## セーブを読み込んで状態を復元する。成功で true。
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed
	# 旧バージョンのセーブは構造が違うため破棄して新規開始させる。
	if int(data.get("version", 1)) != SAVE_VERSION:
		return false

	player_max_hp = int(data.get("player_max_hp", STARTING_HP))
	player_hp = int(data.get("player_hp", STARTING_HP))
	gold = int(data.get("gold", STARTING_GOLD))
	current_floor = int(data.get("current_floor", 1))
	current_row = int(data.get("current_row", -1))
	current_col = int(data.get("current_col", 0))

	var loaded: Array[MonsterData] = []
	for md in data.get("deck", []):
		loaded.append(MonsterData.from_dict(md))
	deck.assign(loaded)

	# マップグラフは保存された配列をそのまま使う（数値は利用側で int() 変換済み）。
	map_rows = data.get("map_rows", [])
	if map_rows.is_empty():
		_build_map()
		current_row = -1
		current_col = 0
	return true

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

# --- 図鑑（unlocks）---------------------------------------------------------

## 魔物を図鑑に記録する（既知なら何もしない）。敵撃破・仲間獲得・初期デッキで呼ぶ。
func record_unlock(monster_name: String) -> void:
	if monster_name == "" or unlocked.has(monster_name):
		return
	unlocked[monster_name] = true
	save_unlocks()

func is_unlocked(monster_name: String) -> bool:
	return unlocked.has(monster_name)

func unlocked_count() -> int:
	return unlocked.size()

func load_unlocks() -> void:
	unlocked = {}
	if not FileAccess.file_exists(UNLOCK_PATH):
		return
	var file := FileAccess.open(UNLOCK_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		unlocked = parsed

func save_unlocks() -> void:
	var file := FileAccess.open(UNLOCK_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(unlocked, "\t"))
		file.close()

# --- 引き継ぎ（carryover）---------------------------------------------------

## 死亡時に選んだ魔物を、次ランの初期デッキとして保存する（幼体にリセット）。
func set_carryover(monsters: Array) -> void:
	var data: Array = []
	for m: MonsterData in monsters:
		if data.size() >= START_DECK_SIZE:
			break
		var copy := MonsterData.from_dict(m.to_dict())
		copy.stage = MonsterData.Stage.INFANT # 幼体にリセット
		copy.exp = 0.0
		data.append(copy.to_dict())
	var file := FileAccess.open(CARRYOVER_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func has_carryover() -> bool:
	return FileAccess.file_exists(CARRYOVER_PATH)

## 引き継ぎデッキを読み込む（無ければ空）。消費は _consume_carryover で別途行う。
func _load_carryover() -> Array[MonsterData]:
	var result: Array[MonsterData] = []
	if not FileAccess.file_exists(CARRYOVER_PATH):
		return result
	var file := FileAccess.open(CARRYOVER_PATH, FileAccess.READ)
	if file == null:
		return result
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_ARRAY:
		return result
	for md in parsed:
		var m := MonsterData.from_dict(md)
		m.stage = MonsterData.Stage.INFANT # 念のため幼体に
		m.exp = 0.0
		result.append(m)
	return result

func _consume_carryover() -> void:
	if FileAccess.file_exists(CARRYOVER_PATH):
		DirAccess.remove_absolute(CARRYOVER_PATH)
