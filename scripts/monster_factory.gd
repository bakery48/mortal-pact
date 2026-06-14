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

# --- 報酬・ショップ用プール -------------------------------------------------

## 戦闘報酬やショップで提示する魔物候補（毎回新しい幼体インスタンスを返す）。
static func reward_pool() -> Array[MonsterData]:
	var list: Array[MonsterData] = []

	list.append(_monster("ハーピー", 11, 4, MonsterData.Element.WIND, 1.2, [
		_cmd("旋風爪", 1, CommandData.Effect.DAMAGE, 10, "敵に10ダメージ"),
		_cmd("追い風", 2, CommandData.Effect.BUFF_ATK, 5, "このターンの与ダメージ+5"),
	]))
	list.append(_monster("ケルベロス", 16, 7, MonsterData.Element.DARK, 0.9, [
		_cmd("三連牙", 1, CommandData.Effect.DAMAGE, 13, "敵に13ダメージ"),
		_cmd("獄炎", 3, CommandData.Effect.DAMAGE, 24, "敵に24ダメージ"),
	]))
	list.append(_monster("ユニコーン", 9, 8, MonsterData.Element.LIGHT, 1.0, [
		_cmd("聖なる角", 1, CommandData.Effect.DAMAGE, 9, "敵に9ダメージ"),
		_cmd("加護", 2, CommandData.Effect.BUFF_ATK, 6, "このターンの与ダメージ+6"),
	]))
	list.append(_monster("リッチ", 13, 3, MonsterData.Element.DARK, 1.1, [
		_cmd("呪詛", 1, CommandData.Effect.DAMAGE, 11, "敵に11ダメージ"),
		_cmd("死の宣告", 3, CommandData.Effect.DOUBLE_NEXT, 0, "次のダメージを2倍にする"),
	]))
	list.append(_monster("アイススピリット", 10, 6, MonsterData.Element.ICE, 1.0, [
		_cmd("氷礫", 1, CommandData.Effect.DAMAGE, 10, "敵に10ダメージ"),
		_cmd("吹雪", 2, CommandData.Effect.DAMAGE, 16, "敵に16ダメージ"),
	]))
	list.append(_monster("スライム", 7, 7, MonsterData.Element.NONE, 1.3, [
		_cmd("体当たり", 1, CommandData.Effect.DAMAGE, 8, "敵に8ダメージ"),
		_cmd("分裂の構え", 1, CommandData.Effect.BUFF_ATK, 3, "このターンの与ダメージ+3"),
	]))
	list.append(_monster("ドライアド", 8, 9, MonsterData.Element.EARTH, 1.0, [
		_cmd("蔦縛り", 1, CommandData.Effect.DAMAGE, 8, "敵に8ダメージ"),
		_cmd("生命の歌", 2, CommandData.Effect.BUFF_ATK, 5, "このターンの与ダメージ+5"),
	]))
	list.append(_monster("ワイバーン", 15, 5, MonsterData.Element.WIND, 1.0, [
		_cmd("急降下", 1, CommandData.Effect.DAMAGE, 12, "敵に12ダメージ"),
		_cmd("竜巻", 2, CommandData.Effect.DAMAGE, 19, "敵に19ダメージ"),
	]))
	list.append(_monster("バンシー", 12, 3, MonsterData.Element.DARK, 1.2, [
		_cmd("怨嗟の叫び", 1, CommandData.Effect.DAMAGE, 11, "敵に11ダメージ"),
		_cmd("絶望", 2, CommandData.Effect.DAMAGE, 17, "敵に17ダメージ"),
	]))
	list.append(_monster("ゴーストファイア", 11, 2, MonsterData.Element.FIRE, 1.3, [
		_cmd("鬼火", 1, CommandData.Effect.DAMAGE, 10, "敵に10ダメージ"),
		_cmd("焼尽", 3, CommandData.Effect.DOUBLE_NEXT, 0, "次のダメージを2倍にする"),
	]))
	list.append(_monster("トレント", 6, 14, MonsterData.Element.EARTH, 0.8, [
		_cmd("枝打ち", 1, CommandData.Effect.DAMAGE, 7, "敵に7ダメージ"),
		_cmd("大地の怒り", 2, CommandData.Effect.DAMAGE, 15, "敵に15ダメージ"),
	]))
	list.append(_monster("グリフォン", 14, 8, MonsterData.Element.WIND, 0.9, [
		_cmd("鉤爪", 1, CommandData.Effect.DAMAGE, 12, "敵に12ダメージ"),
		_cmd("天翔ける", 2, CommandData.Effect.BUFF_ATK, 6, "このターンの与ダメージ+6"),
	]))
	list.append(_monster("サキュバス", 11, 5, MonsterData.Element.DARK, 1.1, [
		_cmd("魅了", 1, CommandData.Effect.BUFF_ATK, 5, "このターンの与ダメージ+5"),
		_cmd("精気吸収", 2, CommandData.Effect.DAMAGE, 14, "敵に14ダメージ"),
	]))
	list.append(_monster("フェニックス", 13, 6, MonsterData.Element.FIRE, 1.0, [
		_cmd("火の翼", 1, CommandData.Effect.DAMAGE, 11, "敵に11ダメージ"),
		_cmd("再生の焔", 3, CommandData.Effect.DOUBLE_NEXT, 0, "次のダメージを2倍にする"),
	]))
	list.append(_monster("クラーケン", 17, 9, MonsterData.Element.ICE, 0.8, [
		_cmd("触手", 1, CommandData.Effect.DAMAGE, 13, "敵に13ダメージ"),
		_cmd("大渦", 3, CommandData.Effect.DAMAGE, 26, "敵に26ダメージ"),
	]))
	list.append(_monster("ミノタウロス", 16, 7, MonsterData.Element.EARTH, 0.9, [
		_cmd("突進", 1, CommandData.Effect.DAMAGE, 13, "敵に13ダメージ"),
		_cmd("斧叩き", 2, CommandData.Effect.DAMAGE, 20, "敵に20ダメージ"),
	]))
	list.append(_monster("ピクシー", 5, 4, MonsterData.Element.LIGHT, 1.4, [
		_cmd("妖精の粉", 1, CommandData.Effect.BUFF_ATK, 4, "このターンの与ダメージ+4"),
		_cmd("光の矢", 1, CommandData.Effect.DAMAGE, 8, "敵に8ダメージ"),
	]))
	list.append(_monster("ヴァンパイア", 14, 6, MonsterData.Element.DARK, 1.0, [
		_cmd("牙", 1, CommandData.Effect.DAMAGE, 12, "敵に12ダメージ"),
		_cmd("血の宴", 2, CommandData.Effect.DAMAGE, 18, "敵に18ダメージ"),
	]))
	list.append(_monster("サンダーバード", 15, 4, MonsterData.Element.WIND, 1.1, [
		_cmd("電撃", 1, CommandData.Effect.DAMAGE, 12, "敵に12ダメージ"),
		_cmd("雷鳴", 2, CommandData.Effect.DAMAGE, 19, "敵に19ダメージ"),
	]))
	list.append(_monster("マーメイド", 9, 7, MonsterData.Element.ICE, 1.1, [
		_cmd("水鞭", 1, CommandData.Effect.DAMAGE, 9, "敵に9ダメージ"),
		_cmd("癒やしの歌", 2, CommandData.Effect.BUFF_ATK, 6, "このターンの与ダメージ+6"),
	]))
	list.append(_monster("デーモン", 18, 5, MonsterData.Element.FIRE, 0.8, [
		_cmd("地獄爪", 1, CommandData.Effect.DAMAGE, 14, "敵に14ダメージ"),
		_cmd("業炎弾", 3, CommandData.Effect.DAMAGE, 28, "敵に28ダメージ"),
	]))
	list.append(_monster("ホーリーナイト", 12, 11, MonsterData.Element.LIGHT, 0.9, [
		_cmd("聖剣", 1, CommandData.Effect.DAMAGE, 11, "敵に11ダメージ"),
		_cmd("聖騎士の誓い", 2, CommandData.Effect.BUFF_ATK, 7, "このターンの与ダメージ+7"),
	]))

	# --- 役割特化（新コマンド効果）---
	list.append(_monster("ヒーラースライム", 6, 6, MonsterData.Element.LIGHT, 1.2, [
		_cmd("癒やしの粘液", 1, CommandData.Effect.HEAL, 8, "HPを8回復"),
		_cmd("体当たり", 1, CommandData.Effect.DAMAGE, 7, "敵に7ダメージ"),
	]))
	list.append(_monster("守護騎士", 9, 13, MonsterData.Element.EARTH, 0.8, [
		_cmd("盾構え", 1, CommandData.Effect.GUARD, 9, "ブロック9を得る"),
		_cmd("シールドバッシュ", 2, CommandData.Effect.DAMAGE, 13, "敵に13ダメージ"),
	]))
	list.append(_monster("アサシン", 15, 3, MonsterData.Element.DARK, 1.1, [
		_cmd("背後刺し", 1, CommandData.Effect.PIERCE, 11, "防御無視で11ダメージ"),
		_cmd("毒刃", 2, CommandData.Effect.PIERCE, 17, "防御無視で17ダメージ"),
	]))
	list.append(_monster("妖術師", 10, 5, MonsterData.Element.DARK, 1.0, [
		_cmd("呪いの目", 1, CommandData.Effect.WEAKEN, 5, "敵の攻撃力-5"),
		_cmd("闇の波動", 2, CommandData.Effect.DAMAGE, 14, "敵に14ダメージ"),
	]))
	list.append(_monster("マナイーター", 8, 4, MonsterData.Element.NONE, 1.1, [
		_cmd("魔力吸収", 1, CommandData.Effect.ENERGY, 2, "エネルギー+2"),
		_cmd("噛みつき", 1, CommandData.Effect.DAMAGE, 8, "敵に8ダメージ"),
	]))
	list.append(_monster("プリーステス", 7, 7, MonsterData.Element.LIGHT, 1.0, [
		_cmd("祈り", 1, CommandData.Effect.HEAL, 10, "HPを10回復"),
		_cmd("聖なる加護", 2, CommandData.Effect.BUFF_ATK, 6, "このターンの与ダメージ+6"),
	]))
	list.append(_monster("ストーンガード", 5, 16, MonsterData.Element.EARTH, 0.7, [
		_cmd("岩の壁", 1, CommandData.Effect.GUARD, 11, "ブロック11を得る"),
		_cmd("圧殺", 2, CommandData.Effect.DAMAGE, 12, "敵に12ダメージ"),
	]))
	list.append(_monster("シャドウ", 13, 4, MonsterData.Element.DARK, 1.2, [
		_cmd("影縫い", 1, CommandData.Effect.PIERCE, 10, "防御無視で10ダメージ"),
		_cmd("闇討ち", 2, CommandData.Effect.DAMAGE, 16, "敵に16ダメージ"),
	]))
	list.append(_monster("氷壁の精", 6, 12, MonsterData.Element.ICE, 0.9, [
		_cmd("氷の盾", 1, CommandData.Effect.GUARD, 10, "ブロック10を得る"),
		_cmd("凍てつく息", 2, CommandData.Effect.WEAKEN, 6, "敵の攻撃力-6"),
	]))
	list.append(_monster("バーサーカー", 17, 4, MonsterData.Element.FIRE, 0.9, [
		_cmd("乱打", 1, CommandData.Effect.DAMAGE, 12, "敵に12ダメージ"),
		_cmd("戦いの咆哮", 1, CommandData.Effect.ENERGY, 2, "エネルギー+2"),
	]))
	list.append(_monster("ドルイド", 9, 8, MonsterData.Element.EARTH, 1.0, [
		_cmd("自然の恵み", 1, CommandData.Effect.HEAL, 9, "HPを9回復"),
		_cmd("茨の鞭", 2, CommandData.Effect.DAMAGE, 14, "敵に14ダメージ"),
	]))
	list.append(_monster("雷神", 16, 5, MonsterData.Element.WIND, 0.9, [
		_cmd("裁きの雷", 1, CommandData.Effect.PIERCE, 12, "防御無視で12ダメージ"),
		_cmd("雷鳴", 2, CommandData.Effect.DAMAGE, 18, "敵に18ダメージ"),
	]))
	list.append(_monster("ヴァルキリー", 13, 9, MonsterData.Element.LIGHT, 1.0, [
		_cmd("聖槍", 1, CommandData.Effect.DAMAGE, 12, "敵に12ダメージ"),
		_cmd("天盾", 1, CommandData.Effect.GUARD, 8, "ブロック8を得る"),
	]))
	list.append(_monster("呪術師", 8, 6, MonsterData.Element.DARK, 1.1, [
		_cmd("衰弱の呪い", 1, CommandData.Effect.WEAKEN, 6, "敵の攻撃力-6"),
		_cmd("骨の槍", 1, CommandData.Effect.DAMAGE, 9, "敵に9ダメージ"),
	]))
	list.append(_monster("錬金術師", 7, 6, MonsterData.Element.NONE, 1.0, [
		_cmd("触媒生成", 1, CommandData.Effect.ENERGY, 2, "エネルギー+2"),
		_cmd("治癒薬", 2, CommandData.Effect.HEAL, 12, "HPを12回復"),
	]))
	list.append(_monster("タイタン", 14, 14, MonsterData.Element.EARTH, 0.7, [
		_cmd("大地割り", 2, CommandData.Effect.DAMAGE, 20, "敵に20ダメージ"),
		_cmd("巨壁", 1, CommandData.Effect.GUARD, 12, "ブロック12を得る"),
	]))
	list.append(_monster("セイレーン", 10, 6, MonsterData.Element.ICE, 1.1, [
		_cmd("惑わしの歌", 1, CommandData.Effect.WEAKEN, 5, "敵の攻撃力-5"),
		_cmd("水流弾", 2, CommandData.Effect.DAMAGE, 15, "敵に15ダメージ"),
	]))
	list.append(_monster("グリモワール", 6, 5, MonsterData.Element.NONE, 1.2, [
		_cmd("詠唱", 1, CommandData.Effect.ENERGY, 2, "エネルギー+2"),
		_cmd("禁呪", 3, CommandData.Effect.DOUBLE_NEXT, 0, "次のダメージを2倍にする"),
	]))

	# --- 状態異常特化 ---
	list.append(_monster("バジリスク", 11, 5, MonsterData.Element.DARK, 1.0, [
		_cmd("猛毒の牙", 1, CommandData.Effect.POISON, 4, "敵に毒4を付与"),
		_cmd("石化の眼", 2, CommandData.Effect.DAMAGE, 13, "敵に13ダメージ"),
	]))
	list.append(_monster("毒沼の主", 9, 9, MonsterData.Element.EARTH, 0.9, [
		_cmd("汚泥", 1, CommandData.Effect.POISON, 3, "敵に毒3を付与"),
		_cmd("飲み込む", 2, CommandData.Effect.DAMAGE, 14, "敵に14ダメージ"),
	]))
	list.append(_monster("イグニス", 13, 4, MonsterData.Element.FIRE, 1.1, [
		_cmd("発火", 1, CommandData.Effect.BURN, 2, "敵を2ターン炎上"),
		_cmd("火炎弾", 2, CommandData.Effect.DAMAGE, 15, "敵に15ダメージ"),
	]))
	list.append(_monster("フロストゴーレム", 8, 13, MonsterData.Element.ICE, 0.8, [
		_cmd("絶対零度", 2, CommandData.Effect.FREEZE, 1, "敵を1回凍結"),
		_cmd("氷塊", 1, CommandData.Effect.DAMAGE, 9, "敵に9ダメージ"),
	]))
	list.append(_monster("世界樹の苗", 5, 8, MonsterData.Element.LIGHT, 1.2, [
		_cmd("芽吹き", 1, CommandData.Effect.REGEN, 4, "再生4を得る"),
		_cmd("癒やしの光", 2, CommandData.Effect.HEAL, 12, "HPを12回復"),
	]))
	list.append(_monster("コカトリス", 12, 5, MonsterData.Element.WIND, 1.0, [
		_cmd("毒の翼", 1, CommandData.Effect.POISON, 3, "敵に毒3を付与"),
		_cmd("つつき", 1, CommandData.Effect.DAMAGE, 9, "敵に9ダメージ"),
	]))

	return list

## プールからランダムに count 体を選んで返す。
static func random_rewards(count: int) -> Array[MonsterData]:
	var pool := reward_pool()
	pool.shuffle()
	var result: Array[MonsterData] = []
	for i in range(mini(count, pool.size())):
		result.append(pool[i])
	return result

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
