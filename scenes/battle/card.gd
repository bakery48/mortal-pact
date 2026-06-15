class_name CardUI
extends PanelContainer

## 手札に並ぶ1枚の「スキルカード」のUI。所属モンスター＋1スキルを表示する。
## 同じモンスターの別スキルは別カードとして並ぶ。
## battle_manager が monster / command をセットしてから add_child する。

signal command_selected(card: CardUI)
## 合体候補としての選択トグル（成体・老体のみ）。
signal fusion_toggled(card: CardUI)

var monster: MonsterData
var command: CommandData
## 山札側の対応エントリ（捨札へ送る際に使う）。
var source: SkillCard
## このバトルの敵の属性（相性表示用）。
var enemy_element: int = MonsterData.Element.NONE

var _title: Label
var _stats: Label
var _exp_bar: ProgressBar
var _cmd_button: Button
var _stat_label: Label
var _select_button: Button
var _selected := false

func _ready() -> void:
	custom_minimum_size = Vector2(190, 0)
	if monster != null and command != null:
		_build()

func _build() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_title)

	# スプライト（あれば）／無ければ属性色の図形プレースホルダ。
	vbox.add_child(_make_visual())

	_stats = Label.new()
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_stats)

	_exp_bar = ProgressBar.new()
	_exp_bar.max_value = 1.0
	_exp_bar.show_percentage = false
	_exp_bar.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(_exp_bar)

	vbox.add_child(HSeparator.new())

	_cmd_button = Button.new()
	_cmd_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cmd_button.pressed.connect(func() -> void: command_selected.emit(self))
	vbox.add_child(_cmd_button)

	_stat_label = Label.new()
	_stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stat_label.add_theme_font_size_override("font_size", 11)
	_stat_label.add_theme_color_override("font_color", Color(0.55, 0.6, 0.65))
	vbox.add_child(_stat_label)

	_select_button = Button.new()
	_select_button.toggle_mode = true
	_select_button.pressed.connect(func() -> void: fusion_toggled.emit(self))
	vbox.add_child(_select_button)

	_refresh_texts()

## モンスターの現在状態に合わせて表示を更新する。
func _refresh_texts() -> void:
	_title.text = "%s %s %s" % [monster.rarity_label(), monster.monster_name, monster.stage_label()]
	_stats.text = "属性:%s  ATK:%d DEF:%d" % [monster.element_label(), monster.effective_attack(), monster.effective_defense()]
	_exp_bar.value = monster.exp_progress()
	_cmd_button.text = "▶ %s  (コスト%d)\n%s" % [command.command_name, monster.effective_cost(command), _command_text()]
	var breakdown := _stat_breakdown()
	_stat_label.text = breakdown
	_stat_label.visible = breakdown != ""
	if monster.can_fuse():
		if not _selected:
			_select_button.text = "合体候補にする"
	else:
		_select_button.text = "合体は成体/老体のみ"
		_select_button.disabled = true

## スプライト or プレースホルダのビジュアルを作る。
func _make_visual() -> Control:
	var tex := SpriteLoader.monster(monster.monster_name)
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.custom_minimum_size = Vector2(0, 58)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST # ドット絵をくっきり
		return tr
	var box := ColorRect.new()
	box.color = SpriteLoader.element_color(monster.elements[0] if not monster.elements.is_empty() else MonsterData.Element.NONE)
	box.custom_minimum_size = Vector2(0, 58)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_child(cc)
	var l := Label.new()
	l.text = monster.element_label()
	l.add_theme_font_size_override("font_size", 28)
	cc.add_child(l)
	return box

func _command_text() -> String:
	var p := monster.effective_power(command)
	match command.effect:
		CommandData.Effect.DAMAGE:
			return "敵に%dダメージ%s" % [monster.command_value(command), _affinity_mark()]
		CommandData.Effect.BUFF_ATK:
			return "このターンの与ダメージ+%d" % p
		CommandData.Effect.DOUBLE_NEXT:
			return "次のダメージを2倍にする"
		CommandData.Effect.HEAL:
			return "HPを%d回復" % p
		CommandData.Effect.GUARD:
			return "ブロック%dを得る" % monster.command_value(command)
		CommandData.Effect.PIERCE:
			return "防御無視で%dダメージ%s" % [monster.command_value(command), _affinity_mark()]
		CommandData.Effect.WEAKEN:
			return "敵の攻撃力-%d" % p
		CommandData.Effect.ENERGY:
			return "エネルギー+%d" % command.power
		CommandData.Effect.POISON:
			return "敵に毒%dを付与" % p
		CommandData.Effect.BURN:
			return "敵を%dターン炎上(被ダメ1.5倍)" % command.power
		CommandData.Effect.FREEZE:
			return "敵を%d回凍結させる" % command.power
		CommandData.Effect.REGEN:
			return "再生%dを得る(毎ターン回復)" % p
	return command.description

## ATK/DEF由来のボーナスが存在するとき、内訳を小さく表示するためのテキスト。
func _stat_breakdown() -> String:
	var scale := monster.stat_scale_for(command)
	match command.effect:
		CommandData.Effect.DAMAGE, CommandData.Effect.PIERCE:
			if monster.damage_bonus(command) <= 0:
				return ""
			return "(基礎%d＋ATK×%.1f)" % [monster.effective_power(command), scale]
		CommandData.Effect.GUARD:
			if monster.guard_bonus(command) <= 0:
				return ""
			return "(基礎%d＋DEF×%.1f)" % [monster.effective_power(command), scale]
	return ""

func _affinity_mark() -> String:
	var aff := MonsterData.affinity(monster.elements, enemy_element)
	if aff > 1.0:
		return " ▲有利"
	if aff < 1.0:
		return " ▽不利"
	return ""

## 現在のエネルギーに応じて表示と使用可否を更新する。
func refresh(energy: int) -> void:
	_refresh_texts()
	_cmd_button.disabled = monster.effective_cost(command) > energy

## 合体候補としての選択状態を反映する。
func set_fusion_selected(value: bool) -> void:
	_selected = value
	if _select_button != null:
		_select_button.button_pressed = value
		if monster.can_fuse():
			_select_button.text = "✔ 合体候補" if value else "合体候補にする"
	modulate = Color(1.0, 0.9, 0.4) if value else Color.WHITE

func disable_all() -> void:
	if _cmd_button != null:
		_cmd_button.disabled = true
	if _select_button != null:
		_select_button.disabled = true
