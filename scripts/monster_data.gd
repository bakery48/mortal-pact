class_name MonsterData
extends Resource

## 1枚の魔物カードのデータ兼ライフサイクル状態。
## ドロー時に duplicate されるため、各カードが独立して成長・老化する。
##
## 成長は使用ごとに蓄積する EXP で進行する：
##   幼体 → 若体 → 成体（ピーク）→ 老体 → 消滅
## ピークを過ぎると弱体化し、老体はコスト増・効果減、消滅でデッキから除外される。
##
## 成体2体を合体させると、属性・コマンド・成長速度・レアリティを継承した
## 子孫カードが生まれる（MonsterFactory.fuse 参照）。

enum Stage { INFANT, YOUNG, ADULT, ELDER, DEAD }
enum Element { NONE, FIRE, WATER, WIND, EARTH, LIGHT, DARK }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC }

## 属性相性の「勝つ」関係（4すくみ）：水>炎>風>土>水。
const ELEMENT_BEATS := {
	Element.WATER: Element.FIRE,
	Element.FIRE: Element.WIND,
	Element.WIND: Element.EARTH,
	Element.EARTH: Element.WATER,
}
const AFFINITY_ADVANTAGE := 1.5
const AFFINITY_DISADVANTAGE := 0.75

## 各段階に到達するのに必要な累計 EXP（この値以上で当該段階）。
const STAGE_THRESHOLDS := {
	Stage.INFANT: 0,
	Stage.YOUNG: 2,
	Stage.ADULT: 4,
	Stage.ELDER: 7,
	Stage.DEAD: 10,
}

## 段階ごとの能力倍率（ATK/DEF とコマンド威力に共通で適用）。
const STAGE_MULT := {
	Stage.INFANT: 0.6,
	Stage.YOUNG: 0.8,
	Stage.ADULT: 1.0,
	Stage.ELDER: 0.55,
	Stage.DEAD: 0.0,
}

## 段階ごとのコスト補正（最終コストは最低1にクランプ）。
const STAGE_COST_DELTA := {
	Stage.INFANT: -1, # 幼体はコスト安め
	Stage.YOUNG: 0,
	Stage.ADULT: 0,
	Stage.ELDER: 1,   # 老体はコスト増
	Stage.DEAD: 0,
}

const STAGE_LABEL := {
	Stage.INFANT: "🥚幼体",
	Stage.YOUNG: "🌱若体",
	Stage.ADULT: "⚔️成体",
	Stage.ELDER: "🍂老体",
	Stage.DEAD: "💀消滅",
}

const ELEMENT_LABEL := {
	Element.NONE: "無",
	Element.FIRE: "炎",
	Element.WATER: "水",
	Element.WIND: "風",
	Element.EARTH: "土",
	Element.LIGHT: "光",
	Element.DARK: "闇",
}

const RARITY_LABEL := {
	Rarity.COMMON: "★",
	Rarity.UNCOMMON: "★★",
	Rarity.RARE: "★★★",
	Rarity.EPIC: "★★★★",
}

@export var monster_name: String = "魔物"
## 基礎 ATK/DEF。実値は段階倍率を掛けた effective_* を使う。
@export var attack: int = 10
@export var defense: int = 5
@export var stage: Stage = Stage.INFANT
## 蓄積経験値。使用ごとに growth_speed 分だけ加算され、段階移行のトリガーになる。
@export var exp: float = 0.0
## 1回の使用で得る EXP 量（=成長速度）。合体時は両親の平均を引き継ぐ。
@export var growth_speed: float = 1.0
## 属性（複数持つことがある）。Element の値を格納する。
@export var elements: Array[int] = [Element.NONE]
@export var rarity: Rarity = Rarity.COMMON
@export var commands: Array[CommandData] = []

# --- ライフサイクル ---------------------------------------------------------

## EXP を加算し段階を更新する。段階が変化したら true を返す。
func gain_exp(amount: float) -> bool:
	var before := stage
	exp += amount
	_update_stage()
	return stage != before

func _update_stage() -> void:
	var new_stage := Stage.INFANT
	for s in [Stage.INFANT, Stage.YOUNG, Stage.ADULT, Stage.ELDER, Stage.DEAD]:
		if exp >= float(STAGE_THRESHOLDS[s]):
			new_stage = s
	stage = new_stage

func is_dead() -> bool:
	return stage == Stage.DEAD

## 合体の親に選べる段階（成体・老体）。
func can_fuse() -> bool:
	return stage == Stage.ADULT or stage == Stage.ELDER

func stage_label() -> String:
	return String(STAGE_LABEL[stage])

func rarity_label() -> String:
	return String(RARITY_LABEL[rarity])

## 属性をまとめた表示文字列（例：「炎/水」）。
func element_label() -> String:
	var parts: Array[String] = []
	for e in elements:
		parts.append(String(ELEMENT_LABEL[e]))
	return "/".join(parts)

## 攻撃属性1つ vs 防御属性1つの相性倍率。
static func element_pair_multiplier(atk: int, dfn: int) -> float:
	if atk == Element.NONE or dfn == Element.NONE:
		return 1.0
	# 光⇔闇は相互弱点（双方が有利）。
	if (atk == Element.LIGHT and dfn == Element.DARK) or (atk == Element.DARK and dfn == Element.LIGHT):
		return AFFINITY_ADVANTAGE
	if int(ELEMENT_BEATS.get(atk, -1)) == dfn:
		return AFFINITY_ADVANTAGE
	if int(ELEMENT_BEATS.get(dfn, -1)) == atk:
		return AFFINITY_DISADVANTAGE
	return 1.0

## 攻撃側の全属性 vs 防御属性の相性倍率（有利優先、次に不利）。
static func affinity(attacker_elements: Array, defender_element: int) -> float:
	var advantage := false
	var disadvantage := false
	for e in attacker_elements:
		var m := element_pair_multiplier(int(e), defender_element)
		if m > 1.0:
			advantage = true
		elif m < 1.0:
			disadvantage = true
	if advantage:
		return AFFINITY_ADVANTAGE
	if disadvantage:
		return AFFINITY_DISADVANTAGE
	return 1.0

# --- セーブ/ロード用シリアライズ -------------------------------------------

func to_dict() -> Dictionary:
	var cmds: Array = []
	for c in commands:
		cmds.append(c.to_dict())
	return {
		"monster_name": monster_name,
		"attack": attack,
		"defense": defense,
		"stage": int(stage),
		"exp": exp,
		"growth_speed": growth_speed,
		"elements": elements.duplicate(),
		"rarity": int(rarity),
		"commands": cmds,
	}

static func from_dict(d: Dictionary) -> MonsterData:
	var m := MonsterData.new()
	m.monster_name = String(d.get("monster_name", "魔物"))
	m.attack = int(d.get("attack", 10))
	m.defense = int(d.get("defense", 5))
	m.stage = int(d.get("stage", 0)) as Stage
	m.exp = float(d.get("exp", 0.0))
	m.growth_speed = float(d.get("growth_speed", 1.0))
	var els: Array[int] = []
	for e in d.get("elements", []):
		els.append(int(e))
	if els.is_empty():
		els.append(Element.NONE)
	m.elements = els
	m.rarity = int(d.get("rarity", 0)) as Rarity
	var cmds: Array[CommandData] = []
	for cd in d.get("commands", []):
		cmds.append(CommandData.from_dict(cd))
	m.commands = cmds
	return m

## 報酬・ショップ画面用の概要テキスト（基礎ステータスを表示）。
func summary() -> String:
	var text := "%s %s %s\n属性:%s  ATK:%d DEF:%d  成長:%.1f" % [
		rarity_label(), monster_name, stage_label(),
		element_label(), attack, defense, growth_speed,
	]
	for c in commands:
		text += "\n・%s (コスト%d)" % [c.command_name, c.cost]
	return text

# --- 段階補正を反映した実効値 ----------------------------------------------

func _mult() -> float:
	return float(STAGE_MULT[stage])

func effective_attack() -> int:
	return roundi(attack * _mult())

func effective_defense() -> int:
	return roundi(defense * _mult())

func effective_cost(cmd: CommandData) -> int:
	return clampi(cmd.cost + int(STAGE_COST_DELTA[stage]), 1, 99)

func effective_power(cmd: CommandData) -> int:
	return max(0, roundi(cmd.power * _mult()))

## コマンドのステータス依存係数。負なら自動（コストが高い技ほど依存大）。
func _stat_scale(cmd: CommandData) -> float:
	if cmd.stat_scale >= 0.0:
		return cmd.stat_scale
	return clampf(0.4 + 0.3 * float(cmd.cost - 1), 0.4, 1.0)

## ダメージ系コマンドに上乗せされる ATK 由来ボーナス。
func damage_bonus(cmd: CommandData) -> int:
	return roundi(effective_attack() * _stat_scale(cmd))

## ガード系コマンドに上乗せされる DEF 由来ボーナス。
func guard_bonus(cmd: CommandData) -> int:
	return roundi(effective_defense() * _stat_scale(cmd))

## コマンドの実効値（威力＋ステータス補正）を効果種別に応じて返す。
func command_value(cmd: CommandData) -> int:
	match cmd.effect:
		CommandData.Effect.DAMAGE, CommandData.Effect.PIERCE:
			return effective_power(cmd) + damage_bonus(cmd)
		CommandData.Effect.GUARD:
			return effective_power(cmd) + guard_bonus(cmd)
		CommandData.Effect.ENERGY:
			return cmd.power # エネルギーは段階・ステータス補正なし
		_:
			return effective_power(cmd)

# --- EXP バー表示用 ---------------------------------------------------------

func _next_stage() -> Stage:
	if stage == Stage.DEAD:
		return Stage.DEAD
	return (stage + 1) as Stage

## 現段階から次段階までの進捗（0.0〜1.0）。消滅時は 1.0。
func exp_progress() -> float:
	var nxt := _next_stage()
	if nxt == stage:
		return 1.0
	var cur_thr := float(STAGE_THRESHOLDS[stage])
	var next_thr := float(STAGE_THRESHOLDS[nxt])
	if next_thr <= cur_thr:
		return 1.0
	return clampf((exp - cur_thr) / (next_thr - cur_thr), 0.0, 1.0)
