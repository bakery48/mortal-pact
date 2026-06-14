class_name EnemyDatabase
extends RefCounted

## 敵のカタログ。種別ごとのプールからランダムに敵を提供する。
## 各敵は名前・最大HP・行動パターンを持つ。パターンは EnemyUI.Intent で定義。

static func _move(type: int, value: int) -> Dictionary:
	return {"type": type, "value": value}

static func _enemy(enemy_name: String, hp: int, pattern: Array, is_boss := false) -> Dictionary:
	return {"name": enemy_name, "max_hp": hp, "pattern": pattern, "is_boss": is_boss}

# --- 雑魚 -------------------------------------------------------------------

static func zako_pool() -> Array:
	var A := EnemyUI.Intent.ATTACK
	var D := EnemyUI.Intent.DEFEND
	var B := EnemyUI.Intent.BUFF
	var P := EnemyUI.Intent.POISON
	return [
		_enemy("ゴブリン", 44, [_move(A, 8), _move(A, 6), _move(D, 6)]),
		_enemy("スケルトン", 50, [_move(A, 7), _move(A, 10)]),
		_enemy("大コウモリ", 38, [_move(A, 6), _move(A, 6), _move(A, 9)]),
		_enemy("ホブゴブリン", 56, [_move(A, 9), _move(B, 3), _move(A, 11)]),
		_enemy("マッドスライム", 60, [_move(D, 8), _move(A, 7)]),
		_enemy("インプの群れ", 46, [_move(A, 5), _move(A, 5), _move(A, 8)]),
		_enemy("毒蛇", 42, [_move(P, 3), _move(A, 7), _move(A, 9)]),
	]

# --- エリート ---------------------------------------------------------------

static func elite_pool() -> Array:
	var A := EnemyUI.Intent.ATTACK
	var D := EnemyUI.Intent.DEFEND
	var B := EnemyUI.Intent.BUFF
	var H := EnemyUI.Intent.HEAL
	var P := EnemyUI.Intent.POISON
	return [
		_enemy("オーガ", 88, [_move(A, 13), _move(B, 4), _move(A, 18)]),
		_enemy("闇の魔女", 80, [_move(A, 10), _move(H, 14), _move(A, 14)]),
		_enemy("ガーゴイル", 95, [_move(D, 12), _move(A, 15), _move(A, 9)]),
		_enemy("地獄の番犬", 84, [_move(A, 12), _move(A, 12), _move(B, 5)]),
		_enemy("邪毒の妖蛆", 78, [_move(P, 5), _move(A, 11), _move(D, 10)]),
	]

# --- ボス -------------------------------------------------------------------

static func boss_pool() -> Array:
	var A := EnemyUI.Intent.ATTACK
	var D := EnemyUI.Intent.DEFEND
	var B := EnemyUI.Intent.BUFF
	var H := EnemyUI.Intent.HEAL
	var P := EnemyUI.Intent.POISON
	return [
		_enemy("死の騎士", 150, [_move(A, 16), _move(D, 12), _move(A, 24), _move(B, 4)], true),
		_enemy("双頭の竜", 175, [_move(A, 14), _move(A, 14), _move(B, 6), _move(A, 28)], true),
		_enemy("深淵の王", 200, [_move(P, 6), _move(A, 18), _move(H, 20), _move(A, 26)], true),
	]

# --- ランダム取得 -----------------------------------------------------------

static func random_zako() -> Dictionary:
	return zako_pool().pick_random()

static func random_elite() -> Dictionary:
	return elite_pool().pick_random()

static func random_boss() -> Dictionary:
	return boss_pool().pick_random()
