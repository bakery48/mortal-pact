class_name EnemyDatabase
extends RefCounted

## 敵のカタログ。種別ごとのプールからランダムに敵を提供する。
## 各敵は名前・最大HP・行動パターンを持つ。パターンは EnemyUI.Intent で定義。

static func _move(type: int, value: int) -> Dictionary:
	return {"type": type, "value": value}

static func _enemy(enemy_name: String, hp: int, pattern: Array, element := MonsterData.Element.NONE, is_boss := false) -> Dictionary:
	return {"name": enemy_name, "max_hp": hp, "pattern": pattern, "element": element, "is_boss": is_boss}

# --- 雑魚 -------------------------------------------------------------------

static func zako_pool() -> Array:
	var A := EnemyUI.Intent.ATTACK
	var D := EnemyUI.Intent.DEFEND
	var B := EnemyUI.Intent.BUFF
	var P := EnemyUI.Intent.POISON
	var E := MonsterData.Element
	return [
		_enemy("ゴブリン", 44, [_move(A, 8), _move(A, 6), _move(D, 6)], E.EARTH),
		_enemy("スケルトン", 50, [_move(A, 7), _move(A, 10)], E.DARK),
		_enemy("大コウモリ", 38, [_move(A, 6), _move(A, 6), _move(A, 9)], E.WIND),
		_enemy("ホブゴブリン", 56, [_move(A, 9), _move(B, 3), _move(A, 11)], E.EARTH),
		_enemy("マッドスライム", 60, [_move(D, 8), _move(A, 7)], E.WATER),
		_enemy("インプ", 46, [_move(A, 5), _move(A, 5), _move(A, 8)], E.FIRE),
		_enemy("毒蛇", 42, [_move(P, 3), _move(A, 7), _move(A, 9)], E.DARK),
		_enemy("サラマンダー", 50, [_move(A, 10), _move(A, 16)], E.FIRE),
		_enemy("フェンリル", 46, [_move(A, 9), _move(B, 3), _move(A, 13)], E.DARK),
		_enemy("ゴーレム", 62, [_move(D, 10), _move(A, 9)], E.EARTH),
		_enemy("ウィスプ", 34, [_move(B, 3), _move(A, 9), _move(A, 7)], E.LIGHT),
	]

# --- エリート ---------------------------------------------------------------

static func elite_pool() -> Array:
	var A := EnemyUI.Intent.ATTACK
	var D := EnemyUI.Intent.DEFEND
	var B := EnemyUI.Intent.BUFF
	var H := EnemyUI.Intent.HEAL
	var P := EnemyUI.Intent.POISON
	var E := MonsterData.Element
	return [
		_enemy("オーガ", 88, [_move(A, 13), _move(B, 4), _move(A, 18)], E.EARTH),
		_enemy("闇の魔女", 80, [_move(A, 10), _move(H, 14), _move(A, 14)], E.DARK),
		_enemy("ガーゴイル", 95, [_move(D, 12), _move(A, 15), _move(A, 9)], E.EARTH),
		_enemy("地獄の番犬", 84, [_move(A, 12), _move(A, 12), _move(B, 5)], E.FIRE),
		_enemy("邪毒の妖蛆", 78, [_move(P, 5), _move(A, 11), _move(D, 10)], E.DARK),
		_enemy("ケルベロス", 95, [_move(A, 14), _move(A, 22), _move(B, 5)], E.DARK),
		_enemy("ミノタウロス", 100, [_move(A, 13), _move(B, 4), _move(A, 19)], E.EARTH),
		_enemy("ヴァンパイア", 88, [_move(A, 12), _move(H, 12), _move(A, 18)], E.DARK),
	]

# --- ボス -------------------------------------------------------------------

static func boss_pool() -> Array:
	var A := EnemyUI.Intent.ATTACK
	var D := EnemyUI.Intent.DEFEND
	var B := EnemyUI.Intent.BUFF
	var H := EnemyUI.Intent.HEAL
	var P := EnemyUI.Intent.POISON
	var E := MonsterData.Element
	return [
		_enemy("死の騎士", 150, [_move(A, 16), _move(D, 12), _move(A, 24), _move(B, 4)], E.DARK, true),
		_enemy("双頭の竜", 175, [_move(A, 14), _move(A, 14), _move(B, 6), _move(A, 28)], E.FIRE, true),
		_enemy("深淵の王", 200, [_move(P, 6), _move(A, 18), _move(H, 20), _move(A, 26)], E.DARK, true),
	]

# --- floor1 の固定エンカウント -----------------------------------------------

## 名前から雑魚データを引く（見つからなければ先頭）。
static func zako_by_name(n: String) -> Dictionary:
	for e in zako_pool():
		if e["name"] == n:
			return e
	return zako_pool()[0]

## floor1 専用の敵セット（10パターン）。導入なので弱めの1〜2体に絞る。
static func floor1_sets() -> Array:
	return [
		["ゴブリン"],                  # 1) 最弱の導入
		["大コウモリ"],                # 2) 手数だが脆い
		["スケルトン"],                # 3) 攻撃寄り
		["ウィスプ"],                  # 4) 光・強化持ち
		["マッドスライム"],            # 5) 防御寄りのタンク
		["ゴブリン", "ゴブリン"],       # 6) 数で攻める
		["インプ", "大コウモリ"],       # 7) 速攻ペア
		["毒蛇", "ゴブリン"],           # 8) 毒に注意
		["スケルトン", "大コウモリ"],   # 9) 攻撃ペア
		["サラマンダー"],              # 10) 単体だが火力高め
	]

static func random_floor1_zako() -> Array:
	var names: Array = floor1_sets().pick_random()
	var group: Array = []
	for n in names:
		group.append(zako_by_name(String(n)))
	return group

# --- ランダム取得 -----------------------------------------------------------

static func random_zako() -> Dictionary:
	return zako_pool().pick_random()

static func random_elite() -> Dictionary:
	return elite_pool().pick_random()

static func random_boss() -> Dictionary:
	return boss_pool().pick_random()
