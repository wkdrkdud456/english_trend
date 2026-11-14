extends RefCounted
# ── 탐험 화면 2D 렌더러 ───────────────────────────────────────
# 전투씬(battle_art.gd)과 똑같이 Control._draw 위에 픽셀 블록으로 그린다.
# 좌표는 3D 월드의 (x, z)를 그대로 쓰기 때문에 이동/충돌 로직은 건드리지 않는다.

const Pixels = preload ("res://scripts/legacy_pixels.gd")
var bounds: Dictionary = {}

# C = 모자 또는 머리, G = 손(장갑), T = 상의, D = 하의, E = 신발
const GIRL = [
"....OOOOOO....",
"...OCCCCCCO...",
"..OCCCCCCCCO..",
"..OHHHHHHHHO..",
"..OHSSSSSSHO..",
"..OHSSSSSSHO..",
"..OHSOSSOSHO..",
"..OHSSSSSSHO..",
"..OHOSSSSOHO..",
"..OHOTTTTOHO..",
"..OTTTTTTTTO..",
".OGTTTTTTTTGO.",
".OGTTTTTTTTGO.",
".OGTTTTTTTTGO.",
".OTTTTTTTTTTO.",
"OTTTTTTTTTTTTO",
"...ODDOODDO...",
"...ODDOODDO...",
"...ODDOODDO...",
"..OEEEOOEEEO.."
]
const BOY = [
"....OOOOOO....",
"...OCCCCCCO...",
"..OCCCCCCCCO..",
"..OHHHHHHHHO..",
"..OHSSSSSSHO..",
"..OSSSSSSSSO..",
"..OSSOSSOSSO..",
"..OSSSSSSSSO..",
"...OSSSSSSO...",
"....OTTTTO....",
"..OTTTTTTTTO..",
".OGTTTTTTTTGO.",
".OGTTTTTTTTGO.",
".OGTTTTTTTTGO.",
"..OTTTTTTTTO..",
"..OTTTTTTTTO..",
"...ODDOODDO...",
"...ODDOODDO...",
"...ODDOODDO...",
"..OEEEOOEEEO.."
]

var u = 26.0                 # 1 월드유닛 = 몇 픽셀인가
var cam = Vector2.ZERO       # 화면 중심이 보는 월드 좌표 (x, z)
var org = Vector2.ZERO       # 월드 (0,0)이 찍히는 화면 좌표
var view = Rect2()           # 월드를 그리는 화면 영역
var pal = {}
var k = 1.0                  # 소품 크기 단위 (u 에 비례)
var mute = Color("b3bca6")
var out = Color("343b41")
var shade = Color(0.16, 0.2, 0.17, 0.22)
var g0 = Color.WHITE
var g1 = Color.WHITE
var gm = Color.WHITE
var gd = Color.WHITE
var p0 = Color.WHITE
var p1 = Color.WHITE
var pe = Color.WHITE
var a0 = Color.WHITE
var a1 = Color.WHITE
var a2 = Color.WHITE
var leaf0 = Color.WHITE
var leaf1 = Color.WHITE
var leaf2 = Color.WHITE
const CANOPY = [[10, -52], [18, -48], [22, -42], [24, -34], [22, -26], [16, -20]]
var items: Array = []

const MAP = Vector2(13.4, 14.4)

func col(key: String, fallback: String = "7a9a68") -> Color:
    if pal.has(key): return Color(pal[key])
    return Color(fallback)

# 전투씬과 같은 차분한 톤: 도시 색을 세이지 회색 쪽으로 당긴다
func tone(key: String, t: float = 0.42) -> Color:
    return col(key).lerp(mute, t)

func soft(hex: String, t: float = 0.18) -> Color:
    return Color(hex).lerp(mute, t)

func block(c: Control, x: float, y: float, w: float, h: float, color: Color) -> void:
    if w <= 0 or h <= 0: return
    if x > view.end.x or y > view.end.y or x + w < view.position.x or y + h < view.position.y: return
    c.draw_rect(Rect2(roundf(x), roundf(y), ceilf(w), ceilf(h)), color)

func at(wx: float, wz: float) -> Vector2:
    return Vector2(roundf(org.x + wx * u), roundf(org.y + wz * u))

func wrect(c: Control, r: Rect2, color: Color) -> void:
    var p = at(r.position.x, r.position.y)
    var q = at(r.end.x, r.end.y)
    block(c, p.x, p.y, q.x - p.x, q.y - p.y, color)

func noise(i: float, j: float) -> float:
    return fposmod(sin(i * 127.1 + j * 311.7) * 43758.5453, 1.0)

func sprite(c: Control, rows: Array, foot: Vector2, s: float, palette: Dictionary) -> void:
    var ox = roundf(foot.x - rows[0].length() * s / 2.0)
    var oy = roundf(foot.y - rows.size() * s)
    if ox > view.end.x or oy > view.end.y: return
    if ox + rows[0].length() * s < view.position.x or oy + rows.size() * s < view.position.y: return
    for y in range(rows.size()):
        var row = rows[y]
        var run_start = -1
        var run_key = ""
        for xx in range(row.length() + 1):
            var key = row[xx] if xx < row.length() else ""
            if key == run_key: continue
            if run_start >= 0 and palette.has(run_key):
                c.draw_rect(Rect2(ox + run_start * s, oy + y * s, (xx - run_start) * s, s), palette[run_key])
            run_key = key
            run_start = xx

func mob_size(art: String) -> Vector2:
    if not bounds.has(art):
        var lo = Vector2(999, 999); var hi = Vector2(-999, -999)
        for part in Pixels.PARTS[art]:
            lo = lo.min(Vector2(part[0], part[1])); hi = hi.max(Vector2(part[0] + part[2], part[1] + part[3]))
        bounds[art] = [lo, hi]
    return bounds[art][1] - bounds[art][0]

func mob(c: Control, art: String, foot: Vector2, s: float) -> void:
    if not Pixels.PARTS.has(art): return
    var size = mob_size(art)
    var lo = bounds[art][0]
    var o = Vector2(roundf(foot.x - size.x * s / 2.0), roundf(foot.y - size.y * s))
    for part in Pixels.PARTS[art]:
        c.draw_rect(Rect2(o + (Vector2(part[0], part[1]) - lo) * s, Vector2(part[2], part[3]) * s), Color(part[4]))

func shadow(c: Control, foot: Vector2, w: float, h: float = 6.0) -> void:
    block(c, foot.x - w / 2, foot.y - h / 2, w, h, shade)

# ── 카메라 ────────────────────────────────────────────────
func setup(c: Control, g) -> void:
    pal = g.city().pal
    view = Rect2(0, 0, c.w, c.flat_bottom())
    u = view.size.x / (14.6 if g.overview else 10.6)
    k = u * 0.036
    var lead = Vector2(g.move_vel.x, g.move_vel.z) * 0.25
    # 위쪽 카드와 아래쪽 조작부 사이 가운데에 주인공이 오게 한다
    var want = Vector2(g.hero.position.x, g.hero.position.z + view.size.y * 0.04 / u) + lead
    var half = Vector2(view.size.x, view.size.y) / (2.0 * u)
    var lx = maxf(0.0, MAP.x - half.x)
    var lz = maxf(0.0, MAP.y - half.y)
    cam = Vector2(clampf(want.x, - lx, lx), clampf(want.y, - lz, lz))
    org = Vector2(view.size.x / 2.0, view.size.y / 2.0) - cam * u
    # 이번 프레임에 쓸 색
    g0 = tone("g0"); g1 = g0.lerp(tone("g1"), 0.22); gm = tone("g1").lerp(tone("g2"), 0.35); gd = tone("g1").lerp(tone("g2"), 0.5)
    p0 = tone("p0", 0.3); p1 = p0.lerp(tone("p2"), 0.22); pe = p0.lerp(tone("p2"), 0.55)
    a0 = tone("a0", 0.3); a1 = tone("a1", 0.38); a2 = tone("a2", 0.4)
    leaf0 = tone("tr0", 0.4); leaf1 = tone("tr1", 0.42); leaf2 = tone("tr2", 0.4).lerp(out, 0.15)

func on_screen(wx: float, wz: float, pad: float = 2.0) -> bool:
    var p = at(wx, wz)
    return p.x > view.position.x - pad * u and p.x < view.end.x + pad * u and p.y > view.position.y - pad * u and p.y < view.end.y + pad * u

func in_water(g, wx: float, wz: float) -> bool:
    for r in g.world.water_zones:
        if r.has_point(Vector2(wx, wz)): return true
    return false

# ── 바닥 ──────────────────────────────────────────────────
func ground(c: Control, g) -> void:
    block(c, view.position.x, view.position.y, view.size.x, view.size.y, gd)
    wrect(c, Rect2(-13.4, -14.4, 26.8, 28.8), g0)
    var x0 = floorf(cam.x - view.size.x / (2.0 * u)) - 1.0
    var z0 = floorf(cam.y - view.size.y / (2.0 * u)) - 1.0
    var nx = int(ceilf(view.size.x / u)) + 2
    var nz = int(ceilf(view.size.y / u)) + 2
    # 한 칸씩 엇갈리는 잔디 무늬
    for i in range(nx):
        for j in range(nz):
            var wx = x0 + i
            var wz = z0 + j
            if wx < -13.0 or wx >= 13.0 or wz < -14.0 or wz >= 14.0: continue
            if int(wx + wz + 64) % 2 == 1:
                var p = at(wx, wz)
                block(c, p.x, p.y, u, u, g1)
    # 키 큰 풀숲 (파리의 잔디밭 표시)
    for zone in g.world.grass_zones:
        wrect(c, zone, leaf1.lerp(g0, 0.35))
        var zp = at(zone.position.x, zone.position.y)
        var blades = mini(int(zone.size.x * 2.5), 16)
        for i in range(blades):
            for j in range(3):
                block(c, zp.x + (i + 0.3) * zone.size.x * u / blades, zp.y + (j + 0.2) * zone.size.y * u / 3.0, 3, 9, leaf2 if (i + j) % 3 == 0 else leaf0)
    # ㄴ자 풀과 작은 꽃 (전투 화면 풀과 같은 모양)
    for i in range(nx):
        for j in range(nz):
            var tx = x0 + i
            var tz = z0 + j
            var r = noise(tx, tz)
            if r > 0.42: continue
            var fx = tx + 0.2 + noise(tx + 7.0, tz) * 0.6
            var fz = tz + 0.2 + noise(tx, tz + 7.0) * 0.6
            if absf(fx) > 13.2 or absf(fz) > 14.2: continue
            if g.world.on_path(Vector3(fx, 0, fz)) or in_water(g, fx, fz): continue
            var q = at(fx, fz)
            if r < 0.05:
                block(c, q.x, q.y, 4, 4, tone("f0", 0.25)); block(c, q.x + 1, q.y + 4, 2, 4, gm)
            elif r < 0.09:
                block(c, q.x, q.y, 4, 4, tone("f1", 0.2)); block(c, q.x + 1, q.y + 4, 2, 4, gm)
            else:
                block(c, q.x, q.y, 3, 7, gm); block(c, q.x + 3, q.y + 4, 6, 3, gm)

func water(c: Control, g) -> void:
    for r in g.world.water_zones:
        wrect(c, r, a1)
        var top = at(r.position.x, r.position.y)
        var bot = at(r.position.x, r.end.y)
        var wide = r.size.x * u
        if r.size.x >= r.size.y:
            block(c, top.x, top.y, wide, 5, gd); block(c, top.x, top.y + 5, wide, 5, a2)
            block(c, bot.x, bot.y - 4, wide, 4, a2)
        else:
            block(c, top.x, top.y, 5, r.size.y * u, gd); block(c, top.x + 5, top.y, 5, r.size.y * u, a2)
        for i in range(26):
            var wx = r.position.x + r.size.x * fmod(i * 0.317 + g.clock_time * 0.014, 1.0)
            var wz = r.position.y + r.size.y * (0.2 + fmod(i * 0.29, 0.6))
            var p = at(wx, wz)
            block(c, p.x, p.y, 18, 3, a0); block(c, p.x + 6, p.y + 5, 10, 3, a0)

func paths(c: Control, g) -> void:
    for r in g.world.roads: wrect(c, r, p0)
    # 돌바닥 줄눈
    var bw = u * 0.9
    var bh = u * 0.5
    for r in g.world.roads:
        var p = at(r.position.x, r.position.y)
        var q = at(r.end.x, r.end.y)
        var row = 0
        var y = p.y
        while y < q.y:
            if y <= view.end.y and y + bh >= view.position.y:
                block(c, p.x, y, q.x - p.x, 2, p1)
                var x = p.x + (bw / 2.0 if row % 2 == 1 else 0.0)
                while x < q.x:
                    if x <= view.end.x and x >= view.position.x - bw: block(c, x, y, 2, minf(bh, q.y - y), p1)
                    x += bw
            y += bh; row += 1
    # 가장자리 턱 — 다른 길과 만나는 쪽은 건너뛴다
    var step = 0.5
    for r in g.world.roads:
        for side in range(4):
            var along_x = side < 2
            var count = int(round((r.size.x if along_x else r.size.y) / step))
            for i in range(count):
                var ex = r.position.x + ((i + 0.5) * step if along_x else (r.size.x if side == 3 else 0.0))
                var ez = r.position.y + ((r.size.y if side == 1 else 0.0) if along_x else (i + 0.5) * step)
                var e = at(ex, ez)
                if e.x < view.position.x - u or e.x > view.end.x + u or e.y < view.position.y - u or e.y > view.end.y + u: continue
                var probe = Vector3(ex + (-0.1 if side == 2 else (0.1 if side == 3 else 0.0)), 0, ez + (-0.1 if side == 0 else (0.1 if side == 1 else 0.0)))
                if g.world.on_path(probe): continue
                if along_x: block(c, e.x - step * u / 2.0, e.y - (3 if side == 1 else 0), step * u, 3, pe)
                else: block(c, e.x - (3 if side == 3 else 0), e.y - step * u / 2.0, 3, step * u, pe)
    for r in g.world.bridges:
        var p = at(r.position.x, r.position.y)
        var q = at(r.end.x, r.end.y)
        var deck = tone("w0", 0.2)
        var rail = tone("r1", 0.35)
        block(c, p.x, p.y, q.x - p.x, q.y - p.y, deck)
        if r.size.y >= r.size.x:
            var y = p.y + 8
            while y < q.y:
                block(c, p.x + 6, y, q.x - p.x - 12, 2, deck.lerp(tone("w2"), 0.25)); y += 14
            block(c, p.x - 2, p.y, 8, q.y - p.y, out); block(c, p.x, p.y, 4, q.y - p.y, rail)
            block(c, q.x - 6, p.y, 8, q.y - p.y, out); block(c, q.x - 4, p.y, 4, q.y - p.y, rail)
        else:
            var x = p.x + 8
            while x < q.x:
                block(c, x, p.y + 6, 2, q.y - p.y - 12, deck.lerp(tone("w2"), 0.25)); x += 14
            block(c, p.x, p.y - 2, q.x - p.x, 8, out); block(c, p.x, p.y, q.x - p.x, 4, rail)
            block(c, p.x, q.y - 6, q.x - p.x, 8, out); block(c, p.x, q.y - 4, q.x - p.x, 4, rail)

# ── 입체물 ────────────────────────────────────────────────
func house(c: Control, d: Dictionary) -> void:
    var p = at(d.x - d.bw / 2, d.z - d.bd / 2)
    var q = at(d.x + d.bw / 2, d.z + d.bd / 2)
    var w = q.x - p.x
    var h = q.y - p.y
    var wall = soft(d.wall)
    var roof = soft(d.roof, 0.2)
    var roof_d = roof.lerp(out, 0.3)
    var roof_l = roof.lerp(Color.WHITE, 0.25)
    block(c, p.x + 6, p.y + 10, w, h, shade)
    var rh = roundf(h * 0.46)
    block(c, p.x - 4, p.y - 6, w + 8, rh + 6, out); block(c, p.x - 1, p.y - 3, w + 2, rh, roof); block(c, p.x - 1, p.y - 3, w + 2, 4, roof_l)
    var ty = p.y + 8
    var band = 0
    while ty < p.y + rh - 6:
        block(c, p.x - 1, ty, w + 2, 2, roof_d)
        var tx = p.x + (7.0 if band % 2 == 1 else 0.0)
        while tx < p.x + w:
            block(c, tx, ty, 2, 9, roof_d); tx += 14
        ty += 9; band += 1
    if w > 110:
        block(c, p.x + w * 0.72, p.y - 16, 16, 18, out); block(c, p.x + w * 0.72 + 3, p.y - 13, 10, 14, wall.lerp(out, 0.25))
    var wy = p.y + rh
    block(c, p.x, wy, w, h - rh, out); block(c, p.x + 3, wy + 3, w - 6, h - rh - 6, wall); block(c, p.x + 3, wy + 3, w - 6, 4, wall.lerp(Color.WHITE, 0.3))
    var stripes = int((w - 10) / 12)
    for i in range(stripes + 1):
        block(c, p.x + 5 + i * 12, wy + 8, minf(12, w - 10 - i * 12), 9, Color("fff8e8") if i % 2 == 1 else roof)
    block(c, p.x + 5, wy + 17, w - 10, 2, out)
    var cx = p.x + w / 2
    var by = q.y - 3
    if h - rh > 52:
        block(c, cx - 13, by - 34, 26, 34, out); block(c, cx - 10, by - 31, 20, 31, roof_d); block(c, cx - 10, by - 31, 20, 4, roof_l); block(c, cx + 4, by - 17, 3, 3, Color("f6d58b"))
        if w > 120:
            for side in [-1, 1]:
                var wx = cx + side * (w * 0.3) - 15
                block(c, wx, by - 36, 30, 26, out); block(c, wx + 3, by - 33, 24, 20, soft(String(pal.a0), 0.25)); block(c, wx + 3, by - 33, 24, 5, Color(1, 1, 1, 0.6)); block(c, wx + 14, by - 33, 2, 20, out)
                block(c, wx - 2, by - 11, 34, 5, out); block(c, wx, by - 10, 30, 3, tone("f0", 0.2))
    var title = String(d.get("title", ""))
    if title != "":
        var tw = c.font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 18
        block(c, cx - tw / 2 - 2, wy - 13, tw + 4, 22, out); block(c, cx - tw / 2, wy - 11, tw, 18, Color("fff8e8"))
        c.txt(title, cx - tw / 2, wy + 3, 13, c.ink, tw, HORIZONTAL_ALIGNMENT_CENTER)

func tree(c: Control, d: Dictionary) -> void:
    var p = at(d.x, d.z)
    var s = k * float(d.get("s", 1.0))
    var kind = String(d.get("kind", "tree"))
    shadow(c, p, 30 * s, 8 * s)
    if kind == "palm":
        block(c, p.x - 4 * s, p.y - 44 * s, 8 * s, 46 * s, out); block(c, p.x - 2.5 * s, p.y - 43 * s, 5 * s, 44 * s, Color("b0926a"))
        for i in range(6):
            var a = i * TAU / 6.0
            var lx = p.x + cos(a) * 15 * s
            var ly = p.y - 48 * s + sin(a) * 7 * s
            block(c, lx - 10 * s - 2, ly - 4 * s - 2, 20 * s + 4, 8 * s + 4, out); block(c, lx - 10 * s, ly - 4 * s, 20 * s, 8 * s, leaf1 if i % 2 == 0 else leaf0)
        return
    if kind == "bamboo":
        for n in range(3):
            var bx = p.x + (n - 1) * 8 * s
            var tall = (46 + n * 6) * s
            block(c, bx - 3 * s, p.y - tall, 6 * s, tall, out); block(c, bx - 2 * s, p.y - tall + s, 4 * s, tall - s, Color("7f9a66"))
            block(c, bx - 3 * s, p.y - tall * 0.5, 6 * s, 2 * s, Color("c3caa0"))
        block(c, p.x - 18 * s, p.y - 60 * s, 36 * s, 10 * s, out); block(c, p.x - 16 * s, p.y - 58 * s, 32 * s, 6 * s, leaf0)
        return
    var body = leaf1
    var light = leaf0
    var dark = leaf2
    if kind == "cherry":
        body = Color("e6b9c6"); light = Color("f3d3dc"); dark = Color("c995a6")
    elif kind == "snow":
        body = Color("dfe9ee"); light = Color("f6fafb"); dark = Color("b9cdd8")
    block(c, p.x - 4 * s, p.y - 18 * s, 8 * s, 20 * s, out); block(c, p.x - 2.5 * s, p.y - 17 * s, 5 * s, 18 * s, Color("8a6a4c"))
    for row in CANOPY: block(c, p.x - row[0] * s - 2, p.y + row[1] * s - 2, row[0] * 2 * s + 4, 8 * s + 4, out)
    for row in CANOPY: block(c, p.x - row[0] * s, p.y + row[1] * s, row[0] * 2 * s, 8 * s, body)
    block(c, p.x - 14 * s, p.y - 46 * s, 14 * s, 6 * s, light); block(c, p.x - 18 * s, p.y - 38 * s, 12 * s, 6 * s, light); block(c, p.x - 6 * s, p.y - 50 * s, 10 * s, 4 * s, light)
    block(c, p.x + 6 * s, p.y - 28 * s, 14 * s, 6 * s, dark); block(c, p.x - 2 * s, p.y - 21 * s, 16 * s, 5 * s, dark); block(c, p.x + 12 * s, p.y - 36 * s, 8 * s, 6 * s, dark)

func lamp(c: Control, d: Dictionary) -> void:
    var p = at(d.x, d.z)
    shadow(c, p, 14 * k, 5 * k)
    block(c, p.x - 3 * k, p.y - 4 * k, 6 * k, 5 * k, out); block(c, p.x - 2 * k, p.y - 40 * k, 4 * k, 40 * k, out); block(c, p.x - k, p.y - 39 * k, 2 * k, 38 * k, Color("6d7a80"))
    block(c, p.x - 7 * k, p.y - 54 * k, 14 * k, 15 * k, out); block(c, p.x - 5 * k, p.y - 52 * k, 10 * k, 11 * k, Color("f6d98b")); block(c, p.x - 5 * k, p.y - 52 * k, 10 * k, 3 * k, Color("fff4cd"))
    block(c, p.x - 8 * k, p.y - 57 * k, 16 * k, 4 * k, out)

func flowerbed(c: Control, d: Dictionary) -> void:
    var p = at(d.x, d.z)
    block(c, p.x - 22 * k, p.y - 12 * k, 44 * k, 20 * k, out); block(c, p.x - 20 * k, p.y - 4 * k, 40 * k, 10 * k, Color("b08a66")); block(c, p.x - 20 * k, p.y - 10 * k, 40 * k, 7 * k, leaf1)
    for i in range(7): block(c, p.x - 18 * k + i * 5.6 * k, p.y - 15 * k, 4 * k, 5 * k, tone("f0", 0.15) if i % 2 == 1 else tone("f1", 0.12))

func bench(c: Control, d: Dictionary) -> void:
    var p = at(d.x, d.z)
    shadow(c, p, 34 * k, 6 * k)
    block(c, p.x - 17 * k, p.y - 20 * k, 34 * k, 17 * k, out); block(c, p.x - 15 * k, p.y - 18 * k, 30 * k, 5 * k, Color("c79a66")); block(c, p.x - 15 * k, p.y - 11 * k, 30 * k, 6 * k, Color("b48655"))
    block(c, p.x - 14 * k, p.y - 3 * k, 4 * k, 6 * k, out); block(c, p.x + 10 * k, p.y - 3 * k, 4 * k, 6 * k, out)

func tower(c: Control, d: Dictionary) -> void:
    var p = at(d.x, d.z)
    shadow(c, p, 70 * k, 10 * k)
    var c0 = Color("bfae8f")
    var c1 = Color("8f8068")
    for i in range(22):
        var t = i / 21.0
        var w = (6 + 62 * t * t) * k
        block(c, p.x - w / 2 - 2, p.y - (22 - i) * 5.4 * k - 1, w + 4, 5.4 * k + 2, out)
    for i in range(22):
        var t2 = i / 21.0
        var w2 = (6 + 62 * t2 * t2) * k
        var y = p.y - (22 - i) * 5.4 * k
        block(c, p.x - w2 / 2, y, w2, 5.4 * k, c1 if i % 4 == 3 else c0)
        if i > 8 and i % 4 != 3: block(c, p.x - w2 * 0.28, y, w2 * 0.56, 5.4 * k, g0)
    block(c, p.x - 3 * k, p.y - 138 * k, 6 * k, 20 * k, out); block(c, p.x - 1.5 * k, p.y - 136 * k, 3 * k, 18 * k, c0)

func monument(c: Control, d: Dictionary) -> void:
    var p = at(d.x - d.bw / 2, d.z - d.bd / 2)
    var q = at(d.x + d.bw / 2, d.z + d.bd / 2)
    var w = q.x - p.x
    var h = q.y - p.y
    var stone = tone("w1", 0.3)
    block(c, p.x + 5, p.y + 8, w, h, shade)
    block(c, p.x - 2, p.y - 8, w + 4, h + 8, out); block(c, p.x + 1, p.y - 5, w - 2, h + 2, stone); block(c, p.x + 1, p.y - 5, w - 2, maxf(5, h * 0.3), stone.lerp(Color.WHITE, 0.35))
    block(c, p.x + 1, q.y - maxf(4, h * 0.22), w - 2, maxf(4, h * 0.22) - 3, stone.lerp(out, 0.25))

func prop(c: Control, d: Dictionary) -> void:
    var p = at(d.x, d.z)
    shadow(c, p, 26 * k, 6 * k)
    var gem = tone("tr1", 0.2) if bool(d.get("done", false)) else tone("r1", 0.2)
    block(c, p.x - 12 * k, p.y - 10 * k, 24 * k, 10 * k, out); block(c, p.x - 10 * k, p.y - 8 * k, 20 * k, 6 * k, Color("cdbf9c"))
    block(c, p.x - 9 * k, p.y - 34 * k, 18 * k, 26 * k, out); block(c, p.x - 7 * k, p.y - 32 * k, 14 * k, 22 * k, gem); block(c, p.x - 7 * k, p.y - 32 * k, 14 * k, 5 * k, gem.lerp(Color.WHITE, 0.4))

func pickup(c: Control, d: Dictionary, t: float) -> void:
    var p = at(d.x, d.z)
    shadow(c, p, 20 * k, 6 * k)
    var y = p.y - 26 * k + sin(t * 3.0 + d.x) * 3.0
    block(c, p.x - 11 * k, y - 2 * k, 22 * k, 24 * k, out); block(c, p.x - 9 * k, y, 18 * k, 20 * k, Color("f4e6c8")); block(c, p.x - 9 * k, y, 18 * k, 6 * k, Color("e0b46a")); block(c, p.x - 4 * k, y + 9 * k, 8 * k, 7 * k, Color("c8553d"))
    for i in range(4):
        var a = i * 1.57 + t * 1.4
        block(c, p.x + cos(a) * 19 * k - 2, y + 10 * k + sin(a) * 16 * k - 2, 4, 4, Color("fffbe0"))

func shop(c: Control, d: Dictionary) -> void:
    var p = at(d.x, d.z)
    shadow(c, p, 56 * k, 8 * k)
    block(c, p.x - 27 * k, p.y - 36 * k, 54 * k, 36 * k, out); block(c, p.x - 25 * k, p.y - 22 * k, 50 * k, 20 * k, Color("f4e6c8"))
    for i in range(5): block(c, p.x - 25 * k + i * 10 * k, p.y - 34 * k, 10 * k, 12 * k, Color("fff8e8") if i % 2 == 1 else tone("r1", 0.25))
    block(c, p.x - 25 * k, p.y - 22 * k, 50 * k, 2 * k, out)
    block(c, p.x - 18 * k, p.y - 16 * k, 10 * k, 9 * k, Color("e0a85a")); block(c, p.x - 4 * k, p.y - 16 * k, 10 * k, 9 * k, Color("c98b4b")); block(c, p.x + 9 * k, p.y - 16 * k, 9 * k, 9 * k, Color("f6d58b"))

func gate(c: Control, d: Dictionary) -> void:
    var p = at(d.x, d.z)
    var stone = tone("w1", 0.3)
    shadow(c, p, 62 * k, 8 * k)
    for side in [-1, 1]:
        block(c, p.x + side * 22 * k - 6 * k, p.y - 50 * k, 12 * k, 52 * k, out); block(c, p.x + side * 22 * k - 4 * k, p.y - 48 * k, 8 * k, 48 * k, stone)
    block(c, p.x - 32 * k, p.y - 62 * k, 64 * k, 14 * k, out); block(c, p.x - 30 * k, p.y - 60 * k, 60 * k, 10 * k, tone("r1", 0.3)); block(c, p.x - 30 * k, p.y - 60 * k, 60 * k, 3 * k, Color(1, 1, 1, 0.3))
    var label = String(d.get("label", ""))
    if label != "":
        var tw = c.font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 14
        block(c, p.x - tw / 2 - 2, p.y - 86 * k, tw + 4, 20, out); block(c, p.x - tw / 2, p.y - 86 * k + 2, tw, 16, Color("fff8e8"))
        c.txt(label, p.x - tw / 2, p.y - 86 * k + 14, 11, c.ink, tw, HORIZONTAL_ALIGNMENT_CENTER)

func chest(c: Control, d: Dictionary, opened: bool, t: float) -> void:
    var p = at(d.x, d.z)
    shadow(c, p, 30 * k, 6 * k)
    block(c, p.x - 14 * k, p.y - 20 * k, 28 * k, 20 * k, out); block(c, p.x - 12 * k, p.y - 12 * k, 24 * k, 10 * k, Color("9a6a3c"))
    if opened:
        block(c, p.x - 12 * k, p.y - 18 * k, 24 * k, 6 * k, Color("3a2a1e")); block(c, p.x - 14 * k, p.y - 30 * k, 28 * k, 10 * k, out); block(c, p.x - 12 * k, p.y - 28 * k, 24 * k, 6 * k, Color("7a5230"))
    else:
        block(c, p.x - 12 * k, p.y - 18 * k, 24 * k, 6 * k, Color("b9834a")); block(c, p.x - 12 * k, p.y - 13 * k, 24 * k, 2 * k, Color("e5b33c")); block(c, p.x - 2 * k, p.y - 15 * k, 4 * k, 6 * k, Color("f6d98b"))
        var glint = t * 2.0 + d.x
        block(c, p.x + cos(glint) * 16 * k - 2, p.y - 24 * k + sin(glint) * 6 * k - 2, 4, 4, Color("fffbe0"))

func shard(c: Control, d: Dictionary, t: float) -> void:
    var p = at(d.x, d.z)
    shadow(c, p, 20 * k, 5 * k)
    var y = p.y - 30 * k + sin(t * 2.4) * 4.0
    block(c, p.x - 10 * k, y - 2 * k, 20 * k, 26 * k, out); block(c, p.x - 8 * k, y, 16 * k, 22 * k, Color("fff8e8"))
    for i in range(4): block(c, p.x - 5 * k, y + (4 + i * 4) * k, (10 - (i % 2) * 3) * k, 1.5 * k, Color("8a7254"))
    for i in range(5):
        var spin = t * 1.6 + i * TAU / 5.0
        block(c, p.x + cos(spin) * 20 * k - 2, y + 10 * k + sin(spin) * 16 * k - 2, 4, 4, Color("f6cf6a"))

func person(c: Control, foot: Vector2, girl: bool, outfit: Dictionary, hop: float = 0.0) -> void:
    var s = maxf(2.0, roundf(u * 0.075))
    shadow(c, foot, 13 * s, 2 * s)
    sprite(c, GIRL if girl else BOY, foot - Vector2(0, roundf(hop)), s, outfit)

func pet_draw(c: Control, d: Dictionary, t: float) -> void:
    var foot = at(d.x, d.z)
    if foot.x < view.position.x - 60 or foot.x > view.end.x + 60 or foot.y < view.position.y - 20 or foot.y > view.end.y + 60: return
    var s = u * 0.058
    shadow(c, foot, 18 * s, 4 * s)
    var bob = absf(sin(t * 5.0 + d.x * 2.0)) * 2.0
    mob(c, d.art, foot - Vector2(0, bob), s)
    var grade = int(d.get("grade", 0))
    if grade > 0:
        var spark = Color(d.tone)
        for i in range(3):
            var spin = t * 2.2 + i * TAU / 3.0
            c.draw_rect(Rect2(foot.x + cos(spin) * 14 * s - 2, foot.y - 12 * s + sin(spin) * 7 * s - 2, 4, 4), spark)

func marker(c: Control, g) -> void:
    var p = at(g.target.x, g.target.z)
    var rad = 20 * k * (0.86 + sin(g.clock_time * 3.4) * 0.14)
    for i in range(16):
        var a = i * TAU / 16.0 + g.clock_time
        block(c, p.x + cos(a) * rad - 3, p.y + sin(a) * rad * 0.5 - 3, 6, 6, Color("f6cf6a"))

# ── 정렬용 수집 ───────────────────────────────────────────
func _by_depth(a: Dictionary, b: Dictionary) -> bool:
    return a.z < b.z

func draw(c: Control, g) -> void:
    setup(c, g)
    ground(c, g)
    water(c, g)
    paths(c, g)
    if g.world.marker and g.world.marker.visible: marker(c, g)

    items.clear()
    for d in g.world.flat:
        if on_screen(d.x, d.z, 3.0): items.append(d)
    if g.city_index == 0 and g.stage == 0 and g.area_index == 0:
        for i in range(3):
            if not g.collected[i]:
                var q = g.world.pickups[i].position
                items.append({ "t": "pickup", "x": q.x, "z": q.z})
    if g.city_index > 0:
        for i in range(g.world.mission_nodes.size()):
            var m = g.world.mission_nodes[i]
            items.append({ "t": "prop", "x": m.position.x, "z": m.position.z, "done": g.tour.point_done(i)})
    items.append({ "t": "boy", "x": g.partner.position.x, "z": g.partner.position.z})
    items.append({ "t": "girl", "x": g.hero.position.x, "z": g.hero.position.z})
    for n in range(mini(g.pet_spots.size(), g.pet_team.size())):
        var friend = g.pets[int(g.pet_team[n])]
        var fg = int(friend.get("g", 0))
        items.append({ "t": "pet", "x": g.pet_spots[n].x, "z": g.pet_spots[n].z, "art": g.pet_art(friend), "grade": fg, "tone": g.GRADES[fg].color})
    if g.story_rival and g.story_rival.visible:
        items.append({ "t": "rival", "x": g.story_rival.position.x, "z": g.story_rival.position.z})
    items.sort_custom(_by_depth)

    var hop = absf(sin(g.step_phase)) * 3.0 * minf(1.0, g.move_speed)
    var hop2 = absf(sin(g.step_phase + 1.3)) * 3.0 * minf(1.0, g.move_speed)
    var girl_look = g.look(true)
    var boy_look = g.look(false)
    for d in items:
        match d.t:
            "house": house(c, d)
            "tree": tree(c, d)
            "lamp": lamp(c, d)
            "flower": flowerbed(c, d)
            "bench": bench(c, d)
            "tower": tower(c, d)
            "monument": monument(c, d)
            "shop": shop(c, d)
            "prop": prop(c, d)
            "pickup": pickup(c, d, g.clock_time)
            "gate": gate(c, d)
            "chest": chest(c, d, bool(g.tour.record().chests[int(d.i)]), g.clock_time)
            "shard":
                if not bool(g.tour.record().shard): shard(c, d, g.clock_time)
            "npc": person(c, at(d.x, d.z), true, { "O": out, "S": Color("f1c9a0"), "G": Color("f1c9a0"), "H": Color("b9b2a8"), "C": Color("b9b2a8"), "T": tone("a1", 0.3), "D": Color("5a5248"), "E": Color("3a3430")})
            "pet": pet_draw(c, d, g.clock_time)
            "girl": person(c, at(d.x, d.z), true, girl_look, hop)
            "boy": person(c, at(d.x, d.z), false, boy_look, hop2)
            "rival":
                var rf = at(d.x, d.z)
                var art = String(g.city().boss.art)
                if Pixels.PARTS.has(art):
                    shadow(c, rf, 22 * u * 0.07, 6)
                    mob(c, art, rf - Vector2(0, absf(sin(g.clock_time * 2.0)) * 2.0), u * 0.07)
                    c.txt(String(g.city().boss.name), rf.x - 60, rf.y - mob_size(art).y * u * 0.07 - 8, 12, out, 120, HORIZONTAL_ALIGNMENT_CENTER)
                else:
                    person(c, rf, false, boy_look)
