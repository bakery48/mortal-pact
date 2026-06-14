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

	var proceed := Button.new()
	proceed.text = "進む"
	proceed.pressed.connect(Run.go_after_node)
	vbox.add_child(proceed)

	_refresh()

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
	panel.queue_free()
	_offer_rows = _offer_rows.filter(func(r): return r["panel"] != panel)
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
