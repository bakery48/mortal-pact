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
var _end_turn_button: Button

func _ready() -> void:
	_build_ui()
	deck.build_starter_deck()
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

	_end_turn_button = Button.new()
	_end_turn_button.text = "ターン終了"
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	status.add_child(_end_turn_button)

	# 手札エリア（下部・中央寄せ）
	_hand_container = HBoxContainer.new()
	_hand_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_hand_container.add_theme_constant_override("separation", 12)
	main.add_child(_hand_container)

# --- 戦闘フロー -------------------------------------------------------------

func _spawn_enemy() -> void:
	enemy = EnemyScene.instantiate() as EnemyUI
	enemy.enemy_name = "腐肉喰らい"
	enemy.max_hp = 60
	enemy.hp = 60
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
	enemy.set_intent(randi_range(8, 14))
	_refresh()

func _add_card_to_hand(monster: MonsterData) -> void:
	var card := CardScene.instantiate() as CardUI
	card.data = monster
	_hand_container.add_child(card)
	card.command_selected.connect(_on_command_selected)

func _on_command_selected(card: CardUI, cmd: CommandData) -> void:
	if battle_over:
		return
	if energy < cmd.cost:
		return

	energy -= cmd.cost
	_apply_command(cmd)

	# 使用したカードは捨札へ送り、手札から取り除く。
	deck.discard_card(card.data)
	card.queue_free()

	if enemy.is_dead():
		_win()
		return
	_refresh()

func _apply_command(cmd: CommandData) -> void:
	match cmd.effect:
		CommandData.Effect.DAMAGE:
			var dmg := cmd.power + atk_buff
			if double_next:
				dmg *= 2
				double_next = false
			enemy.take_damage(dmg)
		CommandData.Effect.BUFF_ATK:
			atk_buff += cmd.power
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
	for child in _hand_container.get_children():
		child.queue_free()

# --- 表示更新・終了処理 -----------------------------------------------------

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

func _lose() -> void:
	battle_over = true
	_message_label.text = "敗北..."
	_message_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	_end_battle_input()

func _end_battle_input() -> void:
	_end_turn_button.disabled = true
	for child in _hand_container.get_children():
		if child is CardUI:
			(child as CardUI).disable_all()
