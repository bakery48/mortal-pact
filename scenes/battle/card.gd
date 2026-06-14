class_name CardUI
extends PanelContainer

## 手札に並ぶ魔物カード1枚のUI。
## battle_manager が data をセットしてから add_child することで _ready で描画する。
## 表示は data の現在の成長段階に応じた実効値（effective_*）を反映する。

signal command_selected(card: CardUI, command: CommandData)

var data: MonsterData

var _command_buttons: Array[Button] = []

func _ready() -> void:
	custom_minimum_size = Vector2(190, 270)
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
	title.text = "%s %s" % [data.monster_name, data.stage_label()]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var stats := Label.new()
	stats.text = "ATK:%d  DEF:%d" % [data.effective_attack(), data.effective_defense()]
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

## コマンドの効果説明を、現在の段階の実効威力で生成する。
func _command_text(cmd: CommandData) -> String:
	var p := data.effective_power(cmd)
	match cmd.effect:
		CommandData.Effect.DAMAGE:
			return "敵に%dダメージ" % p
		CommandData.Effect.BUFF_ATK:
			return "このターンの与ダメージ+%d" % p
		CommandData.Effect.DOUBLE_NEXT:
			return "次のダメージを2倍にする"
	return cmd.description

## 現在のエネルギーに応じて、払えないコマンドのボタンを無効化する。
func refresh(energy: int) -> void:
	for btn in _command_buttons:
		btn.disabled = int(btn.get_meta("cost")) > energy

## 勝敗確定時など、入力を完全に止める。
func disable_all() -> void:
	for btn in _command_buttons:
		btn.disabled = true
