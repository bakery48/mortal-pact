class_name SpriteLoader
extends RefCounted

## スプライト読み込みヘルパー。
## assets/sprites/monsters/<モンスター名>.png ・ enemies/<敵名>.png を探す。
## 見つかればテクスチャを返し、無ければ null（呼び出し側が図形でフォールバック）。
## 一度調べた結果はキャッシュする。

const MONSTER_DIR := "res://assets/sprites/monsters/"
const ENEMY_DIR := "res://assets/sprites/enemies/"

static var _cache := {}

static func monster(monster_name: String) -> Texture2D:
	return _load(MONSTER_DIR + monster_name + ".png")

static func enemy(enemy_name: String) -> Texture2D:
	return _load(ENEMY_DIR + enemy_name + ".png")

static func _load(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		var res := load(path)
		if res is Texture2D:
			tex = res
	_cache[path] = tex
	return tex

## 属性ごとのプレースホルダ色（スプライトが無いときの図形色）。
static func element_color(element: int) -> Color:
	match element:
		MonsterData.Element.FIRE: return Color("e0654a")
		MonsterData.Element.WATER: return Color("5ab6e0")
		MonsterData.Element.WIND: return Color("7ad6a0")
		MonsterData.Element.EARTH: return Color("c79a5a")
		MonsterData.Element.LIGHT: return Color("f0d860")
		MonsterData.Element.DARK: return Color("a06ad0")
		_: return Color("8a8398")
