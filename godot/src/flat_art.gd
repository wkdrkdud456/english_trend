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
var items: Array = []

const MAP = Vector2(14.6, 15.2)

func col(key: String, fallback: String = "7a9a68") -> Color:
    if pal.has(key): return Color(pal[key])
    return Color(fallback)

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

func shadow(c: Control, foot: Vector2, w: float) -> void:
    block(c, foot.x - w / 2, foot.y - 2, w, 5, Color(0.11, 0.07, 0.04, 0.22))

# ── 카메라 ────────────────────────────────────────────────
func setup(c: Control, g) -> void:
    pal = g.city().pal
    view = Rect2(0, 0, c.w, c.flat_bottom())
    u = maxf(view.size.y / 22.6, view.size.x / 17.4)
    if g.overview: u *= 0.80
    var lead = Vector2(g.move_vel.x, g.move_vel.z) * 0.30
    var want = Vector2(g.hero.position.x, g.hero.position.z) + lead
    var half = Vector2(view.size.x, view.size.y) / (2.0 * u)
    var lx = maxf(0.0, MAP.x - half.x)
    var lz = maxf(0.0, MAP.y - half.y)
    cam = Vector2(clampf(want.x, - lx, lx), clampf(want.y, - lz, lz))
    org = Vector2(view.size.x / 2.0, view.size.y / 2.0) - cam * u

func on_screen(wx: float, wz: float, pad: float = 2.0) -> bool:
    var p = at(wx, wz)
    return p.x > view.position.x - pad * u and p.x < view.end.x + pad * u and p.y > view.position.y - pad * u and p.y < view.end.y + pad * u

# ── 바닥 ──────────────────────────────────────────────────
func ground(c: Control, g) -> void:
    block(c, view.position.x, view.position.y, view.size.x, view.size.y, col("g2"))
    wrect(c, Rect2(-13.4, -14.4, 26.8, 28.8), col("g1"))
    if g.city_index == 0:
        wrect(c, Rect2(-13.2, -13.5, 26.4, 15.0), col("g0"))
        wrect(c, Rect2(-13.2, 4.1, 26.4, 9.8), col("g0"))
    else:
        wrect(c, Rect2(-13.3, -14.3, 26.6, 28.6), col("g0"))
    # 키 큰 풀숲 (파리의 잔디밭 표시)
    for zone in g.world.grass_zones:
        wrect(c, zone, col("tr1"))
        var zp = at(zone.position.x, zone.position.y)
        var blades = mini(int(zone.size.x * 3), 18)
        for i in range(blades):
            for j in range(3):
                block(c, zp.x + (i + 0.3) * zone.size.x * u / blades, zp.y + (j + 0.25) * zone.size.y * u / 3.0, 3, 7, col("tr0") if (i + j) % 3 else col("tr2"))
    # 풀 질감 — 보이는 범위만 성글게
    var step = 1.7
    var x0 = snappedf(cam.x - view.size.x / (2.0 * u) - step, step)
    var z0 = snappedf(cam.y - view.size.y / (2.0 * u) - step, step)
    var nx = mini(int(view.size.x / (step * u)) + 3, 14)
    var nz = mini(int(view.size.y / (step * u)) + 3, 18)
    var tuft0 = col("tr0")
    var tuft1 = col("g2")
    for i in range(nx):
        for j in range(nz):
            var wx = x0 + i * step + fmod(j * 0.61, 1.1)
            var wz = z0 + j * step + fmod(i * 0.83, 1.0)
            if absf(wx) > 13.0 or absf(wz) > 14.0: continue
            if g.world.on_path(Vector3(wx, 0, wz)): continue
            var p = at(wx, wz)
            block(c, p.x, p.y - 3, 3, 5, tuft0 if (i + j) % 3 == 0 else tuft1)

func water(c: Control, g) -> void:
    for r in g.world.water_zones:
        wrect(c, r, col("a1"))
        var top = at(r.position.x, r.position.y)
        var bot = at(r.position.x, r.end.y)
        block(c, top.x, top.y, r.size.x * u, 3, col("a2"))
        block(c, bot.x, bot.y - 3, r.size.x * u, 3, col("a2"))
        for i in range(14):
            var wx = r.position.x + r.size.x * fmod(i * 0.317 + g.clock_time * 0.014, 1.0)
            var wz = r.position.y + r.size.y * (0.22 + fmod(i * 0.29, 0.58))
            var p = at(wx, wz)
            block(c, p.x, p.y, maxf(4, r.size.x * u * 0.035), 2, col("a0"))

func paths(c: Control, g) -> void:
    for r in g.world.roads:
        wrect(c, r, col("p0"))
    for r in g.world.roads:
        var p = at(r.position.x, r.position.y)
        var q = at(r.end.x, r.end.y)
        block(c, p.x, p.y, q.x - p.x, 2, col("p2"))
        block(c, p.x, q.y - 2, q.x - p.x, 2, col("p2"))
        # 가운데 점선
        if r.size.y > r.size.x:
            var cx = (p.x + q.x) / 2
            var n = int(r.size.y / 1.6)
            for i in range(mini(n, 22)):
                block(c, cx - 1, p.y + (i + 0.4) * 1.6 * u, 2, u * 0.5, col("p1"))
        else:
            var cy = (p.y + q.y) / 2
            var n2 = int(r.size.x / 1.6)
            for i in range(mini(n2, 22)):
                block(c, p.x + (i + 0.4) * 1.6 * u, cy - 1, u * 0.5, 2, col("p1"))
    for r in g.world.bridges:
        wrect(c, r, col("w0"))
        var p = at(r.position.x, r.position.y)
        var q = at(r.end.x, r.end.y)
        if r.size.x > r.size.y:
            block(c, p.x, p.y, q.x - p.x, 3, col("r1"))
            block(c, p.x, q.y - 3, q.x - p.x, 3, col("r1"))
        else:
            block(c, p.x, p.y, 3, q.y - p.y, col("r1"))
            block(c, q.x - 3, p.y, 3, q.y - p.y, col("r1"))

# ── 입체물 ────────────────────────────────────────────────
func house(c: Control, d: Dictionary) -> void:
    var r = Rect2(d.x - d.bw / 2, d.z - d.bd / 2, d.bw, d.bd)
    var p = at(r.position.x, r.position.y)
    var q = at(r.end.x, r.end.y)
    var w = q.x - p.x
    var h = q.y - p.y
    var wall = Color(d.wall)
    var roof = Color(d.roof)
    block(c, p.x + 4, p.y + 7, w, h, Color(0.11, 0.07, 0.04, 0.20))
    block(c, p.x, p.y, w, h, wall)
    block(c, p.x, p.y, w, maxf(7, h * 0.30), roof)
    var o = col("out", "2a1c18")
    block(c, p.x, p.y, w, 3, o)
    block(c, p.x, q.y - 3, w, 3, o)
    block(c, p.x, p.y, 3, h, o)
    block(c, q.x - 3, p.y, 3, h, o)
    block(c, p.x + 3, p.y + maxf(7, h * 0.30), w - 6, 2, o)
    var top = p.y + maxf(7, h * 0.30) + 8
    var cols = maxi(1, int((w - 20) / 26))
    var rows = maxi(1, int((q.y - 10 - top) / 24))
    var ox = (w - (cols * 26 - 8)) / 2
    for i in range(cols):
        for j in range(rows):
            var wx = p.x + ox + i * 26
            var wy = top + j * 24
            block(c, wx - 1, wy - 1, 20, 18, o)
            block(c, wx, wy, 18, 16, col("a0"))
            block(c, wx, wy, 18, 5, Color(1, 1, 1, 0.35))
    # 문
    block(c, (p.x + q.x) / 2 - 8, q.y - 17, 16, 14, roof)
    block(c, (p.x + q.x) / 2 - 9, q.y - 18, 18, 2, o)

func tree(c: Control, d: Dictionary) -> void:
    var p = at(d.x, d.z)
    var s = u * 0.042 * d.get("s", 1.0)
    var o = col("out", "2a1c18")
    shadow(c, p, 18 * s)
    var kind = d.get("kind", "tree")
    if kind == "palm":
        block(c, p.x - 2 * s, p.y - 26 * s, 4 * s, 26 * s, Color("b28e5b"))
        for i in range(6):
            var a = i * TAU / 6.0
            block(c, p.x + cos(a) * 11 * s - 5 * s, p.y - 30 * s + sin(a) * 5 * s, 10 * s, 5 * s, col("tr1"))
        return
    if kind == "bamboo":
        for k in range(3):
            var bx = p.x + (k - 1) * 5 * s
            block(c, bx - 2 * s, p.y - (30 + k * 4) * s, 4 * s, (30 + k * 4) * s, Color("719257"))
            block(c, bx - 3 * s, p.y - 16 * s, 6 * s, 2 * s, Color("bdc58a"))
        block(c, p.x - 12 * s, p.y - 38 * s, 24 * s, 7 * s, col("tr1"))
        return
    block(c, p.x - 2.5 * s, p.y - 16 * s, 5 * s, 18 * s, Color("7a5230"))
    var leaf = col("tr1")
    if kind == "cherry": leaf = Color("e9b4c5")
    if kind == "snow": leaf = Color("e8eff6")
    block(c, p.x - 14 * s, p.y - 34 * s, 28 * s, 20 * s, leaf)
    block(c, p.x - 10 * s, p.y - 41 * s, 20 * s, 9 * s, leaf)
    block(c, p.x - 16 * s, p.y - 30 * s, 3 * s, 12 * s, o)
    block(c, p.x + 13 * s, p.y - 30 * s, 3 * s, 12 * s, o)
    block(c, p.x - 11 * s, p.y - 32 * s, 8 * s, 6 * s, col("tr0") if kind == "tree" else leaf.lightened(0.18))

func lamp(c: Control, d: Dictionary) -> void:
    var p = at(d.x, d.z)
    var s = u * 0.042
    shadow(c, p, 10 * s)
    block(c, p.x - 1.5 * s, p.y - 30 * s, 3 * s, 30 * s, Color("5c6470"))
    block(c, p.x - 5 * s, p.y - 39 * s, 10 * s, 9 * s, col("f1"))
    block(c, p.x - 5 * s, p.y - 39 * s, 10 * s, 2 * s, col("out", "2a1c18"))

func flowerbed(c: Control, d: Dictionary) -> void:
    var p = at(d.x, d.z)
    var s = u * 0.042
    block(c, p.x - 15 * s, p.y - 6 * s, 30 * s, 12 * s, Color("b08a5e"))
    block(c, p.x - 13 * s, p.y - 10 * s, 26 * s, 5 * s, col("tr1"))
    for i in range(6):
        block(c, p.x - 12 * s + i * 4.2 * s, p.y - 13 * s, 3 * s, 3 * s, col("f0") if i % 2 else col("f1"))

func bench(c: Control, d: Dictionary) -> void:
    var p = at(d.x, d.z)
    var s = u * 0.042
    shadow(c, p, 22 * s)
    block(c, p.x - 11 * s, p.y - 6 * s, 22 * s, 5 * s, Color("a8763e"))
    block(c, p.x - 11 * s, p.y - 12 * s, 22 * s, 5 * s, Color("c08a4e"))
    block(c, p.x - 9 * s, p.y - 1 * s, 3 * s, 6 * s, Color("7a5230"))
    block(c, p.x + 6 * s, p.y - 1 * s, 3 * s, 6 * s, Color("7a5230"))

func tower(c: Control, d: Dictionary) -> void:
    var p = at(d.x, d.z)
    var s = u * 0.042
    var o = col("out", "2a1c18")
    shadow(c, p, 46 * s)
    for i in range(16):
        var t = i / 15.0
        var w = (5 + 42 * t * t) * s
        var y = p.y - (16 - i) * 4.6 * s
        block(c, p.x - w / 2 - s, y, w + 2 * s, 5 * s, o)
        block(c, p.x - w / 2, y, w, 4 * s, Color("c8ae84") if i % 3 else Color("8a7352"))
    block(c, p.x - 2 * s, p.y - 86 * s, 4 * s, 12 * s, o)
    block(c, p.x - s, p.y - 85 * s, 2 * s, 11 * s, Color("c8ae84"))

func monument(c: Control, d: Dictionary) -> void:
    var r = Rect2(d.x - d.bw / 2, d.z - d.bd / 2, d.bw, d.bd)
    var p = at(r.position.x, r.position.y)
    var q = at(r.end.x, r.end.y)
    var o = col("out", "2a1c18")
    block(c, p.x + 4, p.y + 7, q.x - p.x, q.y - p.y, Color(0.11, 0.07, 0.04, 0.20))
    block(c, p.x, p.y, q.x - p.x, q.y - p.y, col("w1"))
    block(c, p.x, p.y, q.x - p.x, maxf(6, (q.y - p.y) * 0.3), col("w2"))
    block(c, p.x, p.y, q.x - p.x, 3, o)
    block(c, p.x, q.y - 3, q.x - p.x, 3, o)
    block(c, p.x, p.y, 3, q.y - p.y, o)
    block(c, q.x - 3, p.y, 3, q.y - p.y, o)

func prop(c: Control, d: Dictionary) -> void:
    var p = at(d.x, d.z)
    var s = u * 0.042
    var o = col("out", "2a1c18")
    shadow(c, p, 16 * s)
    var body = col("r1") if d.get("done", false) == false else col("tr1")
    block(c, p.x - 9 * s, p.y - 20 * s, 18 * s, 20 * s, o)
    block(c, p.x - 7 * s, p.y - 18 * s, 14 * s, 16 * s, body)
    block(c, p.x - 7 * s, p.y - 18 * s, 14 * s, 4 * s, Color(1, 1, 1, 0.30))

func pickup(c: Control, d: Dictionary, t: float) -> void:
    var bob = sin(t * 3.0 + d.x) * u * 0.07
    var p = at(d.x, d.z)
    var s = u * 0.042
    var o = col("out", "2a1c18")
    shadow(c, p, 14 * s)
    var y = p.y - 16 * s + bob
    block(c, p.x - 8 * s, y, 16 * s, 16 * s, o)
    block(c, p.x - 6 * s, y + 2 * s, 12 * s, 12 * s, col("f1"))
    block(c, p.x - 6 * s, y + 2 * s, 12 * s, 3 * s, Color("fffbe0"))
    for i in range(4):
        var a = i * 1.57 + t * 1.4
        block(c, p.x + cos(a) * 14 * s, y + 7 * s + sin(a) * 12 * s, 3 * s, 3 * s, Color("fffbe0"))

func shop(c: Control, d: Dictionary) -> void:
    var p = at(d.x, d.z)
    var s = u * 0.042
    var o = col("out", "2a1c18")
    shadow(c, p, 36 * s)
    block(c, p.x - 18 * s, p.y - 24 * s, 36 * s, 24 * s, o)
    block(c, p.x - 16 * s, p.y - 22 * s, 32 * s, 20 * s, col("w0"))
    for i in range(4):
        block(c, p.x - 16 * s + i * 8 * s, p.y - 30 * s, 8 * s, 8 * s, col("r1") if i % 2 else col("w0"))
    block(c, p.x - 17 * s, p.y - 31 * s, 34 * s, 2 * s, o)
    block(c, p.x - 6 * s, p.y - 14 * s, 12 * s, 12 * s, col("f1"))

func person(c: Control, foot: Vector2, girl: bool, outfit: Dictionary, hop: float = 0.0) -> void:
    var s = maxf(2.0, roundf(u * 0.075))
    shadow(c, foot, 11 * s)
    sprite(c, GIRL if girl else BOY, foot - Vector2(0, roundf(hop)), s, outfit)

func pet_draw(c: Control, d: Dictionary, t: float) -> void:
    var foot = at(d.x, d.z)
    if foot.x < view.position.x - 60 or foot.x > view.end.x + 60 or foot.y < view.position.y - 20 or foot.y > view.end.y + 60: return
    var s = u * 0.055
    shadow(c, foot, 20 * s)
    var bob = absf(sin(t * 5.0 + d.x * 2.0)) * 2.0
    mob(c, d.art, foot - Vector2(0, bob), s)
    var grade = int(d.get("grade", 0))
    if grade > 0:
        var tone = Color(d.tone)
        for i in range(3):
            var a2 = t * 2.2 + i * TAU / 3.0
            c.draw_rect(Rect2(foot.x + cos(a2) * 14 * s - 2, foot.y - 12 * s + sin(a2) * 7 * s - 2, 4, 4), tone)

func marker(c: Control, g) -> void:
    var p = at(g.target.x, g.target.z)
    var s = u * 0.042
    var pulse = 0.78 + sin(g.clock_time * 3.4) * 0.22
    var rad = 15 * s * pulse
    for i in range(20):
        var a = i * TAU / 20.0
        block(c, p.x + cos(a) * rad - 2 * s, p.y + sin(a) * rad * 0.55 - 2 * s, 4 * s, 4 * s, Color("f9cc72"))
    block(c, p.x - 2 * s, p.y - (26 + sin(g.clock_time * 3.4) * 4) * s, 4 * s, 10 * s, Color("f9cc72"))

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
    if g.city_index == 0 and g.stage == 0:
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
    for k in range(mini(g.pet_spots.size(), g.pet_team.size())):
        var friend = g.pets[int(g.pet_team[k])]
        var fg = int(friend.get("g", 0))
        items.append({ "t": "pet", "x": g.pet_spots[k].x, "z": g.pet_spots[k].z, "art": g.pet_art(friend), "grade": fg, "tone": g.GRADES[fg].color})
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
            "pet": pet_draw(c, d, g.clock_time)
            "girl": person(c, at(d.x, d.z), true, girl_look, hop)
            "boy": person(c, at(d.x, d.z), false, boy_look, hop2)
            "rival":
                var rf = at(d.x, d.z)
                var art = String(g.city().boss.art)
                if Pixels.PARTS.has(art):
                    shadow(c, rf, 26 * u * 0.05)
                    mob(c, art, rf - Vector2(0, absf(sin(g.clock_time * 2.0)) * 2.0), u * 0.085)
                    c.txt(String(g.city().boss.name), rf.x - 60, rf.y - mob_size(art).y * u * 0.085 - 8, 12, col("r2", "8a2c44"), 120, HORIZONTAL_ALIGNMENT_CENTER)
                else:
                    person(c, rf, false, boy_look)
    # 건물 이름표
    for d in g.world.flat:
        if d.t == "house" and d.get("title", "") != "" and on_screen(d.x, d.z, 2.0):
            var p = at(d.x, d.z - d.bd / 2)
            c.txt(d.title, p.x - 70, p.y - 8, 12, col("out", "2a1c18"), 140, HORIZONTAL_ALIGNMENT_CENTER)
