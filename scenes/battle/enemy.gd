class_name EnemyUI
extends PanelContainer

## 敵1体のUI兼簡易AI。
## 行動パターン（pattern）を順に実行し、次の行動を「予告（intent）」として表示する。
## 行動種別：攻撃 / 防御（ブロック獲得）/ 強化（攻撃力上昇）/ 回復。

enum Intent { ATTACK, DEFEND, BUFF, HEAL, POISON }

## クリックでターゲットに選ばれたときに発火。
signal targeted(enemy: EnemyUI)

const INTENT_ICON := {
	Intent.ATTACK: "⚔",
	Intent.DEFEND: "🛡",
	Intent.BUFF: "💪",
	Intent.HEAL: "✚",
	Intent.POISON: "☠",
}

var enemy_name: String = "敵"
var sprite_name: String = "" # スプライト探索用の生の敵名（【ボス】等の接頭辞なし）
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
var _target_marker: Label
var _affinity_label: Label

func _ready() -> void:
	custom_minimum_size = Vector2(280, 190)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	_target_marker = Label.new()
	_target_marker.text = "🎯 狙い"
	_target_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_marker.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_target_marker.visible = false
	vbox.add_child(_target_marker)

	_affinity_label = Label.new()
	_affinity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_affinity_label.add_theme_font_size_override("font_size", 20)
	_affinity_label.visible = false
	vbox.add_child(_affinity_label)

	# スプライト（あれば）／無ければ属性色の図形プレースホルダ。
	vbox.add_child(_make_visual())

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

## スプライト or プレースホルダのビジュアルを作る。
func _make_visual() -> Control:
	var tex := SpriteLoader.enemy(sprite_name)
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.custom_minimum_size = Vector2(0, 96)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		return tr
	var box := ColorRect.new()
	box.color = SpriteLoader.element_color(element)
	box.custom_minimum_size = Vector2(0, 82)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_child(cc)
	var l := Label.new()
	l.text = String(MonsterData.ELEMENT_LABEL[element])
	l.add_theme_font_size_override("font_size", 40)
	cc.add_child(l)
	return box

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

func take_damage(amount: int) -> int:
	var remaining := roundi(amount * status.damage_multiplier()) # 炎上中は被ダメ増加
	if block > 0:
		var absorbed := mini(block, remaining)
		block -= absorbed
		remaining -= absorbed
	var before := hp
	hp = maxi(0, hp - remaining)
	_update()
	return before - hp

## ブロックを無視してダメージを与える（貫通攻撃）。
func take_damage_pierce(amount: int) -> int:
	var before := hp
	hp = maxi(0, hp - roundi(amount * status.damage_multiplier()))
	_update()
	return before - hp

## 毒など、ブロック・炎上補正を無視する固定ダメージ。
func take_fixed(amount: int) -> int:
	var before := hp
	hp = maxi(0, hp - amount)
	_update()
	return before - hp

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		targeted.emit(self)

## ターゲット選択状態の表示。
func set_targeted(value: bool) -> void:
	if _target_marker != null:
		_target_marker.visible = value

## 被弾時に赤く点滅する。
func flash_hit() -> void:
	modulate = Color(1.0, 0.45, 0.45)
	var t := create_tween()
	t.tween_property(self, "modulate", Color.WHITE, 0.25)

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

func show_affinity(text: String) -> void:
	if _affinity_label == null:
		return
	if text == "WEAK":
		_affinity_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		_affinity_label.text = "▲ WEAK"
	elif text == "HALF":
		_affinity_label.add_theme_color_override("font_color", Color(0.5, 0.75, 1.0))
		_affinity_label.text = "▽ HALF"
	else:
		_affinity_label.text = ""
	_affinity_label.visible = text != ""

func hide_affinity() -> void:
	if _affinity_label != null:
		_affinity_label.visible = false

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
