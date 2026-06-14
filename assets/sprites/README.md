# スプライトの置き方

PNG を以下の名前で置くと、カード／敵に自動表示されます（無ければ属性色の図形で代替）。

## モンスター（カード）
`assets/sprites/monsters/<モンスター名>.png`

例：
- `assets/sprites/monsters/フェンリル.png`
- `assets/sprites/monsters/サラマンダー.png`

モンスター名は図鑑（`game_design.html`）やコードのカタログ名と完全一致させてください。
合体で生まれた子孫（例：「フェサラの子」）はスプライト未用意なら属性色で表示されます。

## 敵
`assets/sprites/enemies/<敵名>.png`

例：
- `assets/sprites/enemies/ゴブリン.png`
- `assets/sprites/enemies/死の騎士.png`

ボスも接頭辞「【ボス】」は付けず、素の名前（例：`死の騎士.png`）で置きます。

## 推奨
- 透過PNG。サイズは目安でモンスター ~96px 角、敵 ~160px 角程度
- ドット絵がボケないよう、Godotの読み込みは Nearest フィルタにしています
- 名前は完全一致（全角/半角・表記ゆれに注意）

置けば次回起動時に自動で反映されます（コード変更不要）。
