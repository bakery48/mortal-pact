class_name EnemyUI
extends PanelContainer

## 敵1体のUI。HPバーと「行動予告（intent）」を表示する。
## battle_manager がプロパティをセットしてから add_child することで _ready で描画する。

var enemy_name: String = "敵"
var max_hp: int = 60
var hp: int = 60
var intent_damage: int = 0

var _name_label: Label
var _intent_label: Label
var _hp_bar: ProgressBar
var _hp_label: Label

func _ready() -> void:
	custom_minimum_size = Vector2(300, 170)
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
	_name_label.text = enemy_name
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
	_hp_bar.custom_minimum_size = Vector2(260, 22)
	vbox.add_child(_hp_bar)

	_hp_label = Label.new()
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_hp_label)

	_update()

func take_damage(amount: int) -> void:
	hp = max(0, hp - amount)
	_update()

## 次の敵ターンの攻撃を予告する。
func set_intent(damage: int) -> void:
	intent_damage = damage
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
		_intent_label.text = "次の行動: ⚔ %d ダメージ" % intent_damage
