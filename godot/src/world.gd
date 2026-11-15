extends Node3D
const TourWorld = preload ("res://scripts/tour_world.gd")
var city_index = 0
var mission_nodes: Array = []
var decor_movers: Array = []
var swayers: Array = []        # 바람에 흔들리는 나무
var clouds: Array = []         # 하늘에 흐르는 구름
var tide_lines: Array = []
var roads: Array[Rect2] = [Rect2(-1.55, -9.4, 3.1, 11.2), Rect2(-1.55, 4.75, 3.1, 7.1), Rect2(-10.5, -2.3, 21, 2.6), Rect2(-10.5, 6.3, 21, 2.4)]
var water_zones: Array[Rect2] = [Rect2(-13, 1.2, 26, 3.6)]
var bridges: Array[Rect2] = [Rect2(-1.55, 0.9, 3.1, 4.2)]

var solid: Array[Rect2] = []
var area = 0                  # 0 = 도시 중심, 1 = 골목, 2 = 자연 구역
var gates: Array = []         # {"x","z","to","label"} — 다른 구역으로 가는 문
var chests: Array = []        # {"x","z","i"} — 보물 상자 (i = 도시 안에서의 번호)
var extras: Array = []
var zones: Array = []         # {"r": Rect2, "c": 색} — 광장·모래사장 같은 바닥
var legend: Dictionary = {}   # {"x","z"} — 전설의 괴물이 잠든 자리 (자연 구역)
var eggs: Array = []          # {"x","z","i"} — 숨은 발견        # {"t": "shard"|"npc", "x","z"}
const AREA_NAMES = [
    ["몽마르트 골목", "센강 둔치"], ["기온 뒷골목", "대나무 숲"], ["시장 골목", "오아시스"], ["트라스테베레 골목", "올리브 언덕"], ["브루클린 골목", "센트럴 파크"],
    ["어촌 골목", "빙하 호수"], ["이아 골목", "절벽 아래 해변"], ["소호 골목", "템스 강변 공원"], ["더 록스 골목", "유칼립투스 숲"], ["익선동 골목", "한강 공원"],
]
var flat: Array = []          # 2D 탐험 화면용 납작한 장면 목록
var materials: Dictionary = {}
var water_bits: Array[Node3D] = []
var pickups: Array[Node3D] = []
var marker: Node3D
var ambient_people: Array[Node3D] = []
var font: Font
var grass_zones: Array[Rect2] = [Rect2(-9, 8.9, 5, 1.5), Rect2(4, 8.9, 5, 1.5), Rect2(-9, -8.5, 5, 1.8), Rect2(4, -8.5, 5, 1.8)]
var occluders: Array = []
var hidden_people: Array[bool] = [false, false]
var faded_count = 0

func mat(hex: String) -> StandardMaterial3D:
    if materials.has(hex): return materials[hex]
    var m = StandardMaterial3D.new()
    m.albedo_color = Color(hex)
    m.roughness = 0.92
    materials[hex] = m
    return m

func mesh(parent: Node3D, shape: Mesh, pos: Vector3, color: String) -> MeshInstance3D:
    var n = MeshInstance3D.new()
    n.mesh = shape
    n.material_override = mat(color)
    n.position = pos
    parent.add_child(n)
    return n

func box(parent: Node3D, pos: Vector3, size: Vector3, color: String) -> MeshInstance3D:
    var m = BoxMesh.new()
    m.size = size
    return mesh(parent, m, pos, color)

func ball(parent: Node3D, pos: Vector3, radius: float, color: String, scale_y: float = 1.0) -> MeshInstance3D:
    var m = SphereMesh.new()
    m.radius = radius
    m.height = radius * 2.0
    m.radial_segments = 12
    m.rings = 6
    var n = mesh(parent, m, pos, color)
    n.scale.y = scale_y
    return n

func tube(parent: Node3D, pos: Vector3, radius: float, height: float, color: String, top: float = -1.0) -> MeshInstance3D:
    var m = CylinderMesh.new()
    m.bottom_radius = radius
    m.top_radius = radius if top < 0 else top
    m.height = height
    m.radial_segments = 10
    return mesh(parent, m, pos, color)

func beam(parent: Node3D, a: Vector3, b: Vector3, width: float, color: String) -> MeshInstance3D:
    var n = box(parent, (a + b) / 2.0, Vector3(width, a.distance_to(b), width), color)
    n.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
    return n

func sign3d(parent: Node3D, pos: Vector3, text: String, size: int = 48, color: String = "344c47") -> Label3D:
    var l = Label3D.new()
    l.position = pos
    l.text = text
    l.font = font
    l.font_size = size
    l.pixel_size = 0.009
    l.modulate = Color(color)
    l.outline_size = 0
    l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    l.no_depth_test = false
    parent.add_child(l)
    l.add_to_group("world_labels")
    return l

func group(pos: Vector3, parent: Node3D = self) -> Node3D:
    var n = Node3D.new()
    n.position = pos
    parent.add_child(n)
    return n

func build(f: Font, destination: int = 0, zone: int = 0) -> void:
    font = f; city_index = destination; area = zone
    flat.clear(); gates.clear(); chests.clear(); extras.clear(); zones.clear(); eggs.clear()
    if area > 0:
        TourWorld.new().build_area(self, city_index, area); seal_flat(); return
    if city_index > 0:
        TourWorld.new().build(self, city_index); seal_flat(); place_gates(); return

    box(self, Vector3(0, -0.65, 0), Vector3(27, 1.2, 29), "c8bda3")
    box(self, Vector3(0, -0.05, 0), Vector3(26.8, 0.12, 28.8), "e9dcc0")
    box(self, Vector3(0, 0.035, -6.0), Vector3(26.4, 0.1, 15.0), "a9ba8f")
    box(self, Vector3(0, 0.035, 9.0), Vector3(26.4, 0.1, 9.8), "acbd91")
    box(self, Vector3(0, 0.04, 3.0), Vector3(26.5, 0.1, 3.2), "73b5b5")
    box(self, Vector3(0, 0.11, 3.0), Vector3(3.4, 0.35, 4.2), "f1dec0")
    for side in [-1, 1]:
        box(self, Vector3(side * 1.65, 0.62, 3), Vector3(0.13, 0.12, 4.2), "e9ceb1")
        for j in range(7): tube(self, Vector3(side * 1.65, 0.36, 1.0 + j * 0.66), 0.065, 0.6, "e9ceb1")

    box(self, Vector3(0, 0.105, -3.8), Vector3(3.1, 0.04, 11.2), "f3e4c7")
    box(self, Vector3(0, 0.105, 8.3), Vector3(3.1, 0.04, 7.1), "f3e4c7")
    box(self, Vector3(0, 0.105, -1), Vector3(21, 0.04, 2.6), "f3e4c7")
    box(self, Vector3(0, 0.105, 7.5), Vector3(21, 0.04, 2.4), "f3e4c7")
    for z in range(-10, 13, 2):
        if z > 0 and z < 6: continue
        box(self, Vector3(0, 0.13, z), Vector3(0.03, 0.015, 0.9), "e7d4b5")
    for i in range(22):
        var x = -12.0 + fmod(i * 7.13, 24.0)
        var z = 1.8 + fmod(i * 0.73, 2.3)
        water_bits.append(box(self, Vector3(x, 0.11, z), Vector3(0.3 + fmod(i * 0.21, 0.8), 0.02, 0.045), "b0d5cd"))

    building(Vector3(-7.1, 0, -3.8), "e9bb97", "a85e50", "MAISON MIEL", true)
    building(Vector3(7.6, 0, -3.8), "e7d9b7", "527b74", "CAFÉ DES AMIS", false)
    solid.append(Rect2(-9.6, -6.0, 5.0, 3.7))
    solid.append(Rect2(5.1, -6.0, 5.0, 3.7))
    flat.append({ "t": "house", "x": -7.1, "z": -4.15, "bw": 5.0, "bd": 3.7, "wall": "e9bb97", "roof": "a85e50", "title": "앨리 빵집"})
    flat.append({ "t": "house", "x": 7.6, "z": -4.15, "bw": 5.0, "bd": 3.7, "wall": "e7d9b7", "roof": "527b74", "title": "카페"})
    eiffel(Vector3(0, 0, -9.3))
    solid.append(Rect2(-1.7, -10.9, 3.4, 3.0))
    flat.append({ "t": "tower", "x": 0.0, "z": -9.3})

    for pos in [Vector3(-11, 0, -10), Vector3(-6, 0, -10), Vector3(6, 0, -10), Vector3(11, 0, -10), Vector3(-11, 0, 0), Vector3(11, 0, 0), Vector3(-10, 0, 11), Vector3(-6, 0, 11), Vector3(6, 0, 11), Vector3(10, 0, 11), Vector3(-11, 0, 6), Vector3(11, 0, 6)]:
        tree(pos, 1.0 + fmod(abs(pos.x) * 0.13, 0.3))
    for pos in [Vector3(-3.0, 0, -5), Vector3(3.0, 0, -5), Vector3(-3.1, 0, 5.5), Vector3(3.1, 0, 5.5)]: lamp(pos)
    for pos in [Vector3(-4, 0, 10), Vector3(4, 0, 10), Vector3(-4, 0, -7), Vector3(4, 0, -7)]: flowerbed(pos)
    bench(Vector3(-7.3, 0, 5.1)); bench(Vector3(7.3, 0, 5.1))

    for x in [-10.7, 10.7]:
        tube(self, Vector3(x, 0.6, -2), 0.55, 0.12, "f7e6c2")
        tube(self, Vector3(x, 0.3, -2), 0.07, 0.6, "6d7863")
        tube(self, Vector3(x, 1.8, -2), 0.035, 2.5, "7b7d66")
        tube(self, Vector3(x, 2.8, -2), 1.1, 0.45, "ead2a2", 0.05)
    for i in range(3):
        var at = [Vector3(-5, 0, 7.5), Vector3(5, 0, 7.5), Vector3(-3.5, 0, -1)][i]
        var node = group(at)
        node.set_meta("moving", true)
        tube(node, Vector3(0, 0.1, 0), 0.55, 0.13, "e4c091")
        ball(node, Vector3(0, 0.5, 0), 0.24, ["eac66f", "f2ebe0", "e8a174"][i])
        sign3d(node, Vector3(0, 1.3, 0), ["밀가루", "우유", "버터"][i], 27)
        pickups.append(node)
    flat.append({ "t": "shop", "x": 8.6, "z": 10.2})
    var stand = group(Vector3(8.6, 0, 10.2))
    box(stand, Vector3(0, 0.45, -0.55), Vector3(1.8, 0.8, 0.65), "c85068")
    sign3d(stand, Vector3(0, 1.55, -0.55), "앨리 빵집", 23, "35524d")
    marker = group(Vector3(0, 0.2, 0))
    marker.set_meta("moving", true)
    var ring = TorusMesh.new()
    ring.inner_radius = 0.52; ring.outer_radius = 0.61; ring.rings = 24; ring.ring_segments = 6
    mesh(marker, ring, Vector3.ZERO, "f9cc72")

    sign3d(self, Vector3(-7, 5, -3.8), "01  ·  빵집", 32)
    sign3d(self, Vector3(0, 8, -9.3), "PARIS", 40, "405e55")
    for i in range(2):
        var person = character(false, ["dba566", "9ea7bc"][i])
        person.position = Vector3(7 + i * 2, 0, 0)
        ambient_people.append(person)
    build_grass()
    build_clouds()
    merge_static_geometry()
    prepare_occluders()
    seal_flat()
    place_gates()

# 도시 중심 지도 가장자리에서 걸어갈 수 있는 자리를 찾아 두 구역으로 가는 문을 세운다
func place_gates() -> void:
    var Cities = preload ("res://scripts/city_data.gd")
    var data = Cities.CITIES[city_index]
    var busy = [data.spawn, data.boss_at, data.photo_at, data.shop_at]
    for q in data.points: busy.append(q)
    var offsets = [0.0, 1.5, -1.5, 3.0, -3.0, 4.5, -4.5, 6.0, -6.0, 8.0, -8.0, 10.0, -10.0]
    for which in range(2):
        var spots = []
        for d in offsets:
            if which == 0:
                spots.append(Vector2(-11.3, d)); spots.append(Vector2(11.3, d))
            else:
                spots.append(Vector2(d, 11.8)); spots.append(Vector2(d, -11.8))
        for spot in spots:
            if not can_walk(Vector3(spot.x, 0, spot.y)): continue
            var clear = true
            for q in busy:
                if Vector2(q[0], q[1]).distance_to(spot) < 2.4: clear = false
            for gate in gates:
                if Vector2(gate.x, gate.z).distance_to(spot) < 4.0: clear = false
            if not clear: continue
            gates.append({ "x": spot.x, "z": spot.y, "to": which + 1, "label": AREA_NAMES[city_index][which]})
            flat.append({ "t": "gate", "x": spot.x, "z": spot.y, "label": AREA_NAMES[city_index][which]})
            break

    # 숨은 발견: 구석진 자리 하나
    for spot in [Vector2(10.6, -10.6), Vector2(-10.6, 10.6), Vector2(-10.6, -10.6), Vector2(10.6, 10.6), Vector2(8.0, -10.8), Vector2(-8.0, 10.8), Vector2(-11.2, -6.0), Vector2(11.2, 6.0)]:
        if not can_walk(Vector3(spot.x, 0, spot.y)): continue
        var free = true
        for q in busy:
            if Vector2(q[0], q[1]).distance_to(spot) < 2.6: free = false
        for gate in gates:
            if Vector2(gate.x, gate.z).distance_to(spot) < 2.6: free = false
        if not free: continue
        eggs.append({ "x": spot.x, "z": spot.y, "i": 0}); flat.append({ "t": "egg", "x": spot.x, "z": spot.y, "i": 0})
        break

func gate_to(zone: int) -> Dictionary:
    for gate in gates:
        if int(gate.to) == zone: return gate
    return {}

func seal_flat() -> void:
    for rect in solid:
        if rect.size.x < 0.5: continue
        var mid = rect.get_center()
        var known = false
        for d in flat:
            if absf(float(d.x) - mid.x) < 0.75 and absf(float(d.z) - mid.y) < 0.75: known = true
        if known: continue
        flat.append({ "t": "monument", "x": mid.x, "z": mid.y, "bw": rect.size.x, "bd": rect.size.y})

func building(pos: Vector3, wall: String, awning: String, title: String, bakery: bool) -> void:
    var g = group(pos)
    register_occluder(g, AABB(pos + Vector3(-2.65, 0, -1.95), Vector3(5.3, 4.3, 4.6)))
    box(g, Vector3(0, 1.65, 0), Vector3(4.8, 3.3, 3.5), wall)
    box(g, Vector3(0, 3.4, 0), Vector3(5.1, 0.3, 3.8), "f4dfb8")
    box(g, Vector3(0, 3.8, 0), Vector3(4.6, 0.55, 3.1), "65716d")
    box(g, Vector3(0, 4.13, 0), Vector3(4.85, 0.12, 3.3), "536562")
    for x in [-1.4, 0, 1.4]:
        box(g, Vector3(x, 2.6, 1.77), Vector3(0.8, 0.95, 0.07), "f9edce")
        box(g, Vector3(x, 2.6, 1.82), Vector3(0.59, 0.72, 0.04), "729693")
        box(g, Vector3(x, 2.6, 1.85), Vector3(0.035, 0.72, 0.025), "f9edce")
        box(g, Vector3(x, 2.6, 1.85), Vector3(0.59, 0.035, 0.025), "f9edce")
    box(g, Vector3(0, 0.85, 1.79), Vector3(0.85, 1.7, 0.08), "4b6863")
    box(g, Vector3(0, 1.02, 1.85), Vector3(0.59, 1.05, 0.03), "a7c6bc")
    ball(g, Vector3(0.25, 0.7, 1.9), 0.05, "e4bd75")
    for x in [-1.45, 1.45]:
        box(g, Vector3(x, 0.88, 1.8), Vector3(1.4, 1.2, 0.09), "f7e4bf")
        box(g, Vector3(x, 0.9, 1.86), Vector3(1.2, 0.95, 0.05), "88aaa1")
        if bakery:
            for j in range(3):
                var bread = ball(g, Vector3(x - 0.35 + j * 0.35, 0.65, 1.94), 0.16, "e3b268", 0.65)
                bread.scale.z = 0.6
    box(g, Vector3(0, 1.91, 1.82), Vector3(4.6, 0.45, 0.12), awning)
    var l = sign3d(g, Vector3(0, 1.95, 1.92), title, 31, "fff2d7")
    l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
    l.pixel_size = 0.007
    for i in range(10):
        var cloth = box(g, Vector3(-2.25 + i * 0.5, 1.7, 2.15), Vector3(0.5, 0.09, 0.9), awning if i % 2 == 0 else "f7e6c6")
        cloth.rotation.x = 0.2
        box(g, Vector3(-2.25 + i * 0.5, 1.52, 2.58), Vector3(0.5, 0.22, 0.06), awning if i % 2 == 0 else "f7e6c6")
    box(g, Vector3(0, 0.12, 2.02), Vector3(1.3, 0.24, 0.6), "dfcba8")

func eiffel(pos: Vector3) -> void:
    var g = group(pos)
    register_occluder(g, AABB(pos + Vector3(-1.9, 0, -1.9), Vector3(3.8, 7.8, 3.8)))
    var iron = "897457"
    for x in [-1, 1]:
        for z in [-1, 1]:
            beam(g, Vector3(x * 1.8, 0, z * 1.8), Vector3(x * 0.65, 3.4, z * 0.65), 0.22, iron)
            beam(g, Vector3(x * 0.65, 3.4, z * 0.65), Vector3(x * 0.23, 5.6, z * 0.23), 0.15, iron)
            beam(g, Vector3(x * 0.23, 5.6, z * 0.23), Vector3(0, 7.2, 0), 0.1, iron)
    box(g, Vector3(0, 2.0, 0), Vector3(2.6, 0.16, 2.6), iron)
    box(g, Vector3(0, 3.4, 0), Vector3(1.7, 0.17, 1.7), iron)
    box(g, Vector3(0, 5.5, 0), Vector3(0.85, 0.13, 0.85), iron)
    beam(g, Vector3(0, 6.5, 0), Vector3(0, 7.7, 0), 0.07, iron)
    for z in [-1, 1]:
        for level in range(3):
            var y = 0.4 + level * 0.55
            var r = 1.8 - y * 0.32
            beam(g, Vector3(- r, y, z * r), Vector3(r - 0.25, y + 0.55, z * (r - 0.18)), 0.065, iron)
            beam(g, Vector3(r, y, z * r), Vector3(- r + 0.25, y + 0.55, z * (r - 0.18)), 0.065, iron)

func tree(pos: Vector3, s: float) -> void:
    var g = group(pos)
    g.scale = Vector3.ONE * s
    register_occluder(g, AABB(pos + Vector3(-1.1, 0, -1.1) * s, Vector3(2.2, 3.0, 2.2) * s))
    tube(g, Vector3(0, 0.65, 0), 0.13, 1.3, "9b8563")
    ball(g, Vector3(0, 1.8, 0), 0.9, "74987b", 1.25)
    ball(g, Vector3(-0.35, 1.6, 0.2), 0.58, "87a784")
    tube(g, Vector3(0, 0.1, 0), 0.7, 0.2, "dfcfb0")
    solid.append(Rect2(pos.x - 0.4, pos.z - 0.4, 0.8, 0.8))
    flat.append({ "t": "tree", "x": pos.x, "z": pos.z, "s": s, "kind": "tree"})
    swayers.append({ "node": g, "phase": randf() * TAU, "amp": 0.022 + randf() * 0.018 })

func flowerbed(pos: Vector3) -> void:
    flat.append({ "t": "flower", "x": pos.x, "z": pos.z})
    box(self, pos + Vector3(0, 0.16, 0), Vector3(1.8, 0.3, 0.8), "d4c6a3")
    box(self, pos + Vector3(0, 0.33, 0), Vector3(1.6, 0.12, 0.6), "789371")
    for i in range(5): ball(self, pos + Vector3(-0.65 + i * 0.32, 0.46, 0), 0.15, "df9a87" if i % 2 else "f0ce7e", 0.8)

func lamp(pos: Vector3) -> void:
    flat.append({ "t": "lamp", "x": pos.x, "z": pos.z})
    tube(self, pos + Vector3(0, 1.2, 0), 0.045, 2.4, "526a60")
    box(self, pos + Vector3(0, 2.4, 0), Vector3(0.32, 0.45, 0.32), "fae9b6")
    tube(self, pos + Vector3(0, 2.68, 0), 0.26, 0.15, "526a60", 0.02)

func bench(pos: Vector3) -> void:
    flat.append({ "t": "bench", "x": pos.x, "z": pos.z})
    for i in range(3): box(self, pos + Vector3(0, 0.45, i * 0.13), Vector3(1.6, 0.09, 0.1), "bd9971")
    for x in [-0.6, 0.6]: box(self, pos + Vector3(x, 0.2, 0.12), Vector3(0.08, 0.4, 0.3), "607266")
    box(self, pos + Vector3(0, 0.85, -0.06), Vector3(1.6, 0.48, 0.08), "bd9971")

func smooth_shape(parent: Node3D, pos: Vector3, size: Vector3, color: String) -> MeshInstance3D:
    var shape = SphereMesh.new(); shape.radius = 0.5; shape.height = 1.0
    shape.radial_segments = 24; shape.rings = 12
    var n = mesh(parent, shape, pos, color); n.scale = size

    n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return n

func hair_shell(body: Node3D, girl: bool) -> void:
    var surface = SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var radii = Vector3(0.329, 0.35, 0.311)
    var rings = 16; var slices = 40
    for row in range(rings):
        for col in range(slices):

            for corner in [Vector2i(0, 0), Vector2i(1, 1), Vector2i(1, 0), Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]:
                var phi = TAU * float(col + corner.y) / slices

                var edge = 1.72 - 0.43 * cos(phi) + (0.12 if girl and cos(phi) < 0 else 0.0)
                var theta = edge * float(row + corner.x) / rings
                var unit = Vector3(sin(theta) * sin(phi), cos(theta), sin(theta) * cos(phi))
                var position = unit * radii
                surface.set_normal( (unit / radii).normalized()); surface.add_vertex(position)
    var hair = mesh(body, surface.commit(), Vector3(0, 0.57, 0.01), "4c3e36")
    hair.name = "HairShell"; hair.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var material = mat("4c3e36").duplicate(); material.cull_mode = BaseMaterial3D.CULL_BACK
    hair.material_override = material

func character(girl: bool, outfit: String = "") -> Node3D:
    var g = group(Vector3.ZERO); g.set_meta("moving", true)
    var color = outfit if outfit != "" else ("c8796e" if girl else "4c7f85")
    var body = group(Vector3(0, 0.75, 0), g); body.name = "Body"
    smooth_shape(body, Vector3(0, 0.01, 0), Vector3(0.51, 0.64, 0.43), color)
    if girl: smooth_shape(body, Vector3(0, -0.15, 0), Vector3(0.65, 0.38, 0.51), color)

    smooth_shape(body, Vector3(0, 0.31, 0), Vector3(0.19, 0.25, 0.19), "edc7a4")
    var head = smooth_shape(body, Vector3(0, 0.57, 0.01), Vector3(0.61, 0.65, 0.57), "edc7a4"); head.name = "Head"
    hair_shell(body, girl)
    if girl:
        smooth_shape(body, Vector3(0, 0.35, -0.24), Vector3(0.58, 0.66, 0.22), "4c3e36")
        for side in [-1, 1]:
            smooth_shape(body, Vector3(side * 0.265, 0.43, -0.025), Vector3(0.16, 0.5, 0.24), "4c3e36")
        smooth_shape(body, Vector3(-0.08, 0.73, 0.245), Vector3(0.33, 0.16, 0.19), "4c3e36")
        smooth_shape(body, Vector3(0.19, 0.715, 0.225), Vector3(0.19, 0.17, 0.17), "4c3e36")
        smooth_shape(body, Vector3(0.305, 0.67, 0.12), Vector3(0.065, 0.16, 0.065), "d9ab68")
    else:
        for i in range(3):
            var fringe = smooth_shape(body, Vector3(-0.16 + i * 0.15, 0.72 + i * 0.012, 0.248), Vector3(0.24, 0.15, 0.19), "4c3e36")
            fringe.rotation.z = -0.26
    for side in [-1, 1]:
        smooth_shape(body, Vector3(side * 0.29, 0.56, 0), Vector3(0.1, 0.15, 0.13), "edc7a4")
        smooth_shape(body, Vector3(side * 0.105, 0.6, 0.28), Vector3(0.055, 0.068, 0.038), "293b37")
        smooth_shape(body, Vector3(side * 0.18, 0.49, 0.25), Vector3(0.085, 0.04, 0.035), "db9b87")
        var arm = group(Vector3(side * 0.26, 0.16, 0), body); arm.name = "ArmL" if side < 0 else "ArmR"
        smooth_shape(arm, Vector3(side * 0.025, -0.13, 0), Vector3(0.18, 0.36, 0.18), color)
        smooth_shape(arm, Vector3(side * 0.035, -0.32, 0), Vector3(0.16, 0.18, 0.16), "edc7a4")
        var leg = group(Vector3(side * 0.13, 0.46, 0), g); leg.name = "LegL" if side < 0 else "LegR"
        smooth_shape(leg, Vector3(0, -0.16, 0), Vector3(0.18, 0.4, 0.19), "e4d7bb" if girl else "3e595e")
        smooth_shape(leg, Vector3(0, -0.36, 0.055), Vector3(0.21, 0.15, 0.33), "624e40")

    smooth_shape(body, Vector3(0, 0.01, -0.27), Vector3(0.38, 0.43, 0.23), "bf945e")
    smooth_shape(body, Vector3(0, -0.075, -0.39), Vector3(0.26, 0.16, 0.065), "9b734d")
    smooth_shape(body, Vector3(0, 0.125, -0.39), Vector3(0.3, 0.055, 0.045), "e4c18b")
    var shade = StandardMaterial3D.new(); shade.albedo_color = Color(0.12, 0.2, 0.17, 0.16)
    shade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; shade.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    var shape = CylinderMesh.new(); shape.top_radius = 0.34; shape.bottom_radius = 0.34; shape.height = 0.003; shape.radial_segments = 32
    var shadow = MeshInstance3D.new(); shadow.name = "ContactShadow"; shadow.mesh = shape; shadow.material_override = shade
    shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; g.add_child(shadow)
    return g

func animate_person(g: Node3D, time: float, speed: float) -> void:
    var dt = clampf(time - float(g.get_meta("last_motion_time", time)), 0, 0.05)
    g.set_meta("last_motion_time", time)
    var blend = move_toward(float(g.get_meta("walk_blend", 0.0)), speed, dt * 6)
    g.set_meta("walk_blend", blend)
    var phase = float(g.get_meta("walk_phase", 0.0)) + dt * 10 * maxf(blend, 0.25)
    g.set_meta("walk_phase", phase)
    var swing = sin(phase) * 0.43 * blend
    g.get_node("LegL").rotation.x = swing; g.get_node("LegR").rotation.x = - swing
    var body = g.get_node("Body")
    body.position.y = 0.75 + abs(sin(phase)) * 0.028 * blend
    body.get_node("ArmL").rotation.x = - swing * 0.8; body.get_node("ArmR").rotation.x = swing * 0.8
    var shadow = g.get_node_or_null("ContactShadow")
    if shadow: shadow.position.y = surface_height(g.position) - g.position.y + 0.008

func elevation_at(pos: Vector3) -> float:
    return clampf( (8.0 - pos.z) * 0.06, 0, 1.35) if city_index == 6 else 0.0

func surface_height(pos: Vector3) -> float:
    for bridge in bridges:
        if bridge.has_point(Vector2(pos.x, pos.z)): return 0.285
    for zone in grass_zones:
        if zone.has_point(Vector2(pos.x, pos.z)): return 0.19
    return elevation_at(pos) + (0.125 if on_path(pos) else 0.085)

func on_path(pos: Vector3) -> bool:
    var point = Vector2(pos.x, pos.z)
    for bridge in bridges:
        if bridge.has_point(point): return true
    for road in roads:
        if road.has_point(point): return true
    return false

func can_walk(pos: Vector3) -> bool:
    if abs(pos.x) > 12 or abs(pos.z) > 12.5: return false
    var point = Vector2(pos.x, pos.z)
    for water in water_zones:
        if water.has_point(point):
            var crossing = false
            for bridge in bridges:
                if bridge.grow(-0.26).has_point(point): crossing = true
            if not crossing: return false
    for rect in solid:
        if rect.grow(0.26).has_point(point): return false
    return true

func animate(time: float, dt: float) -> void:
    for i in range(water_bits.size()):
        water_bits[i].position.x += dt * 0.22
        if water_bits[i].position.x > 12.5: water_bits[i].position.x = -12.5
    for i in range(pickups.size()):
        if pickups[i].visible: pickups[i].position.y = 0.04 + sin(time * 2.5 + i) * 0.1
    marker.position.y = surface_height(marker.position) + 0.06 + sin(time * 3.0) * 0.04
    for rotor in decor_movers: rotor.rotation.z = time * 0.45
    marker.rotation.y = time * 0.25
    for s in swayers:
        var g = s.node
        var k = sin(time * 1.15 + s.phase) + 0.35 * sin(time * 2.7 + s.phase * 1.7)
        g.rotation.z = k * s.amp
        g.rotation.x = cos(time * 0.9 + s.phase) * s.amp * 0.6
    for c in clouds:
        var n2 = c.node
        n2.position.x += dt * c.speed
        if n2.position.x > 19.0: n2.position.x = -19.0
    for i in range(ambient_people.size()):
        var n = ambient_people[i]
        n.position.x = 7.0 + sin(time * 0.22 + i * 2.0) * 2.0
        n.rotation.y = PI / 2 if cos(time * 0.22 + i * 2.0) > 0 else - PI / 2
        animate_person(n, time + i, 0.4)

func merge_static_geometry() -> void:

    var batches: Dictionary = {}
    collect_static(self, batches)
    for material in batches:
        var instance = MeshInstance3D.new()
        instance.mesh = batches[material].commit()
        instance.material_override = material
        add_child(instance)

func collect_static(node: Node, batches: Dictionary) -> void:
    if node.has_meta("moving") or node.has_meta("occluder") or water_bits.has(node): return
    if node is MeshInstance3D:
        var material = node.material_override
        if not batches.has(material):
            var surface = SurfaceTool.new()
            surface.begin(Mesh.PRIMITIVE_TRIANGLES)
            batches[material] = surface
        batches[material].append_from(node.mesh, 0, node.global_transform)
        node.queue_free()
        return
    for child in node.get_children(): collect_static(child, batches)

func in_grass(pos: Vector3) -> bool:

    return can_walk(pos) and not on_path(pos)

func build_clouds() -> void:
    for i in range(7):
        var c = group(Vector3(randf_range(-16, 16), randf_range(9.5, 13.5), randf_range(-16, 10)))
        c.set_meta("moving", true)
        var s = randf_range(0.8, 1.7)
        box(c, Vector3.ZERO, Vector3(3.2 * s, 0.55, 1.9 * s), "fffaf0")
        box(c, Vector3(-1.0 * s, 0.34, 0.1), Vector3(1.7 * s, 0.5, 1.4 * s), "fff6e4")
        box(c, Vector3(1.1 * s, 0.26, -0.15), Vector3(1.5 * s, 0.44, 1.2 * s), "fff6e4")
        clouds.append({ "node": c, "speed": 0.1 + randf() * 0.14 })

func build_grass() -> void:
    for zone in grass_zones:
        var center = zone.get_center()
        box(self, Vector3(center.x, 0.15, center.y), Vector3(zone.size.x, 0.08, zone.size.y), "7c9e70")
        for ix in range(15):
            for iz in range(4):
                var pos = Vector3(zone.position.x + 0.18 + ix * 0.33, 0.24, zone.position.y + 0.15 + iz * (zone.size.y - 0.3) / 3)
                var blade = box(self, pos, Vector3(0.08, 0.26 + 0.06 * sin(ix * 3 + iz), 0.06), "a8c880" if (ix + iz) % 3 else "537e61")
                blade.rotation.z = 0.3 if ix % 2 else -0.3
        var label = sign3d(self, Vector3(center.x, 0.65, zone.position.y - 0.1), "잔디밭 · 몬스터 출현", 22, "355c45")
        label.outline_size = 4; label.outline_modulate = Color("fff8e8")

func creature(index: int) -> Node3D:
    if index == 2:
        var mime = character(false, "eee7d5")
        var body = mime.get_node("Body")
        tube(body, Vector3(0, 0.88, 0), 0.35, 0.09, "34373e")
        for y in [-0.13, 0.02, 0.17]: box(body, Vector3(0, y, 0.21), Vector3(0.4, 0.055, 0.025), "34373e")
        return mime
    var g = group(Vector3.ZERO); g.set_meta("moving", true)
    var body = group(Vector3(0, 0.7, 0), g); body.name = "Body"
    if index == 0:
        smooth_shape(body, Vector3.ZERO, Vector3(0.96, 1.2, 0.8), "e9e8f1")
        for side in [-1, 1]:
            smooth_shape(body, Vector3(side * 0.19, 0.12, 0.38), Vector3(0.11, 0.19, 0.06), "444859")
            smooth_shape(body, Vector3(side * 0.45, -0.16, 0), Vector3(0.3, 0.42, 0.27), "e9e8f1")
        smooth_shape(body, Vector3(0, -0.18, 0.395), Vector3(0.13, 0.19, 0.035), "55566b")
    else:
        smooth_shape(body, Vector3.ZERO, Vector3(0.88, 0.83, 0.72), "8f9ba4")
        smooth_shape(body, Vector3(0, 0.45, 0.16), Vector3(0.53, 0.57, 0.52), "81939f")
        box(body, Vector3(0, 0.37, 0.49), Vector3(0.19, 0.13, 0.2), "d7a85e")
        for side in [-1, 1]:
            smooth_shape(body, Vector3(side * 0.23, 0.49, 0.28), Vector3(0.06, 0.07, 0.05), "263c41")
            smooth_shape(body, Vector3(side * 0.36, -0.02, -0.03), Vector3(0.25, 0.57, 0.5), "627889")
        var bread = smooth_shape(body, Vector3(0, -0.22, 0.43), Vector3(0.88, 0.18, 0.18), "d5a15b"); bread.rotation.z = 0.18
    return g

func register_occluder(node: Node3D, bounds: AABB) -> void:
    node.set_meta("occluder", true)
    occluders.append({ "node": node, "bounds": bounds, "materials": [], "labels": [], "alpha": 1.0})

func prepare_occluders() -> void:

    for obstacle in occluders:
        var batches: Dictionary = {}
        for child in obstacle.node.get_children():
            if child is Label3D: obstacle.labels.append(child)
            collect_static(child, batches)
        for material in batches:
            var copy = material.duplicate()
            var instance = MeshInstance3D.new()
            instance.mesh = batches[material].commit(); instance.material_override = copy
            add_child(instance); obstacle.materials.append(copy)

func update_occlusion(cam: Camera3D, people: Array, enabled: bool, dt: float) -> void:
    hidden_people = [false, false]; faded_count = 0
    for obstacle in occluders:
        var blocked = false
        if enabled:
            for i in range(people.size()):

                for height in [0.45, 1.25]:
                    var point = people[i].position + Vector3(0, height, 0)
                    var origin = cam.project_ray_origin(cam.unproject_position(point))
                    if obstacle.bounds.intersects_segment(origin, point) != null:
                        blocked = true; hidden_people[i] = true
        var alpha = move_toward(float(obstacle.alpha), 0.16 if blocked else 1.0, dt * 4)
        obstacle.alpha = alpha
        if alpha < 0.99: faded_count += 1
        for material in obstacle.materials:
            material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if alpha < 0.99 else BaseMaterial3D.TRANSPARENCY_DISABLED
            material.albedo_color.a = alpha
        for label in obstacle.labels: label.modulate.a = alpha

func update_tide(time: float) -> void:
    for i in range(tide_lines.size()):
        var line = tide_lines[i]
        var low = fmod(time, 7.0) < 4.0
        line.position.x = (6.3 if low else 5.55) + sin(time * 2.2 + i) * 0.15
        line.scale.z = 0.7 if low else 1.0
