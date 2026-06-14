class_name MonsterFactory
extends RefCounted

## 魔物データをコードから生成するフォールバック用ファクトリ。
## 通常は res://resources/monsters/*.tres を読み込むが、
## リソースが見つからない場合（最小構成での起動など）に
## ここで定義した初期デッキを使う。両者の内容は一致させること。

static func _cmd(name: String, cost: int, effect: int, power: int, desc: String) -> CommandData:
	var c := CommandData.new()
	c.command_name = name
	c.cost = cost
	c.effect = effect
	c.power = power
	c.description = desc
	return c

static func _monster(name: String, atk: int, def: int, cmds: Array[CommandData]) -> MonsterData:
	var m := MonsterData.new()
	m.monster_name = name
	m.attack = atk
	m.defense = def
	m.stage = MonsterData.Stage.INFANT # 生まれたて（幼体）から育てる
	m.exp = 0
	m.commands = cmds
	return m

static func starter_monsters() -> Array[MonsterData]:
	var list: Array[MonsterData] = []

	list.append(_monster("フェンリル", 12, 6, [
		_cmd("噛みつき", 1, CommandData.Effect.DAMAGE, 12, "敵に12ダメージ"),
		_cmd("遠吠え", 2, CommandData.Effect.BUFF_ATK, 4, "このターンの与ダメージ+4"),
		_cmd("狂化", 3, CommandData.Effect.DOUBLE_NEXT, 0, "次のダメージを2倍にする"),
	]))

	list.append(_monster("サラマンダー", 14, 4, [
		_cmd("火炎の牙", 1, CommandData.Effect.DAMAGE, 9, "敵に9ダメージ"),
		_cmd("業火", 2, CommandData.Effect.DAMAGE, 18, "敵に18ダメージ"),
	]))

	list.append(_monster("ゴーレム", 8, 12, [
		_cmd("岩石投げ", 1, CommandData.Effect.DAMAGE, 7, "敵に7ダメージ"),
		_cmd("地響き", 2, CommandData.Effect.DAMAGE, 14, "敵に14ダメージ"),
	]))

	list.append(_monster("ウィスプ", 6, 3, [
		_cmd("導きの光", 1, CommandData.Effect.BUFF_ATK, 3, "このターンの与ダメージ+3"),
		_cmd("呪いの炎", 2, CommandData.Effect.DAMAGE, 11, "敵に11ダメージ"),
	]))

	list.append(_monster("インプ", 10, 5, [
		_cmd("引っかき", 1, CommandData.Effect.DAMAGE, 8, "敵に8ダメージ"),
		_cmd("挑発", 1, CommandData.Effect.BUFF_ATK, 2, "このターンの与ダメージ+2"),
	]))

	return list
