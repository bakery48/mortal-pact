class_name StatusSet
extends RefCounted

## 状態異常をまとめて管理する。敵・プレイヤー双方が1つずつ持つ。
##  毒(POISON)  ：毎ターン量ぶんHP減少し、1ずつ減衰
##  炎上(BURN)  ：被ダメージ1.5倍（残りターン制）
##  凍結(FREEZE)：行動を回数ぶんスキップ
##  再生(REGEN) ：毎ターン量ぶんHP回復し、1ずつ減衰

enum Status { POISON, BURN, FREEZE, REGEN }

const ICON := {
	Status.POISON: "☠",
	Status.BURN: "🔥",
	Status.FREEZE: "❄",
	Status.REGEN: "💚",
}

var values := {} # Status(int) -> int

func add(s: int, amount: int) -> void:
	values[s] = amount_of(s) + amount

func amount_of(s: int) -> int:
	return int(values.get(s, 0))

func has(s: int) -> bool:
	return amount_of(s) > 0

## ターン開始処理：毒ダメージ・再生回復量を返し、各カウンタを1減らす。
## 戻り値 {"poison": int, "regen": int}
func tick_turn() -> Dictionary:
	var result := {"poison": amount_of(Status.POISON), "regen": amount_of(Status.REGEN)}
	for s in [Status.POISON, Status.REGEN, Status.BURN]:
		if has(s):
			values[s] = amount_of(s) - 1
			if amount_of(s) <= 0:
				values.erase(s)
	return result

## 凍結を1つ消費する。行動をスキップするなら true。
func consume_freeze() -> bool:
	if has(Status.FREEZE):
		values[Status.FREEZE] = amount_of(Status.FREEZE) - 1
		if amount_of(Status.FREEZE) <= 0:
			values.erase(Status.FREEZE)
		return true
	return false

## 被ダメージ倍率（炎上中は1.5倍）。
func damage_multiplier() -> float:
	return 1.5 if has(Status.BURN) else 1.0

## 表示用のアイコン文字列（例：「☠3 🔥2」）。
func label() -> String:
	var parts: Array[String] = []
	for s in [Status.POISON, Status.BURN, Status.FREEZE, Status.REGEN]:
		if has(s):
			parts.append("%s%d" % [ICON[s], amount_of(s)])
	return " ".join(parts)
