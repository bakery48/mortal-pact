class_name CommandData
extends Resource

## 魔物が持つコマンド（技）1つ分のデータ。
## カードリソース（MonsterData）の中に複数保持される。

enum Effect {
	DAMAGE,      ## 敵に power ダメージ（atk_buff / 次2倍の影響を受ける）
	BUFF_ATK,    ## このターンの与ダメージに +power の補正
	DOUBLE_NEXT, ## 次に使うダメージコマンドを2倍にする
}

@export var command_name: String = "コマンド"
@export var cost: int = 1
@export var effect: Effect = Effect.DAMAGE
@export var power: int = 0
@export var description: String = ""

# --- セーブ/ロード用シリアライズ -------------------------------------------

func to_dict() -> Dictionary:
	return {
		"command_name": command_name,
		"cost": cost,
		"effect": int(effect),
		"power": power,
		"description": description,
	}

static func from_dict(d: Dictionary) -> CommandData:
	var c := CommandData.new()
	c.command_name = String(d.get("command_name", "コマンド"))
	c.cost = int(d.get("cost", 1))
	c.effect = int(d.get("effect", 0)) as Effect
	c.power = int(d.get("power", 0))
	c.description = String(d.get("description", ""))
	return c
