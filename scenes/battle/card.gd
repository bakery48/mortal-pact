class_name CardUI
extends PanelContainer

## 手札に並ぶ魔物カード1枚のUI。
## battle_manager が data をセットしてから add_child することで _ready で描画する。

signal command_selected(card: CardUI, command: CommandData)

var data: MonsterData

var _command_buttons: Array[Button] = []

func _ready() -> void:
	custom_minimum_size = Vector2(190, 250)
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
	title.text = "%s [%s]" % [data.monster_name, data.stage]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var stats := Label.new()
	stats.text = "ATK:%d  DEF:%d" % [data.attack, data.defense]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats)

	vbox.add_child(HSeparator.new())

	for cmd in data.commands:
		var btn := Button.new()
		btn.text = "▶ %s  (コスト%d)\n%s" % [cmd.command_name, cmd.cost, cmd.description]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.set_meta("cost", cmd.cost)
		# lambda で対象コマンドを束縛してシグナルを発火。
		btn.pressed.connect(func() -> void: command_selected.emit(self, cmd))
		vbox.add_child(btn)
		_command_buttons.append(btn)

## 現在のエネルギーに応じて、払えないコマンドのボタンを無効化する。
func refresh(energy: int) -> void:
	for btn in _command_buttons:
		btn.disabled = int(btn.get_meta("cost")) > energy

## 勝敗確定時など、入力を完全に止める。
func disable_all() -> void:
	for btn in _command_buttons:
		btn.disabled = true
