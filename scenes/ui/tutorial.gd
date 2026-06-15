extends Control

## スキップ可能なチュートリアル（複数ページのオーバーレイ）。
## タイトルに子として add_child して使う。初回は自動表示、ボタンからも開ける。
## 「スキップ」または最終ページの「はじめる」で既読フラグを立てて閉じる。

var _page := 0

var _title_label: Label
var _body_label: Label
var _page_label: Label
var _back_button: Button
var _next_button: Button

const PAGES := [
	{
		"title": "ようこそ、Mortal Pact へ",
		"body": "「育てた魔物はいつか老いる。だからこそ、命をつなげ。」\n\nこれは魔物を率いて戦うデッキ構築型ローグライト。\nこの遊び方はタイトルの「遊び方」からいつでも読み返せます。",
	},
	{
		"title": "① 戦闘の基本",
		"body": "手札の「スキルカード」を使って敵を倒します。\n\n・毎ターン エネルギーが3回復\n・カードのコスト分のエネルギーを払って発動\n・使ったカードは捨札へ。山札が尽きたら自動で再シャッフル\n・エネルギーを使い切ると自動でターン終了",
	},
	{
		"title": "② ターゲットと攻撃",
		"body": "敵が複数いるときは、スキルを押す → 矢印が伸びる → 対象の敵をクリックで命中。\n（右クリック・Esc・空白クリックで取消）\n敵が1体や非攻撃スキルは自動で対象が決まります。\n\nATK/DEFはスキル威力に上乗せされ、属性相性（有利×1.5/不利×0.75）も乗ります。",
	},
	{
		"title": "③ 成長と消滅",
		"body": "同じ魔物のスキルを使うほど、その魔物が成長します。\n\n🥚幼体 → 🌱若体 → ⚔️成体 → 🍂老体 → 💀消滅\n\n成体がピーク（最強）。使い込むとやがて老いて消滅し、デッキから除外されます。",
	},
	{
		"title": "④ 合体（血統強化）",
		"body": "休憩/ショップで、成体・老体の2体を合体できます。\n\n・「血統（残る側）」と「相手（消える側）」を選ぶ\n・名前と属性は血統を引き継ぐ\n・+値が加算され強化（例：フェンリル×ピクシー＝フェンリル+1）\n・固有2スキル＋両親から継承を選択。合体後は幼体に戻って再育成",
	},
	{
		"title": "⑤ マップを進む",
		"body": "分岐マップを選んで進みます。\n\n⚔ バトル（雑魚・エリート・ボス）\n🏕 休憩 / ショップ（HP回復・購入・合体）\n\nボスを倒すと次のフロアへ（敵が強化、デッキは継続）。",
	},
	{
		"title": "⑥ 継承と図鑑（命をつなぐ）",
		"body": "HPが0になるとランは終了。でも血脈は続きます。\n\n・倒れたとき、デッキから最大6体を選んで次のランへ引き継げる（幼体に戻る）\n・出会った魔物（倒した敵・仲間にした魔物）はタイトルの「図鑑」に記録されます",
	},
	{
		"title": "さあ、始めよう",
		"body": "タイトルの「はじめから」で冒険を開始。\n育て、つなぎ、より強い血統を未来へ託しましょう。",
	},
]

func _ready() -> void:
	_build_ui()
	_refresh()

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 420)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var head := HBoxContainer.new()
	vbox.add_child(head)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 26)
	_title_label.add_theme_color_override("font_color", Color(0.82, 0.66, 0.92))
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title_label)

	var skip := Button.new()
	skip.text = "スキップ ✕"
	skip.pressed.connect(_close)
	head.add_child(skip)

	vbox.add_child(HSeparator.new())

	_body_label = Label.new()
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_font_size_override("font_size", 16)
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	vbox.add_child(_body_label)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	vbox.add_child(foot)

	_page_label = Label.new()
	_page_label.add_theme_color_override("font_color", Color(0.65, 0.66, 0.72))
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_page_label)

	_back_button = Button.new()
	_back_button.text = "← 戻る"
	_back_button.pressed.connect(_on_back)
	foot.add_child(_back_button)

	_next_button = Button.new()
	_next_button.pressed.connect(_on_next)
	foot.add_child(_next_button)

func _refresh() -> void:
	var p: Dictionary = PAGES[_page]
	_title_label.text = String(p["title"])
	_body_label.text = String(p["body"])
	_page_label.text = "%d / %d" % [_page + 1, PAGES.size()]
	_back_button.disabled = _page == 0
	_next_button.text = "はじめる ▶" if _page == PAGES.size() - 1 else "次へ →"

func _on_back() -> void:
	if _page > 0:
		_page -= 1
		_refresh()

func _on_next() -> void:
	if _page < PAGES.size() - 1:
		_page += 1
		_refresh()
	else:
		_close()

func _close() -> void:
	Run.mark_tutorial_done()
	Audio.play_se("select")
	queue_free()
