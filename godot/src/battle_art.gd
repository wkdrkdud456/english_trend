extends RefCounted
const Props = preload ("res://scripts/battle_props.gd")
var props = Props.new()
const Regional = preload ("res://scripts/regional_battle.gd")
var regional = Regional.new()

const BOY = [
".......OOOOOOOO.......",
".....OOHHHHHHHHOO.....",
"....OHHHHHHHHHHHHO....",
"...OHHHLLLLHHHHHHHO...",
"...OHHLLLLLLHHHHHHO...",
"...OHHHHHHHHHHHHHHO...",
"...OHHHHHHHHHHHHHHO...",
"....OHHHHHHHHHHHHO....",
"....OSSHHHHHHHHSSO....",
"....OSSSSSSSSSSSSO....",
".....OSSSSSSSSSSO.....",
"......OSSSSSSSSO......",
".....OOTTTTTTTTOO.....",
"....OTTTTTTTTTTTTO....",
"...OTTTTTOOOOTTTTTO...",
"...OTTTOOBBBBOOTTTTO..",
"...OTTTOBYYYYBOTTTTO..",
"...OTTTOBYYYYBOTTTTO..",
"...OSSTOBBBBBBOTSSO...",
"...OSSSOBYYYYBOSSSO...",
"....OSSOBOOOOBOSSO....",
".....OOTOBBBBOTOO.....",
"......OTTTOOTTTO......",
"......ODDDDDDDDO......",
"......ODDDOODDDO......",
"......ODDDOODDDO......",
"......ODDDOODDDO......",
"......ODDDOODDDO......",
".....OOEEEOOEEEOO.....",
".....OEEEEOOEEEEO.....",
".....OOOOOOOOOOOO....."
]
const GHOST = [
".........OOOOOO.........",
".......OOWWWWWWOO.......",
"......OWWWWWWWWWWO......",
".....OWWWWLLWWWWWWO.....",
"....OWWWWWWWWWWWWWWO....",
"....OWWWWWWWWWWWWWWO....",
"...OWWWWWWWWWWWWWWWWO...",
"...OWWWOOOWWWOOOWWWWO...",
"...OWWWOOOWWWOOOWWWWO...",
"...OWWWOOOWWWOOOWWWWO...",
"...OWWWWWWWWWWWWWWWWO...",
"...OWWRRWWWWWWWRRWWWO...",
"..OWWWRRWWOOOWWRRWWWWO..",
".OWWWWWWWOOOOOWWWWWWWWO.",
"OWWWWWWWWOOOOOWWWWWWWWWO",
"OWWWWWWWWWOOOWWWWWWWWWWO",
".OOWWWWWWWWWWWWWWWWWOO..",
"...OWWWWWWWWWWWWWWWWO...",
"...OWWWWWWWWWWWWWWWWO...",
"...OWWWWLWWWWWWLWWWWO...",
"..OWWWWWLWWWWWWLWWWWWO..",
"..OWWWWLLWWWWWWLLWWWWO..",
".OWWWWWLLWWWWWWLLWWWWWO.",
".OWWWWOLLWWWWWWLLOWWWWO.",
".OWWWO..OLWWWWLO..OWWWO.",
"..OOO....OOOOOO....OOO.."
]
const PIGEON = [
"..........OOOOOO...........",
".........OGGGGGGO..........",
"........OGGLLLGGGO.........",
"........OGWWOGGGGO.........",
"........OGWWOGGGGO.........",
"........OGGGGGGGGOOO.......",
"........OGGGGGGGOBBBO......",
"........OPPPPPPGGOOO.......",
".......OGPPPPPPGGGO........",
"......OGGGPPPPGGGGGO.......",
".....OGGGGGGGGGGGGGGO......",
"....OGDDDDGGGGGGDDDDGO.....",
"...OGDDDDDGGGGGGDDDDDGO....",
"..OGDDODDDGGGGGGDDODDDGO...",
".OGDDOODDDGGGGGGDDOODDDGO..",
".OGDDOODDDGGGGGGDDOODDDGO..",
"..OOOGDDDGGGGGGGGDDGOOO....",
".....OGGGGLLLLGGGGGO.......",
"......OGGLLLLLLGGGO........",
"......OGGLLLLLLGGGO........",
".......OGGLLLLGGGO.........",
"........OOOOOOOOO..........",
"........OBB..OBBO..........",
"...OOOOOOOOOOOOOOOOOOOO....",
"..OBBYBBBYBBBYBBBYBBBYBO...",
"..OBBYBBBYBBBYBBBYBBBYBO...",
"...OOOOOOOOOOOOOOOOOOOO....",
".......OBBB...BBBBO........",
".......OOOO...OOOOO........"
]
const MIME = [
"..........OOOO.........",
"......OOOOOOOOOOO......",
".....OOOOOOOOOOOOO.....",
"....OOOOOOOOOOOOOOO....",
"....OOOOOOOOOOOOOOO....",
"......OWWWWWWWWWO......",
"......OWOWWWWOWWO......",
"......OWOWWWWOWWO......",
"......OWWWWWWWWWO......",
"......OWRWWWWWRWO......",
"......OWWWRRWWWWO......",
".......OWWWWWWWO.......",
".......OORRRROOO.......",
"......OWWRRRRWWWO......",
".....OWWWWORWWWWWO.....",
"....OOOOOOOROOOOOOO....",
"....OWWWWWORWWWWWWO....",
"..WWOWWOOOOOOOOOWWO....",
".WWWWOOOWWWWWWWOOO.....",
".WWWWOOWWWWWWWWWOO.....",
"..WW.OOOOOOOOOOOOWWW...",
".....OWWWWWWWWWWWWWWW..",
"......OOOOOOOOOOWWWWW..",
"......ODDDDDDDDO.WWW...",
"......ODDDOODDDO.......",
"......ODDDOODDDO.......",
"......ODDDOODDDO.......",
"......ODDDOODDDO.......",
".....OOEEEOOEEEOO......",
".....OEEEEOOEEEEO......",
".....OOOOOOOOOOOO......"
]
const CHEF = [
".......OOOOOOOO.......",
".....OOWWWWWWWWOO.....",
"....OWWWWWWWWWWWWO....",
"....OWWWWWWWWWWWWO....",
".....OWWWWWWWWWWO.....",
".....OCCCCCCCCCCO.....",
".....OOOOOOOOOOOO.....",
".....OSSSSSSSSSSO.....",
".....OSOOSSSSOOSO.....",
".....OSWOSSSSOWSO.....",
".....OSSSSSSSSSSO.....",
"......OSSOOOOSSO......",
"......OSSSSSSSSO......",
".....OOWWWRRWWOOO.....",
"....OWWWWWRRWWWWWO....",
"...OWWWWWWWWWWWWWWO...",
"...OWWWOWWWWWOWWWWO...",
"...OWWWOWWWWWOWWWWO...",
"...OWWWWWWWWWWWWWWO...",
"...OSSSOWWWWWOSSSSO...",
"...OSSSOWWWWWOSSSSO...",
"....OOOWWWWWWWOOOO....",
"......OWWWWWWWWO......",
"......OOOOOOOOOO......",
"......ODDDOODDDO......",
"......ODDDOODDDO......",
"......ODDDOODDDO......",
".....OOEEEOOEEEOO.....",
".....OEEEEOOEEEEO.....",
".....OOOOOOOOOOOO....."
]

func block(c: Control, x: float, y: float, width: float, height: float, color: String) -> void:
    c.draw_rect(Rect2(roundf(x), roundf(y), width, height), Color(color))

func sprite(c: Control, rows: Array, foot: Vector2, scale_px: int, palette: Dictionary, hit: bool = false) -> void:
    var origin = Vector2(roundf(foot.x - rows[0].length() * scale_px / 2.0), roundf(foot.y - rows.size() * scale_px))
    for y in range(rows.size()):
        for x in range(rows[y].length()):
            var key = rows[y][x]
            if palette.has(key):
                c.draw_rect(Rect2(origin + Vector2(x, y) * scale_px, Vector2.ONE * scale_px), Color("fff2c8") if hit else Color(palette[key]))

func ground(c: Control, foot: Vector2, width: float) -> void:
    block(c, foot.x - width / 2, foot.y - 4, width, 8, "4c755e")
    block(c, foot.x - width / 2 + 9, foot.y - 8, width - 18, 4, "4c755e")
    block(c, foot.x - width / 2 + 9, foot.y + 4, width - 18, 4, "4c755e")

func dash(t: float) -> float:

    if t < 0.1: return - t * 0.18
    if t < 0.23: return lerpf(-0.018, 1.0, (t - 0.1) / 0.13)
    if t < 0.36: return 1.0
    return maxf(0, 1.0 - (t - 0.36) / 0.2)

func draw(c: Control) -> void:
    var g = c.game
    var floor_y = c.h - 414

    block(c, 0, 0, c.w, c.h, "dde6c5")
    block(c, 0, 0, c.w, 190, "c3d9d0")
    block(c, 0, 174, c.w, 44, "aec7ba")
    block(c, 0, 218, c.w, c.h - 218, "a6bf87")
    for i in range(13):
        var x = i * 39 - 18
        block(c, x, 191 + (i % 3) * 6, 33, 37, "89aa98")
        block(c, x + 6, 185 + (i % 3) * 6, 21, 6, "89aa98")

    var tower = c.w * 0.58
    for i in range(15):
        var span = 4 + i * 1.8
        block(c, tower - span, 136 + i * 6, 3 + i * 0.18, 6, "8ca69b")
        block(c, tower + span, 136 + i * 6, 3 + i * 0.18, 6, "8ca69b")
    block(c, tower - 24, 203, 52, 5, "8ca69b")
    block(c, tower - 14, 181, 32, 4, "8ca69b")
    for i in range(48):
        var x = float( (i * 71 + 17) % 420) / 432 * c.w
        var y = 230 + float( (i * 47) % maxi(1, int(floor_y - 230)))
        block(c, x, y, 3, 6, "73976b"); block(c, x + 3, y + 3, 6, 3, "73976b")
    block(c, 0, floor_y + 14, c.w, c.h - floor_y, "e9e7cb")
    block(c, 0, floor_y + 10, c.w, 4, "789564")
    if g.city_index > 0: regional.background(c, floor_y)
    var foe = Vector2(c.w * 0.76, clampf(floor_y - 132, 286, 410))
    var boy = Vector2(c.w * 0.28, floor_y - 8)
    var active = g.state == "battle" or (g.state == "pause" and g.previous_state == "battle")
    var phase = g.battle_phase if active else "none"
    var t = g.battle_phase_time

    if phase == "enemy" and g.battle_intent not in ["brace", "rest"] and ( (g.city_index == 0 and g.wild_battle and g.wild_index == 1) or (g.city_index > 0 and regional.melee(g))):
        foe += (boy + Vector2(38, -10) - foe) * dash(t + 0.07)
    var fx = g.battle_fx_left > 0
    var fx_age = 0.65 - g.battle_fx_left
    var foe_hit = fx and g.battle_fx_target == "enemy"
    var ally_hit = fx and g.battle_fx_target == "party" and g.battle_fx_kind in ["haunt", "peck", "wall", "baguette", "regional"]
    if g.effects_on and fx_age < 0.22:
        var recoil = Vector2(4 if int(fx_age * 45) % 2 == 0 else -4, 0)
        if foe_hit: foe += recoil
        if ally_hit: boy += recoil
    if g.state != "battle_won": ground(c, foe, 94)
    ground(c, boy, 66)
    var palette = { "O": "343b41", "H": "493f40", "L": "68504a", "S": "e9b78a", "T": "4e9895", "D": "375b70", "E": "494a55", "B": "a5734e", "Y": "e0ba74", "W": "fff6dd", "C": "d9d6bb", "R": "ca7367"}
    # 장비와 도시 옷차림이 전투 모습에도 반영된다
    var mine = palette.duplicate()
    var lk = g.look(false)
    mine["T"] = lk.T.to_html(false); mine["D"] = lk.D.to_html(false); mine["E"] = lk.E.to_html(false)
    var weapon_tier = int(g.slot_gear(0).tier)
    if weapon_tier > 0:
        mine["B"] = ["", "7c8791", "d83d70", "c9951a"][weapon_tier]; mine["Y"] = ["", "c3ccd4", "ff7fa6", "ffe27a"][weapon_tier]
    if g.wild_battle and g.wild_grade > 0 and g.state != "battle_won":
        var tone = Color(g.GRADES[g.wild_grade].color)
        var mid = foe - Vector2(0, 58)
        for i in range(12):
            var a = i * TAU / 12.0 + g.clock_time * 0.9
            c.draw_rect(Rect2((mid + Vector2(cos(a) * 68, sin(a) * 52)).round() - Vector2(4, 4), Vector2(8, 8)), Color(tone, 0.55 + 0.3 * sin(g.clock_time * 4.0 + i)))
        c.panel(Rect2(foe.x - 40, foe.y + 12, 80, 22), tone, 3)
        c.txt(String(g.GRADES[g.wild_grade].tag), foe.x - 40, foe.y + 28, 13, Color("fff8e8"), 80, HORIZONTAL_ALIGNMENT_CENTER)
    if g.state != "battle_won":
        var flash = foe_hit and fx_age < 0.1 and g.effects_on
        if g.city_index > 0 or g.legend_battle or g.tower_battle: regional.sprite(c, foe, flash)
        elif g.wild_battle:
            var enemy_palette = { "O": "35434e", "G": "94a7b5", "L": "c6d4d8", "D": "62778c", "P": "72878b", "B": "c7934d", "Y": "fae1a7", "R": "cc7382", "W": "fff6e4", "E": "35434e"}
            if g.wild_index == 0: enemy_palette["L"] = "d1cddc"
            sprite(c, [GHOST, PIGEON, MIME][g.wild_index], foe, 4, enemy_palette, flash)
        else: sprite(c, CHEF, foe, 4, palette, flash)
    sprite(c, BOY, boy, 4, mine, ally_hit and fx_age < 0.1 and g.effects_on)
    job_gear(c, boy, g)
    if active:
        if g.battle_bomb > 0:
            var st = g.tier("soak")
            var pot = foe + Vector2(-84, -6)
            props.pot(c, pot, 1.0 + st * 0.14, st)
            for i in range(2 + st):
                block(c, pot.x - 15 + i * 9, pot.y - 30 - st * 3 - int(g.clock_time * 3 + i) % 2 * 4, 6, 6, ["bfe9f2", "ffe0b0", "e3c8ff", "fff2a8"][st])
            c.txt(str(g.battle_bomb), pot.x - 17, pot.y - 4, 15, Color("fff4cd"), 34, HORIZONTAL_ALIGNMENT_CENTER)
        if g.battle_vuln > 0:
            var sp = g.tier("soap")
            for i in range(5 + sp * 2):
                block(c, foe.x - 54 + i * (108.0 / (4 + sp * 2)), foe.y + 2 + (i % 2) * 3, 10, 5, ["bfe9f2", "ffd0e8", "d0ffd8", "fff2a8"][i % 4] if sp >= 2 else "bfe9f2")
            if sp >= 1:
                for i in range(sp + 1): props.bubble(c, foe + Vector2(-40 + i * 30, -20 - fmod(g.clock_time * 26 + i * 17, 70)), 8)
        if g.battle_charge:
            var cf = g.tier("coffee")
            for i in range(3 + cf): block(c, boy.x - 22 + i * (44.0 / (2 + cf)), boy.y - 142 - fmod(g.clock_time * (22 + cf * 6) + i * 7, 16 + cf * 6), 5, 9 + cf * 2, ["c98b4b", "e8974d", "ff7a2a", "ffd84a"][cf])
    props.draw(c, boy, foe)
    if g.city_index > 0: regional.effects(c, boy, foe)
    # 떠오르는 숫자
    for one in g.pops:
        var base = foe - Vector2(0, 118) if one.side == "enemy" else boy - Vector2(-34, 150)
        var rise = 1.0 - pow(1.0 - minf(1.0, one.age / 0.5), 2.0)
        var at = base + Vector2(one.dx, - rise * 44.0)
        at.x = clampf(at.x, 100, c.w - 100)
        var size = (30 if one.big else 22) + (8 if one.age < 0.1 else 0)
        var alpha = clampf((1.0 - one.age) / 0.3, 0, 1)
        for off in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
            c.txt(String(one.t), at.x - 100 + off.x, at.y + off.y, size, Color(0.13, 0.16, 0.17, alpha), 200, HORIZONTAL_ALIGNMENT_CENTER)
        c.txt(String(one.t), at.x - 100, at.y, size, Color(Color(String(one.color)), alpha), 200, HORIZONTAL_ALIGNMENT_CENTER)

# 전직하면 머리에 쓰는 것이 달라진다 (2차는 금빛)
func job_gear(c: Control, boy: Vector2, g) -> void:
    if g.job == 0: return
    var o = Vector2(boy.x - 44, boy.y - 124)
    var two = g.job_rank() >= 2
    var dark = "343b41"
    match g.job:
        1:
            var band = "ffd84a" if two else "f4f4f4"
            block(c, o.x + 10, o.y + 18, 68, 12, dark); block(c, o.x + 12, o.y + 20, 64, 8, band)
            block(c, o.x + 76, o.y + 18, 14, 16, dark); block(c, o.x + 78, o.y + 20, 10, 6, band); block(c, o.x + 80, o.y + 26, 6, 6, band)
            block(c, o.x + 40, o.y + 21, 8, 6, "d8483c")
        2:
            var cloth = "3a2a6a" if two else "7a4fc0"
            block(c, o.x - 2, o.y + 8, 92, 12, dark); block(c, o.x, o.y + 10, 88, 8, cloth)
            for i in range(6):
                var half = 30 - i * 5
                block(c, o.x + 44 - half - 2 + i * 2, o.y + 2 - i * 8 - 2, half * 2 + 4, 10, dark)
            for i in range(6):
                var half2 = 30 - i * 5
                block(c, o.x + 44 - half2 + i * 2, o.y + 2 - i * 8, half2 * 2, 8, cloth)
            block(c, o.x + 14, o.y + 2, 60, 5, "ffd84a" if two else "c9a8f6")
            block(c, o.x + 44, o.y - 22, 8, 8, "ffd84a")
        _:
            var metal = "ffcf3a" if two else "9aa4ad"
            block(c, o.x + 8, o.y - 6, 72, 30, dark); block(c, o.x + 10, o.y - 4, 68, 24, metal)
            block(c, o.x + 10, o.y - 4, 68, 6, Color(metal).lightened(0.4).to_html(false))
            block(c, o.x + 4, o.y + 18, 80, 8, dark); block(c, o.x + 6, o.y + 20, 76, 4, Color(metal).darkened(0.25).to_html(false))
            block(c, o.x + 36, o.y - 14, 16, 10, dark); block(c, o.x + 38, o.y - 12, 12, 8, metal)
    if two and g.effects_on:
        var tint = Color(String(g.JOBS[g.job].color))
        for i in range(6):
            var a = i * TAU / 6.0 + g.clock_time * 1.4
            c.draw_rect(Rect2((boy + Vector2(cos(a) * 46, -62 + sin(a) * 60)).round() - Vector2(3, 3), Vector2(6, 6)), Color(tint, 0.5 + 0.35 * sin(g.clock_time * 5.0 + i)))
