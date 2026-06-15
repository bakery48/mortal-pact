extends Control

## 休憩 / ショップ ノード。
## ・休憩：HPを回復（1回）
## ・ショップ：所持金で魔物カードを購入
## 行動後「進む」で次のノードへ。

var _offers: Array[MonsterData] = []
var _rested := false

var _status_label: Label
var _rest_button: Button
var _offer_rows: Array = [] # [{ "panel": PanelContainer, "button": Button, "monster": MonsterData }]

func _ready() -> void:
	_offers = MonsterFactory.random_rewards(2)
	_build_ui()

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.07, 0.06)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "休憩 / ショップ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	vbox.add_child(title)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_status_label)

	# 休憩
	_rest_button = Button.new()
	_rest_button.pressed.connect(_on_rest)
	vbox.add_child(_rest_button)

	vbox.add_child(HSeparator.new())

	var shop_title := Label.new()
	shop_title.text = "ショップ（1枚 %dG）" % Run.SHOP_CARD_COST
	shop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(shop_title)

	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 16)
	vbox.add_child(cards)

	for monster in _offers:
		cards.add_child(_make_offer(monster))

	vbox.add_child(HSeparator.new())

	# 合体（子孫生成）：成体・老体2体から子孫を作る。
	var fuse_title := Label.new()
	fuse_title.text = "合体（成体・老体2体から子孫を生む）"
	fuse_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(fuse_title)

	var fuse_button := Button.new()
	var fusable := _fusable_monsters()
	fuse_button.text = "合体する（候補 %d体）" % fusable.size()
	fuse_button.disabled = fusable.size() < 2
	fuse_button.pressed.connect(_open_fusion_picker)
	vbox.add_child(fuse_button)

	var proceed := Button.new()
	proceed.text = "進む"
	proceed.pressed.connect(Run.go_after_node)
	vbox.add_child(proceed)

	_refresh()

## デッキ内で合体の親に選べる魔物（成体・老体）。
func _fusable_monsters() -> Array[MonsterData]:
	var result: Array[MonsterData] = []
	for m: MonsterData in Run.deck:
		if m.can_fuse():
			result.append(m)
	return result

func _make_offer(monster: MonsterData) -> Control:
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

	var buy := Button.new()
	buy.text = "購入 (%dG)" % Run.SHOP_CARD_COST
	buy.pressed.connect(func() -> void: _on_buy(monster, panel))
	vbox.add_child(buy)

	_offer_rows.append({"panel": panel, "button": buy, "monster": monster})
	return panel

func _on_rest() -> void:
	if _rested:
		return
	var healed := Run.rest_heal()
	_rested = true
	_refresh()
	_status_label.text = "休憩した（HP +%d）" % healed

func _on_buy(monster: MonsterData, panel: PanelContainer) -> void:
	if Run.gold < Run.SHOP_CARD_COST or not Run.can_add(monster.commands.size()):
		return
	Audio.play_se("coin")
	Run.gold -= Run.SHOP_CARD_COST
	Run.add_card(monster)
	Run.record_unlock(monster.monster_name) # 購入した魔物を図鑑に記録
	panel.queue_free()
	_offer_rows = _offer_rows.filter(func(r): return r["panel"] != panel)
	_offers.erase(monster) # 再描画で復活させない
	_refresh()

func _refresh() -> void:
	_status_label.text = "HP %d/%d    💰 %d    デッキ %d/%d枚" % [
		Run.player_hp, Run.player_max_hp, Run.gold, Run.deck_card_count(), Run.DECK_LIMIT,
	]
	if _rested or Run.player_hp >= Run.player_max_hp:
		_rest_button.text = "休憩済み" if _rested else "HP満タン"
		_rest_button.disabled = true
	else:
		_rest_button.text = "休憩する（HP +%d）" % roundi(Run.player_max_hp * Run.REST_HEAL_RATIO)
		_rest_button.disabled = false
	var affordable := Run.gold >= Run.SHOP_CARD_COST and Run.can_add(2)
	for r in _offer_rows:
		(r["button"] as Button).disabled = not affordable

# --- 合体（子孫生成） -------------------------------------------------------

## 親2体を選ぶモーダルを開く。
func _open_fusion_picker() -> void:
	var selected: Array[MonsterData] = []

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 460)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "合体：親にする2体を選ぶ"
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	var count_label := Label.new()
	count_label.text = "選択 0 / 2"
	vbox.add_child(count_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)

	var toggles: Array = []
	for mon: MonsterData in _fusable_monsters():
		var btn := Button.new()
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(280, 0)
		btn.text = "%s %s %s\n属性:%s ATK:%d DEF:%d" % [
			mon.rarity_label(), mon.monster_name, mon.stage_label(),
			mon.element_label(), mon.effective_attack(), mon.effective_defense(),
		]
		toggles.append({"button": btn, "monster": mon})
		btn.pressed.connect(_on_fusion_parent_toggled.bind(mon, btn, selected, count_label, toggles))
		grid.add_child(btn)

	vbox.add_child(HSeparator.new())

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)
	vbox.add_child(buttons)

	var cancel := Button.new()
	cancel.text = "キャンセル"
	cancel.pressed.connect(func() -> void: overlay.queue_free())
	buttons.add_child(cancel)

	var next_btn := Button.new()
	next_btn.text = "次へ（継承スキル選択）"
	next_btn.disabled = true
	next_btn.pressed.connect(_on_fusion_next.bind(selected, overlay))
	buttons.add_child(next_btn)
	# next ボタンの有効/無効更新のため参照を保持。
	count_label.set_meta("next_button", next_btn)

func _on_fusion_next(selected: Array, overlay: Control) -> void:
	if selected.size() != 2:
		return
	overlay.queue_free()
	_open_inherit_dialog(selected[0], selected[1])

func _on_fusion_parent_toggled(mon: MonsterData, btn: Button, selected: Array, count_label: Label, toggles: Array) -> void:
	if mon in selected:
		selected.erase(mon)
	elif selected.size() < 2:
		selected.append(mon)
	else:
		btn.button_pressed = false
		return
	count_label.text = "選択 %d / 2" % selected.size()
	var next_btn := count_label.get_meta("next_button") as Button
	if next_btn != null:
		next_btn.disabled = selected.size() != 2
	# 2体選択済みなら未選択を無効化。
	for t in toggles:
		var b := t["button"] as Button
		var m: MonsterData = t["monster"]
		b.disabled = (m not in selected) and selected.size() >= 2

## 継承スキルを選ぶモーダルを開く。
func _open_inherit_dialog(mon_a: MonsterData, mon_b: MonsterData) -> void:
	var element := MonsterFactory.choose_child_element(mon_a, mon_b)
	var max_inherit := MonsterFactory.max_inheritable(mon_a, mon_b)
	var pool := MonsterFactory.inheritable_pool(mon_a, mon_b)
	var innate := MonsterFactory.element_innate_kit(element)
	var chosen: Array[CommandData] = []

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "合体：継承するスキルを選択"
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	var elem_label := Label.new()
	elem_label.text = "子孫の属性: %s ／ 固有スキル2つ＋継承 最大%d" % [String(MonsterData.ELEMENT_LABEL[element]), max_inherit]
	elem_label.modulate = Color(0.8, 0.85, 0.95)
	vbox.add_child(elem_label)

	var innate_label := Label.new()
	var innate_names: Array[String] = []
	for c in innate:
		innate_names.append(c.command_name)
	innate_label.text = "固有: " + "／".join(innate_names)
	vbox.add_child(innate_label)

	vbox.add_child(HSeparator.new())

	var count_label := Label.new()
	vbox.add_child(count_label)

	for cmd in pool:
		var btn := Button.new()
		btn.toggle_mode = true
		btn.disabled = max_inherit <= 0
		btn.text = "%s（コスト%d）" % [cmd.command_name, cmd.cost]
		btn.toggled.connect(_on_inherit_toggled.bind(cmd, btn, chosen, max_inherit, count_label))
		vbox.add_child(btn)
	if pool.is_empty():
		var none_label := Label.new()
		none_label.text = "継承できるスキルがありません（固有2つで誕生）"
		none_label.modulate = Color(0.7, 0.7, 0.7)
		vbox.add_child(none_label)

	vbox.add_child(HSeparator.new())

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)
	vbox.add_child(buttons)

	var cancel := Button.new()
	cancel.text = "キャンセル"
	cancel.pressed.connect(func() -> void: overlay.queue_free())
	buttons.add_child(cancel)

	var confirm := Button.new()
	confirm.text = "合体する"
	confirm.pressed.connect(_on_fusion_confirm.bind(mon_a, mon_b, element, chosen, overlay))
	buttons.add_child(confirm)

	count_label.text = "継承 0 / %d" % max_inherit

func _on_inherit_toggled(pressed: bool, cmd: CommandData, btn: Button, chosen: Array, max_inherit: int, count_label: Label) -> void:
	if pressed:
		if chosen.size() >= max_inherit:
			btn.button_pressed = false
			return
		chosen.append(cmd)
	else:
		chosen.erase(cmd)
	count_label.text = "継承 %d / %d" % [chosen.size(), max_inherit]

func _on_fusion_confirm(mon_a: MonsterData, mon_b: MonsterData, element: int, chosen: Array, overlay: Control) -> void:
	var child := MonsterFactory.make_child(mon_a, mon_b, element, chosen)
	Run.deck.erase(mon_a)
	Run.deck.erase(mon_b)
	Run.deck.append(child)
	Run.record_unlock(child.monster_name)
	Audio.play_se("fuse")
	overlay.queue_free()
	# 合体結果が反映された画面に作り直す。
	for c in get_children():
		c.queue_free()
	_offer_rows.clear()
	_build_ui()
