extends Control

## ランのマップ画面。ノード列（バトル→休憩/ショップ→ボス）を表示し、
## 現在地のノードに進入できる。状態は autoload の Run が保持する。

func _ready() -> void:
	# マップはノード間の安全な地点なので、ここで自動セーブする。
	Run.save_game()
	_build_ui()
	Audio.play_bgm("res://assets/audio/bgm_map.ogg")

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.09)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.custom_minimum_size = Vector2(520, 0)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "── 第 %d フロア ──" % Run.current_floor
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	var status := Label.new()
	status.text = "HP %d/%d    💰 %d    デッキ %d/%d枚" % [
		Run.player_hp, Run.player_max_hp, Run.gold, Run.deck.size(), Run.DECK_LIMIT,
	]
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(status)

	vbox.add_child(HSeparator.new())

	for i in range(Run.map_nodes.size()):
		vbox.add_child(_make_node_row(i, Run.map_nodes[i]))

	vbox.add_child(HSeparator.new())

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	vbox.add_child(buttons)

	var settings := Button.new()
	settings.text = "設定"
	settings.pressed.connect(func(): get_tree().change_scene_to_file(Run.SCENE_SETTINGS))
	buttons.add_child(settings)

	var restart := Button.new()
	restart.text = "最初からやり直す（進行を消去）"
	restart.pressed.connect(_on_restart)
	buttons.add_child(restart)

func _on_restart() -> void:
	Run.delete_save()
	Run.restart_run()

func _make_node_row(index: int, node: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var status_icon := "✅" if index < Run.current_index else ("▶" if index == Run.current_index else "　")
	var label := Label.new()
	label.text = "%s  %s" % [status_icon, _node_title(node)]
	label.add_theme_font_size_override("font_size", 20)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if index < Run.current_index:
		label.modulate = Color(0.5, 0.5, 0.5)
	elif index > Run.current_index:
		label.modulate = Color(0.7, 0.7, 0.7)
	row.add_child(label)

	if index == Run.current_index:
		var btn := Button.new()
		btn.text = "進む"
		btn.pressed.connect(Run.begin_node)
		row.add_child(btn)

	return row

func _node_title(node: Dictionary) -> String:
	match int(node["type"]):
		Run.NodeType.BATTLE_ZAKO:
			return "バトル：%s" % node["name"]
		Run.NodeType.BATTLE_ELITE:
			return "エリート：%s" % node["name"]
		Run.NodeType.BATTLE_BOSS:
			return "ボス：%s" % node["name"]
		Run.NodeType.REST_SHOP:
			return "休憩 / ショップ"
	return "？"
