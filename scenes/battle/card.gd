class_name CardUI
extends PanelContainer

## 手札に並ぶ魔物カード1枚のUI。
## battle_manager が data をセットしてから add_child することで _ready で描画する。
## 表示は data の現在の成長段階に応じた実効値（effective_*）を反映する。

signal command_selected(card: CardUI, command: CommandData)
## 合体候補としての選択トグル（成体のみ選択可能）。
signal fusion_toggled(card: CardUI)

var data: MonsterData
## このバトルの敵の属性（相性表示用）。battle_manager がセットする。
var enemy_element: int = MonsterData.Element.NONE

var _command_buttons: Array[Button] = []
var _select_button: Button
var _selected := false

func _ready() -> void:
	custom_minimum_size = Vector2(190, 300)
	if data != null:
		_build()

func _build() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "%s %s %s" % [data.rarity_label(), data.monster_name, data.stage_label()]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title)

	var stats := Label.new()
	stats.text = "属性:%s  ATK:%d DEF:%d" % [data.element_label(), data.effective_attack(), data.effective_defense()]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats)

	# EXP バー（次の段階までの進捗）
	var exp_bar := ProgressBar.new()
	exp_bar.max_value = 1.0
	exp_bar.value = data.exp_progress()
	exp_bar.show_percentage = false
	exp_bar.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(exp_bar)

	vbox.add_child(HSeparator.new())

	for cmd in data.commands:
		var btn := Button.new()
		var cost := data.effective_cost(cmd)
		btn.text = "▶ %s  (コスト%d)\n%s" % [cmd.command_name, cost, _command_text(cmd)]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.set_meta("cost", cost)
		btn.pressed.connect(func() -> void: command_selected.emit(self, cmd))
		vbox.add_child(btn)
		_command_buttons.append(btn)

	# 合体候補の選択ボタン（成体のみ有効）
	_select_button = Button.new()
	_select_button.toggle_mode = true
	if data.is_adult():
		_select_button.text = "合体候補にする"
	else:
		_select_button.text = "合体は成体のみ"
		_select_button.disabled = true
	_select_button.pressed.connect(func() -> void: fusion_toggled.emit(self))
	vbox.add_child(_select_button)

## コマンドの効果説明を、現在の段階の実効威力で生成する。
func _command_text(cmd: CommandData) -> String:
	var p := data.effective_power(cmd)
	match cmd.effect:
		CommandData.Effect.DAMAGE:
			return "敵に%dダメージ%s" % [p, _affinity_mark()]
		CommandData.Effect.BUFF_ATK:
			return "このターンの与ダメージ+%d" % p
		CommandData.Effect.DOUBLE_NEXT:
			return "次のダメージを2倍にする"
		CommandData.Effect.HEAL:
			return "HPを%d回復" % p
		CommandData.Effect.GUARD:
			return "ブロック%dを得る" % p
		CommandData.Effect.PIERCE:
			return "防御無視で%dダメージ%s" % [p, _affinity_mark()]
		CommandData.Effect.WEAKEN:
			return "敵の攻撃力-%d" % p
		CommandData.Effect.ENERGY:
			return "エネルギー+%d" % cmd.power
		CommandData.Effect.POISON:
			return "敵に毒%dを付与" % p
		CommandData.Effect.BURN:
			return "敵を%dターン炎上(被ダメ1.5倍)" % cmd.power
		CommandData.Effect.FREEZE:
			return "敵を%d回凍結させる" % cmd.power
		CommandData.Effect.REGEN:
			return "再生%dを得る(毎ターン回復)" % p
	return cmd.description

## 現在の敵に対する属性相性の印。
func _affinity_mark() -> String:
	var aff := MonsterData.affinity(data.elements, enemy_element)
	if aff > 1.0:
		return " ▲有利"
	if aff < 1.0:
		return " ▽不利"
	return ""

## 現在のエネルギーに応じて、払えないコマンドのボタンを無効化する。
func refresh(energy: int) -> void:
	for btn in _command_buttons:
		btn.disabled = int(btn.get_meta("cost")) > energy

## 合体候補としての選択状態を反映する（battle_manager から呼ばれる）。
func set_fusion_selected(value: bool) -> void:
	_selected = value
	if _select_button != null:
		_select_button.button_pressed = value
		_select_button.text = "✔ 合体候補" if value else "合体候補にする"
	modulate = Color(1.0, 0.9, 0.4) if value else Color.WHITE

## 勝敗確定時など、入力を完全に止める。
func disable_all() -> void:
	for btn in _command_buttons:
		btn.disabled = true
	if _select_button != null:
		_select_button.disabled = true
