extends Control

## ランの分岐マップ。行ごとに複数ノードがあり、エッジで繋がった次の行のノードを選んで進む。
## 状態は autoload の Run（map_rows / current_row / current_col）が保持する。

var _centers: Array = [] # _centers[r][c] = ノード中心座標（エッジ描画用）

func _ready() -> void:
	# マップはノード間の安全な地点なので、ここで自動セーブする。
	Run.save_game()
	_build_ui()
	Audio.play_bgm("res://assets/audio/bgm_map.ogg")

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.09)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var header := Label.new()
	header.text = "第 %d フロア      HP %d/%d      💰 %d      デッキ %d/%d" % [
		Run.current_floor, Run.player_hp, Run.player_max_hp, Run.gold, Run.deck.size(), Run.DECK_LIMIT,
	]
	header.position = Vector2(24, 20)
	header.add_theme_font_size_override("font_size", 18)
	add_child(header)

	# 設定・やり直しボタン（右上）
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	tools.position = Vector2(960, 16)
	add_child(tools)
	var settings := Button.new()
	settings.text = "設定"
	settings.pressed.connect(_on_settings)
	tools.add_child(settings)
	var restart := Button.new()
	restart.text = "最初から"
	restart.pressed.connect(_on_restart)
	tools.add_child(restart)

	_layout_nodes()

func _layout_nodes() -> void:
	_centers.clear()
	var rows: int = Run.map_rows.size()
	if rows == 0:
		return

	var top_y := 110.0
	var bottom_y := 650.0
	var left_x := 200.0
	var right_x := 1080.0
	var node_size := Vector2(160, 44)

	var nr := Run.next_row_index()
	var rc := Run.reachable_cols()

	for r in range(rows):
		var row: Array = Run.map_rows[r]
		var count: int = row.size()
		var centers_row: Array = []
		var y := top_y if rows == 1 else top_y + (bottom_y - top_y) * float(r) / float(rows - 1)
		for c in range(count):
			var x := (left_x + right_x) * 0.5 if count == 1 else left_x + (right_x - left_x) * float(c) / float(count - 1)
			var center := Vector2(x, y)
			centers_row.append(center)

			var node: Dictionary = row[c]
			var btn := Button.new()
			btn.text = _node_label(node)
			btn.custom_minimum_size = node_size
			btn.size = node_size
			btn.position = center - node_size * 0.5
			btn.add_theme_font_size_override("font_size", 13)

			var is_current: bool = (r == Run.current_row and c == Run.current_col)
			var is_reachable: bool = (r == nr and c in rc)
			btn.disabled = not is_reachable
			if is_current:
				btn.modulate = Color(1.0, 0.85, 0.3)        # 現在地
			elif is_reachable:
				btn.modulate = Color(1.0, 1.0, 1.0)          # 選択可能
			elif r <= Run.current_row:
				btn.modulate = Color(0.45, 0.45, 0.5)        # 通過済み
			else:
				btn.modulate = Color(0.6, 0.6, 0.66)         # 未到達
			if is_reachable:
				btn.pressed.connect(_on_node_pressed.bind(r, c))
			add_child(btn)
		_centers.append(centers_row)

	queue_redraw()

# エッジ（ノード間の道）を描画する。
func _draw() -> void:
	if _centers.is_empty():
		return
	for r in range(Run.map_rows.size() - 1):
		var row: Array = Run.map_rows[r]
		for c in range(row.size()):
			var from: Vector2 = _centers[r][c]
			for nc in row[c].get("next", []):
				var to: Vector2 = _centers[r + 1][int(nc)]
				var col := Color(0.28, 0.28, 0.36)
				var w := 2.0
				if r == Run.current_row and c == Run.current_col:
					col = Color(0.95, 0.82, 0.35) # 現在地から進める道
					w = 4.0
				elif r < Run.current_row:
					col = Color(0.2, 0.2, 0.24)   # 通過済み
				draw_line(from, to, col, w)

func _node_label(node: Dictionary) -> String:
	match int(node["type"]):
		Run.NodeType.BATTLE_ZAKO:
			return "⚔ %s" % node["name"]
		Run.NodeType.BATTLE_ELITE:
			return "★ %s" % node["name"]
		Run.NodeType.BATTLE_BOSS:
			return "👑 %s" % node["name"]
		Run.NodeType.REST_SHOP:
			return "🏕 休憩/店"
	return "？"

func _on_node_pressed(row: int, col: int) -> void:
	Audio.play_se("select")
	Run.choose_node(row, col)

func _on_settings() -> void:
	Run.settings_return = Run.SCENE_MAP
	get_tree().change_scene_to_file(Run.SCENE_SETTINGS)

func _on_restart() -> void:
	Run.delete_save()
	Run.restart_run()
