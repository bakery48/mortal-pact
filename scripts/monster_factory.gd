class_name MonsterFactory
extends RefCounted

## 魔物データの生成を担う。
## ・starter_monsters(): リソース欠如時のフォールバック用初期デッキ
## ・fuse(): 成体2体から子孫カードを生成（フェーズ3：合体システム）

static func _cmd(name: String, cost: int, effect: int, power: int, desc: String) -> CommandData:
	var c := CommandData.new()
	c.command_name = name
	c.cost = cost
	c.effect = effect
	c.power = power
	c.description = desc
	return c

static func _monster(name: String, atk: int, def: int, element: int, growth: float, cmds: Array[CommandData]) -> MonsterData:
	var m := MonsterData.new()
	m.monster_name = name
	m.attack = atk
	m.defense = def
	m.stage = MonsterData.Stage.INFANT # 生まれたて（幼体）から育てる
	m.exp = 0.0
	m.growth_speed = growth
	m.elements = [element]
	m.rarity = MonsterData.Rarity.COMMON
	m.commands = cmds
	return m

static func starter_monsters() -> Array[MonsterData]:
	var list: Array[MonsterData] = []

	list.append(_monster("フェンリル", 12, 6, MonsterData.Element.DARK, 1.0, [
		_cmd("噛みつき", 1, CommandData.Effect.DAMAGE, 12, "敵に12ダメージ"),
		_cmd("遠吠え", 2, CommandData.Effect.BUFF_ATK, 4, "このターンの与ダメージ+4"),
		_cmd("狂化", 3, CommandData.Effect.DOUBLE_NEXT, 0, "次のダメージを2倍にする"),
	]))

	list.append(_monster("サラマンダー", 14, 4, MonsterData.Element.FIRE, 1.2, [
		_cmd("火炎の牙", 1, CommandData.Effect.DAMAGE, 9, "敵に9ダメージ"),
		_cmd("業火", 2, CommandData.Effect.DAMAGE, 18, "敵に18ダメージ"),
	]))

	list.append(_monster("ゴーレム", 8, 12, MonsterData.Element.EARTH, 0.8, [
		_cmd("岩石投げ", 1, CommandData.Effect.DAMAGE, 7, "敵に7ダメージ"),
		_cmd("地響き", 2, CommandData.Effect.DAMAGE, 14, "敵に14ダメージ"),
	]))

	list.append(_monster("ウィスプ", 6, 3, MonsterData.Element.LIGHT, 1.1, [
		_cmd("導きの光", 1, CommandData.Effect.BUFF_ATK, 3, "このターンの与ダメージ+3"),
		_cmd("呪いの炎", 2, CommandData.Effect.DAMAGE, 11, "敵に11ダメージ"),
	]))

	list.append(_monster("インプ", 10, 5, MonsterData.Element.FIRE, 1.0, [
		_cmd("引っかき", 1, CommandData.Effect.DAMAGE, 8, "敵に8ダメージ"),
		_cmd("挑発", 1, CommandData.Effect.BUFF_ATK, 2, "このターンの与ダメージ+2"),
	]))

	return list

# --- 合体（子孫生成） -------------------------------------------------------

## 成体2体から子孫カードを生成する。子孫は「生まれたて」の幼体になる。
static func fuse(a: MonsterData, b: MonsterData) -> MonsterData:
	var child := MonsterData.new()
	child.monster_name = a.monster_name.left(2) + b.monster_name.left(2) + "の子"

	# レアリティ：両親の高い方を基準に、確率で1段階上がる。
	var base_rarity: int = maxi(a.rarity, b.rarity)
	var child_rarity: int = base_rarity
	if randf() < 0.3 and base_rarity < MonsterData.Rarity.EPIC:
		child_rarity += 1
	child.rarity = child_rarity

	# ステータス：両親の平均＋レアリティボーナス。
	var rarity_bonus := child_rarity * 2
	child.attack = roundi((a.attack + b.attack) / 2.0) + rarity_bonus
	child.defense = roundi((a.defense + b.defense) / 2.0) + rarity_bonus

	# 成長速度：両親の平均。
	child.growth_speed = (a.growth_speed + b.growth_speed) / 2.0

	# 属性：どちらか一方、または混合。
	child.elements = _inherit_elements(a, b)

	# コマンド：両親のコマンドプールからランダムに継承。
	child.commands = _inherit_commands(a, b)

	# 生まれたて。
	child.stage = MonsterData.Stage.INFANT
	child.exp = 0.0
	return child

static func _inherit_elements(a: MonsterData, b: MonsterData) -> Array[int]:
	var result: Array[int] = []
	if randf() < 0.5:
		# 片親からそのまま継承。
		var src := a if randf() < 0.5 else b
		result.assign(src.elements)
	else:
		# 混合（重複排除・最大2属性）。
		for e in a.elements:
			if e not in result:
				result.append(e)
		for e in b.elements:
			if e not in result and result.size() < 2:
				result.append(e)
	if result.is_empty():
		result.append(MonsterData.Element.NONE)
	return result

static func _inherit_commands(a: MonsterData, b: MonsterData) -> Array[CommandData]:
	var pool: Array[CommandData] = []
	pool.append_array(a.commands)
	pool.append_array(b.commands)
	pool.shuffle()
	var count: int = mini(3, pool.size()) # 子孫は最大3コマンド
	var chosen: Array[CommandData] = []
	for i in range(count):
		# 親と独立させるため複製する。
		chosen.append((pool[i] as CommandData).duplicate(true))
	return chosen
