extends RefCounted

func box(c: Control, p: Vector2, size: Vector2, color: String) -> void:
    c.draw_rect(Rect2(p.round(), size), Color(color))

func sponge(c: Control, p: Vector2, angle: float = 0) -> void:
    c.draw_set_transform(p.round(), angle, Vector2.ONE)
    box(c, Vector2(-14, -9), Vector2(28, 18), "314e3b")
    box(c, Vector2(-12, -7), Vector2(24, 8), "5f9b56")
    box(c, Vector2(-12, 1), Vector2(24, 6), "efd57a")
    for offset in [Vector2(-8, -5), Vector2(-1, -3), Vector2(6, -6)]: box(c, offset, Vector2(3, 3), "2f663f")
    for offset in [Vector2(-7, 3), Vector2(4, 2)]: box(c, offset, Vector2(3, 2), "cba451")
    c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func bubble(c: Control, p: Vector2, size: float) -> void:
    box(c, p - Vector2(size / 2, size / 2), Vector2(size, size), "eaffef")
    box(c, p - Vector2(size / 2 - 2, size / 2 - 2), Vector2(size - 4, size - 4), "a6d6ca")
    box(c, p - Vector2(size / 2 - 2, size / 2 - 2), Vector2(3, 3), "ffffff")

func bill(c: Control, p: Vector2, angle: float) -> void:
    c.draw_set_transform(p.round(), angle, Vector2.ONE)
    box(c, Vector2(-17, -10), Vector2(34, 20), "315a49")
    box(c, Vector2(-15, -8), Vector2(30, 16), "b5d8a1")
    box(c, Vector2(-11, -5), Vector2(22, 10), "679b73")
    box(c, Vector2(-3, -5), Vector2(7, 10), "d5e6b8")
    box(c, Vector2(-12, -6), Vector2(3, 3), "e7f1c9")
    box(c, Vector2(9, 3), Vector2(3, 3), "e7f1c9")
    c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func candy(c: Control, p: Vector2) -> void:
    box(c, p + Vector2(-17, -5), Vector2(8, 11), "f4b9c1")
    box(c, p + Vector2(9, -5), Vector2(8, 11), "f4b9c1")
    box(c, p + Vector2(-10, -9), Vector2(20, 18), "b8617d")
    box(c, p + Vector2(-7, -6), Vector2(14, 12), "e99bb2")
    box(c, p + Vector2(-4, -4), Vector2(6, 4), "fff2da")

func heart(c: Control, p: Vector2) -> void:
    box(c, p + Vector2(-8, -6), Vector2(6, 5), "e483a3"); box(c, p + Vector2(2, -6), Vector2(6, 5), "e483a3")
    box(c, p + Vector2(-8, -1), Vector2(16, 5), "e483a3"); box(c, p + Vector2(-5, 4), Vector2(10, 4), "e483a3")
    box(c, p + Vector2(-2, 8), Vector2(4, 3), "e483a3")

func bread(c: Control, p: Vector2, angle: float) -> void:
    c.draw_set_transform(p.round(), angle, Vector2.ONE)
    box(c, Vector2(-22, -7), Vector2(44, 14), "9b653f")
    box(c, Vector2(-20, -5), Vector2(40, 10), "e0b067")
    for x in [-12, 0, 12]: box(c, Vector2(x, -4), Vector2(4, 7), "fff0c2")
    c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

const TIER_A = ["314e3b", "24507a", "5a2f7a", "8a5a10"]
const TIER_B = ["5f9b56", "5fa8e8", "b07ae8", "ffd84a"]
const TIER_C = ["efd57a", "eaf6ff", "ffc4ec", "fff6c8"]

# 기술 단계(0~3)에 따라 수세미 색이 달라진다
func sponge_tier(c: Control, p: Vector2, angle: float, tr: int) -> void:
    if tr <= 0:
        sponge(c, p, angle); return
    c.draw_set_transform(p.round(), angle, Vector2.ONE)
    var big = 2 if tr >= 3 else 0
    box(c, Vector2(-14 - big, -9 - big), Vector2(28 + big * 2, 18 + big * 2), TIER_A[tr])
    box(c, Vector2(-12 - big, -7 - big), Vector2(24 + big * 2, 8 + big), TIER_B[tr])
    box(c, Vector2(-12 - big, 1), Vector2(24 + big * 2, 6 + big), TIER_C[tr])
    for offset in [Vector2(-8, -5), Vector2(-1, -3), Vector2(6, -6)]: box(c, offset, Vector2(3, 3), TIER_A[tr])
    c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func spark(c: Control, p: Vector2, size: float, color: String) -> void:
    box(c, p - Vector2(size / 2, 1.5), Vector2(size, 3), color)
    box(c, p - Vector2(1.5, size / 2), Vector2(3, size), color)

func pot(c: Control, p: Vector2, s: float, tr: int) -> void:
    var body = ["4f5963", "a8703a", "7a4fc0", "d9a520"][tr]
    var rim = ["7b8894", "d9a066", "b79af0", "ffe27a"][tr]
    box(c, p + Vector2(-17, -20) * s, Vector2(34, 20) * s, body); box(c, p + Vector2(-21, -23) * s, Vector2(42, 5) * s, rim)
    box(c, p + Vector2(-25, -17) * s, Vector2(5, 5) * s, rim); box(c, p + Vector2(20, -17) * s, Vector2(5, 5) * s, rim)
    box(c, p + Vector2(-13, -16) * s, Vector2(4, 10) * s, rim)

func draw(c: Control, boy: Vector2, foe: Vector2) -> void:
    var g = c.game; var t = g.battle_phase_time
    var active = g.state == "battle" or (g.state == "pause" and g.previous_state == "battle")
    var phase = g.battle_phase if active else "none"
    var hand = boy + Vector2(27, -48)
    var target = foe + Vector2(0, -55)
    var ult = g.battle_choice == "ult"
    var volley = g.battle_choice == "strike" or (ult and g.job == 1)
    var tr = 3 if ult else g.tier(g.battle_choice) if g.battle_choice in ["strike", "guard", "team", "soak", "soap", "coffee"] else 0
    if phase == "player" and (volley or g.battle_choice == "team"):

        var reach = Vector2(10, -6) if (fmod(t - 0.1, 0.24) < 0.12 and t >= 0.1) else Vector2.ZERO
        c.draw_line(boy + Vector2(20, -54), hand + reach, Color("343b41"), 11)
        c.draw_line(boy + Vector2(20, -54), hand + reach, Color("e9b78a"), 7)
    if phase == "player" and g.battle_choice == "team":
        box(c, boy + Vector2(-29, -42), Vector2(22, 17), "76513f")
        box(c, boy + Vector2(-27, -40), Vector2(18, 5), "d9ab68")
    if phase == "player":
        if volley:
            var gap = 0.15 if ult else 0.24
            for i in range(g.volley_total):
                if g.battle_hp <= 0 and i >= g.battle_volley_hits: continue
                var launch = (0.02 if ult else 0.1) + i * gap
                var u = (t - launch) / 0.28
                if u >= 0 and u < 1:
                    var pos = hand.lerp(target, u) + Vector2(0, - sin(u * PI) * (26 + (i % 2) * 14 * (1 if ult else 0)))
                    sponge_tier(c, pos, u * TAU * 0.7, tr)
                    if g.effects_on:
                        bubble(c, pos - Vector2(13, 0), 7); bubble(c, pos - Vector2(24, -7), 5)
                        if tr >= 1: bubble(c, pos - Vector2(36, 3), 6)
                        if tr >= 2: spark(c, pos - Vector2(46, -4), 9, TIER_B[tr])
                        if tr >= 3:
                            spark(c, pos - Vector2(20, 14), 11, "fff6c8"); spark(c, pos - Vector2(58, 6), 7, "ffd84a")
                if t >= launch - 0.1 and t < launch:
                    box(c, hand + Vector2(-9, 0), Vector2(12, 9), "e9b78a")
                    sponge_tier(c, hand + Vector2(3, -9), -0.25, tr)
        elif g.battle_choice == "team":
            for i in range(4 + tr * 2):
                var u = (t - 0.12 - i * 0.04) / (0.38 - mini(i, 4) * 0.04)
                if u >= 0 and u < 1: bill(c, hand.lerp(target, u) + Vector2(0, sin(u * PI) * (i - 1.5 - tr) * 18), u * 0.8 + i * 0.2)
            if tr >= 2 and t > 0.12 and t < 0.5:
                for i in range(5): spark(c, hand.lerp(target, clampf((t - 0.12) / 0.38, 0, 1)) + Vector2(-12 - i * 13, sin(i * 2.1 + t * 20) * 14), 8, "ffd84a")
            if t < 0.5: c.txt("−40원", boy.x + 46, boy.y - 125, 18, Color("9e4f4b"))
        elif ult and g.job == 2 and t < 0.5:
            # 하늘에서 압력솥이 떨어진다
            var drop = clampf(t / 0.5, 0, 1)
            pot(c, Vector2(target.x, lerpf(target.y - 260, target.y + 20, drop * drop)), 1.5 + g.job_rank() * 0.2, 2 if g.job_rank() < 2 else 3)
        elif ult and g.job == 3:
            c.panel(Rect2(boy.x - 52, boy.y - 190, 104, 34), Color("c9951a"), 6)
            c.txt("18:00 칼퇴", boy.x - 52, boy.y - 166, 17, Color("fff8e8"), 104, HORIZONTAL_ALIGNMENT_CENTER)
    if active and g.battle_guard:
        var glass = ["9bbac1", "8fc7e8", "b79af0", "ffd84a"][3 if g.battle_reflect else g.tier("guard")]
        box(c, boy + Vector2(24, -43), Vector2(25, 20), "414b59")
        box(c, boy + Vector2(27, -40), Vector2(19, 14), glass)
        box(c, boy + Vector2(20, -23), Vector2(34, 4), "ccd4d0")
        box(c, boy + Vector2(-27, -31), Vector2(10, 13), "fff0cb")
        box(c, boy + Vector2(-25, -29), Vector2(6, 3), "76513f")
        var clock = boy + Vector2(65, -108)
        box(c, clock - Vector2(13, 13), Vector2(26, 26), "526c73")
        box(c, clock - Vector2(10, 10), Vector2(20, 20), "f8ebd4")
        c.draw_line(clock, clock + Vector2(sin(t * 13), - cos(t * 13)) * 8, Color("526c73"), 3)
        for i in range(2):
            var drop2 = boy + Vector2(-24 + i * 48, -76 + fmod(t * 28 + i * 7, 22))
            box(c, drop2, Vector2(4, 8), "95cedd")
        if g.battle_reflect or g.tier("guard") >= 2:
            # 단계가 높으면 몸 앞에 빛나는 벽이 선다
            for i in range(6): box(c, boy + Vector2(56, -118 + i * 20 + fmod(g.clock_time * 30, 20) * 0.2), Vector2(6, 14), glass)
    if phase == "player" and g.battle_choice == "heal" and t < 0.28:
        candy(c, hand + Vector2(-5, - minf(t * 60, 25)))
    if phase == "enemy" and g.city_index == 0 and not g.legend_battle:
        var u = clampf( (t - 0.06) / 0.24, 0, 1)
        var dest = boy - Vector2(0, 55)
        if not g.wild_battle:
            if t < 0.3: bread(c, target.lerp(dest, u), u * PI)
        elif g.wild_index == 0:
            if t < 0.3:
                var pos = target.lerp(dest, u)
                for i in range(3): box(c, pos + Vector2(i * 6 - 8, - i * 4), Vector2(12, 10), "d1d0e5")
        elif g.wild_index == 1:

            for side in [-1, 1]:
                box(c, foe + Vector2(side * 37 - 7, -62 - int(t * 20) % 2 * 8), Vector2(14, 26), "687f94")
        else:
            var x = lerpf(foe.x - 35, boy.x + 28, u)
            c.draw_rect(Rect2(x, boy.y - 105, 5, 106), Color("e0f3eb"))
            c.draw_rect(Rect2(x - 8, boy.y - 100, 12, 12), Color("faf3dc"))
    if g.battle_fx_left <= 0: return
    var age = 0.65 - g.battle_fx_left
    var hit = target if g.battle_fx_target == "enemy" else boy - Vector2(0, 58)
    var kind = g.battle_fx_kind
    if kind == "sponge":
        if age < 0.32:
            var count = 7 + tr * 3
            for i in range(count):
                var a = i * TAU / count; var radius = 13 + minf(age, 0.16) * (42 + tr * 22)
                bubble(c, hit + Vector2(cos(a), sin(a)) * radius, 9 + i % 3 * 3)
                if tr >= 2 and i % 2 == 0: spark(c, hit + Vector2(cos(a + 0.3), sin(a + 0.3)) * (radius + 16), 9, TIER_B[tr])
            c.txt(str(g.battle_volley_hits) + " HIT", hit.x - 26, hit.y + 38, 13, Color("fff8df"))
    elif kind == "money":
        if age < 0.36:
            for i in range(4): bill(c, hit + Vector2( (i - 1.5) * 18, -10 + (i % 2) * 22), i * 0.4)
    elif kind in ["boom", "reflect"]:
        var st = g.tier("soak") if kind == "boom" else 3
        var steam = ["eef6f8", "f2c58a", "c9a8f6", "ffe27a"][st]
        if age < 0.1 and g.effects_on: c.draw_rect(Rect2(hit.x - 70, hit.y - 70, 140, 140), Color(1, 1, 0.9, 0.55))
        if age < 0.5:
            var n = 12 + st * 4
            for i in range(n):
                var a2 = i * TAU / n + 0.2
                var rad = 18 + age * (190 + st * 40)
                var size = maxf(4, 16 - age * 24)
                box(c, hit + Vector2(cos(a2), sin(a2) * 0.8) * rad - Vector2(size, size) / 2, Vector2(size, size), steam if i % 2 == 0 else "ffffff")
            for i in range(5):
                box(c, hit + Vector2(-40 + i * 20, -30 - age * 150 - (i % 2) * 20), Vector2(8, 22), steam)
        if age < 0.4: c.txt("쾅!" if kind == "boom" else "반사!", hit.x - 50, hit.y - 62 - age * 30, 26, Color("fff4cd"), 100, HORIZONTAL_ALIGNMENT_CENTER)
    elif kind == "heal":
        heart(c, hit + Vector2(-23, -18)); heart(c, hit + Vector2(22, -4))
    elif kind == "haunt" and g.effects_on:
        for x in [-16, 0, 16]: box(c, hit + Vector2(x, -16), Vector2(4, 30), "c3bddb")
    elif kind in ["peck", "baguette", "wall"] and g.effects_on and age < 0.24:
        for i in [-1, 0, 1]:
            box(c, hit + Vector2(i * 11, -18), Vector2(4, 31), "fff1c0")
