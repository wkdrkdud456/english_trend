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
func sponge_tier(c: Control, p: Vector2, angle: float, tr: int, grow: float = 1.0) -> void:
    if tr <= 0:
        sponge(c, p, angle); return
    c.draw_set_transform(p.round(), angle, Vector2.ONE * grow)
    var big = 2 if tr >= 3 else 0
    box(c, Vector2(-14 - big, -9 - big), Vector2(28 + big * 2, 18 + big * 2), TIER_A[tr])
    box(c, Vector2(-12 - big, -7 - big), Vector2(24 + big * 2, 8 + big), TIER_B[tr])
    box(c, Vector2(-12 - big, 1), Vector2(24 + big * 2, 6 + big), TIER_C[tr])
    for offset in [Vector2(-8, -5), Vector2(-1, -3), Vector2(6, -6)]: box(c, offset, Vector2(3, 3), TIER_A[tr])
    c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

# 단계가 오를수록 이펙트가 커진다. 직업 기술은 그보다 더 크다.
func power(g) -> float:
    if g.battle_choice == "ult": return 1.6 + int(g.ult_info().tier) * 0.3 + (g.job_mul() - 1.0)
    if g.battle_choice in ["strike", "guard", "team", "soak", "soap", "coffee"]: return [1.0, 1.25, 1.55, 1.9][g.tier(g.battle_choice)]
    return 1.0

# 퍼져 나가는 충격파 고리
func ring(c: Control, mid: Vector2, radius: float, count: int, size: float, color: String, squash: float = 0.75) -> void:
    for i in range(count):
        var a = i * TAU / float(count)
        box(c, mid + Vector2(cos(a), sin(a) * squash) * radius - Vector2(size, size) / 2.0, Vector2(size, size), color)

# 사방으로 뻗는 빛줄기
func rays(c: Control, mid: Vector2, inner: float, outer: float, count: int, color: String, width: float = 4.0) -> void:
    for i in range(count):
        var a = i * TAU / float(count) + 0.2
        var dir = Vector2(cos(a), sin(a))
        c.draw_line(mid + dir * inner, mid + dir * outer, Color(color), width)

# 대상 둘레에서 솟아오르는 기운 (버프·방어·회복)
func aura(c: Control, foot: Vector2, t: float, color: String, strength: float) -> void:
    var n = int(6 + strength * 5)
    for i in range(n):
        var a = i * TAU / float(n)
        var rise = fmod(t * 130.0 + i * 23.0, 110.0 * strength)
        box(c, foot + Vector2(cos(a) * 34.0 * strength, - rise - 6), Vector2(5, 12 + strength * 4), color if i % 2 == 0 else "ffffff")
    if strength >= 1.5:
        c.draw_rect(Rect2(foot.x - 26 * strength, foot.y - 150 * strength, 52 * strength, 150 * strength), Color(Color(color), 0.22))

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
    var volley = g.battle_choice == "strike" or g.ult_kind() == "volley"
    var tr = 3 if ult else g.tier(g.battle_choice) if g.battle_choice in ["strike", "guard", "team", "soak", "soap", "coffee"] else 0
    var pw = power(g)
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
                    if g.effects_on and tr >= 1:
                        # 잔상: 지나온 길에 색 조각이 남는다
                        for k in range(1, 2 + tr * 2):
                            var back = clampf(u - k * 0.07, 0, 1)
                            var ghost = hand.lerp(target, back) + Vector2(0, - sin(back * PI) * 26)
                            var gs = (14.0 - k * 1.6) * pw * 0.7
                            box(c, ghost - Vector2(gs, gs) / 2.0, Vector2(gs, gs), TIER_B[tr] if k % 2 == 0 else TIER_C[tr])
                    sponge_tier(c, pos, u * TAU * (0.7 + tr * 0.3), tr, pw * (0.8 if ult else 0.72))
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
        elif g.ult_kind() == "blast" and g.job == 2 and t < 0.5:
            # 하늘에서 압력솥이 떨어진다 (천년 누룽지는 화면을 덮을 만큼 크다)
            var drop = clampf(t / 0.5, 0, 1)
            var top = int(g.ult_info().tier) >= 3
            var huge = 3.4 if top else 1.7 + int(g.ult_info().tier) * 0.25
            c.draw_rect(Rect2(target.x - 30 * huge * drop, target.y + 36, 60 * huge * drop, 10), Color(0.1, 0.12, 0.12, 0.35))
            pot(c, Vector2(target.x, lerpf(target.y - 420, target.y + 30, drop * drop)), huge, 3 if int(g.ult_info().tier) >= 2 else 2)
        elif g.ult_kind() == "blast" and g.job == 3 and t < 0.5:
            # 사표·청구서: 종이 뭉치가 날아간다
            for i in range(4 + int(g.ult_info().tier) * 3):
                var u2 = clampf((t - i * 0.03) / 0.3, 0, 1)
                var sheet = hand.lerp(target, u2) + Vector2(sin(i * 1.7) * 30.0, - sin(u2 * PI) * (30 + i * 6))
                box(c, sheet - Vector2(11, 14), Vector2(22, 28), "343b41"); box(c, sheet - Vector2(9, 12), Vector2(18, 24), "fffdf4")
                for ln in range(3): box(c, sheet + Vector2(-6, -7 + ln * 6), Vector2(12, 2), "9aa4ad")
        elif g.ult_kind() == "blast" and t < 0.5:
            # 스팀 살균: 뜨거운 김이 화면 아래에서 솟구친다
            for i in range(15): box(c, Vector2(target.x - 126 + i * 18, target.y + 60 - t * 520 - (i % 4) * 34), Vector2(12, 46 + (i % 3) * 18), "f4fbff" if i % 2 == 0 else "cfe9f2")
            ring(c, target, 20 + t * 220, 14, 10, "ffffff")
        elif g.ult_kind() == "arm" and t < 0.6:
            for side in [-1, 1]: pot(c, target + Vector2(side * 46, 20 - absf(sin(t * 9.0)) * 18), 1.3, 3)
            aura(c, target + Vector2(0, 30), t, "c9a8f6", 1.6)
        elif g.ult_kind() == "heal":
            # 연차 사용: 파라솔 아래에서 쉰다
            box(c, boy + Vector2(-3, -190), Vector2(6, 70), "8a6a4c")
            for i in range(5): box(c, boy + Vector2(-60 + i * 24, -206 + absi(i - 2) * 8), Vector2(24, 18), "ff8fb0" if i % 2 == 0 else "fff4e0")
            aura(c, boy, t, "8fd96a", 1.8)
        elif g.ult_kind() == "ward":
            # 칼퇴: 시계가 여섯 시를 가리키고 빛의 벽이 선다
            var wall = 1.0 + (int(g.ult_info().get("hits", 1)) - 1) * 0.35 + (g.job_mul() - 1.0) * 0.5
            for i in range(9): box(c, boy + Vector2(60, -170 * wall + i * 22 * wall), Vector2(10, 18 * wall), "ffe27a" if i % 2 == 0 else "fff8d8")
            c.draw_rect(Rect2(boy.x - 60 * wall, boy.y - 170 * wall, 130 * wall, 176 * wall), Color(1.0, 0.89, 0.48, 0.16))
            c.panel(Rect2(boy.x - 62, boy.y - 214, 124, 40), Color("c9951a"), 6)
            c.txt("18:00 칼퇴", boy.x - 62, boy.y - 186, 20, Color("fff8e8"), 124, HORIZONTAL_ALIGNMENT_CENTER)
            aura(c, boy, t, "ffd84a", 1.7 * wall)
    # 기본 기술을 쓸 때 솟는 기운 — 단계가 오를수록 크고 짙다
    if phase == "player" and g.effects_on and t < 0.7:
        if g.battle_choice == "coffee": aura(c, boy, t, ["c98b4b", "e8974d", "ff7a2a", "ffd84a"][tr], pw)
        elif g.battle_choice == "guard": aura(c, boy, t, ["9bbac1", "8fc7e8", "b79af0", "ffd84a"][tr], pw * 0.9)
        elif g.battle_choice == "heal": aura(c, boy, t, "ff9ec8", 1.0)
        elif g.battle_choice == "soap":
            aura(c, foe, t, "bfe9f2", pw)
            for i in range(int(4 + pw * 4)): bubble(c, foe + Vector2(-60 + fmod(i * 37.0, 120.0), -10 - fmod(t * 150.0 + i * 31.0, 130.0 * pw)), 7 + (i % 3) * 3 * pw)
        elif g.battle_choice == "soak":
            aura(c, foe + Vector2(-84, 0), t, ["bfe9f2", "ffe0b0", "e3c8ff", "fff2a8"][tr], pw * 0.8)
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
    if phase == "enemy" and g.city_index == 0 and not g.legend_battle and g.extra_mob < 0 and g.shadow_battle == 0 and not g.tower_battle:
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
            if g.effects_on and tr >= 1:
                ring(c, hit, 20 + age * (230 + tr * 90), 10 + tr * 4, maxf(3, 9 * pw - age * 26), TIER_B[tr])
                if tr >= 2: rays(c, hit, 14 + age * 90, 34 + age * (260 + tr * 60), 8 + tr * 2, TIER_C[tr], 2.0 + tr)
                if tr >= 3 and age < 0.07: c.draw_rect(Rect2(hit.x - 90, hit.y - 90, 180, 180), Color(1, 0.96, 0.7, 0.4))
            c.txt(str(g.battle_volley_hits) + " HIT", hit.x - 40, hit.y + 38 + pw * 6, int(11 + pw * 4), Color("fff8df"), 80, HORIZONTAL_ALIGNMENT_CENTER)
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
        var mega = pw if g.battle_choice == "ult" else 1.0 + st * 0.3
        if g.effects_on:
            if age < 0.09 and mega >= 1.6: c.draw_rect(Rect2(0, 0, c.w, c.h), Color(1, 1, 0.92, 0.5))
            if age < 0.55:
                ring(c, hit, 30 + age * 300 * mega, int(14 + mega * 6), maxf(4, 20 * mega - age * 44), steam)
                ring(c, hit, 10 + age * 190 * mega, int(10 + mega * 4), maxf(3, 14 * mega - age * 36), "ffffff", 0.5)
                rays(c, hit, 20 + age * 120, 60 + age * 420 * mega, int(8 + mega * 4), steam, 3.0 + mega * 2.0)
                # 버섯구름
                for i in range(int(4 + mega * 3)):
                    var puff = 26.0 * mega - i * 3.0
                    box(c, hit + Vector2(-puff / 2.0 + sin(i * 2.4) * 14.0 * mega, -20 - age * 260 * mega - i * 20), Vector2(puff, puff), steam if i % 2 == 0 else "ffffff")
                c.draw_rect(Rect2(hit.x - 140 * mega * minf(1.0, age * 4.0), hit.y + 46, 280 * mega * minf(1.0, age * 4.0), 6), Color(Color(steam), 0.7))
        if age < 0.45: c.txt(("대폭발!!" if mega >= 2.0 else "쾅!") if kind == "boom" else "반사!", hit.x - 110, hit.y - 70 - age * 40, int(26 + mega * 8), Color("fff4cd"), 220, HORIZONTAL_ALIGNMENT_CENTER)
    elif kind == "heal":
        heart(c, hit + Vector2(-23, -18)); heart(c, hit + Vector2(22, -4))
    elif kind == "haunt" and g.effects_on:
        for x in [-16, 0, 16]: box(c, hit + Vector2(x, -16), Vector2(4, 30), "c3bddb")
    elif kind in ["peck", "baguette", "wall"] and g.effects_on and age < 0.24:
        for i in [-1, 0, 1]:
            box(c, hit + Vector2(i * 11, -18), Vector2(4, 31), "fff1c0")
