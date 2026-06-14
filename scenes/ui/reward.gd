extends Control

## バトル勝利後の報酬画面。3体の魔物候補から1体を選んでデッキに加える。

var _choices: Array[MonsterData] = []

func _ready() -> void:
	_choices = MonsterFactory.random_rewards(3)
	_build_ui()

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.07)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "報酬：仲間にする魔物を選べ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	vbox.add_child(title)

	if not Run.can_add(2):
		var warn := Label.new()
		warn.text = "デッキが上限（%d枚）に近いです。獲得には合体で枠を空ける必要があるかも。" % Run.DECK_LIMIT
		warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		warn.modulate = Color(1.0, 0.7, 0.5)
		vbox.add_child(warn)

	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 16)
	vbox.add_child(cards)

	for monster in _choices:
		cards.add_child(_make_choice(monster))

	var skip := Button.new()
	skip.text = "獲得せずに進む"
	skip.pressed.connect(Run.go_after_node)
	vbox.add_child(skip)

func _make_choice(monster: MonsterData) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 200)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var info := Label.new()
	info.text = monster.summary()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(info)

	var pick := Button.new()
	pick.text = "獲得する"
	pick.disabled = not Run.can_add(monster.commands.size())
	pick.pressed.connect(func() -> void: _on_pick(monster))
	vbox.add_child(pick)

	return panel

func _on_pick(monster: MonsterData) -> void:
	Audio.play_se("coin")
	Run.add_card(monster)
	Run.go_after_node()
