#!/usr/bin/env python3
# game_design.html に「魔物図鑑」セクションを生成して差し込む。
# データ元: resources/monsters/*.tres（初期デッキ5体） + scripts/monster_factory.gd の reward_pool（図鑑40体）
import re, pathlib, html

ROOT = pathlib.Path(__file__).resolve().parent.parent
ELEMENT = {0:"無",1:"炎",2:"水",3:"風",4:"土",5:"光",6:"闇"}
ELEMENT_NAME = {0:"NONE",1:"FIRE",2:"WATER",3:"WIND",4:"EARTH",5:"LIGHT",6:"DARK"}
ELEM_BY_NAME = {v:k for k,v in ELEMENT_NAME.items()}
RARITY = {0:"★",1:"★★",2:"★★★",3:"★★★★"}
EFFECT_NAME = {0:"DAMAGE",1:"BUFF_ATK",2:"DOUBLE_NEXT",3:"HEAL",4:"GUARD",5:"PIERCE",6:"WEAKEN",7:"ENERGY",
               8:"POISON",9:"BURN",10:"FREEZE",11:"REGEN"}
EFF_BY_NAME = {v:k for k,v in EFFECT_NAME.items()}

# MonsterData.POWER_SCALE と合わせる（能力値のデフレ係数）。
POWER_SCALE = 0.6
# 能力値として係数を掛ける効果（コスト/エネルギー/継続ターン系は掛けない）。
_SCALABLE = {0, 1, 3, 4, 5, 6, 8, 11}

def _scaled(eff, p):
    return round(p * POWER_SCALE) if eff in _SCALABLE else p

def cmd_text(eff, p):
    p = _scaled(eff, p)
    return {
        0:f"敵に{p}ダメージ", 1:f"与ダメージ+{p}", 2:"次のダメージ2倍",
        3:f"HP{p}回復", 4:f"ブロック{p}", 5:f"貫通{p}ダメージ",
        6:f"敵攻撃力-{p}", 7:f"エネルギー+{p}",
        8:f"毒{p}付与", 9:f"炎上{p}ターン", 10:f"凍結{p}回", 11:f"再生{p}",
    }[eff]

ELEM_CLASS = {0:"e-none",1:"e-fire",2:"e-ice",3:"e-wind",4:"e-earth",5:"e-light",6:"e-dark"}

def parse_tres(path):
    text = path.read_text(encoding="utf-8")
    subs = {}
    for blk in re.split(r"\n\[", text):
        blk = "[" + blk if not blk.startswith("[") else blk
        m = re.match(r'\[sub_resource type="Resource" id="([^"]+)"\]', blk)
        if not m: continue
        sid = m.group(1)
        def field(name, default=None):
            mm = re.search(rf'^{name} = (.+)$', blk, re.M)
            return mm.group(1).strip() if mm else default
        subs[sid] = {
            "name": field("command_name", '""').strip('"'),
            "cost": int(field("cost", "1")),
            "effect": int(field("effect", "0")),
            "power": int(field("power", "0")),
        }
    res = text.split("[resource]")[-1]
    def rf(name, default=""):
        mm = re.search(rf'^{name} = (.+)$', res, re.M)
        return mm.group(1).strip() if mm else default
    name = rf("monster_name", '""').strip('"')
    atk = int(rf("attack","0")); dfn = int(rf("defense","0"))
    growth = float(rf("growth_speed","1.0"))
    rarity = int(rf("rarity","0"))
    els = [int(x) for x in re.findall(r"\d+", rf("elements","[0]"))]
    order = re.findall(r'SubResource\("([^"]+)"\)', rf("commands","[]"))
    cmds = [subs[o] for o in order if o in subs]
    return dict(name=name, atk=atk, dfn=dfn, growth=growth, rarity=rarity, elements=els, cmds=cmds)

def parse_factory_pool(func_name):
    text = (ROOT/"scripts/monster_factory.gd").read_text(encoding="utf-8")
    # 関数本文を抽出
    start = text.index(f"static func {func_name}(")
    body = text[start:]
    end = body.index("\n\treturn list")
    body = body[:end]
    monsters = []
    # 各 _monster(...) ブロックを抽出
    for m in re.finditer(r'_monster\(\s*"([^"]+)",\s*(\d+),\s*(\d+),\s*MonsterData\.Element\.(\w+),\s*([\d.]+),\s*\[(.*?)\]\s*\)', body, re.S):
        name, atk, dfn, elem, growth, cmds_blk = m.groups()
        cmds = []
        for cm in re.finditer(r'_cmd\(\s*"([^"]+)",\s*(\d+),\s*CommandData\.Effect\.(\w+),\s*(\d+),', cmds_blk):
            cn, cc, ce, cp = cm.groups()
            cmds.append(dict(name=cn, cost=int(cc), effect=EFF_BY_NAME[ce], power=int(cp)))
        monsters.append(dict(name=name, atk=int(atk), dfn=int(dfn), growth=float(growth),
                             rarity=0, elements=[ELEM_BY_NAME[elem]], cmds=cmds))
    return monsters

def card_html(mon):
    els = "/".join(ELEMENT[e] for e in mon["elements"])
    eclass = ELEM_CLASS[mon["elements"][0]]
    cmds = ""
    for c in mon["cmds"]:
        cmds += f'<li><span class="cmd-name">{html.escape(c["name"])}</span> <span class="cmd-cost">コスト{c["cost"]}</span><br><span class="cmd-eff">{html.escape(cmd_text(c["effect"], c["power"]))}</span></li>'
    return f'''<div class="mon {eclass}">
  <div class="mon-head"><span class="mon-name">{html.escape(mon["name"])}</span><span class="mon-rarity">{RARITY[mon["rarity"]]}</span></div>
  <div class="mon-meta"><span class="tag">{els}</span> ATK {round(mon["atk"]*POWER_SCALE)} / DEF {round(mon["dfn"]*POWER_SCALE)} / 成長 {mon["growth"]:g}</div>
  <ul class="mon-cmds">{cmds}</ul>
</div>'''

# データ収集
starter_files = ["fenrir","salamander","golem","wisp","imp","yousei"]
starters = [parse_tres(ROOT/f"resources/monsters/{n}.tres") for n in starter_files]
catalog = parse_factory_pool("reward_pool")

section = ['<h2 id="monsters">魔物図鑑 <span class="badge">初期 %d種 + 図鑑 %d種</span></h2>' % (len(starters), len(catalog))]
section.append(f'<p>初期デッキの{len(starters)}体と、報酬・ショップで仲間にできる{len(catalog)}体。すべて幼体から育ち、合体で特性を継承できる。<br><small>※数値は全体デフレ係数({POWER_SCALE})適用後・成体時の目安。実際は成長段階で増減します。</small></p>')
section.append('<h3>初期デッキ</h3>')
section.append('<div class="mon-grid">' + "".join(card_html(m) for m in starters) + '</div>')
section.append('<h3>図鑑（報酬・ショップ）</h3>')
section.append('<div class="mon-grid">' + "".join(card_html(m) for m in catalog) + '</div>')
section_html = "\n".join(section)

CSS = '''
  .mon-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(230px, 1fr)); gap: 14px; margin: 16px 0; }
  .mon { background: var(--panel); border: 1px solid var(--border); border-left-width: 4px; border-radius: 10px; padding: 12px 14px; }
  .mon-head { display: flex; justify-content: space-between; align-items: baseline; }
  .mon-name { font-weight: 700; font-size: 1.05rem; }
  .mon-rarity { color: #f0c860; font-size: 0.85rem; }
  .mon-meta { color: var(--muted); font-size: 0.82rem; margin: 4px 0 8px; }
  .mon-meta .tag { display:inline-block; background: var(--panel-2); border:1px solid var(--border); border-radius:6px; padding:0 7px; margin-right:4px; color: var(--ink); }
  .mon-cmds { list-style: none; padding-left: 0; margin: 0; }
  .mon-cmds li { padding: 5px 0; border-top: 1px dashed var(--border); font-size: 0.85rem; }
  .mon-cmds li:first-child { border-top: none; }
  .cmd-name { color: var(--accent); font-weight: 600; }
  .cmd-cost { color: var(--muted); font-size: 0.75rem; }
  .cmd-eff { color: var(--ink); }
  .mon.e-fire { border-left-color: #e0654a; }
  .mon.e-ice { border-left-color: #5ab6e0; }
  .mon.e-wind { border-left-color: #7ad6a0; }
  .mon.e-earth { border-left-color: #c79a5a; }
  .mon.e-light { border-left-color: #f0d860; }
  .mon.e-dark { border-left-color: #a06ad0; }
  .mon.e-none { border-left-color: #8a8398; }
'''

path = ROOT/"game_design.html"
doc = path.read_text(encoding="utf-8")
# CSS を </style> 直前に追加（未追加なら）
if ".mon-grid" not in doc:
    doc = doc.replace("</style>", CSS + "</style>", 1)
# TOC に項目追加（未追加のときだけ）
if 'href="#monsters"' not in doc:
    doc = doc.replace('<li><a href="#ref">参考タイトル</a></li>',
                      '<li><a href="#monsters">魔物図鑑</a></li>\n      <li><a href="#ref">参考タイトル</a></li>', 1)
# 既存の図鑑セクションがあれば置換、無ければ footer 直前に挿入
if '<h2 id="monsters">' in doc:
    doc = re.sub(r'<h2 id="monsters">.*?(?=  <h2 id="ref">)', section_html + "\n\n  ", doc, flags=re.S)
else:
    doc = doc.replace('  <h2 id="ref">', "  " + section_html + "\n\n  <h2 id=\"ref\">", 1)
path.write_text(doc, encoding="utf-8")
print(f"inserted: starters={len(starters)} catalog={len(catalog)}")
