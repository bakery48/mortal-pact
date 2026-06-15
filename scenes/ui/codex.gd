extends Control

## 図鑑。これまでのランで出会った（倒した／仲間にした）魔物を記録・表示する。
## 未発見の魔物は「？？？」で伏せる。記録は user://unlocks.json に永続。

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.09)
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

	var entries := _catalog()
	var found := 0
	for e in entries:
		if Run.is_unlocked(e["name"]):
			found += 1

	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.text = "魔物図鑑　%d / %d 種 発見" % [found, entries.size()]
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var back := Button.new()
	back.text = "← 戻る"
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file(Run.SCENE_TITLE))
	header.add_child(back)

	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	for e in entries:
		grid.add_child(_make_entry(e))

func _make_entry(e: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(250, 0)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	panel.add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	margin.add_child(v)

	var unlocked: bool = Run.is_unlocked(e["name"])
	var name_lbl := Label.new()
	if unlocked:
		name_lbl.text = "%s 〈%s〉" % [e["name"], String(MonsterData.ELEMENT_LABEL[int(e["element"])])]
	else:
		name_lbl.text = "？？？"
		panel.modulate = Color(0.5, 0.5, 0.55)
	name_lbl.add_theme_font_size_override("font_size", 16)
	v.add_child(name_lbl)

	var role_lbl := Label.new()
	role_lbl.text = String(e["role"])
	role_lbl.add_theme_font_size_override("font_size", 11)
	role_lbl.add_theme_color_override("font_color", Color(0.65, 0.66, 0.72))
	v.add_child(role_lbl)

	if unlocked and e.has("skills"):
		for s in e["skills"]:
			var c := Label.new()
			c.text = "  ▸ %s" % String(s)
			c.add_theme_font_size_override("font_size", 11)
			c.add_theme_color_override("font_color", Color(0.7, 0.7, 0.76))
			v.add_child(c)

	return panel

## 全魔物のカタログを作る。仲間（MonsterData）と敵（EnemyDatabase）を名前で統合。
func _catalog() -> Array:
	var by_name := {}
	var order: Array = []

	var add_ally := func(m: MonsterData, role: String) -> void:
		if not by_name.has(m.monster_name):
			order.append(m.monster_name)
		var skills: Array = []
		for c in m.commands:
			skills.append(c.command_name)
		# 仲間情報を優先（スキル付き）。既存が敵のみなら上書き。
		by_name[m.monster_name] = {
			"name": m.monster_name,
			"element": m.elements[0] if not m.elements.is_empty() else MonsterData.Element.NONE,
			"role": role,
			"skills": skills,
		}

	for m: MonsterData in MonsterFactory.starter_monsters():
		add_ally.call(m, "仲間（初期）")
	for m: MonsterData in MonsterFactory.reward_pool():
		add_ally.call(m, "仲間（報酬）")

	var add_enemy := func(d: Dictionary, role: String) -> void:
		var nm := String(d["name"])
		if by_name.has(nm):
			return # 仲間として既に登録済みなら敵情報は足さない
		order.append(nm)
		by_name[nm] = {
			"name": nm,
			"element": int(d.get("element", MonsterData.Element.NONE)),
			"role": role,
		}

	for d in EnemyDatabase.zako_pool():
		add_enemy.call(d, "敵（雑魚）")
	for d in EnemyDatabase.elite_pool():
		add_enemy.call(d, "敵（エリート）")
	for d in EnemyDatabase.boss_pool():
		add_enemy.call(d, "敵（ボス）")

	var result: Array = []
	for nm in order:
		result.append(by_name[nm])
	return result
