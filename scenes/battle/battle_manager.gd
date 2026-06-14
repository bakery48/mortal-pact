extends Control

## フェーズ1：コア戦闘の進行管理。
## ・プレイヤーターン → エネルギー3回復 → 手札5枚 → コマンド実行
## ・ターン終了宣言 → 敵が予告した攻撃を実行 → 次の予告 → プレイヤーターン
## ・敵HP0で勝利 / プレイヤーHP0で敗北

const CardScene := preload("res://scenes/battle/card.tscn")
const EnemyScene := preload("res://scenes/battle/enemy.tscn")

const MAX_ENERGY := 3
const HAND_SIZE := 5

var deck := DeckManager.new()

var player_max_hp := 50
var player_hp := 50
var energy := MAX_ENERGY
## このターン中の与ダメージ加算（遠吠え等）。ターン開始でリセット。
var atk_buff := 0
## 次のダメージコマンドを2倍にするフラグ（狂化）。
var double_next := false
## プレイヤーのブロック（敵の攻撃を軽減）。プレイヤーターン開始でリセット。
var player_block := 0
## プレイヤーにかかった状態異常（毒・再生など）。
var player_status := StatusSet.new()
var battle_over := false

var enemy: EnemyUI

var _enemy_slot: HBoxContainer
var _hand_container: HBoxContainer
var _hp_label: Label
var _energy_label: Label
var _buff_label: Label
var _pile_label: Label
var _message_label: Label
var _event_label: Label
var _end_turn_button: Button
var _fuse_button: Button

## 合体候補として選択中のモンスター（最大2体）。
var _fusion_selection: Array[MonsterData] = []

func _ready() -> void:
	# ランから直接バトルを起動した場合のフォールバック（単体テスト用）。
	if Run.deck.is_empty():
		Run.start_new_run()
	if Run.current_encounter.is_empty():
		# 単体テスト用：マップ先頭の戦闘ノードを使う。
		Run.current_encounter = Run.map_rows[0][0]

	player_max_hp = Run.player_max_hp
	player_hp = Run.player_hp

	_build_ui()
	deck.setup_from(Run.deck)
	_spawn_enemy()
	_start_player_turn()
	Audio.play_bgm("res://assets/audio/bgm_battle.ogg")

# --- UI 構築 ---------------------------------------------------------------

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.07, 0.1) # ダークファンタジー寄りの暗色背景
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 24)
	root.add_theme_constant_override("margin_right", 24)
	root.add_theme_constant_override("margin_top", 16)
	root.add_theme_constant_override("margin_bottom", 16)
	add_child(root)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 12)
	root.add_child(main)

	# 敵エリア（上部・中央寄せ）
	_enemy_slot = HBoxContainer.new()
	_enemy_slot.alignment = BoxContainer.ALIGNMENT_CENTER
	_enemy_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(_enemy_slot)

	# 勝敗メッセージ（中央）
	_message_label = Label.new()
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_font_size_override("font_size", 36)
	main.add_child(_message_label)

	# ステータスバー
	var status := HBoxContainer.new()
	status.add_theme_constant_override("separation", 24)
	main.add_child(status)

	var floor_label := Label.new()
	floor_label.add_theme_font_size_override("font_size", 18)
	floor_label.text = "B%dF  💰%d" % [Run.current_floor, Run.gold]
	status.add_child(floor_label)

	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", 18)
	status.add_child(_hp_label)

	_energy_label = Label.new()
	_energy_label.add_theme_font_size_override("font_size", 18)
	status.add_child(_energy_label)

	_buff_label = Label.new()
	_buff_label.add_theme_font_size_override("font_size", 18)
	status.add_child(_buff_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_child(spacer)

	_pile_label = Label.new()
	status.add_child(_pile_label)

	_fuse_button = Button.new()
	_fuse_button.disabled = true
	_fuse_button.pressed.connect(_on_fuse_pressed)
	status.add_child(_fuse_button)
	_update_fuse_button()

	_end_turn_button = Button.new()
	_end_turn_button.text = "ターン終了"
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	status.add_child(_end_turn_button)

	# 成長・消滅などのイベント通知（一定時間でフェードアウト）
	_event_label = Label.new()
	_event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event_label.add_theme_font_size_override("font_size", 20)
	_event_label.modulate.a = 0.0
	main.add_child(_event_label)

	# 手札エリア（下部・中央寄せ）
	_hand_container = HBoxContainer.new()
	_hand_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_hand_container.add_theme_constant_override("separation", 12)
	main.add_child(_hand_container)

# --- 戦闘フロー -------------------------------------------------------------

func _spawn_enemy() -> void:
	var enc := Run.current_encounter
	var hp := int(enc["max_hp"])
	enemy = EnemyScene.instantiate() as EnemyUI
	enemy.enemy_name = ("【ボス】" if enc.get("is_boss", false) else "") + String(enc["name"])
	enemy.sprite_name = String(enc["name"]) # スプライト探索用（接頭辞なし）
	enemy.element = int(enc.get("element", MonsterData.Element.NONE))
	enemy.max_hp = hp
	enemy.hp = hp
	enemy.set_pattern(enc.get("pattern", []))
	_enemy_slot.add_child(enemy)
	enemy.plan_next() # 最初の行動を予告

func _start_player_turn() -> void:
	if battle_over:
		return

	# プレイヤーの状態異常を処理（毒ダメージ・再生回復）。
	var pt := player_status.tick_turn()
	if pt.poison > 0:
		player_hp = maxi(0, player_hp - int(pt.poison))
		_flash_message("毒で %d ダメージ" % int(pt.poison))
	if pt.regen > 0:
		player_hp = mini(player_max_hp, player_hp + int(pt.regen))
	if player_hp <= 0:
		_refresh()
		_lose()
		return

	energy = MAX_ENERGY
	atk_buff = 0
	double_next = false
	player_block = 0

	# 手札を HAND_SIZE まで補充（どのモンスターのどのスキルかは運次第）。
	for i in range(HAND_SIZE):
		var sc := deck.draw_card()
		if sc == null:
			break
		_add_card_to_hand(sc)

	# 敵の次の行動は敵ターン終了時に予告済み（plan_next）。
	_refresh()

func _add_card_to_hand(sc: SkillCard) -> void:
	var card := CardScene.instantiate() as CardUI
	card.monster = sc.monster
	card.command = sc.command
	card.source = sc
	card.enemy_element = enemy.element # 相性表示のため敵の属性を渡す
	_hand_container.add_child(card)
	card.command_selected.connect(_on_command_selected)
	card.fusion_toggled.connect(_on_fusion_toggled)

func _on_command_selected(card: CardUI) -> void:
	if battle_over:
		return
	var monster := card.monster
	var cmd := card.command
	var cost := monster.effective_cost(cmd)
	if energy < cost:
		return

	energy -= cost
	_apply_command(monster, cmd)
	Audio.play_se("attack" if cmd.effect == CommandData.Effect.DAMAGE else "select")

	# 使用するたびに、そのモンスターが EXP（=成長速度分）を得て成長する。
	var grew := monster.gain_exp(monster.growth_speed)
	if grew and not monster.is_dead():
		Audio.play_se("grow")
		_flash_message("%s は %s に成長した！" % [monster.monster_name, monster.stage_label()])

	# 使ったスキルカードは捨札へ。
	deck.discard_card(card.source)
	card.queue_free()

	# 消滅したら、そのモンスターのスキルカードを全て除外する。
	if monster.is_dead():
		_kill_monster(monster)

	if enemy.is_dead():
		_win()
		return
	_refresh()

## モンスターを消滅させ、デッキ・手札からスキルカードを一掃する。
func _kill_monster(monster: MonsterData) -> void:
	deck.remove_monster(monster)
	Run.deck.erase(monster)
	_fusion_selection.erase(monster)
	for child in _hand_container.get_children():
		if child is CardUI and (child as CardUI).monster == monster:
			child.queue_free()
	_flash_message("%s は老いて消滅した…" % monster.monster_name)
	_update_fuse_button()

func _apply_command(card_data: MonsterData, cmd: CommandData) -> void:
	var p := card_data.effective_power(cmd)
	match cmd.effect:
		CommandData.Effect.DAMAGE, CommandData.Effect.PIERCE:
			# 威力＋ATK補正にバフ・2倍・属性相性を反映。
			var base := card_data.command_value(cmd) + atk_buff
			if double_next:
				base *= 2
				double_next = false
			# 属性相性を反映（有利×1.5 / 不利×0.75）。
			var mult := MonsterData.affinity(card_data.elements, enemy.element)
			var dmg := roundi(base * mult)
			if cmd.effect == CommandData.Effect.PIERCE:
				enemy.take_damage_pierce(dmg)
			else:
				enemy.take_damage(dmg)
		CommandData.Effect.BUFF_ATK:
			atk_buff += p
		CommandData.Effect.DOUBLE_NEXT:
			double_next = true
		CommandData.Effect.HEAL:
			player_hp = mini(player_max_hp, player_hp + p)
		CommandData.Effect.GUARD:
			player_block += card_data.command_value(cmd) # 威力＋DEF補正
		CommandData.Effect.WEAKEN:
			enemy.apply_weaken(p)
		CommandData.Effect.ENERGY:
			energy += cmd.power # エネルギーは段階補正なしの素の値
		CommandData.Effect.POISON:
			enemy.add_status(StatusSet.Status.POISON, p)
		CommandData.Effect.BURN:
			enemy.add_status(StatusSet.Status.BURN, cmd.power) # 炎上は素のターン数
		CommandData.Effect.FREEZE:
			enemy.add_status(StatusSet.Status.FREEZE, cmd.power) # 凍結は素の回数
		CommandData.Effect.REGEN:
			player_status.add(StatusSet.Status.REGEN, p)

func _on_end_turn_pressed() -> void:
	if battle_over:
		return
	_enemy_turn()

func _enemy_turn() -> void:
	# 敵の状態異常を処理（毒ダメージ・再生回復）。
	var et := enemy.status.tick_turn()
	if et.poison > 0:
		enemy.take_fixed(int(et.poison))
		_flash_message("%s は毒で %d ダメージ" % [enemy.enemy_name, int(et.poison)])
	if et.regen > 0:
		enemy.heal(int(et.regen))
	_refresh()
	if enemy.is_dead():
		_win()
		return

	# 凍結中なら行動をスキップ。
	if enemy.status.consume_freeze():
		_flash_message("%s は凍結して動けない！" % enemy.enemy_name)
	else:
		# 自ターン開始でブロックをリセットし、予告した行動を実行。
		enemy.reset_block()
		var dmg := enemy.execute()
		if enemy.intent_type == EnemyUI.Intent.POISON:
			player_status.add(StatusSet.Status.POISON, enemy.intent_value)
			_flash_message("毒 %d を受けた" % enemy.intent_value)
		elif dmg > 0:
			# プレイヤーのブロックで軽減する。
			var actual := maxi(0, dmg - player_block)
			player_block = maxi(0, player_block - dmg)
			if actual > 0:
				player_hp = maxi(0, player_hp - actual)
				Audio.play_se("hit")
	_refresh()
	if player_hp <= 0:
		_lose()
		return

	# 次の行動を予告し、手札を片付けて次のプレイヤーターンへ。
	enemy.plan_next()
	deck.discard_hand()
	_clear_hand_nodes()
	_start_player_turn()

func _clear_hand_nodes() -> void:
	# 合体候補の選択も解除（カードノードが破棄されるため）。
	_fusion_selection.clear()
	for child in _hand_container.get_children():
		child.queue_free()
	_update_fuse_button()

# --- 合体（子孫生成） -------------------------------------------------------

func _on_fusion_toggled(card: CardUI) -> void:
	if battle_over:
		return
	var m := card.monster
	if not m.can_fuse():
		return
	if m in _fusion_selection:
		_fusion_selection.erase(m)
	elif _fusion_selection.size() < 2:
		_fusion_selection.append(m)
	# すでに2体選択済みで別モンスターなら無視（下で見た目を戻す）。
	_update_fusion_visuals()
	_update_fuse_button()

## 各カードの選択ハイライトを、選択中モンスター集合に合わせて更新する。
func _update_fusion_visuals() -> void:
	for child in _hand_container.get_children():
		if child is CardUI:
			var c := child as CardUI
			c.set_fusion_selected(c.monster in _fusion_selection)

func _update_fuse_button() -> void:
	if _fuse_button == null:
		return
	_fuse_button.text = "合体 (%d/2)" % _fusion_selection.size()
	_fuse_button.disabled = battle_over or _fusion_selection.size() != 2

func _on_fuse_pressed() -> void:
	if battle_over or _fusion_selection.size() != 2:
		return
	_open_fusion_dialog(_fusion_selection[0], _fusion_selection[1])

## 継承スキルを選ぶモーダルを開く。
func _open_fusion_dialog(mon_a: MonsterData, mon_b: MonsterData) -> void:
	var element := MonsterFactory.choose_child_element(mon_a, mon_b)
	var max_inherit := MonsterFactory.max_inheritable(mon_a, mon_b)
	var pool := MonsterFactory.inheritable_pool(mon_a, mon_b)
	var innate := MonsterFactory.element_innate_kit(element)
	var chosen: Array[CommandData] = []

	# 暗幕
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.65)
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

	# 継承候補トグル
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

func _on_fusion_confirm(mon_a: MonsterData, mon_b: MonsterData, element: int, chosen: Array, overlay: Control) -> void:
	var child := MonsterFactory.make_child(mon_a, mon_b, element, chosen)
	overlay.queue_free()
	_commit_fusion(mon_a, mon_b, child)

func _on_inherit_toggled(pressed: bool, cmd: CommandData, btn: Button, chosen: Array, max_inherit: int, count_label: Label) -> void:
	if pressed:
		if chosen.size() >= max_inherit:
			btn.button_pressed = false # 上限超過は取り消し
			return
		chosen.append(cmd)
	else:
		chosen.erase(cmd)
	count_label.text = "継承 %d / %d" % [chosen.size(), max_inherit]

## 合体を確定し、両親を消滅させ子孫を手札に加える。
func _commit_fusion(mon_a: MonsterData, mon_b: MonsterData, child: MonsterData) -> void:
	# 両親のスキルカードをデッキ・手札から除去。
	deck.remove_monster(mon_a)
	deck.remove_monster(mon_b)
	Run.deck.erase(mon_a)
	Run.deck.erase(mon_b)
	for node in _hand_container.get_children():
		if node is CardUI and (node as CardUI).monster in [mon_a, mon_b]:
			node.queue_free()
	_fusion_selection.clear()

	# 子孫をデッキに加え、そのスキルカードを手札に出す。
	Run.deck.append(child)
	for sc in deck.add_monster_to_hand(child):
		_add_card_to_hand(sc)

	Audio.play_se("fuse")
	_flash_message("合体！ %s（%s %s）が誕生した" % [child.monster_name, child.rarity_label(), child.element_label()])
	_update_fusion_visuals()
	_update_fuse_button()
	_refresh()
	_refresh()

# --- 表示更新・終了処理 -----------------------------------------------------

## 画面中央下にイベント文を表示し、しばらくしてフェードアウトさせる。
func _flash_message(text: String) -> void:
	_event_label.text = text
	_event_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.2)
	tween.tween_property(_event_label, "modulate:a", 0.0, 0.8)

func _refresh() -> void:
	var hp_text := "プレイヤー HP: %d / %d" % [player_hp, player_max_hp]
	if player_block > 0:
		hp_text += "  🛡%d" % player_block
	var pst := player_status.label()
	if pst != "":
		hp_text += "  " + pst
	_hp_label.text = hp_text
	_energy_label.text = "⚡ エネルギー: %d / %d" % [energy, MAX_ENERGY]

	var buff_text := ""
	if atk_buff > 0:
		buff_text += "与ダメ+%d  " % atk_buff
	if double_next:
		buff_text += "次のダメ2倍"
	_buff_label.text = buff_text

	_pile_label.text = "山札:%d  捨札:%d" % [deck.draw_pile.size(), deck.discard_pile.size()]

	for child in _hand_container.get_children():
		if child is CardUI:
			(child as CardUI).refresh(energy)

func _win() -> void:
	battle_over = true
	_message_label.text = "勝利！"
	_message_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	_end_battle_input()
	Audio.play_se("win")
	# HPをランへ書き戻し、報酬画面へ（デッキ＝モンスターは戦闘中に直接更新済み）。
	await get_tree().create_timer(1.0).timeout
	Run.on_battle_won(player_hp)

func _lose() -> void:
	battle_over = true
	_message_label.text = "敗北..."
	_message_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	_end_battle_input()
	Audio.play_se("lose")
	await get_tree().create_timer(1.0).timeout
	Run.on_battle_lost()

func _end_battle_input() -> void:
	_end_turn_button.disabled = true
	_fuse_button.disabled = true
	for child in _hand_container.get_children():
		if child is CardUI:
			(child as CardUI).disable_all()
