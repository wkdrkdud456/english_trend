extends RefCounted
const Pixels = preload ("res://scripts/legacy_pixels.gd")
const Sprites = preload ("res://scripts/sprite_data.gd")
var tiles: Dictionary = {}

func box(c, x, y, w, h, color) -> void:
    c.draw_rect(Rect2(roundf(x), roundf(y), w, h), Color(color))

func art_id(g) -> String:
    if g.legend_battle: return "legend" + str(g.city_index)
    return g.city().mobs[g.wild_index].art if g.wild_battle else g.city().boss.art

func melee(g) -> bool:
    return art_id(g) in ["scorpion", "gladiator", "taxi", "donkey", "tuberat", "kangaroo", "streetcat", "marco"]

func sprite(c, foot: Vector2, hit: bool) -> void:
    var id = art_id(c.game)
    if not tiles.has(id):
        var cells = {}; var minp = Vector2(999, 999); var maxp = Vector2(-999, -999)
        for part in (Sprites.PARTS[id] if Sprites.PARTS.has(id) else Pixels.PARTS[id]):
            for x in range(part[0], part[0] + part[2]):
                for y in range(part[1], part[1] + part[3]):
                    var p = Vector2i(x, y); cells[p] = part[4]; minp = minp.min(Vector2(p)); maxp = maxp.max(Vector2(p) + Vector2.ONE)
        var outline = {}
        for p in cells:
            for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
                if not cells.has(p + d): outline[p + d] = "35434e"
        tiles[id] = [cells, outline, minp, maxp]
    var item = tiles[id]; var scale_px = 5; var o = (foot - Vector2( (item[2].x + item[3].x) * 0.5, item[3].y) * scale_px).round()
    for layer in [item[1], item[0]]:
        for p in layer: c.draw_rect(Rect2(o + Vector2(p) * scale_px, Vector2.ONE * scale_px), Color("fff2c8") if hit else Color(layer[p]))

func background(c, floor_y: float) -> void:
    var g = c.game; var pal = g.city().pal; var w = c.w
    box(c, 0, 0, w, c.h, pal.g0); box(c, 0, 0, w, 221, pal.sky)
    var col = Color(pal.w2).lerp(Color(pal.sky), 0.38).to_html(); var light = Color(pal.w0).lerp(Color(pal.sky), 0.25).to_html()
    match g.city_index:
        1:
            for x in [30, w - 60]:
                for j in range(3): box(c, x + j * 12, 175 + j * 8, 5, 80, pal.t1)
            for x in [w * 0.48, w * 0.72]: box(c, x, 170, 9, 80, col)
            box(c, w * 0.43, 165, w * 0.34, 10, pal.r1); box(c, w * 0.45, 186, w * 0.3, 6, pal.r1)
        2:
            for j in range(16):
                box(c, 80 - j * 4, 164 + j * 5, 8 + j * 8, 5, col); box(c, 290 - j * 3, 184 + j * 4, 6 + j * 6, 4, light)
        3:
            box(c, 30, 188, w - 60, 55, col)
            for x in range(40, int(w - 30), 24):
                box(c, x, 201, 13, 36, pal.sky); box(c, x + 3, 197, 7, 4, pal.sky)
            for y in [187, 212, 242]: box(c, 28, y, w - 56, 5, light)
        4:
            for i in range(11):
                var x = i * 43; var hh = 37 + (i * 23) % 65; box(c, x, 245 - hh, 34, hh, col)
                for y in range(int(252 - hh), 237, 13):
                    for xx in [7, 20]: box(c, x + xx, y, 5, 6, light)
        5:
            for j in range(3):
                for i in range(45): box(c, i * 10, 180 + sin(i * 0.15 + j) * 12 + j * 13, 10, 5, ["80c8b4", "a0aed5", "bbdbbd"][j])
            for i in range(8): box(c, i * 64 - 13, 218 + i % 3 * 7, 55, 26, light)
        6:
            box(c, 0, 202, w, 65, pal.a1)
            for x in [40, 140, 270, 360]:
                box(c, x, 203, 49, 42, light); box(c, x + 8, 192, 33, 12, pal.a2); box(c, x + 17, 186, 15, 6, pal.a2); box(c, x + 18, 221, 12, 24, pal.a2)
        7:
            box(c, 245, 163, 35, 83, col); box(c, 239, 180, 47, 32, light); box(c, 247, 185, 31, 23, "e9dcad")
            box(c, 261, 188, 3, 12, col); box(c, 261, 198, 10, 3, col); box(c, 254, 149, 17, 14, col)
            for i in range(25): box(c, i * 19, 179 + (i * 23) % 65, 1, 10, "a8b7c3")
        8:
            box(c, 0, 214, w, 52, pal.a1)
            for i in range(4):
                for j in range(10): box(c, 90 + i * 39 + j * 2, 176 + j * 7, 7 + j * 3, 7, light)
        9:
            box(c, 262, 157, 6, 94, col); box(c, 247, 174, 36, 13, light); box(c, 262, 143, 6, 14, pal.r1)
            for x in [35, 113, 322]:
                box(c, x, 222, 65, 28, light); box(c, x - 7, 216, 79, 6, col); box(c, x + 3, 210, 59, 6, col); box(c, x + 12, 205, 41, 5, col)
    for i in range(37):
        var x = (i * 71 + 17) % int(w); var y = 269 + (i * 47) % maxi(1, int(floor_y - 279))
        box(c, x, y, 7, 3, pal.g1)
    box(c, 0, floor_y + 10, w, 4, pal.g2); box(c, 0, floor_y + 14, w, c.h - floor_y, pal.p0)

func prop(c, p: Vector2, kind: String, angle: float = 0) -> void:
    c.draw_set_transform(p.round(), angle, Vector2.ONE)
    match kind:
        "ninja":
            box(c, -17, -10, 34, 21, "334c3b"); box(c, -15, -8, 30, 10, "f6ead6"); box(c, -15, 2, 30, 7, "e88670"); box(c, -4, -8, 8, 17, "405849")
        "bamboo":
            box(c, -22, -5, 44, 10, "719950")
            for x in [-12, 0, 12]: box(c, x, -6, 3, 12, "c1d599")
        "mummy":
            for i in range(5): box(c, -22 + i * 9, -6 + (i % 2) * 4, 11, 10, "e9dfc4"); box(c, -21 + i * 9, -4 + (i % 2) * 4, 9, 2, "bcaa89")
        "snowtroll", "aurorafox":
            box(c, -11, -14, 22, 28, "c8dfeb"); box(c, -15, -10, 30, 20, "eaf4f9"); box(c, -8, -10, 10, 8, "ffffff")
        "squirrel":
            box(c, -10, -5, 20, 17, "b08050"); box(c, -13, -8, 26, 8, "694b3d"); box(c, -2, -15, 4, 8, "694b3d")
        "wzombie", "buchang", "kenji":
            box(c, -15, -18, 30, 36, "d0b278"); box(c, -12, -15, 24, 30, "fff3d6")
            for y in [-8, 0, 8]: box(c, -8, y, 16, 2, "7d8990")
            box(c, -6, -19, 12, 6, "52616c")
        "phonebox":
            box(c, -16, -4, 32, 8, "3e4856"); box(c, -20, -10, 12, 20, "283b49"); box(c, 8, -10, 12, 20, "283b49")
        "gentleman", "oliver":
            box(c, -2, -14, 4, 40, "755546"); box(c, -23, -14, 46, 9, "647e94"); box(c, -17, -22, 34, 8, "849fb4"); box(c, -8, -28, 16, 6, "a2bac9"); box(c, 0, 22, 10, 4, "755546")
        "shark", "jack":
            box(c, -11, -27, 22, 54, "e5bf6d"); box(c, -7, -34, 14, 68, "edd69a"); box(c, -2, -29, 4, 57, "5b9eaa")
        "koala":
            box(c, -12, -10, 24, 21, "f0b34a"); box(c, -8, -15, 16, 31, "f0c85e"); box(c, -1, -20, 8, 6, "6c9856")
        "delivery", "futuredh":
            box(c, -19, -14, 38, 29, "ac794f"); box(c, -17, -12, 34, 25, "d8ae73"); box(c, -3, -12, 6, 25, "f0dec0"); box(c, -13, 2, 8, 5, "f1e5c9")
        "pastdh":
            box(c, -23, -10, 46, 20, "3a4359"); box(c, -17, -4, 12, 4, "a7c4c1"); box(c, -13, -8, 4, 12, "a7c4c1"); box(c, 10, -6, 5, 5, "dc7d88"); box(c, 16, 0, 5, 5, "e8bf6b")
        "ahmed", "bjorn", "nikos", "windmill":
            box(c, -3, -27, 6, 54, "9a7859")
            box(c, -20, -20, 40, 7, "deca92"); box(c, -20, 13, 40, 7, "deca92")
        "fox", "wraith", "octopus", "hotspring", "fairy", "sphinx":
            var col = { "fox": "e6a467", "wraith": "84739d", "octopus": "63527e", "hotspring": "9cddd3", "fairy": "8ac7e6", "sphinx": "d4b279"}[kind]
            for i in range(4): box(c, -18 + i * 9, -11 + (i % 2) * 5, 12, 17, col)
        _:
            for i in range(3): box(c, -12 + i * 10, -18 + i * 3, 4, 31, "fff1cc")
    c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func effects(c, boy: Vector2, foe: Vector2) -> void:
    var g = c.game; var t = g.battle_phase_time
    if g.battle_enemy_guard:
        c.panel(Rect2(foe.x - 75, foe.y + 12, 146, 26), Color("4e6375"), 3)
        c.txt("방어 · 설거지 피해 절반", foe.x - 71, foe.y + 30, 11, Color("fff3d5"))
    if g.battle_fog:
        for i in range(5): box(c, boy.x - 30 + i * 13, boy.y - 34 + (i % 2) * 5, 23, 7, "bdc8d3")
    if g.battle_phase != "enemy" or g.state not in ["battle", "pause"]: return
    if g.battle_intent in ["brace", "rest"]:
        c.txt("방어 자세" if g.battle_intent == "brace" else "숨 고르기", foe.x - 70, foe.y - 141, 16, Color("405c5b"), 140, HORIZONTAL_ALIGNMENT_CENTER); return
    var dest = boy - Vector2(0, 55); var source = foe - Vector2(0, 55)
    if t >= 0.06 and t < 0.3:
        var u = (t - 0.06) / 0.24
        var point = source.lerp(dest, u)
        match g.battle_intent:
            "sand":
                for i in range(14): box(c, point.x - 22 + (i * 13) % 43, point.y - 15 + (i * 7) % 29, 4 + i % 3, 3 + i % 2, "d5b06d" if i % 2 else "f0d6a0")
            "chill":
                for i in range(3):
                    var x = point.x - 20 + i * 18; var y = point.y - 16 + (i % 2) * 24
                    box(c, x - 7, y - 2, 14, 4, "e8f7fc"); box(c, x - 2, y - 7, 4, 14, "e8f7fc"); box(c, x - 5, y - 5, 10, 10, "c0e3ee")
            "gust":
                for i in range(4):
                    box(c, point.x - 23 + i % 2 * 12, point.y - 20 + i * 12, 35 - i * 4, 3, "edf4d9"); box(c, point.x + 12 - i * 3, point.y - 23 + i * 12, 4, 7, "edf4d9")
            "mist":
                for i in range(6): box(c, point.x - 28 + i * 9, point.y - 15 + (i % 3) * 9, 21, 9, "b9c7d4" if i % 2 else "dce4e9")
            "wave":
                for i in range(6):
                    var x = point.x - 27 + i * 9; var yy = point.y + 20 - sin(i * 0.6) * 30
                    box(c, x, yy, 9, 44 - (yy - point.y), "77b5c9"); box(c, x, yy - 4, 9, 5, "e7f5ee")
            _: prop(c, point, art_id(g), 0 if melee(g) else sin(u * PI) * 0.6)
    if g.battle_fx_kind == "regional" and g.battle_fx_left > 0.41:
        for i in range(3): box(c, dest.x - 15 + i * 13, dest.y - 18 + i * 5, 4, 29, "fff2ce")
