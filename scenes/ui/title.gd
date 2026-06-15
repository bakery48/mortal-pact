extends Control

## タイトル画面。ゲームのエントリーポイント。
## セーブがあれば「つづきから」、無ければ「はじめから」で開始する。

func _ready() -> void:
	_build_ui()
	Audio.play_bgm("res://assets/audio/bgm_title.ogg")

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.08)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	vbox.custom_minimum_size = Vector2(360, 0)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "Mortal Pact"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.78, 0.62, 0.92))
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "── 育てた魔物はいつか老いる。だからこそ、命をつなげ。──"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.66, 0.6, 0.74))
	vbox.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(spacer)

	if Run.has_save():
		var cont := _make_button("つづきから（B%dF / デッキ%d枚）" % [Run.current_floor, Run.deck_card_count()])
		cont.pressed.connect(Run.continue_game)
		vbox.add_child(cont)

	var new_btn := _make_button("はじめから")
	new_btn.pressed.connect(_on_new_game)
	vbox.add_child(new_btn)

	var codex_btn := _make_button("図鑑（%d種 発見）" % Run.unlocked_count())
	codex_btn.pressed.connect(_on_codex)
	vbox.add_child(codex_btn)

	var settings_btn := _make_button("設定")
	settings_btn.pressed.connect(_on_settings)
	vbox.add_child(settings_btn)

	var quit_btn := _make_button("終了")
	quit_btn.pressed.connect(_on_quit)
	vbox.add_child(quit_btn)

func _make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	return b

func _on_new_game() -> void:
	Audio.play_se("select")
	if Run.has_save():
		_confirm_new_game()
	else:
		Run.new_game()

## 既存セーブがある場合は上書き確認を出す。
func _confirm_new_game() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "現在の進行データは消えます。よろしいですか？"
	dialog.title = "はじめから"
	dialog.confirmed.connect(Run.new_game)
	add_child(dialog)
	dialog.popup_centered()

func _on_codex() -> void:
	Audio.play_se("select")
	get_tree().change_scene_to_file(Run.SCENE_CODEX)

func _on_settings() -> void:
	Audio.play_se("select")
	Run.settings_return = Run.SCENE_TITLE
	get_tree().change_scene_to_file(Run.SCENE_SETTINGS)

func _on_quit() -> void:
	get_tree().quit()
