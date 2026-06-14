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
enum Element { NONE, FIRE, ICE, WIND, EARTH, LIGHT, DARK }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC }

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
	Element.ICE: "氷",
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

func is_adult() -> bool:
	return stage == Stage.ADULT

func stage_label() -> String:
	return String(STAGE_LABEL[stage])

func rarity_label() -> String:
	return String(RARITY_LABEL[rarity])

## 属性をまとめた表示文字列（例：「炎/氷」）。
func element_label() -> String:
	var parts: Array[String] = []
	for e in elements:
		parts.append(String(ELEMENT_LABEL[e]))
	return "/".join(parts)

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
