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
        if g.city_index > 0: regional.sprite(c, foe, flash)
        elif g.wild_battle:
            var enemy_palette = { "O": "35434e", "G": "94a7b5", "L": "c6d4d8", "D": "62778c", "P": "72878b", "B": "c7934d", "Y": "fae1a7", "R": "cc7382", "W": "fff6e4", "E": "35434e"}
            if g.wild_index == 0: enemy_palette["L"] = "d1cddc"
            sprite(c, [GHOST, PIGEON, MIME][g.wild_index], foe, 4, enemy_palette, flash)
        else: sprite(c, CHEF, foe, 4, palette, flash)
    sprite(c, BOY, boy, 4, mine, ally_hit and fx_age < 0.1 and g.effects_on)
    if active:
        if g.battle_bomb > 0:
            var pot = foe + Vector2(-78, -6)
            block(c, pot.x - 17, pot.y - 20, 34, 20, "4f5963"); block(c, pot.x - 21, pot.y - 23, 42, 5, "7b8894")
            block(c, pot.x - 13, pot.y - 27 - int(g.clock_time * 3) % 2 * 3, 6, 6, "bfe9f2"); block(c, pot.x + 5, pot.y - 30 - int(g.clock_time * 3 + 1) % 2 * 3, 6, 6, "bfe9f2")
            c.txt(str(g.battle_bomb), pot.x - 17, pot.y - 4, 15, Color("fff4cd"), 34, HORIZONTAL_ALIGNMENT_CENTER)
        if g.battle_vuln > 0:
            for i in range(5): block(c, foe.x - 44 + i * 20, foe.y + 2 + (i % 2) * 3, 10, 5, "bfe9f2")
        if g.battle_charge:
            for i in range(3): block(c, boy.x - 18 + i * 14, boy.y - 142 - fmod(g.clock_time * 22 + i * 7, 16), 5, 9, "c98b4b")
    props.draw(c, boy, foe)
    if g.city_index > 0: regional.effects(c, boy, foe)
    if fx:
        var target = foe - Vector2(0, 54) if g.battle_fx_target == "enemy" else boy - Vector2(0, 60)
        var amount = ("+" if g.battle_fx_kind == "heal" else "−") + str(g.battle_fx_amount)
        if g.battle_fx_kind == "guard": amount = "버티기"
        if g.battle_fx_kind == "buff": amount = g.battle_fx_note

        var label = Rect2(foe.x - 118, foe.y - 88, 70, 32) if g.battle_fx_target == "enemy" else Rect2(boy.x + 46, boy.y - 157, 76, 32)
        if g.battle_fx_kind == "buff": label = Rect2(label.position.x - 18, label.position.y, label.size.x + 36, label.size.y)
        c.panel(label, Color("344943"), 3)
        c.txt(amount, label.position.x, label.position.y + 23, 16 if g.battle_fx_kind == "buff" else 20, Color("fff4cd"), label.size.x, HORIZONTAL_ALIGNMENT_CENTER)
