class_name SkillCard
extends RefCounted

## デッキを構成する1枚の「スキルカード」。
## どのモンスター（owner）のどのコマンド（skill）かを保持する。
## EXP・成長段階・ATK/DEF・属性は owner モンスターが持ち、同じモンスターの
## 複数スキルカードで共有される。

var monster: MonsterData
var command: CommandData

func _init(m: MonsterData = null, c: CommandData = null) -> void:
	monster = m
	command = c
