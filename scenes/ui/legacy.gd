extends Control

## 死亡時の「継承」画面。ラン終了時、デッキの魔物から最大6体を選んで
## 次ランの初期デッキに引き継ぐ（選んだ魔物は幼体にリセットされる）。

const MAX_PICK := 6

var _selected: Array[MonsterData] = []
var _count_label: Label
var _confirm_button: Button
var _cards: Array = [] # [{ "panel": PanelContainer, "monster": MonsterData }]

func _ready() -> void:
	# デッキが6体以下なら全員を初期選択にしておく。
	if Run.deck.size() <= MAX_PICK:
		_selected.assign(Run.deck)
	_build_ui()

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.05, 0.07)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 24)
	add_child(root)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	root.add_child(vbox)

	var title := Label.new()
	title.text = "継承 ── 次代へ命をつなぐ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.82, 0.66, 0.92))
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "倒れた。だが血脈は続く。次のランへ引き継ぐ魔物を最大%d体選べ（幼体に戻って再び育つ）。" % MAX_PICK
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_color_override("font_color", Color(0.7, 0.65, 0.72))
	vbox.add_child(desc)

	_count_label = Label.new()
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_count_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	if Run.deck.is_empty():
		var empty := Label.new()
		empty.text = "引き継げる魔物がいない…（次ランは初期デッキで再開）"
		empty.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		grid.add_child(empty)
	for mon: MonsterData in Run.deck:
		grid.add_child(_make_card(mon))

	_confirm_button = Button.new()
	_confirm_button.custom_minimum_size = Vector2(0, 44)
	_confirm_button.pressed.connect(_on_confirm)
	vbox.add_child(_confirm_button)

	_refresh()

func _make_card(mon: MonsterData) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(240, 0)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	margin.add_child(v)

	var name_lbl := Label.new()
	name_lbl.text = "%s %s %s" % [mon.rarity_label(), mon.display_name(), mon.stage_label()]
	name_lbl.add_theme_font_size_override("font_size", 16)
	v.add_child(name_lbl)

	var stat_lbl := Label.new()
	stat_lbl.text = "属性:%s  ATK:%d DEF:%d" % [mon.element_label(), mon.effective_attack(), mon.effective_defense()]
	stat_lbl.add_theme_font_size_override("font_size", 12)
	stat_lbl.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
	v.add_child(stat_lbl)

	for cmd: CommandData in mon.commands:
		var c := Label.new()
		c.text = "  ▸ %s（コスト%d）" % [cmd.command_name, cmd.cost]
		c.add_theme_font_size_override("font_size", 11)
		c.add_theme_color_override("font_color", Color(0.62, 0.62, 0.68))
		v.add_child(c)

	var toggle := Button.new()
	toggle.toggle_mode = true
	toggle.button_pressed = mon in _selected
	toggle.pressed.connect(_on_toggle.bind(mon, toggle))
	v.add_child(toggle)

	_cards.append({"panel": panel, "monster": mon, "toggle": toggle})
	return panel

func _on_toggle(mon: MonsterData, toggle: Button) -> void:
	if mon in _selected:
		_selected.erase(mon)
	elif _selected.size() < MAX_PICK:
		_selected.append(mon)
	else:
		toggle.button_pressed = false # 上限到達、選択取消
		return
	_refresh()

func _refresh() -> void:
	_count_label.text = "選択中 %d / %d" % [_selected.size(), MAX_PICK]
	_confirm_button.text = "この%d体で次代へ" % _selected.size() if _selected.size() > 0 else "引き継がずに終える"
	for c in _cards:
		var mon: MonsterData = c["monster"]
		var t := c["toggle"] as Button
		var sel := mon in _selected
		t.button_pressed = sel
		t.text = "✔ 継承する" if sel else "継承する"
		(c["panel"] as PanelContainer).modulate = Color(1.0, 0.92, 0.5) if sel else Color.WHITE
		# 上限到達時は未選択トグルを無効化。
		t.disabled = (not sel) and _selected.size() >= MAX_PICK

func _on_confirm() -> void:
	Audio.play_se("select")
	Run.set_carryover(_selected)
	get_tree().change_scene_to_file(Run.SCENE_RESULT)
