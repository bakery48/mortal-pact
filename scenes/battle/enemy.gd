class_name EnemyUI
extends PanelContainer

## 敵1体のUI兼簡易AI。
## 行動パターン（pattern）を順に実行し、次の行動を「予告（intent）」として表示する。
## 行動種別：攻撃 / 防御（ブロック獲得）/ 強化（攻撃力上昇）/ 回復。

enum Intent { ATTACK, DEFEND, BUFF, HEAL, POISON }

const INTENT_ICON := {
	Intent.ATTACK: "⚔",
	Intent.DEFEND: "🛡",
	Intent.BUFF: "💪",
	Intent.HEAL: "✚",
	Intent.POISON: "☠",
}

var enemy_name: String = "敵"
var element: int = MonsterData.Element.NONE
var max_hp: int = 60
var hp: int = 60
var block: int = 0
var attack_bonus: int = 0
var status := StatusSet.new()

## 行動パターン（Dictionary の配列）。各要素は {"type": Intent, "value": int}。
var pattern: Array = []
var _pattern_index: int = 0

var intent_type: Intent = Intent.ATTACK
var intent_value: int = 0

var _name_label: Label
var _intent_label: Label
var _hp_bar: ProgressBar
var _hp_label: Label
var _status_label: Label

func _ready() -> void:
	custom_minimum_size = Vector2(320, 190)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	_name_label = Label.new()
	_name_label.text = "%s 〈%s〉" % [enemy_name, String(MonsterData.ELEMENT_LABEL[element])]
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_name_label)

	_intent_label = Label.new()
	_intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_intent_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(280, 22)
	vbox.add_child(_hp_bar)

	_hp_label = Label.new()
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_hp_label)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_status_label)

	_update()

func set_pattern(p: Array) -> void:
	pattern = p
	_pattern_index = 0

## 次の行動を決めて予告する。
func plan_next() -> void:
	if pattern.is_empty():
		intent_type = Intent.ATTACK
		intent_value = 8
	else:
		var move: Dictionary = pattern[_pattern_index % pattern.size()]
		_pattern_index += 1
		intent_type = int(move["type"]) as Intent
		var base := int(move["value"])
		# 攻撃は現在の攻撃力補正を上乗せして予告する（弱体化で負にもなり得る）。
		intent_value = maxi(0, base + attack_bonus) if intent_type == Intent.ATTACK else base
	_update()

## 予告した行動を実行する。プレイヤーへ与えるダメージを返す（非攻撃なら0）。
func execute() -> int:
	match intent_type:
		Intent.ATTACK:
			return intent_value
		Intent.DEFEND:
			block += intent_value
			_update()
		Intent.BUFF:
			attack_bonus += intent_value
			_update()
		Intent.HEAL:
			hp = mini(max_hp, hp + intent_value)
			_update()
	return 0

## 自ターン開始時にブロックをリセットする。
func reset_block() -> void:
	block = 0
	_update()

func take_damage(amount: int) -> void:
	var remaining := roundi(amount * status.damage_multiplier()) # 炎上中は被ダメ増加
	if block > 0:
		var absorbed := mini(block, remaining)
		block -= absorbed
		remaining -= absorbed
	hp = maxi(0, hp - remaining)
	_update()

## ブロックを無視してダメージを与える（貫通攻撃）。
func take_damage_pierce(amount: int) -> void:
	hp = maxi(0, hp - roundi(amount * status.damage_multiplier()))
	_update()

## 毒など、ブロック・炎上補正を無視する固定ダメージ。
func take_fixed(amount: int) -> void:
	hp = maxi(0, hp - amount)
	_update()

func heal(amount: int) -> void:
	hp = mini(max_hp, hp + amount)
	_update()

func add_status(s: int, amount: int) -> void:
	status.add(s, amount)
	_update()

## 攻撃力を下げる（弱体化）。予告中の攻撃にも即時反映する。
func apply_weaken(amount: int) -> void:
	attack_bonus -= amount
	if intent_type == Intent.ATTACK:
		intent_value = maxi(0, intent_value - amount)
	_update()

func is_dead() -> bool:
	return hp <= 0

func _update() -> void:
	if _hp_bar != null:
		_hp_bar.max_value = max_hp
		_hp_bar.value = hp
	if _hp_label != null:
		_hp_label.text = "HP: %d / %d" % [hp, max_hp]
	if _intent_label != null:
		var icon := String(INTENT_ICON[intent_type])
		match intent_type:
			Intent.ATTACK:
				_intent_label.text = "次の行動: %s %d ダメージ" % [icon, intent_value]
			Intent.DEFEND:
				_intent_label.text = "次の行動: %s 防御 %d" % [icon, intent_value]
			Intent.BUFF:
				_intent_label.text = "次の行動: %s 攻撃力+%d" % [icon, intent_value]
			Intent.HEAL:
				_intent_label.text = "次の行動: %s 回復 %d" % [icon, intent_value]
			Intent.POISON:
				_intent_label.text = "次の行動: %s 毒 %d を付与" % [icon, intent_value]
	if _status_label != null:
		var parts: Array[String] = []
		if block > 0:
			parts.append("🛡%d" % block)
		if attack_bonus > 0:
			parts.append("攻撃+%d" % attack_bonus)
		var st := status.label()
		if st != "":
			parts.append(st)
		_status_label.text = "  ".join(parts)
