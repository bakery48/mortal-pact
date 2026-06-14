class_name DeckManager
extends RefCounted

## デッキ操作を担当。山札・手札・捨札を管理する。
## 設計書の「使ったカードは山札の一番下へ」を踏まえ、
## 使用カードは捨札に送り、山札が尽きたら捨札を再シャッフルして補充する。

var draw_pile: Array[MonsterData] = []
var hand: Array[MonsterData] = []
var discard_pile: Array[MonsterData] = []

const MONSTER_DIR := "res://resources/monsters"

## ラン状態が保持する既存デッキ（同一インスタンス）から戦闘用の山札を初期化する。
## カードの実体を共有するため、成長・老化はバトルをまたいで持続する。
func setup_from(cards: Array[MonsterData]) -> void:
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()
	draw_pile.assign(cards)
	draw_pile.shuffle()

## バトル終了時、消滅していない全カード（山札＋手札＋捨札）を集めて返す。
## これをラン状態のデッキに書き戻すことでデッキの継続性を保つ。
func surviving_cards() -> Array[MonsterData]:
	var result: Array[MonsterData] = []
	result.append_array(draw_pile)
	result.append_array(hand)
	result.append_array(discard_pile)
	return result

## 初期デッキを生成する。resources/monsters/*.tres を優先し、無ければコード生成。
static func load_monster_resources() -> Array[MonsterData]:
	var result: Array[MonsterData] = []
	var dir := DirAccess.open(MONSTER_DIR)
	if dir != null:
		for file_name in dir.get_files():
			# エディタ外（エクスポート後）では .tres が .remap になる場合があるため両対応。
			var clean := file_name.trim_suffix(".remap")
			if clean.ends_with(".tres") or clean.ends_with(".res"):
				var res := load(MONSTER_DIR + "/" + clean)
				if res is MonsterData:
					# 各カードは独立インスタンスにする（個別に成長するため）。
					result.append((res as MonsterData).duplicate(true))
	if result.is_empty():
		# リソースが無い場合はコードのファクトリにフォールバック。
		result.assign(MonsterFactory.starter_monsters())
	return result

func draw_card() -> MonsterData:
	if draw_pile.is_empty():
		_recycle_discard()
	if draw_pile.is_empty():
		return null
	var card: MonsterData = draw_pile.pop_front()
	hand.append(card)
	return card

func _recycle_discard() -> void:
	if discard_pile.is_empty():
		return
	draw_pile.assign(discard_pile)
	discard_pile.clear()
	draw_pile.shuffle()

## 使用したカードを手札から捨札へ。
func discard_card(card: MonsterData) -> void:
	hand.erase(card)
	discard_pile.append(card)

## 消滅した魔物をデッキから完全に除外する（捨札にも戻さない）。
func remove_card(card: MonsterData) -> void:
	hand.erase(card)
	draw_pile.erase(card)
	discard_pile.erase(card)

## ターン終了時、手札に残ったカードをまとめて捨札へ。
func discard_hand() -> void:
	for card in hand:
		discard_pile.append(card)
	hand.clear()
