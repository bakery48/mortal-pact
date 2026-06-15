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

var enemies: Array[EnemyUI] = []
var _targeting := false        # 対象選択中フラグ
var _pending_card: CardUI = null # 対象選択待ちのカード
var _aim_line: Line2D          # 対象選択の矢印（軸）
var _aim_head: Polygon2D       # 対象選択の矢印（先端）

var _enemy_slot: HBoxContainer
var _hand_container: HBoxContainer
var _hp_label: Label
var _energy_label: Label
var _buff_label: Label
var _draw_button: Button
var _discard_button: Button
var _message_label: Label
var _event_label: Label
var _end_turn_button: Button

# 演出用
var _shake_target: Control
var _shake_base := Vector2.ZERO
var _shake_tween: Tween

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
	_spawn_enemies()
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
	_shake_target = root # 画面シェイク対象

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 12)
	root.add_child(main)

	# 敵エリア（上部・中央寄せ）
	_enemy_slot = HBoxContainer.new()
	_enemy_slot.alignment = BoxContainer.ALIGNMENT_CENTER
	_enemy_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_enemy_slot.add_theme_constant_override("separation", 16)
	main.add_child(_enemy_slot)

	# 勝敗メッセージ（中央）：勝敗確定時のみ visible にする
	_message_label = Label.new()
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_font_size_override("font_size", 36)
	_message_label.visible = false
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

	_draw_button = Button.new()
	_draw_button.pressed.connect(_open_draw_pile_view)
	status.add_child(_draw_button)

	_discard_button = Button.new()
	_discard_button.pressed.connect(_open_discard_pile_view)
	status.add_child(_discard_button)

	var deck_btn := Button.new()
	deck_btn.text = "デッキ"
	deck_btn.pressed.connect(_open_deck_view)
	status.add_child(deck_btn)

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

	# 対象選択の矢印（カード→カーソル）
	_aim_line = Line2D.new()
	_aim_line.width = 6.0
	_aim_line.default_color = Color(1.0, 0.85, 0.3, 0.85)
	_aim_line.z_index = 80
	_aim_line.visible = false
	add_child(_aim_line)
	_aim_head = Polygon2D.new()
	_aim_head.color = Color(1.0, 0.85, 0.3, 0.95)
	_aim_head.z_index = 80
	_aim_head.visible = false
	add_child(_aim_head)

# --- 戦闘フロー -------------------------------------------------------------

## 対象選択中、カードからカーソルへ矢印を伸ばす。
func _process(_delta: float) -> void:
	if _targeting and is_instance_valid(_pending_card):
		var from := _pending_card.get_global_rect().get_center()
		var to := get_global_mouse_position()
		_aim_line.points = PackedVector2Array([from, to])
		_aim_line.visible = true
		var dir := to - from
		if dir.length() > 1.0:
			dir = dir.normalized()
			var perp := dir.orthogonal()
			var s := 18.0
			_aim_head.polygon = PackedVector2Array([
				to, to - dir * s + perp * s * 0.6, to - dir * s - perp * s * 0.6,
			])
			_aim_head.visible = true
	else:
		_aim_line.visible = false
		_aim_head.visible = false

func _spawn_enemies() -> void:
	enemies.clear()
	var list: Array = Run.current_encounter.get("enemies", [])
	for enc in list:
		var hp := int(enc["max_hp"])
		var e := EnemyScene.instantiate() as EnemyUI
		e.enemy_name = ("【ボス】" if enc.get("is_boss", false) else "") + String(enc["name"])
		e.sprite_name = String(enc["name"]) # スプライト探索用（接頭辞なし）
		e.element = int(enc.get("element", MonsterData.Element.NONE))
		e.max_hp = hp
		e.hp = hp
		e.set_pattern(enc.get("pattern", []))
		_enemy_slot.add_child(e)
		e.plan_next() # 最初の行動を予告
		e.targeted.connect(_on_enemy_targeted)
		enemies.append(e)

## 敵が1体だけのときその属性を返す（カードの相性表示用）。複数なら無属性扱い。
func _solo_enemy_element() -> int:
	return enemies[0].element if enemies.size() == 1 else MonsterData.Element.NONE

## 敵クリック：対象選択中のときだけ、保留中のカードをその敵に適用する。
func _on_enemy_targeted(e: EnemyUI) -> void:
	if battle_over or not is_instance_valid(e):
		return
	if _targeting:
		_resolve_targeting(e)

## 敵を撃破・除去する。
func _remove_enemy(e: EnemyUI) -> void:
	if is_instance_valid(e):
		Run.record_unlock(e.sprite_name) # 倒した敵を図鑑に記録
	enemies.erase(e)
	if is_instance_valid(e):
		e.queue_free()

func _start_player_turn() -> void:
	if battle_over:
		return

	# プレイヤーの状態異常を処理（毒ダメージ・再生回復）。
	var pt := player_status.tick_turn()
	if pt.poison > 0:
		player_hp = maxi(0, player_hp - int(pt.poison))
		_popup(str(int(pt.poison)), _player_anchor(), Color(0.7, 0.5, 1.0))
		_flash_screen(Color(0.5, 0.1, 0.6), 0.2)
	if pt.regen > 0:
		player_hp = mini(player_max_hp, player_hp + int(pt.regen))
		_popup("+%d" % int(pt.regen), _player_anchor(), Color(0.5, 1.0, 0.5))
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
	card.enemy_element = _solo_enemy_element() # 敵が1体なら相性を表示
	_hand_container.add_child(card)
	card.command_selected.connect(_on_command_selected)

## 敵に作用する（対象が要る）コマンドか。
func _needs_target(cmd: CommandData) -> bool:
	match cmd.effect:
		CommandData.Effect.DAMAGE, CommandData.Effect.PIERCE, CommandData.Effect.WEAKEN, \
		CommandData.Effect.POISON, CommandData.Effect.BURN, CommandData.Effect.FREEZE:
			return true
		_:
			return false

## カードを選択：対象が要り敵が複数なら対象選択へ、それ以外は即発動。
func _on_command_selected(card: CardUI) -> void:
	if battle_over or _targeting:
		return
	var cost := card.monster.effective_cost(card.command)
	if energy < cost:
		return
	if _needs_target(card.command) and enemies.size() > 1:
		_begin_targeting(card)
	else:
		var tgt: EnemyUI = enemies[0] if not enemies.is_empty() else null
		_play_card(card, tgt)

## 対象選択モードに入る。敵にマーカーを出してクリック待ち。
func _begin_targeting(card: CardUI) -> void:
	_targeting = true
	_pending_card = card
	for e in enemies:
		e.set_targeted(true)
	_flash_message("対象の敵をクリック（右クリック/Esc/空白クリックで取消）")

func _resolve_targeting(e: EnemyUI) -> void:
	var card := _pending_card
	_cancel_targeting()
	if is_instance_valid(card):
		_play_card(card, e)

func _cancel_targeting() -> void:
	_targeting = false
	_pending_card = null
	for e in enemies:
		e.set_targeted(false)

## 対象選択中は 右クリック/Esc、または敵以外の場所の左クリックで取消。
func _unhandled_input(event: InputEvent) -> void:
	if not _targeting:
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and (mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_LEFT):
		_cancel_targeting()
		get_viewport().set_input_as_handled()
		return
	var key := event as InputEventKey
	if key != null and key.pressed and key.keycode == KEY_ESCAPE:
		_cancel_targeting()
		get_viewport().set_input_as_handled()

## カードを実際に使う（対象 tgt に対して）。
func _play_card(card: CardUI, tgt: EnemyUI) -> void:
	if battle_over:
		return
	var monster := card.monster
	var cmd := card.command
	var cost := monster.effective_cost(cmd)
	if energy < cost:
		return

	energy -= cost
	_apply_command(monster, cmd, tgt)
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

	if enemies.is_empty():
		_win()
		return
	_refresh()

## モンスターを消滅させ、デッキ・手札からスキルカードを一掃する。
func _kill_monster(monster: MonsterData) -> void:
	deck.remove_monster(monster)
	Run.deck.erase(monster)
	for child in _hand_container.get_children():
		if child is CardUI and (child as CardUI).monster == monster:
			child.queue_free()
	_flash_message("%s は老いて消滅した…" % monster.monster_name)

func _apply_command(card_data: MonsterData, cmd: CommandData, tgt: EnemyUI) -> void:
	var p := card_data.effective_power(cmd)
	match cmd.effect:
		CommandData.Effect.DAMAGE, CommandData.Effect.PIERCE:
			if tgt == null:
				return
			# 威力＋ATK補正にバフ・2倍・属性相性を反映。
			var base := card_data.command_value(cmd) + atk_buff
			if double_next:
				base *= 2
				double_next = false
			# 属性相性を反映（有利×1.5 / 不利×0.75）。
			var mult := MonsterData.affinity(card_data.elements, tgt.element)
			var dmg := roundi(base * mult)
			var dealt := tgt.take_damage_pierce(dmg) if cmd.effect == CommandData.Effect.PIERCE else tgt.take_damage(dmg)
			tgt.flash_hit()
			var dmg_color := Color(1.0, 0.5, 0.3) if mult > 1.0 else Color(1.0, 0.9, 0.5)
			_popup(str(dealt), tgt.get_global_rect().get_center(), dmg_color, 32 if mult > 1.0 else 26)
			if dealt >= 18:
				_screen_shake(5.0)
			if tgt.is_dead():
				_remove_enemy(tgt)
		CommandData.Effect.BUFF_ATK:
			atk_buff += p
		CommandData.Effect.DOUBLE_NEXT:
			double_next = true
		CommandData.Effect.HEAL:
			var healed := mini(player_max_hp, player_hp + p) - player_hp
			player_hp += healed
			if healed > 0:
				_popup("+%d" % healed, _player_anchor(), Color(0.5, 1.0, 0.5))
		CommandData.Effect.GUARD:
			player_block += card_data.command_value(cmd) # 威力＋DEF補正
		CommandData.Effect.WEAKEN:
			if tgt != null:
				tgt.apply_weaken(p)
		CommandData.Effect.ENERGY:
			energy += cmd.power # エネルギーは段階補正なしの素の値
		CommandData.Effect.POISON:
			if tgt != null:
				tgt.add_status(StatusSet.Status.POISON, p)
		CommandData.Effect.BURN:
			if tgt != null:
				tgt.add_status(StatusSet.Status.BURN, cmd.power) # 炎上は素のターン数
		CommandData.Effect.FREEZE:
			if tgt != null:
				tgt.add_status(StatusSet.Status.FREEZE, cmd.power) # 凍結は素の回数
		CommandData.Effect.REGEN:
			player_status.add(StatusSet.Status.REGEN, p)

func _on_end_turn_pressed() -> void:
	if battle_over or _targeting:
		return
	_enemy_turn()

func _enemy_turn() -> void:
	# 各敵が順番に行動する。
	for e: EnemyUI in enemies.duplicate():
		if not is_instance_valid(e) or e not in enemies:
			continue
		# 状態異常（毒ダメージ・再生回復）。
		var et := e.status.tick_turn()
		if et.poison > 0:
			var pd := e.take_fixed(int(et.poison))
			e.flash_hit()
			_popup(str(pd), e.get_global_rect().get_center(), Color(0.7, 0.5, 1.0))
		if et.regen > 0:
			e.heal(int(et.regen))
			_popup("+%d" % int(et.regen), e.get_global_rect().get_center(), Color(0.5, 1.0, 0.5))
		if e.is_dead():
			_remove_enemy(e)
			continue

		# 凍結中なら行動をスキップ。
		if e.status.consume_freeze():
			_flash_message("%s は凍結して動けない！" % e.enemy_name)
		else:
			e.reset_block()
			var dmg := e.execute()
			if e.intent_type == EnemyUI.Intent.POISON:
				player_status.add(StatusSet.Status.POISON, e.intent_value)
				_popup("毒%d" % e.intent_value, _player_anchor(), Color(0.7, 0.5, 1.0))
			elif dmg > 0:
				var actual := maxi(0, dmg - player_block)
				player_block = maxi(0, player_block - dmg)
				if actual > 0:
					player_hp = maxi(0, player_hp - actual)
					Audio.play_se("hit")
					_popup(str(actual), _player_anchor(), Color(1.0, 0.45, 0.45), 30)
					_flash_screen(Color(0.8, 0.1, 0.1))
					_screen_shake(8.0)
		_refresh()
		if player_hp <= 0:
			_lose()
			return

	if enemies.is_empty():
		_win()
		return

	# 生存している敵が次の行動を予告し、次のプレイヤーターンへ。
	for e in enemies:
		e.plan_next()
	deck.discard_hand()
	_clear_hand_nodes()
	_start_player_turn()

func _clear_hand_nodes() -> void:
	_cancel_targeting()
	for child in _hand_container.get_children():
		child.queue_free()

# --- 表示更新・終了処理 -----------------------------------------------------

# --- 演出（エフェクト）-----------------------------------------------------

func _player_anchor() -> Vector2:
	if _hp_label != null:
		return _hp_label.get_global_rect().get_center() + Vector2(0, 28)
	return Vector2(size.x * 0.3, size.y * 0.6)

## ダメージ・回復などの数字をその場にポップさせる。
func _popup(text: String, at: Vector2, color: Color, font_size := 26) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", font_size)
	l.z_index = 100
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	l.global_position = at - Vector2(12, 12)
	var t := create_tween()
	t.tween_property(l, "position", l.position + Vector2(randf_range(-10, 10), -46), 0.6).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.15)
	t.tween_callback(l.queue_free)

## 画面全体を一瞬その色で覆ってフェードさせる（被弾＝赤など）。
func _flash_screen(color: Color, strength := 0.32) -> void:
	var r := ColorRect.new()
	r.color = Color(color.r, color.g, color.b, strength)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.z_index = 90
	add_child(r)
	var t := create_tween()
	t.tween_property(r, "color:a", 0.0, 0.4)
	t.tween_callback(r.queue_free)

func _screen_shake(intensity := 8.0) -> void:
	if _shake_target == null:
		return
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_target.position = _shake_base
	_shake_tween = create_tween()
	for i in range(5):
		var off := Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		_shake_tween.tween_property(_shake_target, "position", _shake_base + off, 0.04)
	_shake_tween.tween_property(_shake_target, "position", _shake_base, 0.05)

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

	_draw_button.text = "山札:%d" % deck.draw_pile.size()
	_discard_button.text = "捨札:%d" % deck.discard_pile.size()

	var solo := _solo_enemy_element()
	for child in _hand_container.get_children():
		if child is CardUI:
			(child as CardUI).enemy_element = solo
			(child as CardUI).refresh(energy)

func _open_draw_pile_view() -> void:
	_open_pile_view("山札", deck.draw_pile, true)

func _open_discard_pile_view() -> void:
	_open_pile_view("捨札", deck.discard_pile, false)

## スキルカードの山（山札/捨札）の中身を一覧表示する。
func _open_pile_view(title_text: String, pile: Array[SkillCard], sorted: bool) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 420)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.text = "%s（%d枚）" % [title_text, pile.size()]
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close := Button.new()
	close.text = "✕ 閉じる"
	close.pressed.connect(func() -> void: overlay.queue_free())
	header.add_child(close)

	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var cards := pile.duplicate()
	if sorted:
		cards.sort_custom(func(a: SkillCard, b: SkillCard) -> bool:
			if a.monster.monster_name == b.monster.monster_name:
				return a.command.command_name < b.command.command_name
			return a.monster.monster_name < b.monster.monster_name)

	if cards.is_empty():
		var empty := Label.new()
		empty.text = "（カードがありません）"
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		list.add_child(empty)
	for sc: SkillCard in cards:
		var row := Label.new()
		row.text = "%s %s ／ ▸ %s（コスト%d）" % [
			sc.monster.monster_name, sc.monster.stage_label(),
			sc.command.command_name, sc.monster.effective_cost(sc.command),
		]
		row.add_theme_font_size_override("font_size", 14)
		list.add_child(row)

func _open_deck_view() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 420)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.text = "デッキ（%d体）" % Run.deck.size()
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close := Button.new()
	close.text = "✕ 閉じる"
	close.pressed.connect(func() -> void: overlay.queue_free())
	header.add_child(close)

	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for mon: MonsterData in Run.deck:
		var row := PanelContainer.new()
		list.add_child(row)

		var rm := MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]:
			rm.add_theme_constant_override("margin_" + side, 8)
		row.add_child(rm)

		var rv := VBoxContainer.new()
		rv.add_theme_constant_override("separation", 3)
		rm.add_child(rv)

		var name_row := HBoxContainer.new()
		rv.add_child(name_row)
		var name_lbl := Label.new()
		name_lbl.text = "%s %s %s" % [mon.rarity_label(), mon.monster_name, mon.stage_label()]
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_row.add_child(name_lbl)
		var elem_lbl := Label.new()
		elem_lbl.text = mon.element_label()
		elem_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
		name_row.add_child(elem_lbl)

		var stat_lbl := Label.new()
		var exp_pct := int(mon.exp_progress() * 100)
		stat_lbl.text = "ATK:%d  DEF:%d  EXP:%d%%" % [mon.effective_attack(), mon.effective_defense(), exp_pct]
		stat_lbl.add_theme_font_size_override("font_size", 12)
		stat_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
		rv.add_child(stat_lbl)

		for cmd: CommandData in mon.commands:
			var cmd_lbl := Label.new()
			cmd_lbl.text = "  ▸ %s（コスト%d）" % [cmd.command_name, mon.effective_cost(cmd)]
			cmd_lbl.add_theme_font_size_override("font_size", 12)
			rv.add_child(cmd_lbl)

func _win() -> void:
	battle_over = true
	_message_label.visible = true
	_message_label.text = "勝利！"
	_message_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	_end_turn_button.disabled = true
	for child in _hand_container.get_children():
		if child is CardUI:
			(child as CardUI).disable_all()
	Audio.play_se("win")
	await get_tree().create_timer(1.0).timeout
	Run.on_battle_won(player_hp)

func _lose() -> void:
	battle_over = true
	_message_label.visible = true
	_message_label.text = "敗北..."
	_message_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	_end_turn_button.disabled = true
	for child in _hand_container.get_children():
		if child is CardUI:
			(child as CardUI).disable_all()
	Audio.play_se("lose")
	await get_tree().create_timer(1.0).timeout
	Run.on_battle_lost()
