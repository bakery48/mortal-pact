extends Node

## ラン全体の状態を保持するシングルトン（autoload 名: Run）。
## デッキ・HP・所持金・マップ進行をシーンをまたいで管理する。
## デッキはカード実体を保持するため、成長・老化・子孫がバトル間で持続する。

const STARTING_HP := 50
const STARTING_GOLD := 50
const DECK_LIMIT := 15        # 設計書のデッキ上限
const SHOP_CARD_COST := 50
const REST_HEAL_RATIO := 0.3  # 休憩で最大HPの30%回復

const SCENE_MAP := "res://scenes/map/map.tscn"
const SCENE_BATTLE := "res://scenes/battle/battle.tscn"
const SCENE_REWARD := "res://scenes/ui/reward.tscn"
const SCENE_SHOP := "res://scenes/ui/shop.tscn"
const SCENE_RESULT := "res://scenes/ui/result.tscn"

const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 1

enum NodeType { BATTLE_ZAKO, BATTLE_ELITE, BATTLE_BOSS, REST_SHOP }

var deck: Array[MonsterData] = []
var player_max_hp := STARTING_HP
var player_hp := STARTING_HP
var gold := STARTING_GOLD
var current_floor := 1

var map_nodes: Array = []      # ノード定義（Dictionary）の配列
var current_index := 0         # 進行ポインタ（次に挑むノード）
var current_encounter := {}    # 戦闘シーンへ渡す敵パラメータ
var last_result := ""          # "clear" / "lose"

func _ready() -> void:
	# セーブがあれば自動的に続きから、無ければ新しいランを開始。
	if has_save():
		if not load_game():
			start_new_run()
	elif deck.is_empty():
		start_new_run()

# --- ランの初期化 -----------------------------------------------------------

func start_new_run() -> void:
	current_floor = 1
	player_max_hp = STARTING_HP
	player_hp = STARTING_HP
	gold = STARTING_GOLD
	deck.assign(DeckManager.load_monster_resources())
	_build_map()
	current_index = 0

func next_floor() -> void:
	current_floor += 1
	player_hp = mini(player_max_hp, player_hp + 20) # フロア移動で少し回復
	_build_map()
	current_index = 0
	get_tree().change_scene_to_file(SCENE_MAP)

func restart_run() -> void:
	start_new_run()
	get_tree().change_scene_to_file(SCENE_MAP)

func _build_map() -> void:
	map_nodes = [
		_battle_node(NodeType.BATTLE_ZAKO, EnemyDatabase.random_zako(), 25),
		_battle_node(NodeType.BATTLE_ZAKO, EnemyDatabase.random_zako(), 25),
		_rest_node(),
		_battle_node(NodeType.BATTLE_ELITE, EnemyDatabase.random_elite(), 55),
		_rest_node(),
		_battle_node(NodeType.BATTLE_BOSS, EnemyDatabase.random_boss(), 120),
	]

## EnemyDatabase の敵設定を、フロアに応じてスケールしたバトルノードに変換する。
func _battle_node(type: NodeType, enemy: Dictionary, reward_gold: int) -> Dictionary:
	var scale := 1.0 + 0.25 * float(current_floor - 1) # フロアが進むほど敵が強化される
	var scaled_pattern: Array = []
	for move in enemy["pattern"]:
		scaled_pattern.append({
			"type": move["type"],
			"value": maxi(1, roundi(int(move["value"]) * scale)),
		})
	return {
		"type": type,
		"name": enemy["name"],
		"max_hp": roundi(int(enemy["max_hp"]) * scale),
		"pattern": scaled_pattern,
		"element": enemy.get("element", MonsterData.Element.NONE),
		"gold": reward_gold,
		"is_boss": enemy.get("is_boss", false),
	}

func _rest_node() -> Dictionary:
	return {"type": NodeType.REST_SHOP, "name": "休憩 / ショップ"}

# --- マップ進行 -------------------------------------------------------------

func current_node() -> Dictionary:
	if current_index < 0 or current_index >= map_nodes.size():
		return {}
	return map_nodes[current_index]

func is_run_complete() -> bool:
	return current_index >= map_nodes.size()

func advance() -> void:
	current_index += 1

## マップから現在ノードに進入する。ノード種別に応じてシーンを切り替える。
func begin_node() -> void:
	var node := current_node()
	if node.is_empty():
		return
	if int(node["type"]) == NodeType.REST_SHOP:
		get_tree().change_scene_to_file(SCENE_SHOP)
	else:
		current_encounter = node
		get_tree().change_scene_to_file(SCENE_BATTLE)

## ノード完了後の遷移：進行を進め、ラン完了ならクリア、そうでなければマップへ。
func go_after_node() -> void:
	advance()
	if is_run_complete():
		last_result = "clear"
		get_tree().change_scene_to_file(SCENE_RESULT)
	else:
		get_tree().change_scene_to_file(SCENE_MAP)

# --- バトル結果 -------------------------------------------------------------

func on_battle_won(remaining_deck: Array[MonsterData], hp: int) -> void:
	deck.assign(remaining_deck)
	player_hp = hp
	if current_encounter.has("gold"):
		gold += int(current_encounter["gold"])
	get_tree().change_scene_to_file(SCENE_REWARD)

func on_battle_lost() -> void:
	player_hp = 0
	last_result = "lose"
	get_tree().change_scene_to_file(SCENE_RESULT)

# --- デッキ操作（報酬・ショップ用） -----------------------------------------

func can_add_card() -> bool:
	return deck.size() < DECK_LIMIT

func add_card(card: MonsterData) -> bool:
	if not can_add_card():
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
		"current_index": current_index,
		"map_nodes": map_nodes,
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

	player_max_hp = int(data.get("player_max_hp", STARTING_HP))
	player_hp = int(data.get("player_hp", STARTING_HP))
	gold = int(data.get("gold", STARTING_GOLD))
	current_floor = int(data.get("current_floor", 1))
	current_index = int(data.get("current_index", 0))

	var loaded: Array[MonsterData] = []
	for md in data.get("deck", []):
		loaded.append(MonsterData.from_dict(md))
	deck.assign(loaded)

	# マップは保存された配列をそのまま使う（数値は利用側で int() 変換済み）。
	map_nodes = data.get("map_nodes", [])
	if map_nodes.is_empty():
		_build_map()
	# 念のため進行ポインタを範囲内に収める。
	current_index = clampi(current_index, 0, map_nodes.size())
	return true

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
