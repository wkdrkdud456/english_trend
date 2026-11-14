extends RefCounted

const Cities = preload ("res://scripts/city_data.gd")
var w: Node3D
var data: Dictionary
var index = 0

func dress_boss(world: Node3D, person: Node3D, ci: int) -> void:

    match ci:
        1:
            world.box(person, Vector3(0, 1.43, 0.25), Vector3(0.5, 0.09, 0.08), "eee4cd")
            world.box(person, Vector3(0.37, 0.7, 0.26), Vector3(0.3, 0.4, 0.07), "dcb87b")
        2, 5:
            world.tube(person, Vector3(-0.43, 0.78, 0), 0.035, 1.55, "94634a")
            world.ball(person, Vector3(-0.43, 1.58, 0), 0.1, "e6c67a" if ci == 2 else "a4dce4")
            world.tube(person, Vector3(0, 1.6, 0), 0.31, 0.14, "eee3c6" if ci == 2 else "a79890")
        3:
            world.box(person, Vector3(-0.43, 0.76, 0.13), Vector3(0.46, 0.62, 0.12), "b76c59")
            world.box(person, Vector3(-0.43, 0.76, 0.21), Vector3(0.07, 0.5, 0.035), "e5c17b")
        4:
            world.box(person, Vector3(0, 0.76, 0.36), Vector3(0.47, 0.19, 0.12), "36495c")
            for x in [-0.15, 0.15]: world.ball(person, Vector3(x, 0.78, 0.43), 0.045, "92bca1")
        6:
            world.tube(person, Vector3(0, 1.61, 0), 0.43, 0.06, "e4c783")
            world.tube(person, Vector3(0, 1.7, 0), 0.26, 0.16, "d6b772")
        7:
            world.tube(person, Vector3(0, 1.61, 0), 0.36, 0.06, "3e4d57")
            world.tube(person, Vector3(0, 1.78, 0), 0.25, 0.29, "3e4d57")
            world.tube(person, Vector3(-0.45, 0.72, 0), 0.035, 1.4, "6b5349")
            world.tube(person, Vector3(-0.45, 1.64, 0), 0.43, 0.32, "667787", 0.06)
        8:
            world.smooth_shape(person, Vector3(-0.53, 0.83, 0), Vector3(0.24, 1.55, 0.48), "e6c26f")
            world.box(person, Vector3(-0.53, 0.83, 0.25), Vector3(0.08, 1.15, 0.03), "74bcb7")
        9:
            world.box(person, Vector3(0.4, 0.46, 0), Vector3(0.36, 0.3, 0.18), "705849")
            world.box(person, Vector3(0.4, 0.65, 0), Vector3(0.16, 0.08, 0.08), "bfa17b")

func at(x: float, z: float) -> Vector3:
    return Vector3(x, w.elevation_at(Vector3(x, 0, z)), z)

func sloped_surface(rect: Rect2, color: String, lift: float) -> void:

    var cuts = [rect.position.y]
    if rect.position.y < 8.0 and rect.end.y > 8.0: cuts.append(8.0)
    cuts.append(rect.end.y)
    var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for j in range(cuts.size() - 1):
        var pts = [at(rect.position.x, cuts[j]), at(rect.end.x, cuts[j]), at(rect.end.x, cuts[j + 1]), at(rect.position.x, cuts[j + 1])]
        for v in [0, 1, 2, 0, 2, 3]:
            st.set_normal(Vector3(0, 1, 0.06 if cuts[j] < 8 else 0).normalized()); st.add_vertex(pts[v] + Vector3(0, lift, 0))
    w.mesh(w, st.commit(), Vector3.ZERO, color)

func road(rect: Rect2) -> void:
    w.roads.append(rect)
    var center = rect.get_center()
    if index == 6:
        sloped_surface(rect, data.pal.p0, 0.125)
    else: w.box(w, at(center.x, center.y) + Vector3(0, 0.105, 0), Vector3(rect.size.x, 0.04, rect.size.y), data.pal.p0)

func water(rect: Rect2) -> void:
    w.water_zones.append(rect)
    var c = rect.get_center()
    w.box(w, Vector3(c.x, 0.045, c.y), Vector3(rect.size.x, 0.12, rect.size.y), data.pal.a1)
    for i in range(8):
        var x = rect.position.x + rect.size.x * (0.12 + 0.1 * i)
        var z = rect.position.y + rect.size.y * (0.15 + fmod(i * 0.29, 0.7))
        w.box(w, Vector3(x, 0.112, z), Vector3(minf(1, rect.size.x * 0.3), 0.012, 0.05), data.pal.a0)

func bridge(rect: Rect2) -> void:
    w.bridges.append(rect); w.roads.append(rect)
    var c = rect.get_center(); w.box(w, Vector3(c.x, 0.14, c.y), Vector3(rect.size.x, 0.28, rect.size.y), data.pal.p0)
    if rect.size.x > rect.size.y:
        for z in [rect.position.y, rect.end.y]: w.box(w, Vector3(c.x, 0.6, z), Vector3(rect.size.x, 0.12, 0.1), data.pal.r1)
    else:
        for x in [rect.position.x, rect.end.x]: w.box(w, Vector3(x, 0.6, c.y), Vector3(0.1, 0.12, rect.size.y), data.pal.r1)

func house(x: float, z: float, width: float, depth: float, height: float, wall: String, roof: String, style: String = "normal") -> void:
    var p = at(x, z); var g = w.group(p)
    w.solid.append(Rect2(x - width / 2, z - depth / 2, width, depth))
    w.flat.append({ "t": "house", "x": x, "z": z, "bw": width, "bd": depth, "wall": wall, "roof": roof, "title": ""})
    w.register_occluder(g, AABB(p + Vector3(- width / 2 - 0.3, 0, - depth / 2 - 0.3), Vector3(width + 0.6, height + 1, depth + 0.6)))
    w.box(g, Vector3(0, height / 2, 0), Vector3(width, height, depth), wall)
    w.box(g, Vector3(0, height, 0), Vector3(width + 0.35, 0.2, depth + 0.35), roof)
    if style == "dome": w.ball(g, Vector3(0, height, 0), width * 0.44, roof, 0.8)
    if style == "hanok" or style == "kyoto":
        for side in [-1, 1]:
            var slab = w.box(g, Vector3(side * width * 0.23, height + 0.25, 0), Vector3(width * 0.65, 0.15, depth + 0.6), roof)
            slab.rotation.z = side * 0.22
        for a in [- width * 0.45, width * 0.45]: w.tube(g, Vector3(a, height / 2, depth * 0.48), 0.065, height, "75533c")
    for row in range(maxi(1, int(height / 1.0))):
        for col in range(maxi(1, int(width / 0.85))):
            var wx = - width * 0.35 + col * 0.8
            w.box(g, Vector3(wx, 0.7 + row * 0.86, depth / 2 + 0.018), Vector3(0.43, 0.53, 0.04), "f1dab0" if index in [5, 7] else data.pal.a0)
    w.box(g, Vector3(0, 0.48, depth / 2 + 0.045), Vector3(0.55, 0.96, 0.05), roof)

func tree(x: float, z: float, kind: String = "tree") -> void:
    var p = at(x, z); var g = w.group(p)
    w.solid.append(Rect2(x - 0.3, z - 0.3, 0.6, 0.6))
    w.flat.append({ "t": "tree", "x": x, "z": z, "s": 1.0, "kind": kind})
    w.register_occluder(g, AABB(p + Vector3(-0.9, 0, -0.9), Vector3(1.8, 3.3, 1.8)))
    if kind == "bamboo":
        for k in range(3):
            w.tube(g, Vector3(k * 0.24 - 0.24, 1.4, k * 0.1), 0.07, 2.8, "719257")
            for y in [0.5, 1.1, 1.7, 2.3]: w.tube(g, Vector3(k * 0.24 - 0.24, y, k * 0.1), 0.085, 0.04, "bdc58a")
        for side in [-1, 1]: w.smooth_shape(g, Vector3(side * 0.35, 2.3, 0), Vector3(0.85, 0.18, 0.32), "9eb47c")
    elif kind == "palm":
        w.tube(g, Vector3(0, 1.25, 0), 0.12, 2.5, "b28e5b")
        for i in range(6):
            var a = i * TAU / 6; var leaf = w.smooth_shape(g, Vector3(cos(a) * 0.6, 2.55, sin(a) * 0.6), Vector3(1.35, 0.16, 0.4), "7aa878"); leaf.rotation.y = - a
    else:
        w.tube(g, Vector3(0, 0.8, 0), 0.12, 1.6, "9b8563")
        if kind == "snow":
            w.tube(g, Vector3(0, 1.6, 0), 0.85, 1.5, "e8eff6", 0.05)
            w.tube(g, Vector3(0, 2.2, 0), 0.6, 1.25, "c9deeb", 0.01)
        else: w.ball(g, Vector3(0, 2, 0), 0.9, "e9b4c5" if kind == "cherry" else data.pal.tr1, 1.15)

func torii(x: float, z: float) -> void:
    var g = w.group(at(x, z))
    for side in [-1, 1]: w.tube(g, Vector3(side * 1.7, 1.8, 0), 0.14, 3.6, "b54e42")
    w.box(g, Vector3(0, 3.6, 0), Vector3(4.3, 0.22, 0.45), "73423a")
    w.box(g, Vector3(0, 2.8, 0), Vector3(3.6, 0.18, 0.28), "c4604c")
    w.box(g, Vector3(0, 3.18, 0), Vector3(0.4, 0.7, 0.25), "e0bd79")
    for side in [-1, 1]: w.solid.append(Rect2(x + side * 1.7 - 0.2, z - 0.2, 0.4, 0.4))

func pyramid(x: float, z: float, s: float) -> void:
    var p = at(x, z); var g = w.group(p)
    for i in range(11):
        var width = s * (1.0 - i / 12.0)
        w.box(g, Vector3(0, 0.18 + i * 0.28, 0), Vector3(width, 0.3, width), "dbba78" if i % 2 else "e9ca8f")
    w.solid.append(Rect2(x - s / 2, z - s / 2, s, s))
    w.register_occluder(g, AABB(p - Vector3(s / 2, 0, s / 2), Vector3(s, 3.6, s)))

func landmark() -> void:
    match index:
        1:
            for z in [-5, -7, -9]: torii(0, z)
            house(0, -11.3, 4, 1.5, 2, "c6ae86", "5e4a3b", "kyoto")
        2:
            pyramid(-6, -8.8, 5.4); pyramid(6, -9.2, 4.5)
            var g = w.group(at(0, -10)); w.box(g, Vector3(0, 0.6, 0), Vector3(2.4, 1.2, 2), "cba86b")
            w.ball(g, Vector3(0, 1.8, 0.5), 0.8, "dfbc77")
            w.box(g, Vector3(0, 2.4, 0.3), Vector3(1.8, 0.3, 1.2), "6c8a9a")
            w.solid.append(Rect2(-1.3, -11.1, 2.6, 2.2))
        3:
            var g = w.group(at(0, -8.5)); w.register_occluder(g, AABB(Vector3(-5, 0, -11.8), Vector3(10, 4.5, 4.3)))
            for i in range(15):
                var a = PI + i * PI / 14; var p = Vector3(cos(a) * 5, 0, sin(a) * 2.9)
                w.box(g, p + Vector3(0, 1.9, 0), Vector3(0.45, 3.8, 0.5), "d7c49b")
                for y in [1.4, 2.8, 3.8]: w.box(g, p + Vector3(0, y, 0), Vector3(1.1, 0.25, 0.6), "eddfbd")
            w.solid.append(Rect2(-5.3, -12, 10.6, 3.9))
        4:
            var g = w.group(at(7, -10)); w.box(g, Vector3(0, 0.6, 0), Vector3(2, 1.2, 2), "c3c5b2")
            w.tube(g, Vector3(0, 2, 0), 0.6, 2, "6f9a8d", 0.3); w.ball(g, Vector3(0, 3.35, 0), 0.4, "83ad9b")
            w.beam(g, Vector3(0.25, 2.8, 0), Vector3(0.85, 4.4, 0), 0.18, "83ad9b")
            w.tube(g, Vector3(0.85, 4.65, 0), 0.16, 0.6, "d8b067"); w.ball(g, Vector3(0.85, 5, 0), 0.24, "f2cd80")
            w.solid.append(Rect2(5.9, -11.1, 2.2, 2.2))
        5:

            for band in range(3):
                for i in range(13):
                    var x = -10 + i * 1.6; var y = 6.8 + sin(i * 0.4 + band) * 0.55 + band * 0.5
                    var ribbon = w.box(w, Vector3(x, y, -11.8 - band * 0.3), Vector3(1.65, 0.35, 0.05), ["81c7ba", "9caacb", "b4d5b5"][band])
                    ribbon.rotation.z = cos(i * 0.4 + band) * 0.13
            for x in [-10, -7, 7, 10]: w.tube(w, at(x, -10) + Vector3(0, 1.2, 0), 1.5, 2.4, "c5dce9", 0.3)
        6:
            house(0, -10, 3.2, 2.8, 2.4, "fcf8ee", "5688b6", "dome")
            var g = w.group(at(-7, -6)); w.tube(g, Vector3(0, 1.5, 0), 0.65, 3, "f9f2df", 0.45)
            var rotor = w.group(Vector3(0, 2.8, 0.55), g); rotor.set_meta("moving", true); w.decor_movers.append(rotor)
            for i in range(4):
                var a = i * PI / 2; w.beam(rotor, Vector3.ZERO, Vector3(cos(a), sin(a), 0) * 1.4, 0.12, "9b8263")
            w.solid.append(Rect2(-7.7, -6.7, 1.4, 1.4))
        7:
            var g = w.group(at(6, -11)); w.register_occluder(g, AABB(Vector3(4.7, 0, -12.3), Vector3(2.6, 7, 2.6)))
            w.box(g, Vector3(0, 2.6, 0), Vector3(1.9, 5.2, 1.9), "bdad88")
            w.box(g, Vector3(0, 5.4, 0), Vector3(2.2, 1.4, 2.2), "d6c7a6")
            w.box(g, Vector3(0, 5.45, 1.115), Vector3(1.3, 1.3, 0.025), "fff4ce")
            w.box(g, Vector3(0, 5.65, 1.14), Vector3(0.07, 0.6, 0.03), "566264")
            w.box(g, Vector3(0.22, 5.45, 1.14), Vector3(0.5, 0.07, 0.03), "566264")
            w.tube(g, Vector3(0, 6.6, 0), 1.3, 1.2, "586373", 0.05)
            w.solid.append(Rect2(4.8, -12.2, 2.4, 2.4))
        8:
            var g = w.group(at(-5, -10)); w.register_occluder(g, AABB(Vector3(-9, 0, -12), Vector3(8, 4, 4)))
            w.box(g, Vector3(0, 0.3, 0), Vector3(7, 0.6, 3.4), "d3c6a9")
            for i in range(4):
                var sail = w.smooth_shape(g, Vector3(-2.4 + i * 1.5, 1.5, 0), Vector3(1.4, 3.4 - i * 0.2, 2.7), "f6f0d9")
                sail.rotation.z = -0.3 + i * 0.12
            w.solid.append(Rect2(-8.7, -11.9, 7.4, 3.8))
        9:
            var g = w.group(at(0, -10)); w.register_occluder(g, AABB(Vector3(-1.5, 0, -11.5), Vector3(3, 7.6, 3)))
            w.tube(g, Vector3(0, 2.9, 0), 0.24, 5.8, "dddcd0", 0.18)
            w.tube(g, Vector3(0, 5.3, 0), 1.2, 0.7, "c8d2ce", 0.95)
            w.tube(g, Vector3(0, 6.6, 0), 0.08, 2, "c4817e")
            w.solid.append(Rect2(-1, -11, 2, 2))

func mission_props() -> void:
    for i in range(data.points.size()):
        var q = data.points[i]; var g = w.group(at(q[0], q[1])); g.set_meta("moving", true)
        w.mission_nodes.append(g)
        w.tube(g, Vector3(0, 0.14, 0), 0.55, 0.15, "dac799")
        match data.kind:
            "lantern":
                w.tube(g, Vector3(0, 0.6, 0), 0.09, 1.2, "755846")
                w.box(g, Vector3(0, 1.1, 0), Vector3(0.5, 0.55, 0.5), ["d696ac", "8faf78", "e6bb6e"][i])
                w.box(g, Vector3(0, 1.45, 0), Vector3(0.65, 0.1, 0.65), "685649")
            "runes":
                w.box(g, Vector3(0, 0.8, 0), Vector3(0.7, 1.6, 0.7), "c8a76a")
                var rune = w.sign3d(g, Vector3(0, 1.1, 0.42), "태양", 25, "fff3ce"); rune.name = "Rune"
            "fire":
                for k in range(3):
                    var log = w.box(g, Vector3(0, 0.28, 0), Vector3(0.8, 0.17, 0.18), "876b53"); log.rotation.y = k * PI / 3
                var flame = w.tube(g, Vector3(0, 0.67, 0), 0.3, 0.75, "f1b96a", 0.03); flame.name = "Flame"; flame.visible = false
            "detective":
                var person = w.character(i == 1, ["a37f72", "6f8992", "a6a477"][i]); person.reparent(g); person.position = Vector3(0, 0.16, 0)
            "tide":
                var board = w.smooth_shape(g, Vector3(0, 0.3, 0), Vector3(0.6, 0.15, 1.7), ["d58b7f", "e6bd76", "6eacbd"][i]); board.name = "Board"
                w.box(g, Vector3(0, 0.39, 0), Vector3(0.1, 0.02, 1.2), "fff0cf")
            "vista":
                for side in [-1, 1]: w.beam(g, Vector3(0, 0.8, 0), Vector3(side * 0.35, 0.2, 0.25), 0.06, "766958")
                w.box(g, Vector3(0, 1, 0), Vector3(0.65, 0.45, 0.28), "536c6b")
                w.ball(g, Vector3(0, 1, 0.19), 0.15, "a6c9c8")
            "delivery":
                w.box(g, Vector3(0, 0.55, 0), Vector3(0.8, 0.75, 0.8), "d6ac73")
                w.box(g, Vector3(0, 0.94, 0), Vector3(0.12, 0.03, 0.8), "f2dfb6")
            _:
                w.tube(g, Vector3(0, 0.45, 0), 0.42, 0.6, data.pal.r1)
                w.sign3d(g, Vector3(0, 1, 0), str(i + 1), 36, "fff4d6")
        var glow = w.ball(g, Vector3(0, 1.75, 0), 0.14, "f6d58b"); glow.name = "Done"; glow.visible = false
        var label = w.sign3d(g, Vector3(0, 2.15, 0), data.labels[i], 23, "35524d"); label.outline_size = 4; label.outline_modulate = Color("fff8e8")

func build(world: Node3D, city: int) -> void:
    w = world; index = city; data = Cities.CITIES[index]
    w.roads.clear(); w.water_zones.clear(); w.bridges.clear(); w.grass_zones.clear()
    w.box(w, Vector3(0, -0.65, 0), Vector3(27, 1.2, 29), data.pal.p2)
    if index == 6:
        sloped_surface(Rect2(-13.3, -14, 22.4, 28), data.pal.g0, 0.085)
    else: w.box(w, Vector3(0, 0.015, 0), Vector3(26.8, 0.14, 28.8), data.pal.g0)
    match index:
        1:
            for rect in [Rect2(-1.4, -11, 2.8, 23), Rect2(-10, 5, 20, 2.2), Rect2(-9, -3, 9, 2), Rect2(0, -7, 10, 2)]: road(rect)
            water(Rect2(3, -3, 6, 4)); house(-8, -7, 3.2, 3, 2.3, "c5a67d", "665142", "kyoto"); house(8, 8, 3.2, 3, 2, "e2c7a2", "80594b", "kyoto")
            for p in [ [-11, 8], [-11, 3], [-10, -2], [-4, -8], [4, -10], [10, -9], [11, 4]]: tree(p[0], p[1], "bamboo")
            for p in [ [-5, 10], [5, 10], [10, -4]]: tree(p[0], p[1], "cherry")
        2:
            for rect in [Rect2(-1.4, -8, 2.8, 20), Rect2(-9, 0, 18, 2), Rect2(-9, 7, 18, 2)]: road(rect)
            water(Rect2(-10, 3.5, 4, 2)); water(Rect2(6, 3.5, 4, 2))
            house(-9, 9, 3, 2.8, 1.8, "e1c08a", "b08a59"); house(9, 9, 3, 2.8, 2, "edcf9a", "c59a63")
            for p in [ [-11, 3], [-5, 4], [5, 4], [11, 3]]: tree(p[0], p[1], "palm")
            for i in range(8): w.smooth_shape(w, at(-11 + i * 3, -12.6), Vector3(2.4, 0.7, 1), "e7cd98")
        3:
            for rect in [Rect2(-1.4, -7, 2.8, 19), Rect2(-10, 3, 20, 2), Rect2(-9, -2, 18, 2)]: road(rect)
            for p in [ [-9, -5], [9, -5]]:
                for z in [-1, 1]: w.tube(w, at(p[0], p[1] + z) + Vector3(0, 1.25, 0), 0.24, 2.5, "e2d6b6")
            water(Rect2(4, 7, 3, 2)); house(-8, 9, 4, 2.5, 2.4, "e6d5b2", "b77f64")
            for p in [ [-11, 8], [10, 10], [-11, -9], [11, -9]]: tree(p[0], p[1])
        4:
            for x in [-8, 0, 7]: road(Rect2(x - 1.3, -11, 2.6, 23))
            for z in [-7, 1, 8]: road(Rect2(-11, z - 1.1, 21, 2.2))
            water(Rect2(10, -13, 3, 26))
            for p in [ [-4, -10, 6], [-4, -3, 7], [-4, 5, 5], [4, 10, 5], [4, -3, 6], [-11, 5, 4]]: house(p[0], p[1], 2.7, 3.3, p[2], "a6b5c6", "607889")
            for p in [ [5, -10], [4, -7], [8, -2], [9, 1]]: tree(p[0], p[1])
        5:
            for rect in [Rect2(-1.4, -6, 2.8, 18), Rect2(-9, 5, 18, 2), Rect2(-7, -5, 14, 2), Rect2(-8, -5, 2, 11), Rect2(6, -6, 2, 12)]: road(rect)
            water(Rect2(-3, -13, 6, 5)); house(-9, 10, 3, 2, 1.7, "a4bdcd", "e6edf1"); house(9, 10, 3, 2, 1.7, "9fb1c1", "e6edf1")
            for p in [ [-11, 3], [11, 2], [-10, -5], [10, -7], [-5, 9], [5, 9]]: tree(p[0], p[1], "snow")
        6:
            for rect in [Rect2(-1.3, -8, 2.6, 20), Rect2(-9, 6, 18, 2), Rect2(-9, -1, 18, 2), Rect2(-8, -6, 16, 2)]: road(rect)
            water(Rect2(9, -14, 4.3, 28))
            for p in [ [-6, 10], [6, 10], [-6, 3], [6, -4], [-6, -10]]: house(p[0], p[1], 3, 2.5, 1.9, "fff9ed", "6c9ebd", "dome")
            for p in [ [-10, 8], [-10, -2], [8, 8]]: tree(p[0], p[1])
        7:
            water(Rect2(-2, -14, 4, 28))
            for x in [-6, 6]: road(Rect2(x - 1.3, -10, 2.6, 22))
            for z in [-5.5, 5.5]: road(Rect2(-10, z - 1, 20, 2)); bridge(Rect2(-2.6, z - 1, 5.2, 2))
            for p in [ [-10, -8], [-10, 0], [10, -2], [10, 9]]: house(p[0], p[1], 2.8, 3, 3, "b68e7e", "67717d")
            var g = w.group(at(-9, 5)); w.box(g, Vector3(0, 1, 0), Vector3(0.75, 2, 0.7), "b6514e"); w.box(g, Vector3(0, 1.2, 0.36), Vector3(0.5, 1.2, 0.03), "bbd3d3")
            for p in [ [-10, 10], [10, 3], [-10, -3]]: tree(p[0], p[1])
        8:
            water(Rect2(6, -14, 7.4, 28))
            for z in [-6, 0, 6]:
                var surf = w.group(Vector3(6.3, 0.14, z)); surf.set_meta("moving", true); w.tide_lines.append(surf)
                for j in range(5): w.box(surf, Vector3(sin(j) * 0.11, 0, (j - 2) * 0.47), Vector3(0.12, 0.025, 0.48), "d5e8dd")
            for rect in [Rect2(-1.3, -8, 2.6, 20), Rect2(-9, 7, 14, 2), Rect2(-7, -7, 12, 2), Rect2(3, -8, 2, 17)]: road(rect)
            bridge(Rect2(4, -8, 7, 1.6))
            house(-8, 9, 3, 2.4, 1.8, "f3ddba", "d68c69"); house(-8, 2, 3.2, 3, 1.8, "e8d8b9", "bf8d65")
            for p in [ [-10, 6], [-4, 5], [-10, -3], [1, -10]]: tree(p[0], p[1], "palm")
            for i in range(5): w.smooth_shape(w, at(5.5, -10 + i * 4) + Vector3(0, 0.14, 0), Vector3(0.35, 0.1, 0.2), "f6e6cd")
        9:
            water(Rect2(-13, 2, 26, 2)); bridge(Rect2(-1.6, 1.7, 3.2, 2.6)); bridge(Rect2(-9, 1.7, 2, 2.6))
            for rect in [Rect2(-1.3, -8, 2.6, 20), Rect2(-10, 6, 20, 2), Rect2(-10, -2, 20, 2), Rect2(-8, -7, 16, 2)]: road(rect)
            for p in [ [-8, -10], [8, -10], [-9, 10], [8, 10]]: house(p[0], p[1], 3.6, 2.5, 2, "d5c4a7", "68747b", "hanok")
            for p in [ [-11, -4], [11, -4], [-4, 10], [4, 10]]: tree(p[0], p[1], "cherry")
    landmark()
    for x in range(-11, 12, 2):
        for z in range(-11, 12, 2):
            var point = at(x + 0.23, z + 0.18)
            if not w.can_walk(point) or w.on_path(point): continue
            var clear = true
            for q in data.points:
                if Vector2(q[0] - point.x, q[1] - point.z).length() < 1.1: clear = false
            if not clear: continue
            for k in range(3):
                w.box(w, point + Vector3(k * 0.12, 0.14, k * 0.08), Vector3(0.055, 0.18 + k * 0.035, 0.06), data.pal.g2)
    mission_props()
    var marker = w.group(Vector3.ZERO); marker.set_meta("moving", true); w.marker = marker
    var ring = TorusMesh.new(); ring.inner_radius = 0.52; ring.outer_radius = 0.61; ring.rings = 24; ring.ring_segments = 6
    w.mesh(marker, ring, Vector3.ZERO, "f9cc72")

    var shop = data.shop_at; var stand = w.group(at(shop[0], shop[1])); stand.set_meta("moving", true)
    w.flat.append({ "t": "shop", "x": float(shop[0]), "z": float(shop[1])})
    w.box(stand, Vector3(0, 0.45, -0.55), Vector3(1.8, 0.8, 0.65), data.pal.r1)
    w.sign3d(stand, Vector3(0, 1.55, -0.55), data.shop, 23, "35524d")
    w.merge_static_geometry(); w.prepare_occluders()
