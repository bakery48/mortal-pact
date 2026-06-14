extends Control

## 設定画面。音量（マスター/BGM/SE）とフルスクリーンを調整し、
## Audio シングルトン経由で即時反映＆ user://settings.json に保存する。

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.09)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.custom_minimum_size = Vector2(440, 0)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "設定"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)

	_add_slider(vbox, "マスター音量", Audio.master_volume, _on_master_changed)
	_add_slider(vbox, "BGM 音量", Audio.bgm_volume, _on_bgm_changed)
	_add_slider(vbox, "SE 音量", Audio.se_volume, _on_se_changed)

	var fs := CheckButton.new()
	fs.text = "フルスクリーン"
	fs.button_pressed = Audio.fullscreen
	fs.toggled.connect(_on_fullscreen_toggled)
	vbox.add_child(fs)

	vbox.add_child(HSeparator.new())

	var back := Button.new()
	back.text = "戻る"
	back.pressed.connect(_on_back)
	vbox.add_child(back)

func _add_slider(parent: VBoxContainer, label_text: String, value: float, on_change: Callable) -> void:
	var row := VBoxContainer.new()
	parent.add_child(row)

	var head := HBoxContainer.new()
	row.add_child(head)
	var name_label := Label.new()
	name_label.text = label_text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	var value_label := Label.new()
	value_label.text = "%d%%" % roundi(value * 100.0)
	head.add_child(value_label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(0, 24)
	slider.set_meta("value_label", value_label)
	slider.set_meta("on_change", on_change)
	slider.value_changed.connect(_on_slider_changed.bind(slider))
	row.add_child(slider)

func _on_slider_changed(v: float, slider: HSlider) -> void:
	(slider.get_meta("value_label") as Label).text = "%d%%" % roundi(v * 100.0)
	(slider.get_meta("on_change") as Callable).call(v)

func _on_master_changed(v: float) -> void:
	Audio.set_master_volume(v)

func _on_bgm_changed(v: float) -> void:
	Audio.set_bgm_volume(v)

func _on_se_changed(v: float) -> void:
	Audio.set_se_volume(v)
	Audio.play_se("select") # 音量確認用に鳴らす

func _on_fullscreen_toggled(on: bool) -> void:
	Audio.set_fullscreen(on)

func _on_back() -> void:
	Audio.play_se("select")
	get_tree().change_scene_to_file(Run.SCENE_MAP)
