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

## 合体候補として選択中のカード（最大2枚）。
var _fusion_selection: Array[CardUI] = []

func _ready() -> void:
	# ランから直接バトルを起動した場合のフォールバック（単体テスト用）。
	if Run.deck.is_empty():
		Run.start_new_run()
	if Run.current_encounter.is_empty():
		Run.current_encounter = Run.map_nodes[0]

	player_max_hp = Run.player_max_hp
	player_hp = Run.player_hp

	_build_ui()
	deck.setup_from(Run.deck)
	_spawn_enemy()
	_start_player_turn()

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
	enemy.max_hp = hp
	enemy.hp = hp
	_enemy_slot.add_child(enemy)

func _start_player_turn() -> void:
	if battle_over:
		return
	energy = MAX_ENERGY
	atk_buff = 0
	double_next = false

	# 手札を HAND_SIZE まで補充。
	for i in range(HAND_SIZE):
		var monster := deck.draw_card()
		if monster == null:
			break
		_add_card_to_hand(monster)

	# 次の敵ターンの行動を予告。
	var enc := Run.current_encounter
	enemy.set_intent(randi_range(int(enc["intent_min"]), int(enc["intent_max"])))
	_refresh()

func _add_card_to_hand(monster: MonsterData) -> void:
	var card := CardScene.instantiate() as CardUI
	card.data = monster
	_hand_container.add_child(card)
	card.command_selected.connect(_on_command_selected)
	card.fusion_toggled.connect(_on_fusion_toggled)

func _on_command_selected(card: CardUI, cmd: CommandData) -> void:
	if battle_over:
		return
	var cost := card.data.effective_cost(cmd)
	if energy < cost:
		return

	energy -= cost
	_apply_command(card.data, cmd)

	# 使用するたびに EXP（=成長速度分）を蓄積し、ライフサイクルを進める。
	var monster_name := card.data.monster_name
	var grew := card.data.gain_exp(card.data.growth_speed)
	if grew and not card.data.is_dead():
		_flash_message("%s は %s に成長した！" % [monster_name, card.data.stage_label()])

	# 合体候補に選ばれていたカードなら選択を解除しておく。
	_deselect_fusion(card)

	if card.data.is_dead():
		# 消滅：デッキから完全に除外し、捨札にも戻さない。
		deck.remove_card(card.data)
		_flash_message("%s は老いて消滅した…" % monster_name)
	else:
		# 通常使用：捨札へ送る。
		deck.discard_card(card.data)
	card.queue_free()

	if enemy.is_dead():
		_win()
		return
	_refresh()

func _apply_command(card_data: MonsterData, cmd: CommandData) -> void:
	match cmd.effect:
		CommandData.Effect.DAMAGE:
			var dmg := card_data.effective_power(cmd) + atk_buff
			if double_next:
				dmg *= 2
				double_next = false
			enemy.take_damage(dmg)
		CommandData.Effect.BUFF_ATK:
			atk_buff += card_data.effective_power(cmd)
		CommandData.Effect.DOUBLE_NEXT:
			double_next = true

func _on_end_turn_pressed() -> void:
	if battle_over:
		return
	_enemy_turn()

func _enemy_turn() -> void:
	# 敵が予告どおりに攻撃。
	player_hp = max(0, player_hp - enemy.intent_damage)
	_refresh()
	if player_hp <= 0:
		_lose()
		return

	# 手札を片付けて次のプレイヤーターンへ。
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
	if card in _fusion_selection:
		_deselect_fusion(card)
	elif _fusion_selection.size() < 2:
		_fusion_selection.append(card)
		card.set_fusion_selected(true)
	else:
		# すでに2枚選択済み。トグルを元に戻す。
		card.set_fusion_selected(false)
	_update_fuse_button()

func _deselect_fusion(card: CardUI) -> void:
	if card in _fusion_selection:
		_fusion_selection.erase(card)
		card.set_fusion_selected(false)
		_update_fuse_button()

func _update_fuse_button() -> void:
	if _fuse_button == null:
		return
	_fuse_button.text = "合体 (%d/2)" % _fusion_selection.size()
	_fuse_button.disabled = battle_over or _fusion_selection.size() != 2

func _on_fuse_pressed() -> void:
	if battle_over or _fusion_selection.size() != 2:
		return
	var card_a := _fusion_selection[0]
	var card_b := _fusion_selection[1]

	var child := MonsterFactory.fuse(card_a.data, card_b.data)

	# 両親はデッキから消滅。
	deck.remove_card(card_a.data)
	deck.remove_card(card_b.data)
	card_a.queue_free()
	card_b.queue_free()
	_fusion_selection.clear()

	# 子孫カードがデッキ（手札）に加わる。
	deck.hand.append(child)
	_add_card_to_hand(child)

	_flash_message("合体！ %s（%s %s）が誕生した" % [child.monster_name, child.rarity_label(), child.element_label()])
	_update_fuse_button()
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
	_hp_label.text = "プレイヤー HP: %d / %d" % [player_hp, player_max_hp]
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
	# 生き残ったデッキとHPをランへ書き戻し、報酬画面へ。
	await get_tree().create_timer(1.0).timeout
	Run.on_battle_won(deck.surviving_cards(), player_hp)

func _lose() -> void:
	battle_over = true
	_message_label.text = "敗北..."
	_message_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	_end_battle_input()
	await get_tree().create_timer(1.0).timeout
	Run.on_battle_lost()

func _end_battle_input() -> void:
	_end_turn_button.disabled = true
	_fuse_button.disabled = true
	for child in _hand_container.get_children():
		if child is CardUI:
			(child as CardUI).disable_all()
