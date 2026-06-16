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

# --- 合体（血統強化） -------------------------------------------------------

## 血統と相手を選ぶモーダルを開く。最初の選択＝血統、次＝相手。
func _open_fusion_picker() -> void:
	# 役割の保持（参照渡しのため Dictionary）。
	var state := {"bloodline": null, "partner": null}

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 480)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "合体：血統（残る側）と相手（消える側）を選ぶ"
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	var hint := Label.new()
	hint.text = "1体目のクリック＝血統 ／ 2体目＝相手。名前と属性は血統を引き継ぎ、+値が加算されます。"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(hint)

	var preview := Label.new()
	preview.add_theme_font_size_override("font_size", 16)
	preview.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
	vbox.add_child(preview)

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
		btn.custom_minimum_size = Vector2(290, 0)
		toggles.append({"button": btn, "monster": mon})
		btn.pressed.connect(_on_fusion_role_toggled.bind(mon, state, toggles, preview))
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
	next_btn.pressed.connect(_on_fusion_next.bind(state, overlay))
	buttons.add_child(next_btn)
	preview.set_meta("next_button", next_btn)

	_refresh_fusion_picker(state, toggles, preview)

func _on_fusion_role_toggled(mon: MonsterData, state: Dictionary, toggles: Array, preview: Label) -> void:
	# 既に役割があるなら解除、無ければ 血統→相手 の順に割り当て。
	if state["bloodline"] == mon:
		state["bloodline"] = null
	elif state["partner"] == mon:
		state["partner"] = null
	elif state["bloodline"] == null:
		state["bloodline"] = mon
	elif state["partner"] == null:
		state["partner"] = mon
	_refresh_fusion_picker(state, toggles, preview)

func _refresh_fusion_picker(state: Dictionary, toggles: Array, preview: Label) -> void:
	var bl: MonsterData = state["bloodline"]
	var pt: MonsterData = state["partner"]
	for t in toggles:
		var mon: MonsterData = t["monster"]
		var b := t["button"] as Button
		var role := ""
		if mon == bl:
			role = "【血統】"
			b.modulate = Color(1.0, 0.85, 0.4)
		elif mon == pt:
			role = "【相手】"
			b.modulate = Color(0.6, 0.8, 1.0)
		else:
			b.modulate = Color.WHITE
		b.button_pressed = role != ""
		b.text = "%s%s %s\n属性:%s ATK:%d DEF:%d" % [
			role, mon.display_name(), mon.stage_label(),
			mon.element_label(), mon.effective_attack(), mon.effective_defense(),
		]
		# 両役割が埋まっているとき、未選択は押せないようにする。
		b.disabled = (mon != bl and mon != pt) and bl != null and pt != null
	if bl != null and pt != null:
		preview.text = "→ %s+%d が誕生（幼体から再育成）" % [bl.monster_name, MonsterFactory.fused_plus(bl, pt)]
	elif bl != null:
		preview.text = "血統: %s（相手を選んでください）" % bl.display_name()
	else:
		preview.text = "血統を選んでください"
	var next_btn := preview.get_meta("next_button") as Button
	if next_btn != null:
		next_btn.disabled = bl == null or pt == null

func _on_fusion_next(state: Dictionary, overlay: Control) -> void:
	var bl: MonsterData = state["bloodline"]
	var pt: MonsterData = state["partner"]
	if bl == null or pt == null:
		return
	overlay.queue_free()
	_open_inherit_dialog(bl, pt)

## 継承スキルを選ぶモーダルを開く（固有2＋両親から手動継承の従来ルール）。
func _open_inherit_dialog(bloodline: MonsterData, partner: MonsterData) -> void:
	var max_inherit := MonsterFactory.max_inheritable(bloodline, partner)
	var pool := MonsterFactory.inheritable_pool(bloodline, partner)
	var element: int = bloodline.elements[0] if not bloodline.elements.is_empty() else MonsterData.Element.NONE
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
	title.text = "合体：%s+%d ／ 継承スキルを選択" % [bloodline.monster_name, MonsterFactory.fused_plus(bloodline, partner)]
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	var innate_lines: Array[String] = []
	for c in innate:
		innate_lines.append("・%s（コスト%d）%s" % [c.command_name, c.cost, _skill_effect_text(c)])
	var innate_label := Label.new()
	innate_label.text = "固有スキル（自動付与）:\n" + "\n".join(innate_lines) + "\n継承できる数: 最大%d" % max_inherit
	innate_label.modulate = Color(0.8, 0.85, 0.95)
	innate_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(innate_label)

	vbox.add_child(HSeparator.new())

	var count_label := Label.new()
	vbox.add_child(count_label)

	for cmd in pool:
		var btn := Button.new()
		btn.toggle_mode = true
		btn.disabled = max_inherit <= 0
		btn.text = "%s（コスト%d）\n%s" % [cmd.command_name, cmd.cost, _skill_effect_text(cmd)]
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
	confirm.pressed.connect(_on_fusion_confirm.bind(bloodline, partner, chosen, overlay))
	buttons.add_child(confirm)

	count_label.text = "継承 0 / %d" % max_inherit

## コマンドのステータス依存係数（モンスター非依存。負なら自動＝コスト依存）。
func _cmd_scale(cmd: CommandData) -> float:
	if cmd.stat_scale >= 0.0:
		return cmd.stat_scale
	return clampf(0.4 + 0.3 * float(cmd.cost - 1), 0.4, 1.0)

## スキルの効果説明テキスト。育成前なので実数値ではなく「基礎N＋ATK×係数」の式表記で示す。
func _skill_effect_text(cmd: CommandData) -> String:
	var p := cmd.power
	var scale := _cmd_scale(cmd)
	match cmd.effect:
		CommandData.Effect.DAMAGE: return "敵にダメージ（基礎%d＋ATK×%.1f）" % [p, scale]
		CommandData.Effect.PIERCE: return "防御無視ダメージ（基礎%d＋ATK×%.1f）" % [p, scale]
		CommandData.Effect.GUARD: return "ブロック（基礎%d＋DEF×%.1f）" % [p, scale]
		CommandData.Effect.BUFF_ATK: return "このターンの与ダメージ+%d" % p
		CommandData.Effect.DOUBLE_NEXT: return "次のダメージを2倍"
		CommandData.Effect.HEAL: return "HPを%d回復" % p
		CommandData.Effect.WEAKEN: return "敵の攻撃力-%d" % p
		CommandData.Effect.ENERGY: return "エネルギー+%d" % p
		CommandData.Effect.POISON: return "毒%dを付与" % p
		CommandData.Effect.BURN: return "%dターン炎上" % p
		CommandData.Effect.FREEZE: return "%d回凍結" % p
		CommandData.Effect.REGEN: return "再生%d" % p
	return ""

func _on_inherit_toggled(pressed: bool, cmd: CommandData, btn: Button, chosen: Array, max_inherit: int, count_label: Label) -> void:
	if pressed:
		if chosen.size() >= max_inherit:
			btn.button_pressed = false
			return
		chosen.append(cmd)
	else:
		chosen.erase(cmd)
	count_label.text = "継承 %d / %d" % [chosen.size(), max_inherit]

func _on_fusion_confirm(bloodline: MonsterData, partner: MonsterData, chosen: Array, overlay: Control) -> void:
	var child := MonsterFactory.make_child(bloodline, partner, chosen)
	Run.deck.erase(bloodline)
	Run.deck.erase(partner)
	Run.deck.append(child)
	Run.record_unlock(child.monster_name)
	Audio.play_se("fuse")
	overlay.queue_free()
	# 合体結果が反映された画面に作り直す。
	for c in get_children():
		c.queue_free()
	_offer_rows.clear()
	_build_ui()
