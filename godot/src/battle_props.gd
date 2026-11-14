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

func draw(c: Control, boy: Vector2, foe: Vector2) -> void:
    var g = c.game; var t = g.battle_phase_time
    var active = g.state == "battle" or (g.state == "pause" and g.previous_state == "battle")
    var phase = g.battle_phase if active else "none"
    var hand = boy + Vector2(27, -48)
    var target = foe + Vector2(0, -55)
    if phase == "player" and g.battle_choice in ["strike", "team"]:

        var reach = Vector2(10, -6) if (fmod(t - 0.1, 0.24) < 0.12 and t >= 0.1) else Vector2.ZERO
        c.draw_line(boy + Vector2(20, -54), hand + reach, Color("343b41"), 11)
        c.draw_line(boy + Vector2(20, -54), hand + reach, Color("e9b78a"), 7)
    if phase == "player" and g.battle_choice == "team":
        box(c, boy + Vector2(-29, -42), Vector2(22, 17), "76513f")
        box(c, boy + Vector2(-27, -40), Vector2(18, 5), "d9ab68")
    if phase == "player":
        if g.battle_choice == "strike":
            for i in range(3):
                if g.battle_hp <= 0 and i >= g.battle_volley_hits: continue
                var launch = 0.1 + i * 0.24
                var u = (t - launch) / 0.28
                if u >= 0 and u < 1:
                    var pos = hand.lerp(target, u) + Vector2(0, - sin(u * PI) * 26)
                    sponge(c, pos, u * TAU * 0.7)
                    if g.effects_on:
                        bubble(c, pos - Vector2(13, 0), 7); bubble(c, pos - Vector2(24, -7), 5)
                if t >= launch - 0.1 and t < launch:
                    box(c, hand + Vector2(-9, 0), Vector2(12, 9), "e9b78a")
                    sponge(c, hand + Vector2(3, -9), -0.25)
        elif g.battle_choice == "team":
            for i in range(4):
                var u = (t - 0.12 - i * 0.055) / (0.38 - i * 0.055)
                if u >= 0 and u < 1: bill(c, hand.lerp(target, u) + Vector2(0, sin(u * PI) * (i - 1.5) * 18), u * 0.8 + i * 0.2)
            if t < 0.5: c.txt("−40원", boy.x + 46, boy.y - 125, 18, Color("9e4f4b"))
    if active and g.battle_guard:

        box(c, boy + Vector2(24, -43), Vector2(25, 20), "414b59")
        box(c, boy + Vector2(27, -40), Vector2(19, 14), "9bbac1")
        box(c, boy + Vector2(20, -23), Vector2(34, 4), "ccd4d0")
        box(c, boy + Vector2(-27, -31), Vector2(10, 13), "fff0cb")
        box(c, boy + Vector2(-25, -29), Vector2(6, 3), "76513f")
        var clock = boy + Vector2(65, -108)
        box(c, clock - Vector2(13, 13), Vector2(26, 26), "526c73")
        box(c, clock - Vector2(10, 10), Vector2(20, 20), "f8ebd4")
        c.draw_line(clock, clock + Vector2(sin(t * 13), - cos(t * 13)) * 8, Color("526c73"), 3)
        for i in range(2):
            var drop = boy + Vector2(-24 + i * 48, -76 + fmod(t * 28 + i * 7, 22))
            box(c, drop, Vector2(4, 8), "95cedd")
    if phase == "player" and g.battle_choice == "heal" and t < 0.28:
        candy(c, hand + Vector2(-5, - minf(t * 60, 25)))
    if phase == "enemy" and g.city_index == 0:
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
            for i in range(7):
                var a = i * TAU / 7; var radius = 13 + minf(age, 0.16) * 42
                bubble(c, hit + Vector2(cos(a), sin(a)) * radius, 9 + i % 3 * 3)
            c.txt(str(g.battle_volley_hits) + " HIT", hit.x - 26, hit.y + 38, 13, Color("fff8df"))
    elif kind == "money":
        if age < 0.36:
            for i in range(4): bill(c, hit + Vector2( (i - 1.5) * 18, -10 + (i % 2) * 22), i * 0.4)
    elif kind == "heal":
        heart(c, hit + Vector2(-23, -18)); heart(c, hit + Vector2(22, -4))
    elif kind == "haunt" and g.effects_on:
        for x in [-16, 0, 16]: box(c, hit + Vector2(x, -16), Vector2(4, 30), "c3bddb")
    elif kind in ["peck", "baguette", "wall"] and g.effects_on and age < 0.24:
        for i in [-1, 0, 1]:
            box(c, hit + Vector2(i * 11, -18), Vector2(4, 31), "fff1c0")
