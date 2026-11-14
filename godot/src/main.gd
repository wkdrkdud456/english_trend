extends Node3D

const World = preload ("res://scripts/world.gd")
const Hud = preload ("res://scripts/hud.gd")
const CityData = preload ("res://scripts/city_data.gd")
const Tour = preload ("res://scripts/tour.gd")
var tour
var city_index = 0
var environment: WorldEnvironment
var battle_enemy_guard = false
var battle_fog = false
var battle_food = 0
var battle_intent = "attack"
var SAVE_FILE = "user://paris_journey_v1.json"
var photo_file = "user://paris-memory.png"
var world: Node3D
var camera: Camera3D
var sun: DirectionalLight3D
var hero: Node3D
var partner: Node3D
var rival: Node3D
var story_rival: Node3D
var creatures: Array = []
# ── 레벨 / 펫 ──────────────────────────────────────────
var level = 1
var xp = 0
const LEVEL_MAX = 30
var pets: Array = []          # {"c": 도시, "i": 종류 0~2, "lv": 친밀도}
var pet_active = -1          # (구버전 세이브 호환용)
var pet_team: Array = []      # 함께 걷는 친구들 — pets 의 인덱스, 최대 3
var pet_spots: Array = []     # 2D 화면에서 각 친구의 위치
var trail: Array = []         # 동훈이 지나온 길 (친구들이 따라 걷는다)
const TEAM_MAX = 3
var pet_node: Node3D = null
var pet_path: Array = []
# 몸통은 세 가지(유령형/짐승형/마임형)뿐이라 종류별로 역할을 나눈다
const PET_ROLE = [
    { "key": "energy", "tag": "기력", "desc": "대결을 기력 1칸으로 시작해요" },
    { "key": "dish", "tag": "설거지", "desc": "설거지 연타가 한 대마다 강해져요" },
    { "key": "care", "tag": "회복", "desc": "야근 버티기와 뽀뽀사탕 회복이 늘어요" },
]
# ── 장비 / 가방 ────────────────────────────────────────
const GEAR = [
    { "id": "g0", "slot": 0, "tier": 0, "name": "낡은 수세미", "line": "집에서 쓰던 그것", "cost": 0, "atk": 0, "hp": 0, "heal": 0, "spd": 0},
    { "id": "g1", "slot": 0, "tier": 1, "name": "철수세미", "line": "설거지 연타 +1", "cost": 150, "atk": 1, "hp": 0, "heal": 0, "spd": 0},
    { "id": "g2", "slot": 0, "tier": 2, "name": "분노의 고무장갑", "line": "설거지 연타 +2 · 손이 안 터요", "cost": 420, "atk": 2, "hp": 0, "heal": 0, "spd": 0},
    { "id": "g3", "slot": 0, "tier": 3, "name": "전설의 고무장갑", "line": "설거지 연타 +4 · 황금빛으로 빛나요", "cost": 980, "atk": 4, "hp": 0, "heal": 0, "spd": 0},
    { "id": "a0", "slot": 1, "tier": 0, "name": "면 티셔츠", "line": "편한 차림", "cost": 0, "atk": 0, "hp": 0, "heal": 0, "spd": 0},
    { "id": "a1", "slot": 1, "tier": 1, "name": "꽃무늬 앞치마", "line": "최대 체력 +8", "cost": 160, "atk": 0, "hp": 8, "heal": 0, "spd": 0},
    { "id": "a2", "slot": 1, "tier": 2, "name": "김장 조끼", "line": "최대 체력 +18 · 어머님이 주셨어요", "cost": 460, "atk": 0, "hp": 18, "heal": 0, "spd": 0},
    { "id": "a3", "slot": 1, "tier": 3, "name": "전설의 수면잠옷", "line": "최대 체력 +32 · 회복 +3", "cost": 1050, "atk": 0, "hp": 32, "heal": 3, "spd": 0},
    { "id": "s0", "slot": 2, "tier": 0, "name": "삼선 슬리퍼", "line": "동네 마실용", "cost": 0, "atk": 0, "hp": 0, "heal": 0, "spd": 0},
    { "id": "s1", "slot": 2, "tier": 1, "name": "하얀 운동화", "line": "이동 속도 +12%", "cost": 170, "atk": 0, "hp": 0, "heal": 0, "spd": 12},
    { "id": "s2", "slot": 2, "tier": 2, "name": "아버님 등산화", "line": "이동 속도 +22% · 회복 +2", "cost": 480, "atk": 0, "hp": 0, "heal": 2, "spd": 22},
    { "id": "s3", "slot": 2, "tier": 3, "name": "날개 달린 크록스", "line": "이동 속도 +35% · 최대 체력 +6", "cost": 1100, "atk": 0, "hp": 6, "heal": 0, "spd": 35},
]
const SLOT_NAME = ["설거지 도구", "옷", "신발"]
const ITEMS = [
    { "id": "candy", "name": "뽀뽀사탕", "line": "대결에서 체력을 회복해요", "cost": 40, "cap": 9},
    { "id": "drink", "name": "기력 드링크", "line": "다음 대결을 기력 1칸으로 시작", "cost": 70, "cap": 5},
    { "id": "treat", "name": "펫 간식", "line": "동행의 친밀도를 1 올려요", "cost": 90, "cap": 5},
    { "id": "film", "name": "기념 필름", "line": "추억 사진 보상 +30원", "cost": 110, "cap": 9},
]
var owned_gear: Array = ["g0", "a0", "s0"]
var equipped: Array = ["g0", "a0", "s0"]
var bag: Dictionary = { "candy": 3}
var next_energy = 0
var sheet_tab = 0               # 0 스텟 · 1 기술 · 2 가방 · 3 장비 · 4 동행
# ── 기술 ───────────────────────────────────────────────
const SKILL_MAX = 10
const SKILLS = [
    { "id": "strike", "name": "설거지 연타", "need": 1, "energy": 0},
    { "id": "guard", "name": "야근 버티기", "need": 1, "energy": 0},
    { "id": "team", "name": "월급 박치기", "need": 1, "energy": 3},
    { "id": "soak", "name": "냄비 불리기", "need": 3, "energy": 1},
    { "id": "soap", "name": "퐁퐁 뿌리기", "need": 5, "energy": 1},
    { "id": "coffee", "name": "커피 수혈", "need": 8, "energy": 0},
]
var skill_lv: Dictionary = { "strike": 1, "guard": 1, "team": 1, "soak": 1, "soap": 1, "coffee": 1}
var skill_points = 0
var battle_bomb = 0             # 냄비 불리기: 터지기까지 남은 턴 (0 = 없음)
var battle_vuln = 0             # 퐁퐁: 상대가 미끄러운 남은 턴
var battle_charge = false       # 커피 수혈: 다음 공격 강화
# ── 야생 등급 ───────────────────────────────────────────
const GRADES = [
    { "tag": "일반", "prefix": "", "hp": 1.0, "atk": 1.0, "gold": 1.0, "xp": 1.0, "color": "788277"},
    { "tag": "엘리트", "prefix": "엘리트 ", "hp": 1.5, "atk": 1.2, "gold": 2.0, "xp": 2.0, "color": "3f8fa8"},
    { "tag": "레어", "prefix": "레어 ", "hp": 2.1, "atk": 1.4, "gold": 3.5, "xp": 3.0, "color": "8a5fc0"},
    { "tag": "전설", "prefix": "전설의 ", "hp": 3.0, "atk": 1.65, "gold": 7.0, "xp": 5.0, "color": "e0a020"},
]
var wild_grade = 0
# ── 세부 구역과 기억 조각 ─────────────────────────────────
var area_index = 0              # 0 = 도시 중심, 1 = 골목, 2 = 자연 구역
const SHARDS = [
    [["기억 조각", "일기 한 장이 강바람에 날려 왔다."], ["동훈의 일기", "“이번 달도 야근. 소현이 생일 케이크는 혼자 먹었다고 했다. 미안하다는 문자를 쓰다가 지웠다.”"], ["소현", "…그 문자, 지우지 말지. 괜찮아. 이제 같이 읽으니까."]],
    [["기억 조각", "대나무 사이에 종이 한 장이 걸려 있다."], ["동훈의 일기", "“새벽 두 시에 들어오니 식탁에 라면이 불어 있었다. 기다리다 잠든 소현이 옆에서 조용히 다 먹었다.”"], ["동훈", "맛없었을 텐데… 왜 그게 제일 맛있었다고 기억하지."]],
    [["기억 조각", "물가의 돌 밑에 종이가 눌려 있다."], ["동훈의 일기", "“오늘은 한마디도 못 했다. 미안하다는 말이 목에 걸려서. 내일 해야지. 내일.”"], ["소현", "그 ‘내일’이 오늘이야."]],
    [["기억 조각", "올리브 나무 아래, 수첩에서 찢긴 한 장."], ["동훈의 일기", "“수첩 뒷장에 적었다. 소현이랑 나중에 하고 싶은 것 — 파리, 교토, 오로라, 서핑… 나중에.”"], ["동훈", "이 여행, 내가 적어 둔 목록이었어?"], ["소현", "응. 네 수첩을 내가 찾았어. 하나씩 지우러 온 거야."]],
    [["기억 조각", "공원 벤치 밑에 구겨진 종이가 끼어 있다."], ["동훈의 일기", "“회사에서 쓰러졌다. 눈을 떴을 때 소현이 손을 잡고 있었는데, 이름이 생각나지 않았다.”"], ["동훈", "…그래서 내가 기억을 잃은 거구나."], ["소현", "의사 선생님이 그랬어. 좋았던 곳을 다시 걸으면 돌아올 거라고."]],
    [["기억 조각", "얼음 위에 종이 한 장이 얼어붙어 있다."], ["동훈의 일기", "“별 보이는 데까지 차 타고 가기. 열 번째 줄. 언젠가.”"], ["동훈", "‘언젠가’라는 말, 내가 제일 많이 썼네."]],
    [["기억 조각", "파도에 밀려온 유리병 안에 종이가 들어 있다."], ["동훈의 일기", "“사진첩에 소현이만 있다. 나는 늘 찍는 사람이었다. 아니, 늘 없는 사람이었다.”"], ["소현", "오늘은 같이 찍자. 둘 다 나오게."]],
    [["기억 조각", "가로등에 젖은 종이가 붙어 있다."], ["동훈의 일기", "“우산을 하나만 챙겼다. 일부러. 그런데 그날도 회사에 불려 갔다.”"], ["동훈", "이번엔 끝까지 같이 쓸게."]],
    [["기억 조각", "코알라가 종이를 물고 있다가 떨어뜨렸다."], ["동훈의 일기", "“못하는 걸 들키기 싫어서 서핑을 미뤘다. 사실은 같이 넘어지는 게 무서웠다.”"], ["소현", "넘어지면 같이 웃으면 되지."]],
    [["기억 조각", "벤치 위에 병원 메모지가 놓여 있다."], ["동훈의 일기", "“마지막 장. 소현이에게 — 기억이 다 돌아오지 않아도, 내일 아침은 내가 차릴게.”"], ["동훈", "이건 병원에서 쓴 거야. 기억이 없을 때도 이건 쓰고 싶었나 봐."], ["소현", "그러니까 괜찮아. 넌 잊어도 다시 약속하는 사람이야."]],
]
const NPC_TALK = [
    [["골목의 화가", "이 골목 상자에는 여행자들이 두고 간 선물이 들어 있어요."], ["골목의 화가", "여기 풀숲 녀석들은 중심가보다 사나워요. 대신 보상도 크죠."]],
    [["찻집 할머니", "켄지 씨는 15년째 막차를 타요. 유키 씨가 매일 등불을 켜 두고요."], ["찻집 할머니", "대나무 숲 안쪽에 종이 한 장이 걸려 있던데, 두 분 것 아닌가요?"]],
    [["향신료 상인", "아흐메드는 말수가 적지만 라일라 앞에서는 지팡이를 내려놓지."], ["향신료 상인", "오아시스 물가에서 낯선 글씨의 종이를 봤소."]],
    [["젤라또 가게 주인", "마르코는 방패 뒤에 숨는 게 아니야. 지킬 게 많은 거지."], ["젤라또 가게 주인", "올리브 언덕에 누가 수첩 조각을 떨어뜨렸더군."]],
    [["핫도그 아저씨", "거울 속에서 게임기를 든 청년이 걸어 나온다는 소문, 들었소?"], ["핫도그 아저씨", "공원 벤치 밑에 종이가 끼어 있던데."]],
    [["어부", "비요른은 양보다 아스타를 먼저 세지. 매일 밤."], ["어부", "빙하 호수 끝에 바람에도 안 날아가는 종이가 있어."]],
    [["당나귀 몰이꾼", "니코스는 석양을 30년 봤지만 엘레니 얼굴이 더 좋대."], ["당나귀 몰이꾼", "절벽 아래 해변에 유리병 하나가 떠밀려 왔어."]],
    [["펍 주인", "올리버는 우산을 안 써. 누가 씌워 주길 기다리는 거지."], ["펍 주인", "강변 공원 가로등에 젖은 종이가 붙어 있더군."]],
    [["서핑 가게 점원", "잭은 사실 파도를 무서워해요. 그래서 클로이랑만 타요."], ["서핑 가게 점원", "유칼립투스 숲에서 코알라가 종이를 물고 있었어요."]],
    [["분식집 이모", "내일의 너라는 사람이 현관 앞에 서 있다며? 바쁘다는 핑계지 뭐."], ["분식집 이모", "한강 공원 벤치에 병원 메모지가 있던데."]],
]
# ── 도시별 옷차림 (소현 상의 / 소현 모자 / 동훈 상의 / 동훈 모자 / 동훈 바지) — 모자 "" = 없음
const CITY_LOOK = [
    ["f08898", "c85068", "4a5570", "", "39415e"],
    ["d696ac", "", "5e6b8a", "", "3b3f52"],
    ["e8c27a", "f3e6c4", "c9a66b", "f3e6c4", "7a6a4c"],
    ["b76c59", "", "6d8a62", "", "4a4a52"],
    ["36495c", "", "2f3542", "c85068", "23262e"],
    ["a4dce4", "c85068", "e6edf1", "4a8a9c", "4d5d70"],
    ["fcf8ee", "e4c783", "5688b6", "", "e8e2d2"],
    ["b68e7e", "", "3e4d57", "2c343a", "2c343a"],
    ["f2a65a", "", "74bcb7", "", "3f6a8a"],
    ["e9b4c5", "", "68747b", "", "3a4250"],
]
var shop_tab = 0                # 0 도시락 · 1 장비 · 2 소모품
var wild_battle = false
var wild_index = 0
var wild_wins = 0
var wild_seen = [false, false, false]
var grass_steps = 0.0
var encounter_at = 3.2
var encounter_grace = 1.5
var battle_return = Vector3.ZERO
var partner_return = Vector3.ZERO
var story_perfects = 0
var battle_max_hp = 5
var WILD_NAMES = ["에펠탑 유령", "바게트 도둑 비둘기", "무서운 마임"]
var hud: Control
var state = "title"
var previous_state = "explore"
var stage = 0
var collected = [false, false, false]
var coins = 0
var best_combo = 0
var perfects = 0
var orders = 0
var order_time = 8.0
var order_wait = 0.0
var recipe_order = [0, 1, 2, 0, 2]
var cooking_streak = 0
var battle_time = 0.0
var battle_hp = 5
var health = 3
var battle_hits = 0
var battle_lock = 0.0
var battle_result = ""
var battle_phase = "choose"
var battle_menu = "main"
var battle_turn = 1
var battle_energy = 0
var battle_berries = 2
var battle_guard = false
var battle_choice = ""
var battle_phase_time = 0.0
var battle_reward = 0
var battle_volley_hits = 0
var battle_quote = ""
var qa_freeze = false
var qa_portrait = false
var qa_portrait_elevation = 3.0
var battle_hit_applied = false
var battle_hitstop = 0.0
var battle_fx_left = 0.0
var battle_fx_kind = "hit"
var battle_fx_target = "enemy"
var battle_fx_amount = 0
var battle_fx_note = ""
var PARTY_HP = 36
const HERO_ARENA = Vector3(-0.7, 0.12, -3.6)
const PARTNER_ARENA = Vector3(0.65, 0.12, -3.6)
const ENEMY_ARENA = Vector3(1.1, 0.12, -6.3)
var dialogue: Array = []
var dialogue_index = 0
var dialogue_next = "explore"
var clock_time = 0.0
var game_time = 0.0
var save_clock = 0.0
var save_ok = true
var sound_on = true
var effects_on = true
var joystick = Vector2.ZERO
var toast_text = ""
var toast_time = 0.0
var flash = 0.0
var photo: ImageTexture
var font: Font
var sparks: Array = []
var has_save = false
var reset_confirm = false
var audio: AudioStreamPlayer
var audio_wave: AudioStreamWAV
var move_speed = 0.0
var move_vel = Vector3.ZERO     # 가속/감속용 속도
var run_blend = 0.0             # 0 걷기 ~ 1 달리기
var step_phase = 0.0            # 걸음 위상 (카메라 바운스)
var dust_t = 0.0
var grass_tension = 0.0         # 풀숲 긴장도 0~1
var rustle_t = 0.0
var rustle_beat = 0
var target_name = ""
var target = Vector3.ZERO
var cam_focus = Vector3.ZERO
var ui_ready = false
var pending_photo = false
var overview = false
var app_paused = false
var intro_page = 0
var tutorial_page = 0
var scene_time = 0.0
var tutorial_seen = false
var intro_return = Vector3.ZERO
var intro_partner_return = Vector3.ZERO
var follow_path: Array[Vector3] = []
var follow_anchor = Vector3.ZERO
var battle_follow_path: Array[Vector3] = []
var battle_follow_anchor = Vector3.ZERO
var intro_follow_path: Array[Vector3] = []
var intro_follow_anchor = Vector3.ZERO
var qa_callback

func _ready() -> void:
    DisplayServer.window_set_title("가라! 동훈! — 열 도시의 약속")
    if "--test-isolated" in OS.get_cmdline_user_args():
        SAVE_FILE = "res://test-progress.json"
        photo_file = "res://test-memory.png"
    if OS.has_feature("web") and OS.has_feature("debug"):
        if JavaScriptBridge.eval("new URLSearchParams(location.search).get('qa') === '1'"):
            SAVE_FILE = "user://qa-progress.json"; photo_file = "user://qa-photo.png"
    var readable_font = FontVariation.new()
    readable_font.base_font = load("res://assets/NotoSansKR.ttf")
    readable_font.variation_opentype = { TextServerManager.get_primary_interface().name_to_tag("wght"): 550}
    font = readable_font
    tour = Tour.new(self)
    var env = WorldEnvironment.new(); environment = env
    var e = Environment.new()
    e.background_mode = Environment.BG_COLOR
    e.background_color = Color("d9e3d9")
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color("f5f5ed")
    e.ambient_light_energy = 0.28
    e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
    env.environment = e; add_child(env)
    sun = DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-54, -28, 0)
    sun.light_color = Color("fffaf1"); sun.light_energy = 0.36
    sun.shadow_enabled = true; sun.directional_shadow_max_distance = 55.0
    add_child(sun)
    camera = Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 21; camera.near = 0.3; camera.far = 70; add_child(camera)
    rebuild_city()
    var canvas = CanvasLayer.new(); add_child(canvas)
    hud = Hud.new(); hud.game = self; hud.font = font; canvas.add_child(hud)
    hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    audio = AudioStreamPlayer.new(); audio.volume_db = -15; add_child(audio)
    load_progress()
    reset_follow_path()
    if FileAccess.file_exists(photo_file):
        var im = Image.load_from_file(photo_file)
        if im: photo = ImageTexture.create_from_image(im)
    update_target()
    set_camera(1.0, true)
    ui_ready = true
    if "--smoke-test" in OS.get_cmdline_user_args(): call_deferred("smoke_test")
    if "--tour-smoke" in OS.get_cmdline_user_args(): call_deferred("tour_smoke_test")
    if OS.has_feature("web") and OS.has_feature("debug"):
        if JavaScriptBridge.eval("new URLSearchParams(location.search).get('qa') === '1'"):
            qa_callback = JavaScriptBridge.create_callback(qa_command)
            JavaScriptBridge.get_interface("window").parisQA = qa_callback

    if OS.has_feature("web"): call_deferred("notify_web_ready")

func city() -> Dictionary:
    return CityData.CITIES[city_index]

func rebuild_city() -> void:
    if is_instance_valid(world): remove_child(world); world.free()
    sparks.clear(); creatures.clear()
    world = World.new(); add_child(world); world.build(font, city_index, area_index)
    WILD_NAMES = []
    for mob in city().mobs: WILD_NAMES.append(mob.name)
    hero = world.character(true); hero.position = tour.v(city().spawn) + Vector3(-0.45, 0, 0)
    partner = world.character(false); partner.position = tour.v(city().spawn) + Vector3(0.55, 0, 0.4)
    rival = world.character(false, city().pal.r1); rival.scale = Vector3.ONE * 1.16; rival.position = tour.v(city().boss_at)
    if city_index == 0:
        world.tube(rival, Vector3(0, 1.58, 0), 0.31, 0.12, "f6e7c6")
        world.ball(rival, Vector3(0, 1.72, 0), 0.27, "f6e7c6", 0.7)
    else: preload ("res://scripts/tour_world.gd").new().dress_boss(world, rival, city_index)
    world.sign3d(rival, Vector3(0, 2.25, 0), city().boss.name, 28)
    story_rival = rival
    if area_index > 0: rival.visible = false
    for i in range(3):
        var creature = world.creature(i); creature.visible = false; creatures.append(creature)
    call_deferred("spawn_pet")
    if environment:
        environment.environment.background_color = Color("d9e3d9" if city_index == 0 else city().pal.sky)
        environment.environment.ambient_light_energy = 0.38 if city_index == 5 else 0.28
    if sun: sun.light_energy = 0.25 if city_index == 5 else 0.36

func exp_needed() -> int:
    return 40 + level * 30

func gear_of(id: String) -> Dictionary:
    for entry in GEAR:
        if entry.id == id: return entry
    return GEAR[0]

func gear_sum(key: String) -> int:
    var total = 0
    for id in equipped: total += int(gear_of(id)[key])
    return total

func slot_gear(slot: int) -> Dictionary:
    return gear_of(String(equipped[clampi(slot, 0, 2)]))

func item_of(id: String) -> Dictionary:
    for entry in ITEMS:
        if entry.id == id: return entry
    return ITEMS[0]

func bag_count(id: String) -> int:
    return maxi(0, int(bag.get(id, 0)))

func bag_add(id: String, n: int) -> void:
    bag[id] = clampi(bag_count(id) + n, 0, int(item_of(id).cap))

func speed_mul() -> float:
    return 1.0 + gear_sum("spd") / 100.0

func party_max() -> int:
    return 36 + tour.completed.count(true) * 3 + (level - 1) * 2 + gear_sum("hp")

func stamps() -> int:
    return tour.completed.count(true)

func dish_base(hit: int) -> int:
    return [3, 3, 2][hit] + int(stamps() / 3) + int((level - 1) / 4) + pet_bonus("dish") + gear_sum("atk") + int(sk("strike") / 2)

func guard_heal() -> int:
    return 3 + int(stamps() / 3) + pet_bonus("care") + (sk("guard") - 1)

func soak_damage() -> int:
    return int((dish_base(0) + dish_base(1) + dish_base(2)) * (3.0 + 0.2 * (sk("soak") - 1)))

func soap_mul() -> float:
    return 1.5 + 0.05 * (sk("soap") - 1)

func coffee_mul() -> float:
    return 2.0 + 0.1 * (sk("coffee") - 1)

# 퐁퐁·커피 효과를 얹는다
func amp(damage: int) -> int:
    var value = float(damage)
    if battle_vuln > 0: value *= soap_mul()
    if battle_charge: value *= coffee_mul()
    return maxi(1, int(round(value)))

func pet() -> Dictionary:
    if pet_team.is_empty(): return {}
    return pets[int(pet_team[0])]

func pet_kind() -> int:
    var p = pet()
    if p.is_empty(): return 0
    return clampi(int(p.i), 0, 2)

func pet_power(p: Dictionary) -> int:
    return 1 + int((int(p.lv) - 1) / 2) + int(p.get("g", 0))

func pet_bonus(key: String) -> int:
    var total = 0
    for index in pet_team:
        var p = pets[int(index)]
        if PET_ROLE[int(p.i)].key == key: total += pet_power(p)
    return total

func pet_art(p: Dictionary) -> String:
    return String(CityData.CITIES[int(p.c)].mobs[int(p.i)].art)

func sk(id: String) -> int:
    return clampi(int(skill_lv.get(id, 1)), 1, SKILL_MAX)

func skill_of(id: String) -> Dictionary:
    for entry in SKILLS:
        if entry.id == id: return entry
    return SKILLS[0]

func skill_open(id: String) -> bool:
    return level >= int(skill_of(id).need)

func skill_line(id: String) -> String:
    match id:
        "strike": return "수세미 3연타 " + str(dish_base(0)) + "/" + str(dish_base(1)) + "/" + str(dish_base(2)) + " · 기력 +1"
        "guard": return "피해 75% 감소 · 체력 +" + str(guard_heal()) + " · 기력 +1"
        "team": return "기력 3 + 40원 · " + str(salary_damage()) + " 피해 · 방어 무시"
        "soak": return "기력 1 · 2턴 뒤 " + str(soak_damage()) + " 피해 폭발"
        "soap": return "기력 1 · 2턴간 주는 피해 +" + str(int((soap_mul() - 1.0) * 100)) + "%"
        _: return "기력 +2 · 다음 공격 " + str(snappedf(coffee_mul(), 0.1)) + "배"

func skill_up(id: String) -> void:
    if skill_points <= 0 or not skill_open(id) or sk(id) >= SKILL_MAX: return
    skill_points -= 1; skill_lv[id] = sk(id) + 1
    chime(880); save_progress()
    toast(String(skill_of(id).name) + " Lv." + str(sk(id)) + "!  " + skill_line(id))

func wild_name() -> String:
    return String(GRADES[wild_grade].prefix) + String(WILD_NAMES[wild_index])

func foe_name() -> String:
    return wild_name() if wild_battle else String(city().boss.name)

# 화면에 그릴 옷 색 — 도시마다 갈아입고, 장비를 끼면 그 색이 덮인다
func look(girl: bool) -> Dictionary:
    var row = CITY_LOOK[clampi(city_index, 0, 9)]
    var skin = Color("ffd2a6")
    if girl:
        var hair = Color("8a5434")
        return { "O": Color("2a1c18"), "S": skin, "G": skin, "H": hair, "C": Color(row[1]) if row[1] != "" else hair, "T": Color(row[0]), "D": Color("3a4a6a"), "E": Color("46304e")}
    var hair2 = Color("5c3620")
    var top = Color(row[2])
    var armor = int(slot_gear(1).tier)
    if armor > 0: top = Color(["", "f3a6c0", "c8553d", "7a5fc0"][armor])
    var glove = skin
    var weapon = int(slot_gear(0).tier)
    if weapon > 0: glove = Color(["", "9aa4ad", "ff5f8f", "ffcf3a"][weapon])
    var shoes = Color(["46304e", "f2f2f2", "8a5a2c", "ffd84a"][int(slot_gear(2).tier)])
    return { "O": Color("2a1c18"), "S": skin, "G": glove, "H": hair2, "C": Color(row[3]) if row[3] != "" else hair2, "T": top, "D": Color(row[4]), "E": shoes}

func pet_name(p: Dictionary) -> String:
    return CityData.CITIES[int(p.c)].mobs[int(p.i)].name

func gain_exp(amount: int) -> void:
    if level >= LEVEL_MAX: return
    xp += amount
    var gained = 0
    while level < LEVEL_MAX and xp >= exp_needed():
        xp -= exp_needed(); level += 1; gained += 1
    if gained > 0:
        skill_points += gained
        PARTY_HP = party_max(); health = PARTY_HP
        chime(1318)
        var note = "레벨 " + str(level) + "! 기술 포인트 +" + str(gained)
        for entry in SKILLS:
            if int(entry.need) > level - gained and int(entry.need) <= level and int(entry.need) > 1: note += " · 새 기술 " + String(entry.name)
        toast(note)

func dish_damage(hit: int) -> int:
    var value = dish_base(hit)
    if battle_fog and hit < 2: value = maxi(1, value - 1)
    if battle_enemy_guard: value = maxi(1, int(ceil(value * 0.5)))
    return amp(value)

func salary_damage() -> int:
    return 22 + stamps() * 2 + (level - 1) * 2 + gear_sum("atk") * 4 + (sk("team") - 1) * 4

func candy_heal() -> int:
    return 16 + tour.completed.count(true) + (level - 1) + pet_bonus("care") * 3 + gear_sum("heal") * 2 + (4 if battle_food == 3 else 0)

func refresh_intent() -> void:
    if city_index == 0: battle_intent = "heavy" if battle_turn % 3 == 0 else "attack"; return
    var pattern = city().pattern
    var offset = 1 if not wild_battle and city_index in [4, 9] and battle_hp <= battle_max_hp / 2 else 0
    battle_intent = pattern[ (battle_turn - 1 + offset) % pattern.size()]

func notify_web_ready() -> void:
    await RenderingServer.frame_post_draw
    JavaScriptBridge.eval("window.parisGameReady=true; window.dispatchEvent(new Event('paris-game-ready'));")

func _notification(what: int) -> void:
    if not ui_ready: return
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
        app_paused = true; joystick = Vector2.ZERO; hud.release_all()
        if state in ["explore", "cook", "battle"]:
            previous_state = state; state = "pause"; save_progress()
    elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
        app_paused = false

func _process(dt: float) -> void:
    if qa_freeze: hud.queue_redraw(); return
    if not ui_ready: return
    var landscape = get_viewport().get_visible_rect().size.x > get_viewport().get_visible_rect().size.y
    if app_paused or landscape:
        joystick = Vector2.ZERO; hud.queue_redraw(); return
    dt = minf(dt, 0.05)
    if state in ["battle", "battle_won", "battle_lost"]: battle_fx_left = maxf(0, battle_fx_left - dt)
    clock_time += dt; scene_time += dt
    toast_time = maxf(0, toast_time - dt); flash = maxf(0, flash - dt * 1.8)
    if state in ["explore", "cook", "battle", "photo", "title", "ending", "intro"]:
        world.animate(clock_time, dt)
    if state == "explore":
        game_time += dt
        world.update_tide(game_time)
        var before = hero.position
        move_player(dt)
        update_target()
        check_pickups()
        check_encounter(Vector2(before.x, before.z).distance_to(Vector2(hero.position.x, hero.position.z)))
        save_clock += dt
        if save_clock > 6: save_clock = 0; save_progress()
    elif state == "puzzle":
        tour.pz.tick(dt)
    elif state == "cook":
        order_wait = maxf(0, order_wait - dt)
        if order_wait <= 0:
            order_time -= dt
            if order_time <= 0:
                cooking_streak = 0; order_time = 8; order_wait = 0.6
                toast("괜찮아요. 같은 주문을 다시 준비해요.")
    elif state == "battle":
        battle_tick(dt)
        world.animate_person(hero, clock_time, 0.12)
        world.animate_person(partner, clock_time, 0.15)
        rival.get_node("Body").rotation.z = sin(clock_time * 2) * 0.04
    else:
        world.animate_person(hero, clock_time, 0)
        world.animate_person(partner, clock_time, 0)
    # 2D로 덮이는 화면에서는 3D 렌더링을 꺼서 배터리와 프레임을 아낀다 (사진·엔딩만 입체)
    var flat_now = hud.flat_backdrop() or state in ["battle", "battle_ready", "battle_won", "battle_lost", "puzzle"] or (state == "pause" and previous_state == "battle")
    if get_viewport().disable_3d != flat_now: get_viewport().disable_3d = flat_now
    set_camera(dt)
    if not flat_now: world.update_occlusion(camera, [hero, partner], false, dt)
    for i in range(sparks.size() - 1, -1, -1):
        var p = sparks[i]
        p.life -= dt; p.node.position += p.velocity * dt; p.velocity.y -= dt * 3.0
        p.node.scale = Vector3.ONE * maxf(0.01, p.life)
        if p.life <= 0: p.node.queue_free(); sparks.remove_at(i)
    hud.queue_redraw()

func set_camera(dt: float, snap: bool = false) -> void:
    if pending_photo: return
    world.marker.visible = state in ["explore", "map"]
    for label in get_tree().get_nodes_in_group("world_labels"):
        label.visible = state not in ["photo", "ending", "vista"]
    if city_index == 7:
        for witness in world.mission_nodes: witness.visible = state not in ["photo", "ending"]
    var focus = hero.position + Vector3(0, 0.2, -1.1)
    var size = 24.0 if overview else 20.0
    var offset = Vector3(8, 23, 19)
    if state == "explore":
        # 가는 쪽을 미리 보여주면 같은 속도라도 빠르게 느껴진다
        focus += Vector3(move_vel.x, 0, move_vel.z) * 0.40
        size += run_blend * 1.7
        offset.y += sin(step_phase * 2.0) * 0.075 * minf(1.0, move_speed)
        offset.x += sin(step_phase) * 0.05 * minf(1.0, move_speed)
    if state in ["title", "map", "arrival", "passport", "journal"]:
        focus = Vector3(0, 0, -1.6); size = 24; offset = Vector3(9, 22, 26)
    elif state in ["battle", "battle_ready", "battle_lost", "battle_won"] or (state == "pause" and previous_state == "battle"):
        focus = Vector3(0.5, -0.5, -3.4); size = 8.5; offset = Vector3(5, 8, 15)
    elif state in ["photo", "ending"]:
        focus = Vector3(0, 2.6, -8); size = 13.2; offset = Vector3(3.4, 9, 20)
    if city_index > 0 and state in ["photo", "ending", "vista"]:
        var framing = city().photo_focus
        focus = Vector3(framing[0], framing[1], framing[2]); size = city().photo_size; offset = Vector3(1.5, 5, 24)
        if city_index == 4: offset = Vector3(14, 8, 22)
        if state == "vista":
            focus = Vector3(0, 2.1, -3); size = 19; offset = [Vector3(12, 12, 17), Vector3(-12, 10, 18), Vector3(3, 10, 23)][tour.vista]
    if state == "arrival":
        focus = Vector3(0, 2.5, -6); size = 32; offset = Vector3(5, 14, 27)
    if state == "intro":
        if intro_page == 0:
            focus = Vector3(0, 0.5, -1.3); size = 25.0; offset = Vector3(8 + sin(scene_time * 0.15) * 1.2, 22, 26)
        elif intro_page == 1:
            focus = Vector3(0, 0.9, 8); size = 5.9; offset = Vector3(2.4, 3.4, 8)
        else:
            focus = Vector3(3.4, 0.7, 9.3); size = 7.8; offset = Vector3(2.4, 5, 10)
    if qa_portrait:
        focus = Vector3(0, 1.0, 8); size = 5.5; offset = Vector3(0, qa_portrait_elevation, 6)
    var rate = 1.0 if snap else minf(1, dt * 4)
    cam_focus = cam_focus.lerp(focus, rate)
    camera.size = lerpf(camera.size, size, rate)
    camera.position = cam_focus + offset
    camera.look_at(cam_focus, Vector3.UP)

func move_player(dt: float) -> void:
    var axis = joystick
    axis.x += float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
    axis.y += float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
    axis = axis.limit_length()
    # 2D 탑다운이라 스틱 방향이 곧 월드 방향이다
    var dir = Vector3(axis.x, 0, axis.y)
    # 스틱을 끝까지 밀면 달린다
    var want_run = clampf((axis.length() - 0.72) / 0.28, 0, 1)
    run_blend = lerpf(run_blend, want_run, minf(1, dt * 6))
    var top = 3.6 * (1.0 + 0.55 * run_blend) * speed_mul()
    # 즉시 최고속도가 아니라 붙었다 떨어진다 — 무게가 생긴다
    move_vel = move_vel.lerp(dir * top, minf(1, dt * (9.0 if dir.length() > 0.05 else 13.0)))
    move_speed = clampf(move_vel.length() / 3.6, 0, 1.6)
    step_phase += dt * (6.5 + run_blend * 5.0) * minf(1.0, move_speed)
    var velocity = move_vel * dt
    var p = hero.position
    if world.can_walk(p + Vector3(velocity.x, 0, 0)): p.x += velocity.x
    else: move_vel.x = 0.0
    if world.can_walk(p + Vector3(0, 0, velocity.z)): p.z += velocity.z
    else: move_vel.z = 0.0
    hero.position = p
    if dir.length() > 0.08:
        var want_y = atan2(dir.x, dir.z)
        var turn = wrapf(want_y - hero.rotation.y, -PI, PI)
        hero.rotation.y = lerp_angle(hero.rotation.y, want_y, minf(1, dt * 12))
        hero.rotation.z = lerpf(hero.rotation.z, clampf(-turn, -0.8, 0.8) * 0.16 * move_speed, minf(1, dt * 8))
    else:
        hero.rotation.z = lerpf(hero.rotation.z, 0.0, minf(1, dt * 8))
    # 달릴 때 발밑에서 먼지가 핀다
    if effects_on and run_blend > 0.35 and move_speed > 0.5:
        dust_t -= dt
        if dust_t <= 0:
            dust_t = 0.1
            burst(hero.position + Vector3(randf_range(-0.12, 0.12), 0.06, randf_range(-0.12, 0.12)), "e8dcc0", 3)
    var old_partner = partner.position
    move_follower(dt)
    var follower_speed = clampf(partner.position.distance_to(old_partner) / maxf(dt, 0.001) / 3.6, 0, 1)
    world.animate_person(hero, clock_time, move_speed)
    world.animate_person(partner, clock_time, follower_speed)

func reset_follow_path() -> void:
    follow_path.clear(); follow_path.append(hero.position); follow_anchor = hero.position

func move_follower(dt: float) -> void:

    if hero.position.distance_to(follow_anchor) > 0.1:
        follow_path.append(hero.position); follow_anchor = hero.position
    var length = Vector2(partner.position.x, partner.position.z).distance_to(Vector2(follow_path[0].x, follow_path[0].z)) if not follow_path.is_empty() else 0.0
    for i in range(1, follow_path.size()): length += Vector2(follow_path[i - 1].x, follow_path[i - 1].z).distance_to(Vector2(follow_path[i].x, follow_path[i].z))
    var budget = minf(4.4 * dt, maxf(0, length - 1.08))
    var old = partner.position
    while budget > 0.001 and not follow_path.is_empty():
        var target_point = Vector3(follow_path[0].x, partner.position.y, follow_path[0].z)
        var distance = partner.position.distance_to(target_point)
        if distance < 0.015: follow_path.pop_front(); continue
        var step = minf(budget, minf(distance, 0.075))
        var next = partner.position.move_toward(target_point, step)
        if not world.can_walk(next): break
        partner.position = next; budget -= step
    var motion = partner.position - old
    if motion.length() > 0.001:
        partner.rotation.y = lerp_angle(partner.rotation.y, atan2(motion.x, motion.z), minf(1, dt * 10))

    hero.position.y = world.surface_height(hero.position) + 0.015
    partner.position.y = world.surface_height(partner.position) + 0.015
    move_pet(dt)
    update_grass_tension(dt)

func start_intro() -> void:
    intro_return = hero.position; intro_partner_return = partner.position
    intro_follow_path = follow_path.duplicate(); intro_follow_anchor = follow_anchor
    intro_page = 0; scene_time = 0; state = "intro"; joystick = Vector2.ZERO; hud.release_all()
    world.marker.visible = false; story_rival.visible = false; toast_time = 0
    set_intro_scene()

func set_intro_scene() -> void:
    for creature in creatures: creature.visible = false
    scene_time = 0
    if intro_page < 2:
        hero.position = Vector3(-0.65, 0.14, 8); partner.position = Vector3(0.65, 0.14, 8.05)
        hero.rotation.y = 0.25; partner.rotation.y = -0.2
    else:
        hero.position = Vector3(2.2, 0.1, 9.3); partner.position = Vector3(3.3, 0.1, 9.7)
        hero.rotation.y = 1.1; partner.rotation.y = 1.1
        creatures[0].position = Vector3(4.8, 0.1, 9.2); creatures[0].rotation.y = -1; creatures[0].visible = true
    set_camera(1, true)

func start_tutorial() -> void:
    for creature in creatures: creature.visible = false
    state = "tutorial"; tutorial_page = 0; scene_time = 0

func finish_tutorial() -> void:
    hero.position = intro_return; partner.position = intro_partner_return
    state = "explore"; tutorial_seen = true; scene_time = 0
    follow_path = intro_follow_path.duplicate(); follow_anchor = intro_follow_anchor
    update_target(); set_camera(1, true); save_progress()
    toast("왼쪽 스틱으로 이동해요. 동훈이는 뒤에서 따라올게요!")

func update_target() -> void:
    if area_index > 0:
        side_target(); return
    update_main_target()
    if need_shard():
        var gate = world.gate_to(2)
        target = Vector3(gate.x, 0, gate.z); target_name = String(gate.label) + "에서 기억 조각 찾기"
        world.marker.position = target + Vector3(0, 0.2, 0)

# 라이벌에게 도전하려면 자연 구역의 기억 조각이 필요하다
func need_shard() -> bool:
    return area_index == 0 and stage == 2 and not bool(tour.record().get("shard", false)) and not world.gate_to(2).is_empty()

func side_target() -> void:
    var rec = tour.record()
    var best = 999.0
    target_name = ""
    for chest in world.chests:
        if bool(rec.chests[int(chest.i)]): continue
        var spot = Vector3(chest.x, 0, chest.z)
        if hero.position.distance_to(spot) < best:
            best = hero.position.distance_to(spot); target = spot; target_name = "보물 상자"
    for extra in world.extras:
        if String(extra.t) == "shard" and not bool(rec.shard):
            target = Vector3(extra.x, 0, extra.z); target_name = "기억 조각"
    if target_name == "":
        var back = world.gate_to(0)
        target = Vector3(back.x, 0, back.z); target_name = String(back.label)
    world.marker.visible = state == "explore"; world.marker.position = target + Vector3(0, 0.2, 0)
    story_rival.visible = false

func near_gate() -> Dictionary:
    for gate in world.gates:
        if hero.position.distance_to(Vector3(gate.x, hero.position.y, gate.z)) < 1.8: return gate
    return {}

# 행동 버튼에 띄울 말 — 문이나 세부 구역의 물건 가까이에서만
func near_label() -> String:
    var gate = near_gate()
    if not gate.is_empty(): return String(gate.label) + " 가기"
    if area_index == 0: return ""
    var rec = tour.record()
    for chest in world.chests:
        if not bool(rec.chests[int(chest.i)]) and hero.position.distance_to(Vector3(chest.x, hero.position.y, chest.z)) < 1.9: return "상자 열기"
    for extra in world.extras:
        if hero.position.distance_to(Vector3(extra.x, hero.position.y, extra.z)) < 1.9:
            if String(extra.t) == "npc": return "말 걸기"
            if not bool(rec.shard): return "기억 조각 줍기"
    return "둘러보기"

func enter_area(zone: int) -> void:
    var from = area_index
    tour.store_current()
    area_index = zone
    rebuild_city()
    var door = world.gate_to(from) if zone == 0 else world.gate_to(0)
    var spot = tour.v(city().spawn)
    if not door.is_empty(): spot = Vector3(door.x, 0, door.z)
    var inward = Vector3(- spot.x, 0, - spot.z)
    if inward.length() > 0.1: inward = inward.normalized() * 1.5
    hero.position = spot + inward if world.can_walk(spot + inward) else spot
    hero.position.y = world.surface_height(hero.position) + 0.015
    partner.position = hero.position
    for offset in [Vector3(0.8, 0, 0.5), Vector3(-0.8, 0, 0.5), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
        if world.can_walk(hero.position + offset):
            partner.position = hero.position + offset; break
    wild_battle = false; grass_steps = 0; encounter_grace = 2.5
    reset_follow_path()
    if zone == 0: tour.sync_props()
    state = "explore"; update_target(); set_camera(1, true); save_progress()
    toast( (String(city().name) + " 중심가") if zone == 0 else String(world.AREA_NAMES[city_index][zone - 1]) + " — 이곳의 야생 친구들은 더 강해요.")

func side_interact() -> void:
    var rec = tour.record()
    for chest in world.chests:
        var i = int(chest.i)
        if bool(rec.chests[i]) or hero.position.distance_to(Vector3(chest.x, hero.position.y, chest.z)) > 1.9: continue
        rec.chests[i] = true; chime(1046); burst(hero.position + Vector3(0, 0.8, 0), "f6d484", 14)
        match i:
            0:
                coins += 60 + city_index * 25; toast("상자에서 여행비 " + str(60 + city_index * 25) + "원을 찾았어요!")
            1:
                bag_add("candy", 2); bag_add("drink", 1); toast("상자에서 뽀뽀사탕 2개와 기력 드링크를 찾았어요!")
            2:
                coins += 90 + city_index * 30; toast("상자에서 여행비 " + str(90 + city_index * 30) + "원을 찾았어요!")
            _:
                skill_points += 1; toast("낡은 요령 수첩을 찾았어요!  기술 포인트 +1")
        update_target(); save_progress(); return
    for extra in world.extras:
        if hero.position.distance_to(Vector3(extra.x, hero.position.y, extra.z)) > 1.9: continue
        if String(extra.t) == "npc":
            show_dialogue(NPC_TALK[city_index], "explore"); return
        if not bool(rec.shard):
            rec.shard = true; chime(1318); save_progress()
            show_dialogue(SHARDS[city_index], "explore"); return
    toast("금색 표시를 따라가 보세요. 이곳 풀숲의 친구들은 중심가보다 강해요.")

func update_main_target() -> void:
    if city_index > 0:
        if stage == 0: target = tour.v(city().points[tour.mission_target()]); target_name = tour.target_name()
        elif stage == 2: target = tour.v(city().boss_at); target_name = city().boss.name + "의 도전"
        else: target = tour.v(city().photo_at); target_name = city().name + " 추억 사진"
        world.marker.visible = state == "explore"; world.marker.position = target + Vector3(0, 0.2, 0)
        story_rival.visible = stage <= 2 and not wild_battle and area_index == 0; return
    if stage == 0:
        var best = 1000.0
        for i in range(3):
            world.pickups[i].visible = not collected[i]
            if not collected[i] and hero.position.distance_to(world.pickups[i].position) < best:
                best = hero.position.distance_to(world.pickups[i].position); target = world.pickups[i].position; target_name = ["밀가루", "우유", "버터"][i]
    elif stage == 1: target = Vector3(-7, 0, -1.5); target_name = "빵집 주문"
    elif stage == 2: target = Vector3(2.7, 0, -5.5); target_name = "피에르의 도전"
    else: target = Vector3(0, 0, -6.5); target_name = "우리의 첫 사진"
    world.marker.visible = state == "explore"
    world.marker.position = target + Vector3(0, 0.2, 0)
    story_rival.visible = stage <= 2 and not wild_battle and area_index == 0

func check_pickups() -> void:
    if city_index > 0 or stage != 0 or area_index > 0: return
    for i in range(3):
        if not collected[i] and hero.position.distance_to(world.pickups[i].position) < 0.85:
            collected[i] = true; world.pickups[i].visible = false
            burst(hero.position + Vector3(0, 0.8, 0), "f6d484"); chime(660 + i * 140)
            toast( ["밀가루", "우유", "버터"][i] + "를 찾았어요!  " + str(collected.count(true)) + " / 3")
            if collected.count(true) == 3:
                stage = 1; coins += 20; toast("재료 준비 완료! 빵집에서 첫 주문을 받아요. +20")
            save_progress(); update_target()

func interact() -> void:
    if state != "explore": return
    var door = near_gate()
    if not door.is_empty():
        enter_area(int(door.to)); return
    if area_index > 0:
        side_interact(); return
    if city_index > 0:
        if stage == 0: tour.interact_mission(); return
        if hero.position.distance_to(target) > 2.05 and tour.near_shop(): state = "food_shop"; joystick = Vector2.ZERO; return

    if hero.position.distance_to(target) > 2.05:
        if tour.near_shop(): state = "food_shop"; joystick = Vector2.ZERO; return
        toast("금색 표시를 따라 " + target_name + " 쪽으로 걸어가요."); return
    if stage == 0: toast("반짝이는 재료 가까이 가면 자동으로 담아요.")
    elif stage == 1:
        show_dialogue( [ ["빵집 주인", "여행자 두 분! 주문을 조금만 도와줄래요?"], ["소현", "좋아요. 동훈아, 메뉴를 잘 보고 같이 만들자."], ["동훈", "크루아상, 바게트, 커피… 이번에는 안 헷갈릴게!"]], "cook")
    elif stage == 2:
        if need_shard():
            toast(String(city().boss.name) + ": “아직 떠올리지 못한 게 있군요.” — " + String(world.AREA_NAMES[city_index][1]) + "에서 기억 조각을 찾아와요."); return
        wild_battle = false; rival = story_rival
        battle_return = hero.position; partner_return = partner.position
        if city_index > 0:
            show_dialogue( [ [city().boss.name, city().boss.intro], ["소현", city().rule], ["동훈", "알았어. 다음 행동을 보고 기술을 고를게."]], "battle_ready"); return
        show_dialogue( [ ["피에르", "한 수씩 겨뤄 볼까? 내가 힘을 모으면, 방어할 차례야!"], ["동훈", "소현아, 맡겨 둬. 설거지만큼은 자신 있어!"]], "battle_ready")
    else:
        if city_index > 0:
            show_dialogue( [ ["동훈", city().memory], ["소현", "오늘의 약속도 사진으로 남기자."]], "photo"); return
        show_dialogue( [ ["동훈", "여기, 같이 오기로 했던 곳이지? 빵 냄새가 나니까 생각났어."], ["소현", "응. 다 기억하지 못해도 괜찮아. 오늘부터 다시 쌓으면 되니까."]], "photo")

func action(id: String) -> void:
    if id.begins_with("vista_album_") and state == "journal" and tour.selected == 6:
        tour.vista = clampi(int(id.trim_prefix("vista_album_")), 0, 2); state = "vista_album"; return
    if id.begins_with("city_") and state == "passport":
        tour.selected = clampi(int(id.trim_prefix("city_")), 0, 9); state = "journal"; return
    if id.begins_with("answer_"):
        tour.puzzle_choice(int(id.trim_prefix("answer_"))); return
    if id.begins_with("pz_"):
        if state == "puzzle": tour.pz.press(String(id.trim_prefix("pz_")))
        return
    if id.begins_with("meal_"):
        tour.buy_meal(int(id.trim_prefix("meal_"))); return
    if id.begins_with("tab_"):
        sheet_tab = clampi(int(id.trim_prefix("tab_")), 0, 4); return
    if id.begins_with("skillup_"):
        skill_up(String(id.trim_prefix("skillup_"))); return
    if id.begins_with("shoptab_"):
        shop_tab = clampi(int(id.trim_prefix("shoptab_")), 0, 2); return
    if id.begins_with("equip_"):
        equip_gear(String(id.trim_prefix("equip_"))); return
    if id.begins_with("buygear_"):
        buy_gear(String(id.trim_prefix("buygear_"))); return
    if id.begins_with("buyitem_"):
        buy_item(String(id.trim_prefix("buyitem_"))); return
    if id.begins_with("useitem_"):
        use_item(String(id.trim_prefix("useitem_"))); return
    if id.begins_with("petpick_"):
        pick_pet(int(id.trim_prefix("petpick_"))); return
    match id:
        "journal_back": state = "journal"
        "arrival_go": state = "explore"; tour.record().visited = true; update_target(); save_progress()
        "passport":
            if state not in ["map", "ending", "explore", "journal"]: return
            tour.store_current(); state = "passport"; joystick = Vector2.ZERO
        "passport_close": state = "explore"; update_target()
        "travel_selected": tour.travel(tour.selected)
        "next_city":
            if stage == 4 and city_index < 9: tour.travel(city_index + 1)
        "tour_help": previous_state = state; state = "city_help"; joystick = Vector2.ZERO
        "help_close": state = previous_state
        "food_close", "vista_close", "puzzle_close": state = "explore"; set_camera(1, true); update_target()
        "vista_capture": tour.capture_vista()

        "start":
            if has_save:
                state = "explore" if stage < 4 else "ending"
                update_target()
            else:
                start_intro()
        "intro_replay":
            if city_index == 0: start_intro()
            else: state = "arrival"
        "intro_next":
            intro_page += 1
            if intro_page >= 3: start_tutorial()
            else: set_intro_scene()
        "intro_skip": start_tutorial()
        "tutorial_next":
            tutorial_page += 1; scene_time = 0
            if tutorial_page >= 3: finish_tutorial()
        "tutorial_skip": finish_tutorial()
        "next":
            dialogue_index += 1
            if dialogue_index >= dialogue.size(): finish_dialogue()
        "skip": finish_dialogue()
        "interact": interact()
        "pause":
            previous_state = state; state = "pause"; joystick = Vector2.ZERO; reset_confirm = false; save_progress()
        "resume": state = previous_state; reset_confirm = false
        "sound": sound_on = not sound_on; save_progress(); chime(660)
        "effects": effects_on = not effects_on; sun.shadow_enabled = effects_on; save_progress()
        "reset":
            if not reset_confirm: reset_confirm = true
            else: restart()
        "zoom": overview = not overview; save_progress()
        "status", "status_card":
            previous_state = state; state = "status"; joystick = Vector2.ZERO; hud.release_all()
        "status_close": state = previous_state
        "pet_next": cycle_pet()
        "map": previous_state = state; state = "map"; joystick = Vector2.ZERO
        "close_map": state = previous_state
        "recipe0", "recipe1", "recipe2": cook_choice(int(id.right(1)))
        "battle_start": begin_battle()
        "fight_menu", "bag_menu", "battle_back":
            if state == "battle" and battle_phase == "choose":
                battle_menu = { "fight_menu": "fight", "bag_menu": "bag", "battle_back": "main"}[id]
        "strike", "guard", "heal", "team", "soak", "soap", "coffee": choose_battle(id)
        "battle_continue": claim_battle_win()
        "retry": begin_battle()
        "leave_battle":
            if state in ["battle_ready", "battle_lost"] or (state == "battle" and battle_phase == "choose"): leave_battle()
        "photo": capture_memory()
        "wander": state = "explore"; hero.position = tour.v(city().photo_at) + Vector3(-0.5, 0, 0); partner.position = tour.v(city().photo_at) + Vector3(0.5, 0, 0); reset_follow_path(); update_target()
        "album": state = "ending"
        "title": state = "title"; save_progress()

func show_dialogue(lines: Array, next: String) -> void:
    dialogue = lines; dialogue_index = 0; dialogue_next = next
    state = "dialogue"; joystick = Vector2.ZERO

func finish_dialogue() -> void:
    state = dialogue_next
    if state == "cook": orders = 0; order_time = 8; order_wait = 0; cooking_streak = 0; best_combo = 0
    if state == "photo":
        toast_time = 0
        hero.position = tour.v(city().photo_at) + Vector3(-0.55, 0, 0); partner.position = tour.v(city().photo_at) + Vector3(0.55, 0, 0)
        hero.rotation.y = 0; partner.rotation.y = 0
    if state == "explore": reset_follow_path(); save_progress()

func cook_choice(index: int) -> void:
    if state != "cook" or order_wait > 0: return
    if index == recipe_order[orders]:
        orders += 1; cooking_streak += 1; best_combo = maxi(best_combo, cooking_streak)
        chime(620 + cooking_streak * 90); toast("맛있게 완성!  " + str(orders) + " / 5")
        order_time = 8; order_wait = 0.45
        if orders == 5:
            var reward = 60 + best_combo * 4
            coins += reward; stage = 2
            burst(hero.position + Vector3(0, 1, 0), "f1ca80", 22)
            show_dialogue( [ ["빵집 주인", "다섯 주문 완성! 여행비 " + str(reward) + "원을 받아요. 최고 연속 " + str(best_combo) + "회!"], ["동훈", "방금 그 빵… 예전에 네가 좋아했던 맛이야."], ["소현", "기억 한 조각이 돌아오려나 봐. 에펠탑으로 가보자."]], "explore")
            save_progress(); update_target()
    else:
        cooking_streak = 0; order_wait = 0.45; order_time = 8; chime(240)
        toast("주문 그림을 한 번 더! 재료는 줄어들지 않아요.")

func begin_battle() -> void:
    if not wild_battle and state not in ["battle", "battle_lost", "battle_won"]:
        battle_return = hero.position; partner_return = partner.position
    PARTY_HP = party_max()
    state = "battle"; battle_max_hp = int((30 + city_index * 12 + wild_index * 3) * float(GRADES[wild_grade].hp)) if wild_battle else 70 + city_index * 34
    battle_bomb = 0; battle_vuln = 0; battle_charge = false
    battle_hp = battle_max_hp; health = PARTY_HP; perfects = 0; battle_hits = 0
    battle_turn = 1; battle_energy = mini(3, pet_bonus("energy") + next_energy); battle_berries = bag_count("candy"); battle_guard = false
    next_energy = 0
    battle_phase = "choose"; battle_menu = "main"; battle_choice = ""; battle_phase_time = 0
    battle_time = 0; battle_lock = 0; battle_reward = 0; battle_hit_applied = false; battle_volley_hits = 0; battle_hitstop = 0; battle_fx_left = 0
    battle_enemy_guard = false; battle_fog = false; battle_food = tour.meal; tour.meal = 0
    save_progress()
    if battle_food == 1: battle_berries += 1
    if battle_food == 2: battle_energy = 1
    refresh_intent()
    battle_result = "무엇을 할까요? 천천히 골라도 괜찮아요."
    reset_battle_pose()
    hero.rotation.y = PI; partner.rotation.y = PI
    rival.visible = true; rival.rotation.y = 0
    joystick = Vector2.ZERO; hud.release_all(); toast_time = 0

func reset_battle_pose() -> void:
    hero.position = HERO_ARENA; partner.position = PARTNER_ARENA; rival.position = ENEMY_ARENA

func enemy_heavy() -> bool:
    return battle_intent in ["heavy", "wave", "rush"]

func enemy_attack_name() -> String:
    if city_index == 0:
        if enemy_heavy(): return ["유령의 단체 야유", "빵 지키기 돌진", "보이지 않는 벽 밀기"][wild_index] if wild_battle else "바게트 풀스윙"
        return ["등골 오싹", "빵 내놔 쪼기", "투명 벽 밀기"][wild_index] if wild_battle else "바게트 휘두르기"
    var name = city().mobs[wild_index].attack if wild_battle else city().boss.attack
    return { "brace": "방어 자세 · 다음 피해 절반", "rest": "숨 고르기 · 반격 없음", "sand": "모래 끼얹기 · 추가 피해 2", "chill": "찬바람 · 기력 1 감소", "gust": "돌풍 · 기력 1 감소", "mist": "안개 · 다음 설거지 약화", "wave": "큰 파도 · 강공격", "rush": "돌진 · 강공격", "heavy": "힘껏 " + name}.get(battle_intent, name)

func enemy_damage() -> int:
    if battle_intent in ["brace", "rest"]: return 0
    var base = ( (10 + wild_index if wild_battle else 12) + int(city_index * 2.2)) if enemy_heavy() else ( (5 + wild_index if wild_battle else 6) + int(city_index * 1.3))
    return int(round(base * float(GRADES[wild_grade].atk))) if wild_battle else base

func choose_battle(choice: String) -> void:

    if state != "battle" or battle_phase != "choose": return
    if choice == "team" and (battle_energy < 3 or coins < 40): return
    if choice == "heal" and (battle_berries <= 0 or health >= PARTY_HP): return
    if choice not in ["strike", "guard", "heal", "team", "soak", "soap", "coffee"]: return
    if choice in ["soak", "soap", "coffee"] and not skill_open(choice): return
    if choice in ["soak", "soap"] and battle_energy < 1: return
    if choice == "soak" and battle_bomb > 0: return
    if choice == "coffee" and battle_charge: return
    battle_choice = choice; battle_phase = "player"; battle_phase_time = 0; battle_menu = "main"
    battle_guard = choice == "guard"; battle_hit_applied = false; battle_volley_hits = 0; battle_hitstop = 0; battle_fx_left = 0
    if choice == "team":
        battle_energy -= 3; coins -= 40; save_progress()
    if choice == "heal": battle_berries -= 1; bag_add("candy", -1)
    if choice in ["soak", "soap"]: battle_energy -= 1
    battle_result = { "strike": "설거지 연타! 수세미 3개, 갑니다!", "guard": "야근 버티기! 방어하면서 체력을 채워요.", "heal": "뽀뽀사탕! 동훈의 체력을 회복해요.", "team": "월급 박치기! 여행비 40원을 던졌다!", "soak": "냄비 불리기! 눌어붙은 냄비를 물에 담가 둔다…", "soap": "퐁퐁 뿌리기! 바닥이 미끌미끌해졌다!", "coffee": "커피 수혈! 눈이 번쩍 뜨인다!"}[choice]
    battle_quote = { "strike": ["이 정도 설거지는 매일 해!", "퐁퐁 묻었다!", "손목 나가겠네…"], "guard": ["야근보단 낫지.", "버티는 건 자신 있어.", "새벽 세 시도 버텼어."], "team": ["이번 달 월급이다!", "카드값… 아니, 받아라!", "돈으로 되는 일도 있어!"], "heal": ["당 충전 완료!", "하나만 더 먹을까…", "조금 살 것 같다."], "soak": ["불려야 잘 닦여.", "지금은 건드리지 마.", "기다림도 기술이야."], "soap": ["한 방울이면 충분해.", "거품 조심해!", "미끄러우니까 뛰지 마."], "coffee": ["샷 추가요.", "이제 좀 살겠다.", "오늘 세 잔째야…"]}[choice][randi_range(0, 2)]
    hud.release_all(); chime(880 if choice == "team" else 540)

func battle_impact(kind: String, target_side: String, amount: int) -> void:
    battle_fx_kind = kind; battle_fx_target = target_side; battle_fx_amount = amount
    battle_fx_left = 0.65; battle_hitstop = (0.055 if kind == "sponge" else 0.09) if effects_on else 0
    if not sound_on: return
    var samples = 5512 if kind in ["money", "heal", "haunt", "buff"] else 3308
    var data = PackedByteArray(); data.resize(samples * 2)
    for i in range(samples):
        var t = float(i) / 22050.0
        var noise = fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0) * 2 - 1
        var v = 0.0
        match kind:
            "sponge":
                v = sin(TAU * (150 * t - 330 * t * t)) * exp(- t * 37) * 0.4 + noise * exp(- t * 55) * 0.22
                if t > 0.035: v += sin(TAU * (530 * t + 1600 * t * t)) * exp(- (t - 0.035) * 45) * 0.12
            "money": v = noise * (0.6 + 0.4 * sin(t * TAU * 38)) * exp(- t * 18) * 0.22 + sin(TAU * 1174 * t) * exp(- t * 24) * 0.13
            "guard": v = noise * pow(maxf(0, sin(t * TAU * 27)), 10) * exp(- t * 18) * 0.32
            "heal", "buff": v = (sin(TAU * 659 * t) + sin(TAU * 988 * t)) * exp(- t * 14) * 0.18
            "haunt": v = sin(TAU * (290 * t - 270 * t * t)) * sin(t * TAU * 13) * exp(- t * 12) * 0.35
            "peck": v = (noise * 0.3 + sin(TAU * 720 * t) * 0.3) * exp(- t * 55)
            _: v = (sin(TAU * (180 * t - 260 * t * t)) * 0.5 + noise * 0.3) * exp(- t * 32) * 0.6
        v *= minf(1, t * 1300)
        data.encode_s16(i * 2, int(clampf(v, -0.9, 0.9) * 32767))

    audio_wave = AudioStreamWAV.new(); audio_wave.format = AudioStreamWAV.FORMAT_16_BITS
    audio_wave.mix_rate = 22050; audio_wave.data = data; audio.stream = audio_wave; audio.play()
    if OS.has_feature("android"): Input.vibrate_handheld(22)

func battle_tick(dt: float) -> void:
    if battle_phase == "choose": return
    if battle_hitstop > 0:
        battle_hitstop = maxf(0, battle_hitstop - dt); return
    battle_phase_time += dt; battle_time += dt
    if battle_phase == "player":

        if battle_choice == "strike":
            if battle_volley_hits < 3 and battle_phase_time >= [0.38, 0.62, 0.86][battle_volley_hits] and battle_hp > 0:
                var damage = dish_damage(battle_volley_hits)
                battle_hp = maxi(0, battle_hp - damage); battle_volley_hits += 1; battle_hits += 1
                battle_result = "설거지 연타 " + str(battle_volley_hits) + "/3! 수세미 명중 · " + str(damage) + " 피해"
                battle_impact("sponge", "enemy", damage)
                if battle_volley_hits == 3 or battle_hp == 0: battle_energy = mini(3, battle_energy + 1)
        elif battle_phase_time >= (0.5 if battle_choice == "team" else 0.28) and not battle_hit_applied:
            battle_hit_applied = true
            if battle_choice == "team":
                var damage = amp(salary_damage())
                battle_hp = maxi(0, battle_hp - damage); battle_hits += 1; perfects += 1
                battle_result = "월급 박치기! " + str(damage) + " 피해. 아파요, 둘 다."
                battle_impact("money", "enemy", damage)
            elif battle_choice == "guard":
                var mend = guard_heal()
                battle_energy = mini(3, battle_energy + 1); health = mini(PARTY_HP, health + mend)
                battle_result = "야근 버티기! 체력 +" + str(mend) + " · 반격 피해 75% 감소"
                battle_impact("guard", "party", 0)
            elif battle_choice == "soak":
                battle_bomb = 2
                battle_result = "냄비를 불려 뒀어요. 2턴 뒤에 " + str(soak_damage()) + " 피해로 터져요!"
                battle_fx_note = "불리는 중"; battle_impact("buff", "party", 0)
            elif battle_choice == "soap":
                battle_vuln = 3
                battle_result = "상대가 미끄러워해요! 2턴 동안 주는 피해 +" + str(int((soap_mul() - 1.0) * 100)) + "%"
                battle_fx_note = "미끌!"; battle_impact("buff", "enemy", 0)
            elif battle_choice == "coffee":
                battle_charge = true; battle_energy = mini(3, battle_energy + 2)
                battle_result = "기력 +2! 다음 공격이 " + str(snappedf(coffee_mul(), 0.1)) + "배로 들어가요."
                battle_fx_note = "각성!"; battle_impact("buff", "party", 0)
            elif battle_choice == "heal":
                var recovered = mini(candy_heal(), PARTY_HP - health); health += recovered
                battle_result = "뽀뽀사탕으로 체력 " + str(recovered) + " 회복!"
                battle_impact("heal", "party", recovered)
        var duration = 1.15 if battle_choice == "strike" else (0.95 if battle_choice == "team" else 0.72)
        if battle_phase_time < duration: return
        if battle_choice in ["strike", "team"]: battle_charge = false
        if battle_hp == 0:
            win_battle(); return
        battle_fog = false
        battle_phase = "windup"; battle_phase_time = 0
    elif battle_phase == "windup":
        if battle_phase_time < 0.45: return
        battle_result = enemy_attack_name() + "! 상대가 반격해요."
        battle_phase = "enemy"; battle_phase_time = 0; battle_hit_applied = false
    elif battle_phase == "enemy":
        if battle_phase_time >= 0.3 and not battle_hit_applied:
            battle_hit_applied = true
            battle_enemy_guard = battle_intent == "brace"
            var damage = enemy_damage()
            if battle_guard: damage = maxi(1, int(ceil(damage * 0.25))) if damage > 0 else 0
            elif battle_intent == "sand": damage += 2
            if not battle_guard and battle_intent in ["chill", "gust"]: battle_energy = maxi(0, battle_energy - 1)
            if not battle_guard and battle_intent == "mist": battle_fog = true
            health = maxi(0, health - damage)
            if battle_intent == "brace": battle_result = "상대가 방어 자세! 다음 피해 절반 · 월급 박치기는 방어를 뚫어요."
            elif battle_intent == "rest": battle_result = "상대가 숨을 골랐어요. 이번에는 반격이 없어요."
            else:
                battle_result = ("잘 막았어요! " if battle_guard else "상대의 반격! ") + str(damage) + " 피해" + (" · 기력 −1" if not battle_guard and battle_intent in ["chill", "gust"] else " · 다음 설거지 −2" if battle_fog else "")
                battle_impact("guard" if battle_guard else ("regional" if city_index > 0 else ( ["haunt", "peck", "wall"][wild_index] if wild_battle else "baguette")), "party", damage)

        if battle_phase_time < 0.6: return
        if health == 0: state = "battle_lost"; battle_phase = "done"; return
        battle_phase = "recover"; battle_phase_time = 0
    elif battle_phase == "recover":
        if battle_phase_time < 0.55: return
        battle_vuln = maxi(0, battle_vuln - 1)
        if battle_bomb > 0:
            battle_bomb -= 1
            if battle_bomb == 0:
                var blast = soak_damage()
                if battle_vuln > 0: blast = int(round(blast * soap_mul()))
                battle_hp = maxi(0, battle_hp - blast); battle_hits += 1
                battle_result = "불려 둔 냄비가 터졌다! " + str(blast) + " 피해!"
                battle_impact("money", "enemy", blast)
                battle_phase = "bomb"; battle_phase_time = 0; return
        next_turn()
    elif battle_phase == "bomb":
        if battle_phase_time < 0.85: return
        if battle_hp == 0: win_battle(); return
        next_turn()

func next_turn() -> void:
    battle_turn += 1; battle_guard = false; battle_phase = "choose"; battle_phase_time = 0; refresh_intent()
    battle_result = "상대가 힘을 모아요. 방어할까요?" if enemy_heavy() else "다음 행동을 골라주세요."
    if battle_bomb == 1: battle_result += " (냄비는 다음 턴에 터져요)"

func win_battle() -> void:
    battle_reward = int((15 + city_index * 4 + perfects * 5) * float(GRADES[wild_grade].gold)) if wild_battle else (80 + city_index * 20 + perfects * 10)
    state = "battle_won"; battle_phase = "done"; chime(1174)

func claim_battle_win() -> void:
    if state != "battle_won": return
    if wild_battle: finish_wild_battle(); return
    coins += battle_reward; stage = 3
    skill_points += 1
    gain_exp(40 + city_index * 12 + perfects * 4)
    hero.position = battle_return; partner.position = partner_return; reset_follow_path()
    rival.position = tour.v(city().boss_at)
    if city_index > 0:
        show_dialogue( [ [city().boss.name, city().boss.win], ["동훈", city().memory], ["소현", "이 순간을 사진으로 남기자."]], "explore"); save_progress(); update_target(); return
    show_dialogue( [ ["피에르", "당신… 설거지 실력이 보통이 아니군!"], ["동훈", "기억났어. 여기서 사진 찍자고 내가 말했었지?"], ["소현", "이번엔 미루지 말자. 지금 찍자!"]], "explore")
    save_progress(); update_target()

func update_grass_tension(dt: float) -> void:
    if state != "explore" or not world.in_grass(hero.position) or encounter_grace > 0:
        grass_tension = maxf(0.0, grass_tension - dt * 1.6); return
    grass_tension = clampf(grass_steps / maxf(0.01, encounter_at), 0, 1)
    if grass_tension < 0.5: return
    rustle_t -= dt
    if rustle_t <= 0:
        # 가까워질수록 자주, 크게 들썩인다
        rustle_t = lerpf(0.5, 0.12, grass_tension)
        if effects_on:
            var a = randf() * TAU
            var r = lerpf(1.6, 0.55, grass_tension)
            burst(hero.position + Vector3(cos(a) * r, 0.1, sin(a) * r), "6f9a63", 3 + int(grass_tension * 4))
        rustle_beat += 1
        if grass_tension > 0.82 and rustle_beat % 3 == 0: chime(520)

func check_encounter(distance: float) -> void:
    if state != "explore" or distance <= 0.001: return
    encounter_grace = maxf(0, encounter_grace - distance)
    if not world.in_grass(hero.position): return
    if encounter_grace > 0: return
    grass_steps += distance
    if grass_steps >= encounter_at: meet_wild()

func meet_wild() -> void:
    wild_battle = true; battle_return = hero.position; partner_return = partner.position
    battle_follow_path = follow_path.duplicate(); battle_follow_anchor = follow_anchor
    story_perfects = perfects; wild_index = randi_range(0, 2)
    wild_grade = 0
    if wild_wins >= 2 or city_index > 0:
        var roll = randf()
        var boost = 1.0 + area_index * 0.9
        if roll < (0.02 + city_index * 0.003) * boost: wild_grade = 3
        elif roll < (0.09 + city_index * 0.006) * boost: wild_grade = 2
        elif roll < (0.28 + city_index * 0.01) * boost: wild_grade = 1
    rival = creatures[wild_index]; story_rival.visible = false
    hero.position = Vector3(-0.7, 0.12, -3.6); partner.position = Vector3(0.65, 0.12, -3.6)
    hero.rotation.y = PI; partner.rotation.y = PI
    rival.position = Vector3(1.1, 0.12, -6.3); rival.rotation.y = 0; rival.visible = true
    state = "battle_ready"; joystick = Vector2.ZERO; hud.release_all()
    grass_steps = 0; chime(880 + wild_grade * 180)

func restore_from_wild() -> void:
    rival.visible = false; rival = story_rival
    hero.position = battle_return; partner.position = partner_return
    perfects = story_perfects; wild_battle = false; wild_grade = 0
    encounter_grace = 1.8; grass_steps = 0; encounter_at = randf_range(2.8, 5.0)
    follow_path = battle_follow_path.duplicate(); follow_anchor = battle_follow_anchor
    state = "explore"; update_target(); set_camera(1, true)

func finish_wild_battle() -> void:
    var reward = battle_reward
    var first = not wild_seen[wild_index]
    wild_seen[wild_index] = true; wild_wins += 1
    coins += reward; var name = wild_name()
    var caught_index = wild_index
    var caught_city = city_index
    var caught_grade = wild_grade
    var bonus_xp = int((8 + city_index * 3 + perfects * 2) * float(GRADES[wild_grade].xp))
    restore_from_wild()
    burst(hero.position + Vector3(0, 0.8, 0), "f6d484", 18)
    toast(name + "와의 대결 승리! +" + str(reward) + "원" + (" · 첫 만남!" if first else ""))
    gain_exp(bonus_xp)
    if caught_grade >= 2 and bag_count("candy") < 9: bag_add("candy", 1)
    befriend(caught_city, caught_index, name, caught_grade)
    tour.wild_victory()
    save_progress()

# 이긴 뒤 가끔 따라오겠다고 한다. 이미 있는 친구면 더 친해진다.
func befriend(c: int, i: int, name: String, grade: int = 0) -> void:
    var found = -1
    for k in range(pets.size()):
        if int(pets[k].c) == c and int(pets[k].i) == i: found = k; break
    if found >= 0:
        if grade > int(pets[found].get("g", 0)):
            pets[found]["g"] = grade
            chime(1318); toast(name + "이(가) 합류! 친구가 " + String(GRADES[grade].tag) + " 등급이 됐어요.")
            return
        if int(pets[found].lv) >= 5: return
        if randf() > 0.34 + perfects * 0.05: return
        pets[found].lv = int(pets[found].lv) + 1
        chime(1046)
        toast(name + "와(과) 더 친해졌어요! 친밀도 " + str(pets[found].lv) + " / 5")
        return
    if randf() > 0.3 + perfects * 0.06 + grade * 0.2: return
    pets.append({ "c": c, "i": i, "lv": 1, "g": grade})
    if pet_team.size() < TEAM_MAX: pet_team.append(pets.size() - 1)
    spawn_pet()
    chime(1318)
    toast(name + "이(가) 따라오기로 했어요! " + String(PET_ROLE[i].desc))

# 구버전 버튼 호환: 첫 번째 자리를 다음 친구로
func cycle_pet() -> void:
    if pets.is_empty(): toast("아직 따라오는 친구가 없어요. 풀숲에서 만나 보세요."); return
    pick_pet((int(pet_team[0]) + 1) % pets.size() if not pet_team.is_empty() else 0)

# 도시를 옮기거나 팀이 바뀌면 자리를 새로 잡는다
func spawn_pet() -> void:
    if pet_node and is_instance_valid(pet_node): pet_node.queue_free()
    pet_node = null; pet_path.clear(); pet_spots.clear(); trail.clear()
    if not world or not partner: return
    for k in range(pet_team.size()): pet_spots.append(partner.position)
    var p = pet()
    if p.is_empty(): return
    pet_node = world.creature(int(p.i))
    pet_node.scale = Vector3(0.62, 0.62, 0.62)
    pet_node.position = partner.position
    pet_node.visible = state == "photo"

# 동훈이 지나온 길을 간격을 두고 줄지어 따라온다
func move_pet(dt: float) -> void:
    if pet_spots.size() != pet_team.size(): spawn_pet()
    if pet_team.is_empty(): return
    if trail.is_empty() or partner.position.distance_to(trail[trail.size() - 1]) > 0.1:
        trail.append(partner.position)
        if trail.size() > 90: trail.pop_front()
    for k in range(pet_spots.size()):
        var want = 0.95 * (k + 1)
        var spot = trail[0]
        var walked = partner.position.distance_to(trail[trail.size() - 1])
        var at_end = true
        for j in range(trail.size() - 1, 0, -1):
            var seg = trail[j].distance_to(trail[j - 1])
            if walked + seg >= want:
                spot = trail[j].lerp(trail[j - 1], clampf((want - walked) / maxf(0.001, seg), 0, 1)); at_end = false; break
            walked += seg
        if at_end and trail.size() == 1: spot = trail[0] + Vector3(-0.5 * (k + 1), 0, 0.35)
        pet_spots[k] = pet_spots[k].lerp(spot, minf(1, dt * 9))
    if pet_node and is_instance_valid(pet_node):
        pet_node.visible = state == "photo"
        pet_node.position = Vector3(pet_spots[0].x, world.surface_height(pet_spots[0]) + 0.015, pet_spots[0].z)

func leave_battle() -> void:
    tour.trial = -1
    if wild_battle: restore_from_wild()
    else:
        state = "explore"; hero.position = battle_return; partner.position = partner_return; rival.position = tour.v(city().boss_at); reset_follow_path(); update_target()
    toast("천천히 산책해요. 풀숲에서는 언제든 다시 만나요.")
    save_progress()

func capture_memory() -> void:
    if state != "photo" or pending_photo: return
    pending_photo = true; hud.visible = false

    var original_size = camera.size
    camera.size = original_size * 2.0
    await get_tree().process_frame
    await RenderingServer.frame_post_draw
    var img = get_viewport().get_texture().get_image()
    camera.size = original_size
    if img == null or img.is_empty():
        hud.visible = true; pending_photo = false
        toast("사진을 읽지 못했어요. 잠시 뒤 다시 눌러주세요."); return
    var crop_height = mini(img.get_height(), int(img.get_width() * 0.72))
    img = img.get_region(Rect2i(0, int( (img.get_height() - crop_height) / 2), img.get_width(), crop_height))
    photo = ImageTexture.create_from_image(img)
    var err = img.save_png(photo_file)
    hud.visible = true; pending_photo = false; stage = 4; state = "ending"; flash = 1
    tour.stamp_city()
    chime(1174); save_progress()
    if err != OK: toast("사진 파일 저장은 실패했지만 지금 화면의 앨범은 볼 수 있어요.")

func burst(pos: Vector3, color: String, count: int = 12) -> void:
    if not effects_on: return
    for i in range(count):
        var n = world.box(world, pos, Vector3.ONE * 0.09, color)
        n.rotation = Vector3(randf(), randf(), randf())
        var a = float(i) / count * TAU
        sparks.append({ "node": n, "velocity": Vector3(cos(a) * 1.4, randf_range(1.2, 2.4), sin(a) * 1.4), "life": 0.9})

func chime(hz: float) -> void:
    if not sound_on: return
    var data = PackedByteArray(); data.resize(6615 * 2)
    for i in range(6615):
        var t = float(i) / 22050.0
        var v = sin(TAU * hz * t) * exp(- t * 17.0) * 0.28
        data.encode_s16(i * 2, int(v * 32767))
    audio_wave = AudioStreamWAV.new(); audio_wave.format = AudioStreamWAV.FORMAT_16_BITS
    audio_wave.mix_rate = 22050; audio_wave.data = data; audio.stream = audio_wave; audio.play()
    if OS.has_feature("android"): Input.vibrate_handheld(12)

func toast(text: String) -> void:
    toast_text = text; toast_time = 2.5

func save_progress() -> void:
    if state in ["intro", "tutorial"]: return
    if not ui_ready or (state == "title" and not has_save): return
    tour.store_current()
    var data = { "version": 3, "city": city_index, "cities": tour.records, "completed": tour.completed, "unlocked": tour.unlocked, "coins": coins, "meal": tour.meal, "time": game_time, "sound": sound_on, "effects": effects_on, "wide_view": overview, "tutorial_seen": tutorial_seen, "level": level, "xp": xp, "pets": pets, "pet_active": pet_active, "owned_gear": owned_gear, "equipped": equipped, "bag": bag, "next_energy": next_energy, "pet_team": pet_team, "skill_lv": skill_lv, "skill_points": skill_points}
    var temp = SAVE_FILE + ".tmp"; var file = FileAccess.open(temp, FileAccess.WRITE)
    save_ok = file != null
    if not file: return
    file.store_string(JSON.stringify(data)); file.close()
    if FileAccess.file_exists(SAVE_FILE):
        var backup = DirAccess.copy_absolute(SAVE_FILE, SAVE_FILE + ".bak")
        if backup != OK: save_ok = false; return
    var err = DirAccess.rename_absolute(temp, SAVE_FILE)
    save_ok = err == OK
    if save_ok: has_save = true

func load_progress() -> void:
    if not FileAccess.file_exists(SAVE_FILE): return
    var parser = JSON.new()
    parser.parse(FileAccess.get_file_as_string(SAVE_FILE))
    var data = parser.data
    if not data is Dictionary and FileAccess.file_exists(SAVE_FILE + ".bak"):
        parser.parse(FileAccess.get_file_as_string(SAVE_FILE + ".bak")); data = parser.data
    if not data is Dictionary or int(data.get("version", 0)) not in [1, 2, 3]: save_ok = false; return
    tour.reset_records()
    if int(data.version) == 1:
        if not FileAccess.file_exists(SAVE_FILE + ".v1-backup"): DirAccess.copy_absolute(SAVE_FILE, SAVE_FILE + ".v1-backup")
        for key in ["stage", "collected", "wild_wins", "wild_seen", "best_combo", "perfects", "position"]:
            if data.has(key): tour.records[0][key] = data[key]
        tour.records[0].visited = true; tour.completed[0] = int(data.get("stage", 0)) >= 4; tour.unlocked = 1 if tour.completed[0] else 0
    else:
        var saved_cities = data.get("cities", [])
        if saved_cities is Array and saved_cities.size() == 10:
            for i in range(10):
                if saved_cities[i] is Dictionary: tour.records[i].merge(saved_cities[i], true)
        var completed = data.get("completed", [])
        if completed is Array and completed.size() == 10:
            for i in range(10): tour.completed[i] = completed[i] == true
        tour.unlocked = clampi(int(data.get("unlocked", 0)), 0, 9)
        tour.meal = clampi(int(data.get("meal", 0)), 0, 3)
    coins = maxi(0, int(data.get("coins", 0))); game_time = maxf(0, float(data.get("time", 0)))
    level = clampi(int(data.get("level", 1)), 1, LEVEL_MAX); xp = maxi(0, int(data.get("xp", 0)))
    next_energy = clampi(int(data.get("next_energy", 0)), 0, 3)
    owned_gear = ["g0", "a0", "s0"]
    var saved_gear = data.get("owned_gear", [])
    if saved_gear is Array:
        for id in saved_gear:
            var found = gear_of(String(id))
            if found.id == String(id) and not owned_gear.has(found.id): owned_gear.append(found.id)
    equipped = ["g0", "a0", "s0"]
    var saved_eq = data.get("equipped", [])
    if saved_eq is Array and saved_eq.size() == 3:
        for i in range(3):
            var pick = gear_of(String(saved_eq[i]))
            if int(pick.slot) == i and owned_gear.has(pick.id): equipped[i] = pick.id
    bag = {}
    var saved_bag = data.get("bag", {})
    if saved_bag is Dictionary:
        for entry in ITEMS:
            bag[entry.id] = clampi(int(saved_bag.get(entry.id, 0)), 0, int(entry.cap))
    pets.clear()
    var saved_pets = data.get("pets", [])
    if saved_pets is Array:
        for entry in saved_pets:
            if not entry is Dictionary: continue
            var c = clampi(int(entry.get("c", 0)), 0, 9)
            var i = clampi(int(entry.get("i", 0)), 0, 2)
            pets.append({ "c": c, "i": i, "lv": clampi(int(entry.get("lv", 1)), 1, 5), "g": clampi(int(entry.get("g", 0)), 0, 3)})
    pet_active = clampi(int(data.get("pet_active", -1)), -1, pets.size() - 1)
    pet_team = []
    var saved_team = data.get("pet_team", null)
    if saved_team is Array:
        for index in saved_team:
            var k = int(index)
            if k >= 0 and k < pets.size() and not pet_team.has(k) and pet_team.size() < TEAM_MAX: pet_team.append(k)
    elif pet_active >= 0: pet_team.append(pet_active)
    skill_points = clampi(int(data.get("skill_points", maxi(0, level - 1) if not data.has("skill_lv") else 0)), 0, 99)
    var saved_skills = data.get("skill_lv", {})
    for entry in SKILLS:
        skill_lv[entry.id] = clampi(int(saved_skills.get(entry.id, 1)) if saved_skills is Dictionary else 1, 1, SKILL_MAX)
    tutorial_seen = data.get("tutorial_seen", true) == true
    sound_on = data.get("sound", true) == true; effects_on = data.get("effects", true) == true; overview = data.get("wide_view", false) == true
    sun.shadow_enabled = effects_on; tour.apply_city(clampi(int(data.get("city", 0)), 0, tour.unlocked))
    PARTY_HP = party_max(); spawn_pet()
    has_save = true

func equip_gear(id: String) -> void:
    var entry = gear_of(id)
    if entry.id != id or not owned_gear.has(id): return
    equipped[int(entry.slot)] = id
    PARTY_HP = party_max(); health = mini(health, PARTY_HP)
    chime(620); save_progress()
    toast(String(entry.name) + " 착용!  " + String(entry.line))

func buy_gear(id: String) -> void:
    var entry = gear_of(id)
    if entry.id != id or owned_gear.has(id): return
    if coins < int(entry.cost): toast("돈이 " + str(int(entry.cost) - coins) + "원 모자라요."); return
    coins -= int(entry.cost); owned_gear.append(id)
    equip_gear(id)
    toast(String(entry.name) + "를 샀어요!  남은 돈 " + str(coins) + "원")

func buy_item(id: String) -> void:
    var entry = item_of(id)
    if entry.id != id: return
    if bag_count(id) >= int(entry.cap): toast("가방에 더는 안 들어가요."); return
    if coins < int(entry.cost): toast("돈이 " + str(int(entry.cost) - coins) + "원 모자라요."); return
    coins -= int(entry.cost); bag_add(id, 1); chime(700); save_progress()
    toast(String(entry.name) + " 구입!  가방에 " + str(bag_count(id)) + "개")

func use_item(id: String) -> void:
    if bag_count(id) <= 0: return
    match id:
        "drink":
            if next_energy > 0: toast("이미 기력이 채워져 있어요."); return
            next_energy = 1; bag_add(id, -1); toast("다음 대결을 기력 1칸으로 시작해요.")
        "treat":
            var p = {}
            for index in pet_team:
                var one = pets[int(index)]
                if int(one.lv) < 5 and (p.is_empty() or int(one.lv) < int(p.lv)): p = one
            if pet_team.is_empty(): toast("아직 동행이 없어요."); return
            if p.is_empty(): toast("함께 걷는 친구들과 이미 최고로 친해요."); return
            p.lv = int(p.lv) + 1; bag_add(id, -1)
            toast(pet_name(p) + "와 더 친해졌어요!  친밀도 " + str(p.lv) + "/5")
        "candy": toast("뽀뽀사탕은 대결 중에 가방에서 꺼내 써요.")
        _: toast("추억 사진을 찍을 때 자동으로 쓰여요.")
    chime(680); save_progress()

func pick_pet(index: int) -> void:
    if index < 0 or index >= pets.size(): return
    if pet_team.has(index):
        pet_team.erase(index); toast(pet_name(pets[index]) + "는 쉬기로 했어요.")
    elif pet_team.size() >= TEAM_MAX:
        toast("세 친구까지만 함께 걸을 수 있어요. 먼저 한 친구를 쉬게 해주세요."); return
    else:
        pet_team.append(index); toast(pet_name(pets[index]) + "와 함께 걸어요. (" + str(pet_team.size()) + " / " + str(TEAM_MAX) + ")")
    spawn_pet(); PARTY_HP = party_max(); chime(640); save_progress()

func restart() -> void:
    if wild_battle: restore_from_wild()
    tour.reset_records(); city_index = 0; level = 1; xp = 0; pets.clear(); pet_active = -1; pet_team = []
    skill_points = 0; wild_grade = 0; area_index = 0
    for entry in SKILLS: skill_lv[entry.id] = 1
    owned_gear = ["g0", "a0", "s0"]; equipped = ["g0", "a0", "s0"]; bag = { "candy": 3}; next_energy = 0; sheet_tab = 0
    rebuild_city(); photo_file = tour.current_photo_path(); PARTY_HP = party_max(); spawn_pet()
    rival = story_rival; wild_wins = 0; wild_seen = [false, false, false]
    grass_steps = 0; encounter_grace = 1.5; encounter_at = 3.2
    stage = 0; collected = [false, false, false]; coins = 0; perfects = 0; best_combo = 0; game_time = 0
    hero.position = Vector3(-0.45, 0.12, 8); partner.position = Vector3(0.55, 0.12, 8.4)
    rival.position = Vector3(2.7, 0.12, -5.5); photo = null
    if FileAccess.file_exists(photo_file): DirAccess.remove_absolute(photo_file)
    state = "explore"; reset_confirm = false; reset_follow_path(); update_target(); save_progress()
    toast("첫 번째 파리, 다시 시작!")

func smoke_test() -> void:

    assert (OS.get_cmdline_user_args().has("--test-isolated"))
    restart()
    for i in range(3): hero.position = world.pickups[i].position; check_pickups()
    assert (stage == 1 and coins == 20)
    state = "cook"; orders = 0; order_wait = 0
    cook_choice(2); assert (orders == 0)
    for i in range(5): order_wait = 0; cook_choice(recipe_order[i])
    assert (stage == 2 and coins == 100)
    begin_battle(); choose_battle("strike")
    var hp_before = battle_hp
    battle_tick(0.2); assert (battle_hp == hp_before)
    battle_tick(0.18); assert (battle_hp == hp_before - 3 and battle_volley_hits == 1 and battle_hitstop > 0)
    var contact_time = battle_phase_time
    battle_tick(0.04); assert (battle_phase_time == contact_time)
    for tick in range(45): battle_tick(0.025)
    assert (battle_hp == hp_before - 8 and battle_volley_hits == 3 and battle_energy == 1)
    assert (hero.position == HERO_ARENA and partner.position == PARTNER_ARENA)
    print("SPONGE_VOLLEY_PASS: three actual contacts, 3+3+2 damage, one charge, hitstop, no duplicate impact")
    begin_battle()
    for choice in ["strike", "strike", "guard", "team", "strike", "strike"]:
        choose_battle(choice)
        for tick in range(90):
            if state == "battle": battle_tick(0.05)
    assert (state == "battle_won" and health > 0 and perfects == 1)
    claim_battle_win(); assert (stage == 3 and coins == 150)
    state = "explore"; save_progress(); coins = 0; load_progress(); assert (coins == 150 and stage == 3)
    assert (not world.can_walk(Vector3(5, 0, 3)))
    assert (world.can_walk(Vector3(0, 0, 3)))

    hero.position = Vector3(-7, 0.12, 9.5); partner.position = Vector3(-7.5, 0.12, 9.5)
    encounter_grace = 0; encounter_at = 1; check_encounter(0); assert (state == "explore")
    check_encounter(1.1); assert (wild_battle and state == "battle_ready")
    save_progress()
    var saved = JSON.parse_string(FileAccess.get_file_as_string(SAVE_FILE))
    assert (is_equal_approx(float(saved.cities[0].position[0]), -7.0) and is_equal_approx(float(saved.cities[0].position[1]), 9.5) and int(saved.cities[0].perfects) == 1)
    begin_battle()
    for choice in ["strike", "strike", "guard", "team"]:
        choose_battle(choice)
        for tick in range(90):
            if state == "battle": battle_tick(0.05)
    assert (state == "battle_won")
    claim_battle_win()
    assert (stage == 3 and coins == 130 and wild_wins == 1 and perfects == 1)
    assert (is_equal_approx(hero.position.x, -7) and is_equal_approx(hero.position.z, 9.5) and not wild_battle)
    check_encounter(0.1); assert (state == "explore")
    encounter_grace = 0; encounter_at = 1; check_encounter(1.1); assert (wild_battle)
    leave_battle(); assert (stage == 3 and coins == 130 and state == "explore")
    save_progress(); wild_wins = 0; load_progress(); assert (wild_wins == 1 and wild_seen.count(true) == 1)
    hero.position = Vector3(-8, 0.12, -6.8); partner.position = hero.position + Vector3(0.5, 0, 0)
    set_camera(1, true); world.update_occlusion(camera, [hero, partner], true, 1)
    assert (world.faded_count > 0 and world.hidden_people[0])
    world.update_occlusion(camera, [hero, partner], false, 1); assert (world.faded_count == 0)
    for stage_to_test in [0, 1, 2, 3, 4]:
        stage = stage_to_test; state = "explore"; hero.position = Vector3(3, 0.1, 10)
        encounter_grace = 0; encounter_at = 0.5; grass_steps = 0; check_encounter(0.6)
        assert (wild_battle); leave_battle(); assert (stage == stage_to_test)
    assert (world.in_grass(Vector3(3, 0.1, 10)))
    assert (not world.in_grass(Vector3(0, 0.1, 8)))
    assert (not world.in_grass(Vector3(0, 0.3, 3)))
    var position_before = hero.position; var coins_before = coins
    start_intro(); assert (state == "intro")
    action("intro_next"); action("intro_next"); action("intro_next"); assert (state == "tutorial")
    action("tutorial_next"); action("tutorial_next"); action("tutorial_next")
    assert (state == "explore" and tutorial_seen and hero.position == position_before and coins == coins_before)
    print("INTRO_SMOKE_PASS: full-screen story, tutorial, replay preservation, all-lawn encounters at every story stage")
    print("GRASS_SMOKE_PASS: idle, repeat encounters, return position, rewards, story preservation, save restore, camera occlusion")
    print("PARIS_SMOKE_PASS: collection, wrong recipe, 5 orders, turn choices, guard, team skill, stage rewards, save reload, river collision")
    get_tree().quit()

func qa_command(args) -> void:
    var d = JSON.parse_string(args[0])
    match d.get("cmd", ""):
        "reset": qa_freeze = false; qa_portrait = false; hud.visible = true; restart()
        "action": action(d.id)
        "teleport": hero.position = Vector3(d.x, 0.12, d.z); partner.position = hero.position + Vector3(0.8, 0, 0.5); reset_follow_path()
        "cook": stage = 1; state = "cook"; orders = 0; order_time = 8; order_wait = 0
        "battle": wild_battle = false; rival = story_rival; stage = 2; begin_battle()
        "intro": start_intro()
        "stage": stage = int(d.stage); update_target()
        "turn": hero.rotation.y = float(d.angle); partner.rotation.y = float(d.angle)
        "grass_setup": encounter_grace = 0; encounter_at = 1.0; grass_steps = 0
        "wild": meet_wild()
        "hair_view":
            start_intro(); intro_page = 1; set_intro_scene(); qa_portrait = true; qa_portrait_elevation = float(d.get("elevation", 3))
            hero.rotation.y = float(d.angle); partner.rotation.y = float(d.angle); hud.visible = false; set_camera(1, true)
        "freeze": qa_freeze = bool(d.value)
        "enemy_health": battle_hp = int(d.health)
        "funds": coins = int(d.coins)
        "wild_type":
            if wild_battle: rival.visible = false
            wild_index = int(d.index); rival = creatures[wild_index]; rival.visible = true
        "battle_health": health = clampi(int(d.health), 0, PARTY_HP)
        "city":
            tour.store_current(); tour.unlocked = 9; tour.apply_city(int(d.index)); state = "explore"; update_target()
        "mission_at":
            hero.position = tour.v(city().points[int(d.index)]); partner.position = hero.position + Vector3(0.6, 0, 0); reset_follow_path()
        "mission": tour.interact_mission()
        "tide": game_time = 0 if d.low else 5
        "tour_snapshot": pass


        "photo": stage = 3; update_target(); dialogue_next = "photo"; finish_dialogue()
        "title": state = "title"
    var data = { "city": city_index, "city_name": city().name, "mission": tour.record(), "completed": tour.completed, "unlocked": tour.unlocked, "intent": battle_intent, "enemy_guard": battle_enemy_guard, "fog": battle_fog, "party_max": PARTY_HP, "meal": tour.meal, "intro_page": intro_page, "tutorial_page": tutorial_page, "tutorial_seen": tutorial_seen, "partner_x": partner.position.x, "partner_z": partner.position.z, "partner_walkable": world.can_walk(partner.position), "follow_points": follow_path.size(), "wild": wild_battle, "wild_wins": wild_wins, "wild_seen": wild_seen, "grass_steps": grass_steps, "grace": encounter_grace, "camera_size": camera.size, "faded": world.faded_count, "hidden": world.hidden_people, "in_grass": world.in_grass(hero.position), "state": state, "stage": stage, "coins": coins, "orders": orders, "health": health, "boss": battle_hp, "phase": battle_phase, "menu": battle_menu, "turn": battle_turn, "energy": battle_energy, "berries": battle_berries, "enemy_max": battle_max_hp, "heavy": enemy_heavy(), "phase_time": battle_phase_time, "volley_hits": battle_volley_hits, "solo": true, "enemy_name": WILD_NAMES[wild_index] if wild_battle else city().boss.name, "impact_left": battle_fx_left, "impact_kind": battle_fx_kind, "impact_amount": battle_fx_amount, "hitstop": battle_hitstop, "battle_visual": "pixel", "reward": battle_reward, "collected": collected, "level": level, "xp": xp, "pets": pets.size(), "pet_active": pet_active, "x": hero.position.x, "z": hero.position.z, "time": game_time, "save_ok": save_ok, "fps": Engine.get_frames_per_second(), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "width": hud.w, "height": hud.h, "buttons": {}}
    for key in hud.buttons:
        var rect = hud.buttons[key]
        data.buttons[key] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
    JavaScriptBridge.eval("window.parisState=" + JSON.stringify(data))

func tour_smoke_test() -> void:
    var test = load("res://scripts/tour_checks.gd").new()
    await test.run(self)
