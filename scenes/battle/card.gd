class_name CardUI
extends PanelContainer

## 手札に並ぶ1枚の「スキルカード」のUI。所属モンスター＋1スキルを表示する。

signal command_selected(card: CardUI)

var monster: MonsterData
var command: CommandData
var source: SkillCard
var enemy_element: int = MonsterData.Element.NONE

var _title: Label
var _stats: Label
var _exp_bar: ProgressBar
var _cmd_button: Button
var _stat_label: Label

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

	_refresh_texts()

func _refresh_texts() -> void:
	_title.text = "%s %s %s" % [monster.rarity_label(), monster.display_name(), monster.stage_label()]
	_stats.text = "属:%s A:%d D:%d I:%d" % [monster.element_label(), monster.effective_attack(), monster.effective_defense(), monster.effective_int()]
	_exp_bar.value = monster.exp_progress()
	var cmd_prefix := "⚡奥義 " if command.is_ultimate else ""
	_cmd_button.text = "▶ %s%s  (コスト%d)\n%s" % [cmd_prefix, command.command_name, monster.effective_cost(command), _command_text()]
	if command.is_ultimate:
		_cmd_button.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	var breakdown := _stat_breakdown()
	_stat_label.text = breakdown
	_stat_label.visible = breakdown != ""

func _make_visual() -> Control:
	var tex := SpriteLoader.monster(monster.monster_name)
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.custom_minimum_size = Vector2(0, 58)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	var v := monster.command_value(command)
	# 敵対象の技は「敵単体／敵全体」を明記する。
	var scope := command.target_label()
	var tgt := "【%s】" % scope if scope != "" else ""
	match command.effect:
		CommandData.Effect.DAMAGE:
			return "%s%dダメージ" % [tgt, v]
		CommandData.Effect.BUFF_ATK:
			return "このターンの与ダメージ+%d" % v
		CommandData.Effect.DOUBLE_NEXT:
			return "次のダメージを2倍にする"
		CommandData.Effect.HEAL:
			return "HPを%d回復" % v
		CommandData.Effect.GUARD:
			return "ブロック%dを得る" % v
		CommandData.Effect.PIERCE:
			return "%s防御無視で%dダメージ" % [tgt, v]
		CommandData.Effect.WEAKEN:
			return "%s攻撃力-%d" % [tgt, v]
		CommandData.Effect.ENERGY:
			return "エネルギー+%d" % command.power
		CommandData.Effect.POISON:
			return "%sに毒%dを付与" % [tgt, v]
		CommandData.Effect.BURN:
			return "%sを%dターン炎上(被ダメ1.5倍)" % [tgt, command.power]
		CommandData.Effect.FREEZE:
			return "%sを%d回凍結させる" % [tgt, command.power]
		CommandData.Effect.REGEN:
			return "再生%dを得る(毎ターン回復)" % v
	return command.description

func _stat_breakdown() -> String:
	var scale := monster.stat_scale_for(command)
	var ep := monster.effective_power(command)
	match command.effect:
		CommandData.Effect.DAMAGE, CommandData.Effect.PIERCE:
			return "(基礎%d＋ATK×%.1f)" % [ep, scale]
		CommandData.Effect.GUARD:
			return "(基礎%d＋DEF×%.1f)" % [ep, scale]
		CommandData.Effect.BUFF_ATK, CommandData.Effect.HEAL, CommandData.Effect.WEAKEN, \
		CommandData.Effect.POISON, CommandData.Effect.REGEN:
			return "(基礎%d＋INT×%.1f)" % [ep, scale]
	return ""

func _affinity_mark() -> String:
	var aff := MonsterData.affinity(monster.elements, enemy_element)
	if aff > 1.0:
		return " ▲有利"
	if aff < 1.0:
		return " ▽不利"
	return ""

func refresh(energy: int) -> void:
	_refresh_texts()
	_cmd_button.disabled = monster.effective_cost(command) > energy

func disable_all() -> void:
	if _cmd_button != null:
		_cmd_button.disabled = true
