class_name CommandData
extends Resource

## 魔物が持つコマンド（技）1つ分のデータ。
## カードリソース（MonsterData）の中に複数保持される。

enum Effect {
	DAMAGE,      ## 敵に power ダメージ（atk_buff / 次2倍の影響を受ける）
	BUFF_ATK,    ## このターンの与ダメージに +power の補正
	DOUBLE_NEXT, ## 次に使うダメージコマンドを2倍にする
	HEAL,        ## プレイヤーの HP を power 回復
	GUARD,       ## プレイヤーがブロック power を得る（敵の攻撃を軽減）
	PIERCE,      ## 敵のブロックを無視して power ダメージ
	WEAKEN,      ## 敵の攻撃力を power 下げる
	ENERGY,      ## このターンのエネルギーを power 回復
	POISON,      ## 敵に毒 power を付与（毎ターンダメージ）
	BURN,        ## 敵に炎上 power ターンを付与（被ダメ1.5倍）
	FREEZE,      ## 敵を power 回凍結（行動スキップ）
	REGEN,       ## プレイヤーに再生 power を付与（毎ターン回復）
}

@export var command_name: String = "コマンド"
@export var cost: int = 1
@export var effect: Effect = Effect.DAMAGE
@export var power: int = 0
@export var description: String = ""
## ステータス依存係数：ダメージ系はATK、ガード系はDEFにこの倍率を掛けて上乗せ。
## 負の値（既定）なら、コストに応じた自動係数を使う（重い技ほど依存が大きい）。
@export var stat_scale: float = -1.0
## 敵に作用する技で true なら全体対象（既定は単体）。
@export var target_all: bool = false

## 敵を対象に取る効果か（ダメージ・状態異常・弱体化）。
func targets_enemy() -> bool:
	match effect:
		Effect.DAMAGE, Effect.PIERCE, Effect.WEAKEN, Effect.POISON, Effect.BURN, Effect.FREEZE:
			return true
		_:
			return false

## カード説明用の対象ラベル（敵対象でなければ空）。
func target_label() -> String:
	if not targets_enemy():
		return ""
	return "敵全体" if target_all else "敵単体"

# --- セーブ/ロード用シリアライズ -------------------------------------------

func to_dict() -> Dictionary:
	return {
		"command_name": command_name,
		"cost": cost,
		"effect": int(effect),
		"power": power,
		"description": description,
		"stat_scale": stat_scale,
		"target_all": target_all,
	}

static func from_dict(d: Dictionary) -> CommandData:
	var c := CommandData.new()
	c.command_name = String(d.get("command_name", "コマンド"))
	c.cost = int(d.get("cost", 1))
	c.effect = int(d.get("effect", 0)) as Effect
	c.power = int(d.get("power", 0))
	c.description = String(d.get("description", ""))
	c.stat_scale = float(d.get("stat_scale", -1.0))
	c.target_all = bool(d.get("target_all", false))
	return c
