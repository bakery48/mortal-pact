class_name MonsterData
extends Resource

## 1枚の魔物カードのデータ。
## フェーズ2以降のライフサイクル（EXP・成長段階）を見越して
## stage / exp フィールドも持たせてあるが、フェーズ1では表示のみ。

@export var monster_name: String = "魔物"
@export var attack: int = 10
@export var defense: int = 5
## 成長段階（幼体 / 若体 / 成体 / 老体）。フェーズ1では固定値。
@export var stage: String = "成体"
## 蓄積経験値。フェーズ2の段階移行で使用予定。
@export var exp: int = 0
@export var commands: Array[CommandData] = []
