extends Control

## 結果画面。Run.last_result に応じてクリア／ゲームオーバーを表示する。

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var is_clear := Run.last_result == "clear"

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.09, 0.07) if is_clear else Color(0.10, 0.04, 0.05)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	var button := Button.new()

	if is_clear:
		title.text = "第 %d フロア クリア！" % Run.current_floor
		title.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
		button.text = "次のフロアへ"
		button.pressed.connect(Run.next_floor)
	else:
		title.text = "ゲームオーバー"
		title.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
		button.text = "新たなランを始める"
		button.pressed.connect(Run.restart_run)

	vbox.add_child(title)

	var info := Label.new()
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.text = "到達フロア: %d    所持金: %d    デッキ: %d枚" % [Run.current_floor, Run.gold, Run.deck_card_count()]
	vbox.add_child(info)

	var btn_box := CenterContainer.new()
	btn_box.add_child(button)
	vbox.add_child(btn_box)
