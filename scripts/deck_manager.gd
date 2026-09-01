class_name DeckManager
extends RefCounted

## 戦闘中のデッキ操作を担当。山札・手札・捨札を「スキルカード」単位で管理する。
## 1モンスターは所持コマンド数ぶんのスキルカードとして展開される
## （どのモンスターのどのスキルを引くかは手札次第）。

var draw_pile: Array[SkillCard] = []
var hand: Array[SkillCard] = []
var discard_pile: Array[SkillCard] = []

## モンスター群から、各コマンドを1枚のスキルカードに展開して山札を作る。
func setup_from(monsters: Array[MonsterData]) -> void:
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()
	for m in monsters:
		for c in m.commands:
			draw_pile.append(SkillCard.new(m, c))
	draw_pile.shuffle()

func draw_card() -> SkillCard:
	if draw_pile.is_empty():
		_recycle_discard()
	if draw_pile.is_empty():
		return null
	var card: SkillCard = draw_pile.pop_front()
	hand.append(card)
	return card

func _recycle_discard() -> void:
	if discard_pile.is_empty():
		return
	draw_pile.assign(discard_pile)
	discard_pile.clear()
	draw_pile.shuffle()

## 使用したスキルカードを手札から捨札へ。
func discard_card(card: SkillCard) -> void:
	hand.erase(card)
	discard_pile.append(card)

## ターン終了時、手札に残ったカードをまとめて捨札へ。
func discard_hand() -> void:
	for card in hand:
		discard_pile.append(card)
	hand.clear()

## 指定モンスターのスキルカードを全ての山から除去する（消滅・合体時）。
func remove_monster(monster: MonsterData) -> void:
	_purge(draw_pile, monster)
	_purge(hand, monster)
	_purge(discard_pile, monster)

func _purge(pile: Array[SkillCard], monster: MonsterData) -> void:
	var i := pile.size() - 1
	while i >= 0:
		if pile[i].monster == monster:
			pile.remove_at(i)
		i -= 1

## モンスターのスキルカードを手札に直接加える（合体直後など）。
func add_monster_to_hand(monster: MonsterData) -> Array[SkillCard]:
	var added: Array[SkillCard] = []
	for c in monster.commands:
		var sc := SkillCard.new(monster, c)
		hand.append(sc)
		added.append(sc)
	return added

## 初期デッキを生成する。
## 魔物データの定義元は MonsterFactory 一箇所に集約している
## （かつては resources/monsters/*.tres を優先していたが、二重管理で
##  スターターの調整が実機に反映されない不具合を招いたため廃止）。
static func load_monster_resources() -> Array[MonsterData]:
	var result: Array[MonsterData] = []
	result.assign(MonsterFactory.starter_monsters())
	return result
