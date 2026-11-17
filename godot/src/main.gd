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
const LEVEL_MAX = 40
# ── 난이도 상수 (tools 의 시뮬레이터로 맞춘 값) ──
const BOSS_HP = 120.0
const BOSS_GROW = 1.31
const HIT_GROW = 1.15
var pets: Array = []          # {"c": 도시, "i": 종류 0~2, "lv": 친밀도}
var pet_active = -1          # (구버전 세이브 호환용)
var pet_team: Array = []      # 함께 걷는 친구들 — pets 의 인덱스, 최대 3
var pet_spots: Array = []     # 2D 화면에서 각 친구의 위치
var trail: Array = []         # 동훈이 지나온 길 (친구들이 따라 걷는다)
var pet_node: Node3D = null
var pet_path: Array = []
# 몸통은 세 가지(유령형/짐승형/마임형)뿐이라 종류별로 역할을 나눈다
const PET_ROLE = [
    { "key": "energy", "tag": "기력", "desc": "대결을 기력 1칸으로 시작해요" },
    { "key": "dish", "tag": "설거지", "desc": "설거지 연타가 한 대마다 강해져요" },
    { "key": "care", "tag": "회복", "desc": "야근 버티기와 뽀뽀사탕 회복이 늘어요" },
    { "key": "legend", "tag": "전설", "desc": "기력·설거지·회복을 모두 올려 줘요" },
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
    { "id": "k0", "slot": 3, "tier": 0, "name": "빈 싱크대", "line": "아직 소품이 없어요", "cost": 0},
    { "id": "k1", "slot": 0, "icon": "slot3", "tier": 1, "name": "양은 냄비", "line": "냄비 불리기 피해 +15%", "cost": 180, "soak": 15},
    { "id": "k2", "slot": 0, "icon": "slot3", "tier": 2, "name": "무쇠 가마솥", "line": "냄비 불리기 +30% · 최대 체력 +6", "cost": 520, "soak": 30, "hp": 6},
    { "id": "k3", "slot": 0, "icon": "slot3", "tier": 3, "name": "전설의 압력밥솥", "line": "냄비 불리기 +50% · 한 턴 만에 터져요", "cost": 1150, "soak": 50, "fuse": 1},
    { "id": "k4", "slot": 3, "tier": 4, "name": "대용량 퐁퐁", "line": "퐁퐁 효과 +20% · 한 턴 더 미끄러워요", "cost": 320, "soap": 20},
    { "id": "k5", "slot": 3, "tier": 5, "name": "보온 텀블러", "line": "대결을 기력 +1칸으로 시작", "cost": 360, "en": 1},
    { "id": "k6", "slot": 3, "tier": 6, "name": "행운의 로또 용지", "line": "치명타 확률 +15%", "cost": 450, "crit": 15},
    { "id": "g4", "slot": 0, "tier": 3, "cycle": 1, "name": "신화의 수세미", "line": "설거지 연타 +7 · 2회차 전용", "cost": 2600, "atk": 7},
    { "id": "k7", "slot": 0, "icon": "slot3", "tier": 3, "cycle": 1, "name": "신화의 무쇠솥", "line": "냄비 불리기 +60% · 한 턴 만에 폭발 · 2회차 전용", "cost": 2800, "soak": 60, "fuse": 1},
    { "id": "a4", "slot": 1, "tier": 3, "cycle": 1, "name": "신화의 앞치마", "line": "최대 체력 +55 · 회복 +5 · 2회차 전용", "cost": 2600, "hp": 55, "heal": 5},
    { "id": "s4", "slot": 2, "tier": 3, "cycle": 1, "name": "구름 슬리퍼", "line": "이동 속도 +45% · 최대 체력 +12 · 2회차 전용", "cost": 2400, "spd": 45, "hp": 12},
]
const SLOT_NAME = ["무기 (수세미 · 냄비)", "옷", "신발", "부엌 소품"]
# ── 강화: 여행비와 강화석으로 장비를 +5 까지 올린다 (한 단계마다 효과 +20%) ──
const ENHANCE_MAX = 5
const ENHANCE_RATE = [100, 90, 75, 60, 45]
var gear_lv: Dictionary = {}
var stones = 0
# ── 2회차부터 상대에게 붙는 특성 ──
const TRAITS = {
    "": { "name": "", "line": ""},
    "hard": { "name": "단단한 ", "line": "단단함: 수세미 피해 40% 감소 — 냄비로 터뜨려요"},
    "lid": { "name": "뚜껑 덮은 ", "line": "뚜껑: 냄비 폭발 40% 감소 — 수세미로 두드려요"},
    "rage": { "name": "성난 ", "line": "분노: 체력이 절반 아래면 피해 +40%"},
    "regen": { "name": "되살아나는 ", "line": "재생: 턴마다 체력 4% 회복"},
}
var battle_trait = ""
var boss_phase = 0              # 2회차 라이벌은 한 번 쓰러지면 각성해서 다시 일어난다
var auto_battle = false         # 도전의 탑: 알아서 싸우고 올라간다
var auto_wait = 0.0
# 2회차부터의 이야기 — 기억이 돌아온 뒤 같은 도시를 다시 걷는다
const CYCLE_TALK = [
    { "meet": [["피에르", "돌아왔군! 기억을 찾은 남편의 설거지, 얼마나 달라졌는지 보자."], ["동훈", "이번엔 소현이가 시켜서 온 게 아니야. 내가 하고 싶어서 왔어."]], "win": [["소피", "피에르, 봤지? 저 사람은 이제 미루지 않아."], ["동훈", "첫 집 싱크대, 기억나. 그날처럼 오늘도 내가 할게."]], "shard": [["새 일기", "같은 강가에 다시 섰다. 이번엔 지우지 않고 보냈다. “미안해. 그리고 고마워.”"], ["소현", "문자 왔네. …옆에 있으면서 뭘 보내."]]},
    { "meet": [["켄지", "막차를 놓치지 않는 법을 배웠다더군. 증명해 보게."], ["동훈", "오늘은 라면이 불기 전에 들어갈 거예요."]], "win": [["유키", "등불을 끄지 않길 잘했네요. 두 분도요."], ["동훈", "새벽 두 시 말고, 저녁 일곱 시에 같이 먹자."]], "shard": [["새 일기", "“오늘은 일곱 시에 퇴근했다. 라면은 둘이 끓였다. 불지 않았다.”"], ["소현", "불지 않은 라면은 처음이네."]]},
    { "meet": [["아흐메드", "말을 아끼던 자네가 말을 배웠다지. 지팡이 없이 겨뤄 보세."], ["동훈", "미안하다는 말, 이제 목에 안 걸려요."]], "win": [["라일라", "당신도 좀 배워요, 아흐메드."], ["동훈", "소현아, 오늘 고마워. 내일도 말할게."]], "shard": [["새 일기", "“오늘은 세 번 말했다. 고마워, 미안해, 그리고 한 번은 그냥 불렀다.”"], ["소현", "세 번째가 제일 좋았어."]]},
    { "meet": [["마르코", "방패 뒤에 숨지 않는 남자가 됐다고? 그럼 정면으로 와."], ["동훈", "수첩의 ‘나중에’는 다 지웠어. 이제 ‘오늘’만 남았지."]], "win": [["줄리아", "마르코, 우리도 수첩 하나 살까?"], ["동훈", "다음 장에는 네가 하고 싶은 걸 적어 줘."]], "shard": [["새 일기", "“수첩 뒷장이 모자라서 새로 샀다. 첫 줄은 소현이가 적었다 — 또 오기.”"], ["동훈", "‘또 오기’는 벌써 지워도 되겠다."]]},
    { "meet": [["과거의 동훈", "또 왔네. 이제 게임기는 안 들어?"], ["동훈", "들어. 근데 둘이서 해. 2인용으로."]], "win": [["과거의 동훈", "…그거 재밌겠다. 나도 그럴걸."], ["소현", "과거의 동훈 씨도 수고했어요. 덕분에 여기까지 왔으니까."]], "shard": [["새 일기", "“쓰러졌던 그 사무실 앞을 지나갔다. 이번엔 소현이 손을 내가 먼저 잡았다.”"], ["소현", "손에 땀 났었어."]]},
    { "meet": [["비요른", "양보다 아내를 먼저 세는 법, 자네도 익혔나?"], ["동훈", "별 보러 가는 길에 졸지 않는 법까지요."]], "win": [["아스타", "오로라는 매년 와요. 두 분도 매년 오세요."], ["동훈", "열 번째 줄 옆에 ‘매년’이라고 적을게."]], "shard": [["새 일기", "“‘언젠가’라고 쓰려다가 날짜를 적었다. 내년 2월 14일.”"], ["소현", "달력에 벌써 동그라미 쳤어."]]},
    { "meet": [["니코스", "석양보다 아내 얼굴을 보는 남자가 또 하나 늘었군."], ["동훈", "오늘은 카메라를 삼각대에 올려놨어요. 둘 다 나오게."]], "win": [["엘레니", "사진 속에서 둘이 웃고 있네요."], ["동훈", "사진첩 첫 장을 바꿔야겠다."]], "shard": [["새 일기", "“사진첩에 내가 생겼다. 눈을 감았지만 소현이가 지우지 말라고 했다.”"], ["소현", "그게 제일 너 같아."]]},
    { "meet": [["올리버", "우산을 두 개 챙기는 사람이 됐다고 들었네."], ["동훈", "아니요. 여전히 하나예요. 대신 끝까지 같이 써요."]], "win": [["에밀리", "올리버, 우리도 하나만 쓸까요?"], ["동훈", "어깨 젖었다. 내 쪽으로 더 와."]], "shard": [["새 일기", "“비가 왔다. 회사에서 전화가 왔다. 안 받았다. 우산은 하나였다.”"], ["소현", "전화는 나중에 걸어도 돼. 지금은 걷자."]]},
    { "meet": [["잭", "넘어지는 걸 겁내지 않게 됐다며? 파도 앞에서 보자고."], ["동훈", "넘어지면 소현이가 웃어 주니까."]], "win": [["클로이", "잭, 너도 좀 넘어져 봐."], ["동훈", "나 아직도 진짜 못해. 근데 또 하자."]], "shard": [["새 일기", "“열한 번 넘어졌다. 열두 번째에 삼 초 섰다. 소현이가 박수를 쳤다.”"], ["소현", "삼 초가 아니라 사 초였어."]]},
    { "meet": [["내일의 동훈", "어제의 나, 왔어? 아침은 차렸고?"], ["동훈", "차렸어. 설거지도 했고. 이제 네가 지킬 차례야."]], "win": [["내일의 동훈", "알았어. 내일도, 모레도 내가 할게."], ["소현", "둘 다 같은 사람이면서 뭘 그렇게 다짐을 해."]], "shard": [["새 일기", "“마지막 장이 아니라 첫 장. 소현이에게 — 기억은 다 돌아왔고, 약속은 계속 늘어난다.”"], ["소현", "그럼 수첩 한 권 더 사야겠네."]]},
]
var gear_slot = 0               # 장비 화면에서 보고 있는 칸
# ── 전직 ───────────────────────────────────────────────
const JOB_LEVEL = 10
const JOBS = [
    { "names": ["평범한 남편", "평범한 남편", "평범한 남편"], "color": "788277"},
    { "names": ["설거지 장인", "식기세척의 달인", "식기세척의 신"], "color": "3f8fd0"},
    { "names": ["불림술사", "가마솥 마법사", "가마솥 대마법사"], "color": "8a5fc0"},
    { "names": ["야근 기사", "철야의 방패", "칼퇴의 수호자"], "color": "c9951a"},
]
# 차수마다 하나씩 늘어나는 패시브 (앞의 것은 그대로 남고, 수치 보너스는 차수만큼 곱해진다)
const JOB_PASSIVE = [
    [],
    ["설거지 한 대마다 +1 · 치명타 +10%", "치명타 피해 1.5배 → 1.8배", "설거지 연타가 한 대 늘어요"],
    ["냄비 불리기 피해 +15%", "냄비가 터지면 체력 5% 회복", "냄비가 한 턴 빨리 터져요"],
    ["최대 체력 +15 · 버티기 회복 +3", "버티기가 피해를 90% 막아요", "매 턴 체력을 3% 회복해요"],
]
# 차수마다 하나씩 생기는 직업 기술. need = 먼저 Lv.10 까지 마스터해야 하는 기본 기술
const JOB_SKILLS = [
    [],
    [
        { "name": "식기세척기 풀가동", "need": "strike", "energy": 2, "kind": "volley", "line": "수세미 5연타"},
        { "name": "스팀 살균", "need": "soap", "energy": 2, "kind": "blast", "line": "큰 피해 · 3턴 미끌 · 방어 무시"},
        { "name": "주방 대청소", "need": "coffee", "energy": 3, "kind": "volley", "line": "8연타 · 전부 치명타"},
    ],
    [
        { "name": "압력솥 대폭발", "need": "soak", "energy": 2, "kind": "blast", "line": "불려 둔 냄비까지 즉시 폭발"},
        { "name": "이중 불림", "need": "soap", "energy": 2, "kind": "arm", "line": "두 배로 터지는 냄비를 불린다"},
        { "name": "천년 누룽지", "need": "coffee", "energy": 3, "kind": "blast", "line": "방어를 뚫는 초대형 폭발"},
    ],
    [
        { "name": "칼퇴 선언", "need": "guard", "energy": 2, "kind": "ward", "line": "반격을 막고 되돌려준다"},
        { "name": "연차 사용", "need": "coffee", "energy": 2, "kind": "heal", "line": "체력 절반 회복 · 기력 +1"},
        { "name": "정시 퇴근 결계", "need": "team", "energy": 3, "kind": "ward", "line": "2턴 동안 막고 되돌려준다"},
    ],
]
var ult_index = 0               # 고른 직업 기술 (0~2)
var ward_turns = 0              # 반격을 되돌리는 남은 턴
var bomb_mul = 1.0              # 이중 불림: 다음 폭발 배율
var job = 0
var battle_reflect = false      # 칼퇴 선언: 이번 반격을 되돌려준다
var volley_total = 3            # 이번 연타가 몇 대인가
# ── 전설의 괴물 — 도시마다 한 마리, 자연 구역 깊은 곳에 잠들어 있다 ──
const LEGENDS = [
    { "name": "노트르담의 가고일", "attack": "돌 날개 내려찍기", "line": "천 년 동안 빗물받이였던 석상이 눈을 떴다."},
    { "name": "천년 구미호", "attack": "아홉 꼬리 휘몰이", "line": "대나무 사이로 아홉 개의 꼬리가 일렁인다."},
    { "name": "잠들지 않는 스핑크스", "attack": "모래 수수께끼", "line": "“설거지는 누가 하는가?” 대답할 틈도 없이 덤벼든다."},
    { "name": "케르베로스", "attack": "세 머리 물어뜯기", "line": "옛 가도를 지키던 세 머리의 개가 길을 막는다."},
    { "name": "하수구의 악어왕", "attack": "왕관 박치기", "line": "공원 호수 밑에서 왕관을 쓴 악어가 올라왔다."},
    { "name": "서리 거인", "attack": "빙하 주먹", "line": "빙하가 일어서더니 사람의 모양이 되었다."},
    { "name": "에게해의 크라켄", "attack": "여덟 다리 조르기", "line": "잔잔하던 바다에서 보랏빛 다리가 솟아오른다."},
    { "name": "템스의 네시", "attack": "긴 목 채찍", "line": "안개 낀 강에서 중절모를 쓴 긴 목이 올라왔다."},
    { "name": "무지개뱀", "attack": "일곱 빛깔 조이기", "line": "숲의 개울이 통째로 몸을 일으킨다."},
    { "name": "광화문의 해태", "attack": "정의의 박치기", "line": "“약속을 미룬 자, 내 앞을 지나갈 수 없다.”"},
]
var legend_battle = false
# ── 심부름: 골목 주민의 물건을 찾아 주면 자연 구역에서 쓸 도구를 빌려준다 ──
# ride = true 인 도시는 그 도구를 타고 강을 건넌다
const ERRANDS = [
    { "who": "골목의 화가", "lost": "붓통", "tool": "곰솥", "ride": true, "ask": "붓통을 골목 어딘가에 떨어뜨렸지 뭐예요. 찾아 주면 국 끓이던 곰솥을 빌려드릴게요. 센강은 그걸 타고 건너는 거랍니다.", "use": ""},
    { "who": "찻집 할머니", "lost": "찻잔", "tool": "큰 가마솥", "ride": true, "ask": "아끼는 찻잔이 안 보여요. 찾아 주면 가마솥을 내줄게요. 대나무 숲 개울은 다리가 떠내려가서 그걸 타야 건너요.", "use": ""},
    { "who": "향신료 상인", "lost": "저울추", "tool": "지렛대", "ride": false, "ask": "저울추가 굴러가 버렸소. 찾아 주면 지렛대를 빌려주리다. 오아시스의 돌은 맨손으론 못 들지.", "use": "지렛대를 끼워 돌을 들어 올렸다. 눌려 있던 종이가 나왔다!"},
    { "who": "젤라또 가게 주인", "lost": "젤라또 스쿱", "tool": "사다리", "ride": false, "ask": "스쿱이 없어서 장사를 못 해요. 찾아 주면 사다리를 빌려줄게요. 올리브 나무는 높아서 그냥은 안 닿아요.", "use": "사다리를 세우고 올라가 가지에 걸린 종이를 떼어 냈다!"},
    { "who": "핫도그 아저씨", "lost": "머스터드 통", "tool": "긴 집게", "ride": false, "ask": "머스터드 통을 어디 뒀더라… 찾아 주면 긴 집게를 빌려주지. 벤치 밑은 손이 안 들어가.", "use": "긴 집게를 벤치 밑으로 밀어 넣어 구겨진 종이를 꺼냈다!"},
    { "who": "어부", "lost": "털장갑", "tool": "끓는 주전자", "ride": false, "ask": "털장갑 한 짝이 없어졌어. 찾아 주면 주전자에 물을 끓여 주지. 얼어붙은 건 녹여야 떼지.", "use": "끓는 물을 조금씩 부었다. 얼음이 녹으며 종이가 떨어졌다!"},
    { "who": "당나귀 몰이꾼", "lost": "당나귀 방울", "tool": "뜰채", "ride": false, "ask": "당나귀 방울이 떨어졌어. 찾아 주면 뜰채를 빌려줄게. 파도에 떠다니는 건 그걸로 건져야 해.", "use": "뜰채를 뻗어 파도에 떠밀리던 유리병을 건져 올렸다!"},
    { "who": "펍 주인", "lost": "병따개", "tool": "양철 욕조", "ride": true, "ask": "병따개가 없으면 가게를 못 열어. 찾아 주면 뒷마당 양철 욕조를 빌려주지. 템스강은 그걸 타고 건너.", "use": ""},
    { "who": "서핑 가게 점원", "lost": "서핑 왁스", "tool": "아이스박스", "ride": true, "ask": "왁스를 잃어버렸어요. 찾아 주면 큰 아이스박스를 빌려드릴게요. 숲 개울은 그걸 타면 건너요.", "use": ""},
    { "who": "분식집 이모", "lost": "국자", "tool": "보관함 열쇠", "ride": false, "ask": "국자가 어디 갔나 몰라. 찾아 주면 공원 분실물 보관함 열쇠를 줄게. 벤치에 있던 메모지는 누가 거기 넣어 놨대.", "use": "보관함을 열자 병원 메모지 한 장이 나왔다!"},
]
var ride_t = -1.0               # 0~1: 강을 건너는 중
var ride_from = Vector3.ZERO
var ride_to = Vector3.ZERO
var tower_battle = false        # 도전의 탑: 끝없이 강해지는 연속 대결
var tower_floor = 1
var tower_best = 0
var pet_page = 0
var cycle = 0                   # 몇 회차인가 (0 = 첫 여행)
# ── 소리 ───────────────────────────────────────────────
var bgm: AudioStreamPlayer
var bgm_name = ""
var sfx_pool: Array = []
var sfx_next = 0
var sounds: Dictionary = {}
var step_tick = 0
# ── 손맛 ───────────────────────────────────────────────
var shake = 0.0
var pops: Array = []            # 떠오르는 숫자 {"t","side","age","big","color"}
var win_time = 0.0
const ITEMS = [
    { "id": "candy", "name": "뽀뽀사탕", "line": "대결에서 체력을 회복해요", "cost": 40, "cap": 9},
    { "id": "drink", "name": "기력 드링크", "line": "다음 대결을 기력 1칸으로 시작", "cost": 70, "cap": 5},
    { "id": "treat", "name": "펫 간식", "line": "동행의 친밀도를 1 올려요", "cost": 90, "cap": 5},
    { "id": "film", "name": "기념 필름", "line": "추억 사진 보상 +30원", "cost": 110, "cap": 9},
]
var owned_gear: Array = ["g0", "a0", "s0", "k0"]
var equipped: Array = ["g0", "a0", "s0", "k0"]
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
const TIER_NAME = ["", "숙련", "달인", "전설"]
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
# 숨은 발견 — 도시마다 중심가 / 골목 / 자연 구역에 하나씩
const EGGS = [
    [["비둘기 둥지", "둥지 속에 누가 흘린 동전이 반짝인다."], ["화가의 낡은 팔레트", "팔레트 밑에 간식 꾸러미가 숨겨져 있다."], ["센강의 사랑 자물쇠", "“동훈♥소현 — 다음엔 꼭 같이.” 언제 걸어 둔 걸까?"]],
    [["동전 던지는 석등", "석등 구멍에 동전이 가득하다. 하나쯤은 괜찮겠지."], ["길고양이의 선물", "고양이가 물어다 놓은 간식 봉지."], ["소원 대나무 쪽지", "“야근 없는 금요일.” 동훈의 글씨다."]],
    [["모래 속 항아리", "항아리에서 옛 동전이 쏟아진다."], ["상인의 덤", "“단골에게만 주는 거요.” 향신료 대신 간식을 받았다."], ["오아시스의 병 편지", "“다음엔 낙타 타자.” 소현의 글씨다."]],
    [["흘린 분수 동전", "분수까지 닿지 못한 동전들이 여기 모여 있다."], ["할머니의 창가", "창가에서 떨어진 비스코티 한 봉지."], ["길가의 옛 주화", "이천 년 전 병사가 흘린 주화. 행운의 부적으로 삼자."]],
    [["소화전 뒤 지갑", "주인은 못 찾았지만 사례금 쪽지가 들어 있다."], ["길거리 농구 내기", "공을 한 번 넣었더니 간식을 준다."], ["공원 벤치의 이름표", "“여기서 프러포즈할 뻔함 — D.” …뻔함?"]],
    [["어부의 통발", "통발 속에 물고기 대신 동전이 들어 있다."], ["훈제 가게의 덤", "따뜻한 간식 꾸러미를 받았다."], ["얼음 속 반지 상자", "빈 상자다. 반지는 지금 소현의 손에 있다."]],
    [["당나귀 방울", "방울 속에서 동전 소리가 난다."], ["할아버지의 올리브", "“멀리서 왔구먼.” 간식을 한 움큼 쥐여 준다."], ["석양 엽서", "“다음엔 둘이 같이 나오게 찍자.” 부치지 못한 엽서."]],
    [["우체통 밑", "왕관이 새겨진 동전 몇 닢."], ["펍의 다트 판", "과녁 한가운데를 맞혔더니 간식이 나온다."], ["강변의 낡은 우산", "손잡이에 ‘J.D.H’ 이니셜이 새겨져 있다."]],
    [["서퍼의 왁스 통", "왁스 통 안에 비상금이 숨겨져 있다."], ["시장 할머니의 덤", "“신혼이야?” 간식을 얹어 준다."], ["코알라의 나무", "나무 틈에 ‘D+S’가 새겨져 있다. 낯익은 솜씨다."]],
    [["붕어빵 봉지", "봉지 밑에 거스름돈이 그대로 있다."], ["포장마차 이모의 서비스", "“많이 먹어.” 간식이 한가득."], ["한강 벤치의 낙서", "“여기서 처음 손잡음.” 날짜가 십 년 전이다."]],
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
var encounter_at = 11.0
var encounter_grace = 6.0
var move_axis = 0               # 0 멈춤 · 1 좌우 · 2 상하
var look_lead = Vector2.ZERO
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
    bgm = AudioStreamPlayer.new(); bgm.volume_db = -13; add_child(bgm)
    for i in range(4):
        var voice = AudioStreamPlayer.new(); voice.volume_db = -7; add_child(voice); sfx_pool.append(voice)
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
    for id in equipped:
        var base = int(gear_of(id).get(key, 0))
        # 강화 한 단계마다 +20% (기력·도화선 같은 개수형 효과는 그대로)
        total += base if key in ["fuse", "en"] else int(ceil(base * (1.0 + 0.2 * enhance_lv(String(id)))))
    return total

func enhance_lv(id: String) -> int:
    return clampi(int(gear_lv.get(id, 0)), 0, ENHANCE_MAX)

func enhance_cost(id: String) -> int:
    return (enhance_lv(id) + 1) * 120 + int(gear_of(id).tier) * 60

func enhance_stones(id: String) -> int:
    return enhance_lv(id) + 1

func enhance(id: String) -> void:
    if not owned_gear.has(id) or enhance_lv(id) >= ENHANCE_MAX: return
    if coins < enhance_cost(id): toast("강화하려면 " + str(enhance_cost(id)) + "원이 필요해요."); return
    if stones < enhance_stones(id): toast("강화석이 " + str(enhance_stones(id) - stones) + "개 모자라요. 등급 높은 상대나 도전의 탑에서 얻어요."); return
    var chance = ENHANCE_RATE[enhance_lv(id)]
    coins -= enhance_cost(id); stones -= enhance_stones(id)
    if randi_range(1, 100) <= chance:
        gear_lv[id] = enhance_lv(id) + 1
        sfx("job"); flash = 0.5
        toast(String(gear_of(id).name) + " +" + str(enhance_lv(id)) + " 강화 성공!  효과 +" + str(enhance_lv(id) * 20) + "%")
    else:
        sfx("bad"); toast("강화 실패… 장비는 그대로예요. (성공 확률 " + str(chance) + "%)")
    PARTY_HP = party_max(); health = mini(health, PARTY_HP); save_progress()

func gain_stones(n: int) -> void:
    if n > 0: stones = mini(999, stones + n)

# 동행 칸: 도장을 모을수록 늘어난다 (3칸 → 최대 6칸)
func team_max() -> int:
    return mini(6, 3 + int(power_stamps() / 5) + (1 if cycle >= 2 else 0))

func slot_gear(slot: int) -> Dictionary:
    return gear_of(String(equipped[clampi(slot, 0, 3)]))

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
    return 36 + power_stamps() * 3 + (level - 1) * 2 + gear_sum("hp") + souvenirs() * 3 + (15 * job_rank() if job == 3 else 0)

# 전직은 레벨 10부터. 레벨 20에 2차, 레벨 30에 3차로 저절로 오른다
func job_rank() -> int:
    if job == 0: return 0
    return 3 if level >= 30 else (2 if level >= 20 else 1)

func job_name() -> String:
    return String(JOBS[job].names[maxi(0, job_rank() - 1)])

func ult_info(i: int = -1) -> Dictionary:
    return JOB_SKILLS[job][clampi(ult_index if i < 0 else i, 0, 2)]

# 직업 기술은 그 차수에 오르고, 연결된 기본 기술을 마스터해야 열린다
func ult_open(i: int) -> bool:
    return job > 0 and job_rank() > i and sk(String(ult_info(i).need)) >= SKILL_MAX

func ult_lock(i: int) -> String:
    if job_rank() <= i: return str(i + 1) + "차 전직 (Lv." + str((i + 1) * 10) + ") 필요"
    return String(skill_of(String(ult_info(i).need)).name) + " Lv.10 필요"

func ult_kind() -> String:
    return String(ult_info().kind) if battle_choice == "ult" and job > 0 else ""

func crit_mul() -> float:
    return 1.8 if job == 1 and job_rank() >= 2 else 1.5

func pick_job(index: int) -> void:
    if index < 1 or index > 3 or index == job or level < JOB_LEVEL: return
    if job > 0:
        if coins < 200: toast("직업을 바꾸려면 200원이 필요해요."); return
        coins -= 200
    job = index
    PARTY_HP = party_max(); health = PARTY_HP
    sfx("job"); flash = 0.8; save_progress()
    toast(job_name() + "(으)로 전직했어요!  직업 기술 「" + String(ult_info(0).name) + "」은 " + String(skill_of(String(ult_info(0).need)).name) + "을(를) 마스터하면 열려요.")

# 기술 레벨 1~3 / 4~6 / 7~9 / 10 — 단계가 오르면 이펙트가 달라진다
func tier(id: String) -> int:
    var lv = sk(id)
    return 3 if lv >= 10 else (2 if lv >= 7 else (1 if lv >= 4 else 0))

func strike_hits() -> int:
    return (4 if sk("strike") >= SKILL_MAX else 3) + (1 if job == 1 and job_rank() >= 3 else 0)

func crit_rate() -> float:
    return (8 + gear_sum("crit") + (10 if job == 1 else 0)) / 100.0

# 회차가 오를수록 상대가 강해진다
# 상대 체력·피해 배율. 1회차는 도시마다 가파르게, 2회차부터는 높은 데서 시작해 완만하게 오른다
# (2회차에는 내 레벨이 조금씩만 오르기 때문)
func foe_hp_scale() -> float:
    if cycle == 0: return pow(BOSS_GROW, route_pos())
    return pow(BOSS_GROW, 5.5 + cycle) * pow(1.13, route_pos())

func foe_hit_scale() -> float:
    if cycle == 0: return pow(HIT_GROW, route_pos())
    return pow(HIT_GROW, 5.5 + cycle) * pow(1.06, route_pos())

func cycle_mul(per: float) -> float:
    return 1.0 + cycle * per

# 직업 기술 한 방(연타는 한 대)의 피해
func ult_damage() -> int:
    if job == 2: return int(soak_damage() * (1.3 if ult_index == 2 else 0.5))
    if ult_index == 1: return int((dish_base(0) + dish_base(1) + dish_base(2)) * 2.5)
    return int((dish_base(1) + job_rank()) * (1.25 if ult_index == 2 else 1.0))

func stamps() -> int:
    return tour.completed.count(true)

# 짝수 번째 여행(2·4회차…)은 서울에서 파리로 거꾸로 돈다.
# 난이도와 보상은 도시 번호가 아니라 '몇 번째 도시인가'를 따른다.
func reversed_route() -> bool:
    return cycle % 2 == 1

func route_pos(c: int = -1) -> int:
    var i = city_index if c < 0 else c
    return 9 - i if reversed_route() else i

func route_city(step: int) -> int:
    var at = clampi(step, 0, 9)
    return 9 - at if reversed_route() else at

# 지난 회차에 모은 도장도 힘으로 남는다
func power_stamps() -> int:
    return tour.completed.count(true) + cycle * 10

func dish_base(hit: int) -> int:
    return [3, 3, 2, 2, 2][clampi(hit, 0, 4)] + int(power_stamps() / 3) + int((level - 1) / 4) + int((pet_bonus("dish") + 1) / 2) + gear_sum("atk") + int(sk("strike") / 2) + (job_rank() if job == 1 else 0)

func guard_heal() -> int:
    return 3 + int(power_stamps() / 3) + pet_bonus("care") + (sk("guard") - 1) + (3 * job_rank() if job == 3 else 0)

func soak_damage() -> int:
    return int((dish_base(0) + dish_base(1) + dish_base(2)) * (1.0 + 0.09 * (sk("soak") - 1)) * (1.0 + gear_sum("soak") / 100.0 + (0.15 * job_rank() if job == 2 else 0.0)))

func soap_mul() -> float:
    return 1.4 + 0.04 * (sk("soap") - 1) + gear_sum("soap") / 100.0

func coffee_mul() -> float:
    return 2.0 + 0.1 * (sk("coffee") - 1)

# 퐁퐁·커피 효과를 얹는다
func amp(damage: int) -> int:
    var value = float(damage)
    # 퐁퐁과 커피는 곱하지 않고 더한다 (둘을 겹쳐도 한 방에 끝나지 않게)
    var boost = 1.0
    if battle_vuln > 0: boost += soap_mul() - 1.0
    if battle_charge: boost += coffee_mul() - 1.0
    value *= boost
    return maxi(1, int(round(value)))

func pet() -> Dictionary:
    if pet_team.is_empty(): return {}
    return pets[int(pet_team[0])]

func pet_kind() -> int:
    var p = pet()
    if p.is_empty(): return 0
    return clampi(int(p.i), 0, 2)

func pet_power(p: Dictionary) -> int:
    if int(p.i) == 3: return 3
    return 1 + (1 if int(p.lv) >= 3 else 0) + (1 if int(p.get("g", 0)) >= 2 else 0)

func pet_bonus(key: String) -> int:
    var total = 0
    for index in pet_team:
        var p = pets[int(index)]
        if PET_ROLE[int(p.i)].key == key or int(p.i) == 3: total += pet_power(p)
    return total

func pet_art(p: Dictionary) -> String:
    if int(p.i) == 3: return "legend" + str(int(p.c))
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
        "strike": return "수세미 " + str(strike_hits()) + "연타 " + str(dish_base(0)) + "/" + str(dish_base(1)) + "/" + str(dish_base(2)) + " · 기력 +1" + ("" if sk("strike") >= SKILL_MAX else " · Lv.10에 4연타")
        "guard": return "피해 75% 감소 · 체력 +" + str(guard_heal()) + " · 기력 +1"
        "team": return "기력 3 + 40원 · " + str(salary_damage()) + " 피해 · 방어 무시"
        "soak": return "기력 1 · " + str(fuse_turns()) + "턴 뒤 " + str(soak_damage()) + " 피해 폭발"
        "soap": return "기력 1 · 2턴간 주는 피해 +" + str(int((soap_mul() - 1.0) * 100)) + "%"
        _: return "기력 +2 · 다음 공격 " + str(snappedf(coffee_mul(), 0.1)) + "배"

func fuse_turns() -> int:
    return 1 if gear_sum("fuse") > 0 or (job == 2 and job_rank() >= 3) else 2

func skill_up(id: String) -> void:
    if skill_points <= 0 or not skill_open(id) or sk(id) >= SKILL_MAX: return
    var before = tier(id)
    skill_points -= 1; skill_lv[id] = sk(id) + 1
    save_progress()
    if tier(id) > before:
        sfx("job"); flash = 0.5
        toast(String(skill_of(id).name) + " — " + TIER_NAME[tier(id)] + " 단계!  이펙트가 달라졌어요.  " + skill_line(id))
    else:
        sfx("good"); toast(String(skill_of(id).name) + " Lv." + str(sk(id)) + "!  " + skill_line(id))

# 지금 싸우는 상대가 어느 도시의 친구인가 (탑에서는 층마다 다른 도시)
func foe_city() -> int:
    return (tower_floor - 1) % 10 if tower_battle else city_index

func foe_title() -> String:
    return ("각성한 " if boss_phase == 1 else "") + String(TRAITS[battle_trait].name) + foe_name()

func wild_name() -> String:
    if tower_battle:
        return str(tower_floor) + "층 · " + String(LEGENDS[foe_city()].name if legend_battle else CityData.CITIES[foe_city()].mobs[wild_index].name)
    if legend_battle: return String(LEGENDS[city_index].name)
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
    var cap = Color(row[3]) if row[3] != "" else hair2
    if job > 0:
        cap = Color([["", "f4f4f4", "7a4fc0", "9aa4ad"], ["", "ffd84a", "3a2a6a", "ffcf3a"], ["", "8fe8ff", "ff7ad0", "fff2a8"]][job_rank() - 1][job])
        if armor == 0: top = Color(["", "dfeaf4", "6a4a9a", "6f7f8f"][job])
    return { "O": Color("2a1c18"), "S": skin, "G": glove, "H": hair2, "C": cap, "T": top, "D": Color(row[4]), "E": shoes}

func pet_name(p: Dictionary) -> String:
    if int(p.i) == 3: return String(LEGENDS[int(p.c)].name)
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
        sfx("levelup")
        var note = "레벨 " + str(level) + "! 기술 포인트 +" + str(gained)
        if job == 0 and level >= JOB_LEVEL and level - gained < JOB_LEVEL: note += " · 전직할 수 있어요! (내 정보 → 스텟)"
        for mark in [20, 30]:
            if job > 0 and level >= mark and level - gained < mark: note += " · " + job_name() + "(으)로 승급!"
        for entry in SKILLS:
            if int(entry.need) > level - gained and int(entry.need) <= level and int(entry.need) > 1: note += " · 새 기술 " + String(entry.name)
        toast(note)

func dish_damage(hit: int) -> int:
    var value = dish_base(hit)
    if battle_fog and hit < 2: value = maxi(1, value - 1)
    if battle_enemy_guard: value = maxi(1, int(ceil(value * 0.5)))
    if battle_trait == "hard": value = maxi(1, int(ceil(value * 0.6)))
    return amp(value)

func salary_damage() -> int:
    return 22 + power_stamps() * 2 + (level - 1) * 2 + gear_sum("atk") * 4 + (sk("team") - 1) * 4

func candy_heal() -> int:
    return 16 + power_stamps() + (level - 1) + pet_bonus("care") * 3 + gear_sum("heal") * 2 + (4 if battle_food == 3 else 0)

func refresh_intent() -> void:
    if city_index == 0:
        battle_intent = "heavy" if battle_turn % 3 == 0 else "attack"; spot_pot(); return
    var pattern = city().pattern
    var offset = 1 if not wild_battle and city_index in [4, 9] and battle_hp <= battle_max_hp / 2 else 0
    battle_intent = pattern[ (battle_turn - 1 + offset) % pattern.size()]
    spot_pot()

# 강한 상대는 불려 둔 냄비를 보면 엎으려 든다. 버티면 막을 수 있다.
func spot_pot() -> void:
    if battle_bomb <= 0 or battle_turn % 2 != 0: return
    if wild_battle and wild_grade == 0 and not legend_battle and cycle == 0: return
    battle_intent = "kick"

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
    shake = maxf(0, shake - dt * 26.0); win_time += dt
    for i in range(pops.size() - 1, -1, -1):
        pops[i].age += dt
        if pops[i].age > 1.0: pops.remove_at(i)
    update_bgm()
    if auto_battle: auto_tick(dt)
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
    elif state == "ride":
        ride_tick(dt)
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
        battle_tick(dt * (2.6 if auto_battle and tower_battle else 1.0))
        world.animate_person(hero, clock_time, 0.12)
        world.animate_person(partner, clock_time, 0.15)
        rival.get_node("Body").rotation.z = sin(clock_time * 2) * 0.04
    else:
        world.animate_person(hero, clock_time, 0)
        world.animate_person(partner, clock_time, 0)
    # 2D로 덮이는 화면에서는 3D 렌더링을 꺼서 배터리와 프레임을 아낀다 (사진·엔딩만 입체)
    var flat_now = hud.flat_backdrop() or state in ["battle", "battle_ready", "battle_won", "battle_lost", "puzzle", "photo", "ending", "passport", "journal"] or (state == "pause" and previous_state == "battle")
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
    # 한 번에 한 방향만: 더 많이 민 쪽으로만 걷는다 (대각선 근처에서 떨리지 않게 지금 방향을 조금 더 쳐 준다)
    if axis.length() < 0.12: move_axis = 0
    elif move_axis == 1 and absf(axis.y) > absf(axis.x) * 1.35: move_axis = 2
    elif move_axis == 2 and absf(axis.x) > absf(axis.y) * 1.35: move_axis = 1
    elif move_axis == 0: move_axis = 1 if absf(axis.x) >= absf(axis.y) else 2
    if move_axis == 1: axis = Vector2(signf(axis.x) * axis.length(), 0)
    elif move_axis == 2: axis = Vector2(0, signf(axis.y) * axis.length())
    # 2D 탑다운이라 스틱 방향이 곧 월드 방향이다
    var dir = Vector3(axis.x, 0, axis.y)
    # 스틱을 끝까지 밀면 달린다
    var want_run = clampf((axis.length() - 0.72) / 0.28, 0, 1)
    run_blend = lerpf(run_blend, want_run, minf(1, dt * 6))
    var top = 3.6 * (1.0 + 0.55 * run_blend) * speed_mul()
    # 즉시 최고속도가 아니라 붙었다 떨어진다 — 무게가 생긴다
    move_vel = move_vel.lerp(dir * top, minf(1, dt * (9.0 if dir.length() > 0.05 else 13.0)))
    if move_axis == 1: move_vel.z = 0.0
    elif move_axis == 2: move_vel.x = 0.0
    # 화면이 미리 보여 주는 쪽은 천천히 따라가게 한다 (방향을 바꿀 때 화면이 튀지 않도록)
    look_lead = look_lead.lerp(Vector2(move_vel.x, move_vel.z) * 0.25, minf(1, dt * 3.5))
    move_speed = clampf(move_vel.length() / 3.6, 0, 1.6)
    step_phase += dt * (6.5 + run_blend * 5.0) * minf(1.0, move_speed)
    if int(step_phase / PI) != step_tick:
        step_tick = int(step_phase / PI)
        if move_speed > 0.3: sfx("step", randf_range(0.85, 1.15))
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
        if errand() < 3 and not world.gate_to(1).is_empty():
            gate = world.gate_to(1)
            target = Vector3(gate.x, 0, gate.z); target_name = String(gate.label) + "에서 " + String(ERRANDS[city_index].tool) + " 빌리기"
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
    var info = ERRANDS[city_index]
    for extra in world.extras:
        if String(extra.t) == "shard" and not bool(rec.shard):
            target = Vector3(extra.x, 0, extra.z); target_name = "기억 조각"
            if errand() < 3:
                var out = world.gate_to(0)
                target = Vector3(out.x, 0, out.z); target_name = String(world.AREA_NAMES[city_index][0]) + "에서 " + String(info.tool) + " 빌려 오기"
            elif world.ferry.size() == 2:
                # 강 건너편에 있으면 먼저 나루터로
                var mid_z = (float(world.ferry[0].z) + float(world.ferry[1].z)) / 2.0
                if (hero.position.z < mid_z) != (float(extra.z) < mid_z):
                    var dock = world.ferry[0] if absf(hero.position.z - float(world.ferry[0].z)) < absf(hero.position.z - float(world.ferry[1].z)) else world.ferry[1]
                    target = Vector3(dock.x, 0, dock.z); target_name = "나루터에서 " + String(info.tool) + " 타기"
        if String(extra.t) == "npc" and errand() in [0, 2]:
            target = Vector3(extra.x, 0, extra.z); target_name = String(info.who) + ("에게 말 걸기" if errand() == 0 else "에게 " + String(info.lost) + " 돌려주기")
    if errand() == 1 and not world.lost.is_empty():
        target = Vector3(world.lost.x, 0, world.lost.z); target_name = "잃어버린 " + String(info.lost) + " 찾기"
    if target_name == "":
        var back = world.gate_to(0)
        target = Vector3(back.x, 0, back.z); target_name = String(back.label)
    world.marker.visible = state == "explore"; world.marker.position = target + Vector3(0, 0.2, 0)
    story_rival.visible = false

func near_egg() -> Dictionary:
    var rec = tour.record()
    for egg in world.eggs:
        if not bool(rec.eggs[int(egg.i)]) and hero.position.distance_to(Vector3(egg.x, hero.position.y, egg.z)) < 1.4: return egg
    return {}

# 자연 구역의 숨은 발견은 기념품이 되어 최대 체력을 올려 준다
func souvenirs() -> int:
    var count = 0
    for rec in tour.records:
        if bool(rec.get("eggs", [false, false, false])[2]): count += 1
    return count

func find_egg(egg: Dictionary) -> void:
    var i = clampi(int(egg.i), 0, 2)
    tour.record().eggs[i] = true
    sfx("egg"); burst(hero.position + Vector3(0, 0.8, 0), "fffbe0", 16)
    var prize = ""
    match i:
        0:
            coins += 100 + route_pos() * 30; prize = "여행비 " + str(100 + route_pos() * 30) + "원을 얻었어요!"
        1:
            bag_add("candy", 2); bag_add("treat", 1); prize = "뽀뽀사탕 2개와 펫 간식을 얻었어요!"
        _:
            PARTY_HP = party_max(); health = PARTY_HP; prize = "기념품으로 간직했어요. 최대 체력 +3 (기념품 " + str(souvenirs()) + " / 10)"
    save_progress()
    show_dialogue( [ ["숨은 발견 · " + String(EGGS[city_index][i][0]), String(EGGS[city_index][i][1])], ["소현", prize]], "explore")

func errand() -> int:
    return int(tour.record().get("errand", 0))

# 지금 서 있는 쪽에서 가장 가까운 나루터 번호 (-1 = 근처에 없음)
func near_dock() -> int:
    for i in range(world.ferry.size()):
        if hero.position.distance_to(Vector3(world.ferry[i].x, hero.position.y, world.ferry[i].z)) < 1.9: return i
    return -1

func near_lost() -> bool:
    return errand() == 1 and not world.lost.is_empty() and hero.position.distance_to(Vector3(world.lost.x, hero.position.y, world.lost.z)) < 1.7

func start_ride(from_dock: int) -> void:
    var info = ERRANDS[city_index]
    if errand() < 3:
        sfx("bad"); toast("다리가 없어서 건널 수 없어요. " + String(world.AREA_NAMES[city_index][0]) + "의 " + String(info.who) + "에게 방법을 물어봐요."); return
    var a = world.ferry[from_dock]
    var b = world.ferry[1 - from_dock]
    ride_from = Vector3(a.x, 0.1, a.z); ride_to = Vector3(b.x, 0.1, b.z)
    ride_t = 0.0; state = "ride"; joystick = Vector2.ZERO; hud.release_all(); move_vel = Vector3.ZERO; look_lead = Vector2.ZERO
    sfx("good"); toast_time = 0

func ride_tick(dt: float) -> void:
    ride_t += dt / 2.6
    var ease = clampf(ride_t, 0, 1)
    ease = ease * ease * (3.0 - 2.0 * ease)
    hero.position = ride_from.lerp(ride_to, ease); partner.position = hero.position
    if int(ride_t * 9.0) != int((ride_t - dt / 2.6) * 9.0): sfx("step", 0.6)
    if ride_t < 1.0: return
    ride_t = -1.0; state = "explore"
    var inward = (ride_to - ride_from).normalized() * 1.2
    hero.position = ride_to + inward if world.can_walk(ride_to + inward) else ride_to
    partner.position = hero.position
    for offset in [Vector3(0.8, 0, 0), Vector3(-0.8, 0, 0), Vector3(0, 0, 0.8), Vector3(0, 0, -0.8)]:
        if world.can_walk(hero.position + offset):
            partner.position = hero.position + offset; break
    reset_follow_path(); spawn_pet(); encounter_grace = 4.0; update_target()
    toast(String(ERRANDS[city_index].tool) + "에서 내렸어요. 돌아갈 때도 나루터에서 타면 돼요.")

# 골목 주민과의 심부름 대화. 끝났으면 false 를 돌려줘 평소 대화를 한다.
func errand_talk() -> bool:
    var info = ERRANDS[city_index]
    var rec = tour.record()
    match errand():
        0:
            rec["errand"] = 1; save_progress()
            show_dialogue( [ [String(info.who), String(info.ask)], ["소현", "우리가 찾아볼게요! 반짝이는 데를 살펴보자."]], "explore")
        1:
            show_dialogue( [ [String(info.who), String(info.lost) + "은(는) 아직인가요? 이 골목 구석 어딘가에서 반짝일 거예요."]], "explore")
        2:
            rec["errand"] = 3; coins += 50 + route_pos() * 20; sfx("chest"); save_progress()
            show_dialogue( [ [String(info.who), "오, 내 " + String(info.lost) + "! 고마워요. 약속대로 " + String(info.tool) + "을(를) 빌려줄게요. 수고비도 조금 넣었어요."], ["동훈", String(info.tool) + "… 이걸 들고 다니라고?"], ["소현", String(world.AREA_NAMES[city_index][1]) + "에 가서 써 보자!"]], "explore")
        _: return false
    return true

func near_legend() -> bool:
    if world.legend.is_empty() or bool(tour.record().get("legend", false)): return false
    return hero.position.distance_to(Vector3(world.legend.x, hero.position.y, world.legend.z)) < 2.3

func wake_legend() -> void:
    var info = LEGENDS[city_index]
    if not tour.completed[city_index] and cycle == 0:
        sfx("bad"); toast(String(info.name) + "이(가) 깊이 잠들어 있어요. 이 도시의 추억 사진을 남긴 뒤에 다시 와요."); return
    meet_wild(true)
    show_dialogue( [ ["전설 · " + String(info.name), String(info.line)], ["소현", "전설의 괴물이야! 지금까지 만난 누구보다 강해. 준비됐어?"], ["동훈", "냄비 불려 놓고, 퐁퐁 뿌리고… 할 수 있어."]], "battle_ready")

# 열 도시를 모두 마치면 더 강한 상대와 다시 여행할 수 있다
func start_cycle() -> void:
    if tour.completed.count(true) < 10: return
    if wild_battle: restore_from_wild()
    tour.store_current()
    cycle += 1; tour.next_cycle(); area_index = 0
    tour.apply_city(route_city(0)); tour.record().visited = true
    state = "explore"; sfx("job"); flash = 1.0; save_progress()
    toast(str(cycle + 1) + "회차 여행 시작! " + ("이번엔 서울에서 파리로 거꾸로 돌아요. " if reversed_route() else "") + "상대가 훨씬 강해졌어요.")

func near_gate() -> Dictionary:
    for gate in world.gates:
        if hero.position.distance_to(Vector3(gate.x, hero.position.y, gate.z)) < 1.8: return gate
    return {}

# 행동 버튼에 띄울 말 — 문이나 세부 구역의 물건 가까이에서만
func near_label() -> String:
    var gate = near_gate()
    if not gate.is_empty(): return String(gate.label) + " 가기"
    if not near_egg().is_empty(): return "살펴보기"
    if near_legend(): return "전설 깨우기"
    if near_lost(): return String(ERRANDS[city_index].lost) + " 줍기"
    if near_dock() >= 0: return String(ERRANDS[city_index].tool) + " 타고 건너기" if errand() >= 3 else "건널 방법 찾기"
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
    wild_battle = false; grass_steps = 0; encounter_grace = 5.0
    reset_follow_path()
    if zone == 0: tour.sync_props()
    state = "explore"; update_target(); set_camera(1, true); save_progress()
    toast( (String(city().name) + " 중심가") if zone == 0 else String(world.AREA_NAMES[city_index][zone - 1]) + " — 이곳의 야생 친구들은 더 강해요.")

func side_interact() -> void:
    var rec = tour.record()
    for chest in world.chests:
        var i = int(chest.i)
        if bool(rec.chests[i]) or hero.position.distance_to(Vector3(chest.x, hero.position.y, chest.z)) > 1.9: continue
        rec.chests[i] = true; sfx("chest"); burst(hero.position + Vector3(0, 0.8, 0), "f6d484", 14)
        match i:
            0:
                coins += 60 + route_pos() * 25; toast("상자에서 여행비 " + str(60 + route_pos() * 25) + "원을 찾았어요!")
            1:
                bag_add("candy", 2); bag_add("drink", 1); toast("상자에서 뽀뽀사탕 2개와 기력 드링크를 찾았어요!")
            2:
                coins += 90 + route_pos() * 30; toast("상자에서 여행비 " + str(90 + route_pos() * 30) + "원을 찾았어요!")
            _:
                skill_points += 1; gain_stones(2); toast("낡은 요령 수첩과 강화석 2개를 찾았어요!  기술 포인트 +1")
        update_target(); save_progress(); return
    for extra in world.extras:
        if hero.position.distance_to(Vector3(extra.x, hero.position.y, extra.z)) > 1.9: continue
        if String(extra.t) == "npc":
            if not errand_talk(): show_dialogue(NPC_TALK[city_index], "explore")
            return
        if not bool(rec.shard):
            var info = ERRANDS[city_index]
            if not bool(info.ride) and errand() < 3:
                sfx("bad"); toast("맨손으로는 꺼낼 수 없어요. " + String(world.AREA_NAMES[city_index][0]) + "의 " + String(info.who) + "에게 도구를 빌려 와요."); return
            rec.shard = true; chime(1318); save_progress()
            var lines = (CYCLE_TALK[city_index].shard if cycle >= 1 else SHARDS[city_index]).duplicate()
            if not bool(info.ride): lines.insert(0, ["소현", String(info.use)])
            show_dialogue(lines, "explore"); return
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
    var found = near_egg()
    if not found.is_empty():
        find_egg(found); return
    if near_legend():
        wake_legend(); return
    if near_lost():
        tour.record()["errand"] = 2; sfx("egg"); burst(hero.position + Vector3(0, 0.8, 0), "fffbe0", 12); save_progress(); update_target()
        toast(String(ERRANDS[city_index].lost) + "을(를) 찾았어요! " + String(ERRANDS[city_index].who) + "에게 돌려주러 가요."); return
    if near_dock() >= 0:
        start_ride(near_dock()); return
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
            if cycle >= 1:
                var again = CYCLE_TALK[city_index].meet.duplicate()
                again.append(["소현", "조심해. 한 번 쓰러뜨려도 각성해서 다시 일어난대."])
                show_dialogue(again, "battle_ready"); return
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
        sheet_tab = clampi(int(id.trim_prefix("tab_")), 0, 6); sfx("click"); return
    if id.begins_with("gearslot_"):
        gear_slot = clampi(int(id.trim_prefix("gearslot_")), 0, 3); sfx("click"); return
    if id.begins_with("job_"):
        pick_job(int(id.trim_prefix("job_"))); return
    if id.begins_with("skillup_"):
        skill_up(String(id.trim_prefix("skillup_"))); return
    if id.begins_with("shoptab_"):
        shop_tab = clampi(int(id.trim_prefix("shoptab_")), 0, 2); sfx("click"); return
    if id.begins_with("equip_"):
        equip_gear(String(id.trim_prefix("equip_"))); return
    if id.begins_with("enh_"):
        enhance(String(id.trim_prefix("enh_"))); return
    if id == "buystone":
        if coins < 150: toast("강화석은 150원이에요.")
        else:
            coins -= 150; gain_stones(1); sfx("coin"); save_progress(); toast("강화석 구입!  보유 " + str(stones) + "개")
        return
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
            if stage == 4 and route_pos() < 9: tour.travel(route_city(route_pos() + 1))
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
        "sound":
            sound_on = not sound_on; save_progress(); chime(660)
            if not sound_on:
                bgm.stop(); bgm_name = ""
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
        "ult0", "ult1", "ult2":
            if state == "battle" and battle_phase == "choose":
                ult_index = int(id.right(1)); choose_battle("ult")
        "jobs_menu":
            if state == "battle" and battle_phase == "choose": battle_menu = "job"
        "new_cycle": start_cycle()
        "openjobs": sheet_tab = 6; sfx("click")
        "petpage_prev": pet_page = maxi(0, pet_page - 1); sfx("click")
        "petpage_next": pet_page += 1; sfx("click")
        "tower_start": start_tower()
        "auto_toggle":
            if tower_battle: auto_battle = not auto_battle
            auto_wait = 0.2; sfx("click")
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
    state = "battle"
    # 도시가 넘어갈 때마다 체력 약 1.3배 — 레벨과 장비를 같이 올려야 따라갈 수 있다
    var boss_hp = BOSS_HP * foe_hp_scale()
    # 2회차부터(탑은 10층부터) 상대마다 특성이 하나 붙는다
    battle_trait = ""; boss_phase = 0
    if (cycle >= 1 and (wild_grade >= 1 or not wild_battle or legend_battle)) or (tower_battle and tower_floor >= 10):
        battle_trait = ["hard", "lid", "rage", "regen"][(city_index + wild_index + tower_floor + (0 if wild_battle else 2)) % 4 if not wild_battle or tower_battle else randi_range(0, 3)]
    if tower_battle: battle_max_hp = int(60.0 * pow(1.14, tower_floor) * (1.6 if legend_battle else 1.0))
    elif legend_battle: battle_max_hp = int(boss_hp * 1.4)
    elif wild_battle: battle_max_hp = int((34 + wild_index * 4) * foe_hp_scale() * float(GRADES[wild_grade].hp))
    else: battle_max_hp = int(boss_hp)
    battle_bomb = 0; battle_vuln = 0; battle_charge = false; battle_reflect = false; ward_turns = 0; bomb_mul = 1.0; pops.clear(); shake = 0
    battle_hp = battle_max_hp; health = PARTY_HP; perfects = 0; battle_hits = 0
    battle_turn = 1; battle_energy = mini(3, pet_bonus("energy") + next_energy + gear_sum("en")); battle_berries = bag_count("candy"); battle_guard = false
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
    if battle_intent == "kick": return "냄비 엎기 · 폭발 절반 (버티면 막아요)"
    if legend_battle:
        var move = String(LEGENDS[foe_city()].attack)
        return { "brace": "웅크리기 · 다음 피해 절반", "rest": "숨 고르기 · 반격 없음"}.get(battle_intent, ("분노의 " if enemy_heavy() else "") + move)
    if city_index == 0:
        if enemy_heavy(): return ["유령의 단체 야유", "빵 지키기 돌진", "보이지 않는 벽 밀기"][wild_index] if wild_battle else "바게트 풀스윙"
        return ["등골 오싹", "빵 내놔 쪼기", "투명 벽 밀기"][wild_index] if wild_battle else "바게트 휘두르기"
    var name = city().mobs[wild_index].attack if wild_battle else city().boss.attack
    return { "brace": "방어 자세 · 다음 피해 절반", "rest": "숨 고르기 · 반격 없음", "sand": "모래 끼얹기 · 추가 피해 2", "chill": "찬바람 · 기력 1 감소", "gust": "돌풍 · 기력 1 감소", "mist": "안개 · 다음 설거지 약화", "wave": "큰 파도 · 강공격", "rush": "돌진 · 강공격", "heavy": "힘껏 " + name}.get(battle_intent, name)

func enemy_damage() -> int:
    if battle_intent in ["brace", "rest"]: return 0
    var grow = foe_hit_scale()
    if tower_battle: return int(round((10.0 if enemy_heavy() else 5.0) * pow(1.07, tower_floor) * (1.25 if legend_battle else 1.0)))
    var base = int(round((13.0 if enemy_heavy() else 6.0) * grow))
    if battle_trait == "rage" and battle_hp * 2 < battle_max_hp: base = int(round(base * 1.4))
    if boss_phase == 1: base = int(round(base * 1.25))
    if legend_battle: base = int(round(base * 1.2))
    elif wild_battle: base = int(round((10.0 + wild_index if enemy_heavy() else 5.0 + wild_index * 0.5) * grow * float(GRADES[wild_grade].atk)))
    return base

func choose_battle(choice: String) -> void:

    if state != "battle" or battle_phase != "choose": return
    if choice == "team" and (battle_energy < 3 or coins < 40): return
    if choice == "heal" and (battle_berries <= 0 or health >= PARTY_HP): return
    if choice == "ult" and (not ult_open(ult_index) or battle_energy < int(ult_info().energy)): return
    if choice not in ["strike", "guard", "heal", "team", "soak", "soap", "coffee", "ult"]: return
    if choice in ["soak", "soap", "coffee"] and not skill_open(choice): return
    if choice in ["soak", "soap"] and battle_energy < 1: return
    if choice == "soak" and battle_bomb > 0: return
    if choice == "coffee" and battle_charge: return
    battle_choice = choice; battle_phase = "player"; battle_phase_time = 0; battle_menu = "main"
    battle_guard = choice == "guard" or battle_reflect; battle_hit_applied = false; battle_volley_hits = 0; battle_hitstop = 0; battle_fx_left = 0
    if choice == "team":
        battle_energy -= 3; coins -= 40; save_progress()
    if choice == "heal": battle_berries -= 1; bag_add("candy", -1)
    if choice in ["soak", "soap"]: battle_energy -= 1
    volley_total = strike_hits() if choice == "strike" else (8 if ult_index == 2 else 5)
    if choice == "ult":
        battle_energy -= int(ult_info().energy)
        if ult_kind() == "ward":
            battle_guard = true; battle_reflect = true; ward_turns = 2 if ult_index == 2 else 1
    battle_result = { "ult": "「" + (String(ult_info().name) if job > 0 else "") + "」!  " + job_name() + "의 직업 기술!", "strike": "설거지 연타! 수세미 " + str(strike_hits()) + "개, 갑니다!", "guard": "야근 버티기! 방어하면서 체력을 채워요.", "heal": "뽀뽀사탕! 동훈의 체력을 회복해요.", "team": "월급 박치기! 여행비 40원을 던졌다!", "soak": "냄비 불리기! 눌어붙은 냄비를 물에 담가 둔다…", "soap": "퐁퐁 뿌리기! 바닥이 미끌미끌해졌다!", "coffee": "커피 수혈! 눈이 번쩍 뜨인다!"}[choice]
    battle_quote = { "ult": [["", "", ""], ["헹굼까지 한 번에!", "건조는 자연 건조야!", "그릇이 뽀득뽀득!"], ["뜸 들일 시간 없어!", "김 빠진다, 물러서!", "밥 다 됐다!"], ["저 먼저 들어가 보겠습니다!", "내일 하겠습니다!", "여섯 시 정각입니다!"]][job], "strike": ["이 정도 설거지는 매일 해!", "퐁퐁 묻었다!", "손목 나가겠네…"], "guard": ["야근보단 낫지.", "버티는 건 자신 있어.", "새벽 세 시도 버텼어."], "team": ["이번 달 월급이다!", "카드값… 아니, 받아라!", "돈으로 되는 일도 있어!"], "heal": ["당 충전 완료!", "하나만 더 먹을까…", "조금 살 것 같다."], "soak": ["불려야 잘 닦여.", "지금은 건드리지 마.", "기다림도 기술이야."], "soap": ["한 방울이면 충분해.", "거품 조심해!", "미끄러우니까 뛰지 마."], "coffee": ["샷 추가요.", "이제 좀 살겠다.", "오늘 세 잔째야…"]}[choice][randi_range(0, 2)]
    hud.release_all(); chime(880 if choice in ["team", "ult"] else 540)

func battle_impact(kind: String, target_side: String, amount: int, crit: bool = false) -> void:
    battle_fx_kind = kind; battle_fx_target = target_side; battle_fx_amount = amount
    battle_fx_left = 0.65; battle_hitstop = (0.055 if kind == "sponge" else 0.09) if effects_on else 0
    var heavy = crit or kind in ["boom", "reflect"]
    if effects_on and kind not in ["heal", "buff"]: shake = maxf(shake, 13.0 if heavy else (4.0 if kind in ["sponge", "guard"] else 8.0))
    if heavy and effects_on: battle_hitstop = 0.13
    match kind:
        "heal": pop("+" + str(amount), target_side, "8fd96a")
        "buff": pop(battle_fx_note, target_side, "fff4cd")
        "guard":
            if amount > 0: pop("-" + str(amount), target_side, "bcd3dc")
            else: pop("버티기", target_side, "bcd3dc")
        _: pop(("치명타! -" if crit else "-") + str(amount), target_side, "ffd84a" if crit else ("ff8f7a" if target_side == "party" else "fff8e8"), heavy)
    if heavy:
        sfx("crit" if crit and kind not in ["boom", "reflect"] else "boom")
        if sound_on and OS.has_feature("android"): Input.vibrate_handheld(45)
        return
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

        var volley = battle_choice == "strike" or ult_kind() == "volley"
        var first = 0.38 if battle_choice == "strike" else 0.3
        var gap = 0.24 if battle_choice == "strike" else 0.15
        if volley:
            if battle_volley_hits < volley_total and battle_phase_time >= first + gap * battle_volley_hits and battle_hp > 0:
                var damage = dish_damage(battle_volley_hits)
                if battle_choice == "ult":
                    damage = ult_damage()
                    if battle_enemy_guard: damage = maxi(1, int(ceil(damage * 0.5)))
                    damage = amp(damage)
                var lucky = randf() < crit_rate() or (battle_choice == "ult" and ult_index == 2)
                if lucky: damage = int(ceil(damage * crit_mul()))
                battle_hp = maxi(0, battle_hp - damage); battle_volley_hits += 1; battle_hits += 1
                battle_result = (String(ult_info().name) + " " if battle_choice == "ult" else "설거지 연타 ") + str(battle_volley_hits) + "/" + str(volley_total) + "! " + ("치명타! " if lucky else "수세미 명중 · ") + str(damage) + " 피해"
                battle_impact("sponge", "enemy", damage, lucky)
                if battle_choice == "strike" and (battle_volley_hits == volley_total or battle_hp == 0): battle_energy = mini(3, battle_energy + 1)
        elif battle_phase_time >= (0.5 if battle_choice in ["team", "ult"] else 0.28) and not battle_hit_applied:
            battle_hit_applied = true
            if ult_kind() == "blast":
                var blast = amp(ult_damage())
                if job == 2 and ult_index == 0 and battle_bomb > 0:
                    blast += int(soak_damage() * bomb_mul); battle_bomb = 0; bomb_mul = 1.0
                if job == 1:
                    battle_vuln = 4; battle_enemy_guard = false
                battle_hp = maxi(0, battle_hp - blast); battle_hits += 1
                battle_result = String(ult_info().name) + "! " + str(blast) + " 피해!" + (" 상대가 3턴 동안 미끄러워해요." if job == 1 else "")
                battle_impact("boom", "enemy", blast)
            elif ult_kind() == "arm":
                bomb_mul = 2.0
                if battle_bomb == 0: battle_bomb = fuse_turns()
                battle_result = "이중 불림! 이번 냄비는 두 배(" + str(int(soak_damage() * 2)) + ")로 터져요."
                battle_fx_note = "두 배 불림!"; battle_impact("buff", "party", 0)
            elif ult_kind() == "heal":
                var day_off = mini(int(PARTY_HP * 0.5), PARTY_HP - health)
                health += day_off; battle_energy = mini(3, battle_energy + 1); battle_fog = false
                battle_result = "연차 사용! 체력 " + str(day_off) + " 회복 · 기력 +1"
                battle_impact("heal", "party", day_off)
            elif battle_choice == "ult":
                var rest = guard_heal() * 2
                health = mini(PARTY_HP, health + rest)
                battle_result = String(ult_info().name) + "! 체력 +" + str(rest) + " · " + str(ward_turns) + "턴 동안 반격을 그대로 돌려줘요."
                battle_fx_note = "칼퇴!"; battle_impact("buff", "party", 0)
            elif battle_choice == "team":
                var damage = amp(salary_damage())
                var lucky = randf() < crit_rate()
                if lucky: damage = int(ceil(damage * crit_mul()))
                battle_hp = maxi(0, battle_hp - damage); battle_hits += 1; perfects += 1
                battle_result = "월급 박치기! " + ("치명타! " if lucky else "") + str(damage) + " 피해. 아파요, 둘 다."
                battle_impact("money", "enemy", damage, lucky)
            elif battle_choice == "guard":
                var mend = guard_heal()
                battle_energy = mini(3, battle_energy + 1); health = mini(PARTY_HP, health + mend)
                battle_result = "야근 버티기! 체력 +" + str(mend) + " · 반격 피해 75% 감소"
                battle_impact("guard", "party", 0)
            elif battle_choice == "soak":
                battle_bomb = fuse_turns()
                battle_result = "냄비를 불려 뒀어요. " + str(fuse_turns()) + "턴 뒤에 " + str(soak_damage()) + " 피해로 터져요!"
                battle_fx_note = "불리는 중"; battle_impact("buff", "party", 0)
            elif battle_choice == "soap":
                battle_vuln = 3 + (1 if gear_sum("soap") > 0 else 0)
                battle_result = "상대가 미끄러워해요! " + str(battle_vuln - 1) + "턴 동안 주는 피해 +" + str(int((soap_mul() - 1.0) * 100)) + "%"
                battle_fx_note = "미끌!"; battle_impact("buff", "enemy", 0)
            elif battle_choice == "coffee":
                battle_charge = true; battle_energy = mini(3, battle_energy + 2)
                battle_result = "기력 +2! 다음 공격이 " + str(snappedf(coffee_mul(), 0.1)) + "배로 들어가요."
                battle_fx_note = "각성!"; battle_impact("buff", "party", 0)
            elif battle_choice == "heal":
                var recovered = mini(candy_heal(), PARTY_HP - health); health += recovered
                battle_result = "뽀뽀사탕으로 체력 " + str(recovered) + " 회복!"
                battle_impact("heal", "party", recovered)
        var duration = first + gap * (volley_total - 1) + 0.3 if volley else (0.95 if battle_choice in ["team", "ult"] else 0.72)
        if battle_phase_time < duration: return
        if battle_choice in ["strike", "team"] or ult_kind() in ["volley", "blast"]: battle_charge = false
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
            if battle_guard: damage = maxi(1, int(ceil(damage * (0.1 if job == 3 and job_rank() >= 2 else 0.25)))) if damage > 0 else 0
            elif battle_intent == "sand": damage += 2
            if not battle_guard and battle_intent in ["chill", "gust"]: battle_energy = maxi(0, battle_energy - 1)
            if not battle_guard and battle_intent == "mist": battle_fog = true
            var spilled = battle_intent == "kick" and battle_bomb > 0 and not battle_guard
            if spilled: bomb_mul *= 0.5
            var back = 0
            if battle_reflect:
                back = int(enemy_damage() * (1.0 + 0.5 * job_rank())) + guard_heal(); damage = 0
                battle_hp = maxi(0, battle_hp - back); battle_hits += 1
            health = maxi(0, health - damage)
            if battle_reflect:
                battle_result = "반격을 흘려보내고 " + str(back) + " 피해로 되돌려줬어요."
                battle_impact("reflect", "enemy", back)
            elif battle_intent == "brace": battle_result = "상대가 방어 자세! 다음 피해 절반 · 월급 박치기는 방어를 뚫어요."
            elif battle_intent == "rest": battle_result = "상대가 숨을 골랐어요. 이번에는 반격이 없어요."
            elif battle_intent == "kick":
                battle_result = ("냄비를 엎었다! 폭발이 절반으로 줄어요 · " if spilled else ("냄비를 지켜 냈어요! " if battle_bomb > 0 else "허공을 걷어찼어요 · ")) + str(damage) + " 피해"
                battle_impact("guard" if battle_guard else "regional", "party", damage)
            else:
                battle_result = ("잘 막았어요! " if battle_guard else "상대의 반격! ") + str(damage) + " 피해" + (" · 기력 −1" if not battle_guard and battle_intent in ["chill", "gust"] else " · 다음 설거지 −2" if battle_fog else "")
                battle_impact("guard" if battle_guard else ("regional" if city_index > 0 else ( ["haunt", "peck", "wall"][wild_index] if wild_battle else "baguette")), "party", damage)

        if battle_phase_time < 0.6: return
        if health == 0:
            state = "battle_lost"; battle_phase = "done"; sfx("lose"); return
        if battle_hp == 0:
            win_battle(); return
        ward_turns = maxi(0, ward_turns - 1); battle_reflect = ward_turns > 0
        battle_phase = "recover"; battle_phase_time = 0
    elif battle_phase == "recover":
        if battle_phase_time < 0.55: return
        battle_vuln = maxi(0, battle_vuln - 1)
        if battle_bomb > 0:
            battle_bomb -= 1
            if battle_bomb == 0:
                var blast = int(soak_damage() * bomb_mul * (0.6 if battle_trait == "lid" else 1.0))
                bomb_mul = 1.0
                if job == 2 and job_rank() >= 2: health = mini(PARTY_HP, health + maxi(1, int(PARTY_HP * 0.05)))
                if battle_vuln > 0: blast = int(round(blast * soap_mul()))
                battle_hp = maxi(0, battle_hp - blast); battle_hits += 1
                battle_result = "불려 둔 냄비가 터졌다! " + str(blast) + " 피해!"
                battle_impact("boom", "enemy", blast)
                battle_phase = "bomb"; battle_phase_time = 0; return
        next_turn()
    elif battle_phase == "morph":
        if battle_phase_time < 1.3: return
        next_turn()
    elif battle_phase == "bomb":
        if battle_phase_time < 0.85: return
        if battle_hp == 0: win_battle(); return
        next_turn()

func next_turn() -> void:
    battle_turn += 1; battle_guard = false; battle_phase = "choose"; battle_phase_time = 0; refresh_intent()
    if battle_trait == "regen" and battle_hp > 0: battle_hp = mini(battle_max_hp, battle_hp + maxi(1, int(battle_max_hp * 0.04)))
    if job == 3 and job_rank() >= 3 and health < PARTY_HP: health = mini(PARTY_HP, health + maxi(1, int(ceil(PARTY_HP * 0.03))))
    battle_result = "상대가 힘을 모아요. 방어할까요?" if enemy_heavy() else "다음 행동을 골라주세요."
    if battle_bomb == 1: battle_result += " (냄비는 다음 턴에 터져요)"

# 2회차 라이벌: 처음 쓰러지면 각성해서 체력을 되찾고 더 세게 덤빈다
func boss_awaken() -> void:
    boss_phase = 1
    battle_max_hp = int(battle_max_hp * 0.5); battle_hp = battle_max_hp
    battle_vuln = 0; battle_enemy_guard = false
    battle_trait = ["rage", "regen", "hard", "lid"][city_index % 4]
    battle_result = String(city().boss.name) + "이(가) 각성했다! 체력을 되찾고 더 사나워졌어요."
    battle_phase = "morph"; battle_phase_time = 0
    sfx("roar"); shake = 16; flash = 0.9
    pop("각성!", "enemy", "ff7a5a", true)

func win_battle() -> void:
    if not wild_battle and cycle >= 1 and boss_phase == 0:
        boss_awaken(); return
    battle_reward = int((15 + route_pos() * 4 + perfects * 5) * float(GRADES[wild_grade].gold)) if wild_battle else (80 + route_pos() * 20 + perfects * 10)
    if legend_battle: battle_reward = 300 + route_pos() * 80
    battle_reward = int(battle_reward * cycle_mul(0.5))
    if tower_battle: battle_reward = 20 + tower_floor * 10
    state = "battle_won"; battle_phase = "done"; sfx("win"); win_time = 0

# 자동 전투가 고르는 행동: 위험하면 지키고, 기력이 차면 큰 기술, 아니면 불리고 두드린다
func auto_pick() -> String:
    var danger = enemy_damage()
    if health * 100 < PARTY_HP * 35 and battle_berries > 0: return "heal"
    if (enemy_heavy() and health < danger * 2) or (battle_intent == "kick" and battle_bomb > 0): return "guard"
    for i in [2, 1, 0]:
        if ult_open(i) and battle_energy >= int(ult_info(i).energy):
            if String(ult_info(i).kind) == "arm" and battle_bomb > 0: continue
            if String(ult_info(i).kind) == "heal" and health * 2 > PARTY_HP: continue
            if String(ult_info(i).kind) == "ward" and not enemy_heavy(): continue
            return "ult" + str(i)
    if skill_open("soap") and battle_energy >= 2 and battle_vuln == 0 and battle_bomb == 0: return "soap"
    if skill_open("soak") and battle_energy >= 1 and battle_bomb == 0: return "soak"
    if skill_open("coffee") and battle_energy == 0 and not battle_charge: return "coffee"
    return "strike"

func auto_tick(dt: float) -> void:
    if not tower_battle:
        auto_battle = false; return
    auto_wait -= dt
    if auto_wait > 0: return
    match state:
        "battle_ready": auto_wait = 0.25; begin_battle()
        "battle_won": auto_wait = 0.45; claim_battle_win()
        "battle_lost":
            auto_battle = false; toast("자동 전투가 " + str(tower_floor) + "층에서 멈췄어요.")
        "battle":
            if battle_phase == "choose":
                auto_wait = 0.12
                var pick = auto_pick()
                if pick.begins_with("ult"):
                    ult_index = int(pick.right(1)); choose_battle("ult")
                else: choose_battle(pick)

func start_tower() -> void:
    if state != "pause" or previous_state != "explore" or stamps() + cycle < 1: return
    state = "explore"; tower_floor = 1
    next_floor()

func next_floor() -> void:
    meet_wild()
    tower_battle = true
    legend_battle = tower_floor % 5 == 0
    wild_index = (tower_floor * 7) % 3
    wild_grade = 3 if legend_battle else (1 if tower_floor % 5 == 4 else 0)
    if legend_battle: sfx("roar")

# 한 층을 이기면 바로 다음 층 — 5층마다 수호자가 나오고 처음 넘으면 기술 포인트를 준다
func finish_floor() -> void:
    coins += battle_reward
    var note = str(tower_floor) + "층 돌파! +" + str(battle_reward) + "원"
    if tower_floor > tower_best:
        tower_best = tower_floor
        if tower_floor % 5 == 0:
            skill_points += 1; note += " · 최고 기록! 기술 포인트 +1"
    gain_exp(10 + tower_floor * 3)
    gain_stones(3 if legend_battle else 1)
    tower_floor += 1
    hero.position = battle_return; partner.position = partner_return
    next_floor(); save_progress(); toast(note)

func claim_battle_win() -> void:
    if state != "battle_won": return
    if tower_battle:
        finish_floor(); return
    if wild_battle: finish_wild_battle(); return
    coins += battle_reward; stage = 3
    skill_points += 1; gain_stones(3)
    gain_exp(40 + route_pos() * 12 + perfects * 4)
    hero.position = battle_return; partner.position = partner_return; reset_follow_path()
    rival.position = tour.v(city().boss_at)
    if city_index > 0:
        if cycle >= 1:
            var after = CYCLE_TALK[city_index].win.duplicate()
            after.append(["소현", "이번에도 사진으로 남기자. 둘 다 나오게."])
            show_dialogue(after, "explore"); save_progress(); update_target(); return
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

func meet_wild(legend: bool = false) -> void:
    wild_battle = true; battle_return = hero.position; partner_return = partner.position
    battle_follow_path = follow_path.duplicate(); battle_follow_anchor = follow_anchor
    story_perfects = perfects; wild_index = 0 if legend else randi_range(0, 2)
    wild_grade = 3 if legend else 0; legend_battle = legend
    if not legend and (wild_wins >= 2 or city_index > 0):
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
    grass_steps = 0
    if legend: sfx("roar"); shake = 14
    else: chime(880 + wild_grade * 180)

func restore_from_wild() -> void:
    rival.visible = false; rival = story_rival
    hero.position = battle_return; partner.position = partner_return
    perfects = story_perfects; wild_battle = false; wild_grade = 0; legend_battle = false; tower_battle = false; auto_battle = false
    encounter_grace = 5.0; grass_steps = 0; encounter_at = randf_range(9.0, 16.0)
    follow_path = battle_follow_path.duplicate(); follow_anchor = battle_follow_anchor
    state = "explore"; update_target(); set_camera(1, true)

func finish_wild_battle() -> void:
    if legend_battle:
        finish_legend(); return
    var reward = battle_reward
    var first = not wild_seen[wild_index]
    wild_seen[wild_index] = true; wild_wins += 1
    coins += reward; var name = wild_name()
    var caught_index = wild_index
    var caught_city = city_index
    var caught_grade = wild_grade
    var bonus_xp = int((8 + route_pos() * 3 + perfects * 2) * float(GRADES[wild_grade].xp))
    restore_from_wild()
    burst(hero.position + Vector3(0, 0.8, 0), "f6d484", 18)
    toast(name + "와의 대결 승리! +" + str(reward) + "원" + (" · 첫 만남!" if first else ""))
    gain_exp(bonus_xp)
    if caught_grade >= 2 and bag_count("candy") < 9: bag_add("candy", 1)
    gain_stones(caught_grade)
    befriend(caught_city, caught_index, name, caught_grade)
    tour.wild_victory()
    save_progress()

# 전설을 이기면 반드시 친구가 된다
func finish_legend() -> void:
    var c = city_index
    var name = String(LEGENDS[c].name)
    coins += battle_reward
    var prize = battle_reward
    restore_from_wild()
    tour.record()["legend"] = true
    pets.append({ "c": c, "i": 3, "lv": 5, "g": 3})
    if pet_team.size() < team_max(): pet_team.append(pets.size() - 1)
    spawn_pet(); skill_points += 2; gain_stones(5)
    burst(hero.position + Vector3(0, 0.8, 0), "ffd84a", 24); flash = 0.8
    gain_exp(120 + c * 30)
    PARTY_HP = party_max(); save_progress()
    show_dialogue( [ ["전설 · " + name, "…졌다. 너희 둘의 약속, 끝까지 지켜보겠다."], ["소현", name + "이(가) 친구가 됐어! 여행비 " + str(prize) + "원과 기술 포인트 2개도 얻었어."], ["동훈", "전설이랑 같이 걷다니… 내일 설거지는 얘한테 시켜도 되나?"]], "explore")

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
    if pet_team.size() < team_max(): pet_team.append(pets.size() - 1)
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
    if state != "photo": return
    stage = 4; state = "ending"; flash = 1
    tour.stamp_city()
    sfx("chest"); save_progress()

func burst(pos: Vector3, color: String, count: int = 12) -> void:
    if not effects_on: return
    for i in range(count):
        var n = world.box(world, pos, Vector3.ONE * 0.09, color)
        n.rotation = Vector3(randf(), randf(), randf())
        var a = float(i) / count * TAU
        sparks.append({ "node": n, "velocity": Vector3(cos(a) * 1.4, randf_range(1.2, 2.4), sin(a) * 1.4), "life": 0.9})

# 미리 만들어 둔 16kHz WAV 를 읽는다. 파일이 없으면 조용히 넘어간다.
func load_wav(name: String):
    if sounds.has(name): return sounds[name]
    var stream = null
    var bytes = FileAccess.get_file_as_bytes("res://audio/" + name + ".wav")
    if bytes.size() > 64:
        stream = AudioStreamWAV.new(); stream.format = AudioStreamWAV.FORMAT_16_BITS; stream.mix_rate = 16000
        stream.data = bytes.slice(44)
    sounds[name] = stream
    return stream

func sfx(name: String, pitch: float = 1.0) -> void:
    if not sound_on or sfx_pool.is_empty(): return
    var stream = load_wav("fx_" + name)
    if stream == null: return
    var voice = sfx_pool[sfx_next]; sfx_next = (sfx_next + 1) % sfx_pool.size()
    voice.stream = stream; voice.pitch_scale = pitch; voice.play()

func want_bgm() -> String:
    if not sound_on or not ui_ready: return ""
    var now = previous_state if state == "pause" else state
    if now in ["battle", "battle_ready"]: return "boss" if legend_battle or not wild_battle else "battle"
    if now in ["battle_won", "battle_lost"]: return ""
    return "city" + str(city_index)

func update_bgm() -> void:
    var want = want_bgm()
    if want == bgm_name: return
    bgm_name = want; bgm.stop()
    if want == "": return
    var stream = load_wav(want)
    if stream == null: return
    stream.loop_mode = AudioStreamWAV.LOOP_FORWARD; stream.loop_begin = 0; stream.loop_end = int(stream.data.size() / 2)
    bgm.stream = stream; bgm.pitch_scale = 1.07 if legend_battle else 1.0; bgm.play()

func pop(text: String, side: String, color: String, big: bool = false) -> void:
    pops.append({ "t": text, "side": side, "age": 0.0, "big": big, "color": color, "dx": randf_range(-14, 14)})
    if pops.size() > 8: pops.pop_front()

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
    var data = { "version": 3, "city": city_index, "cities": tour.records, "completed": tour.completed, "unlocked": tour.unlocked, "coins": coins, "meal": tour.meal, "time": game_time, "sound": sound_on, "effects": effects_on, "wide_view": overview, "tutorial_seen": tutorial_seen, "level": level, "xp": xp, "pets": pets, "pet_active": pet_active, "owned_gear": owned_gear, "equipped": equipped, "bag": bag, "next_energy": next_energy, "pet_team": pet_team, "skill_lv": skill_lv, "skill_points": skill_points, "job": job, "cycle": cycle, "tower_best": tower_best, "gear_lv": gear_lv, "stones": stones}
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
    tower_best = maxi(0, int(data.get("tower_best", 0)))
    stones = clampi(int(data.get("stones", 0)), 0, 999); gear_lv = {}
    var saved_lv = data.get("gear_lv", {})
    if saved_lv is Dictionary:
        for key in saved_lv: gear_lv[String(key)] = clampi(int(saved_lv[key]), 0, ENHANCE_MAX)
    job = clampi(int(data.get("job", 0)), 0, 3); cycle = clampi(int(data.get("cycle", 0)), 0, 99)
    owned_gear = ["g0", "a0", "s0", "k0"]
    var saved_gear = data.get("owned_gear", [])
    if saved_gear is Array:
        for id in saved_gear:
            var found = gear_of(String(id))
            if found.id == String(id) and not owned_gear.has(found.id): owned_gear.append(found.id)
    equipped = ["g0", "a0", "s0", "k0"]
    var saved_eq = data.get("equipped", [])
    if saved_eq is Array:
        for i in range(mini(4, saved_eq.size())):
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
            var i = clampi(int(entry.get("i", 0)), 0, 3)
            pets.append({ "c": c, "i": i, "lv": clampi(int(entry.get("lv", 1)), 1, 5), "g": clampi(int(entry.get("g", 0)), 0, 3)})
    pet_active = clampi(int(data.get("pet_active", -1)), -1, pets.size() - 1)
    pet_team = []
    var saved_team = data.get("pet_team", null)
    if saved_team is Array:
        for index in saved_team:
            var k = int(index)
            if k >= 0 and k < pets.size() and not pet_team.has(k) and pet_team.size() < team_max(): pet_team.append(k)
    elif pet_active >= 0: pet_team.append(pet_active)
    skill_points = clampi(int(data.get("skill_points", maxi(0, level - 1) if not data.has("skill_lv") else 0)), 0, 99)
    var saved_skills = data.get("skill_lv", {})
    for entry in SKILLS:
        skill_lv[entry.id] = clampi(int(saved_skills.get(entry.id, 1)) if saved_skills is Dictionary else 1, 1, SKILL_MAX)
    tutorial_seen = data.get("tutorial_seen", true) == true
    sound_on = data.get("sound", true) == true; effects_on = data.get("effects", true) == true; overview = data.get("wide_view", false) == true
    sun.shadow_enabled = effects_on; tour.apply_city(clampi(int(data.get("city", 0)), 0, 9) if route_pos(clampi(int(data.get("city", 0)), 0, 9)) <= tour.unlocked else route_city(tour.unlocked))
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
    coins -= int(entry.cost); owned_gear.append(id); sfx("coin")
    equip_gear(id)
    toast(String(entry.name) + "를 샀어요!  남은 돈 " + str(coins) + "원")

func buy_item(id: String) -> void:
    var entry = item_of(id)
    if entry.id != id: return
    if bag_count(id) >= int(entry.cap): toast("가방에 더는 안 들어가요."); return
    if coins < int(entry.cost): toast("돈이 " + str(int(entry.cost) - coins) + "원 모자라요."); return
    coins -= int(entry.cost); bag_add(id, 1); sfx("coin"); save_progress()
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
    elif pet_team.size() >= team_max():
        toast("세 친구까지만 함께 걸을 수 있어요. 먼저 한 친구를 쉬게 해주세요."); return
    else:
        pet_team.append(index); toast(pet_name(pets[index]) + "와 함께 걸어요. (" + str(pet_team.size()) + " / " + str(team_max()) + ")")
    spawn_pet(); PARTY_HP = party_max(); chime(640); save_progress()

func restart() -> void:
    if wild_battle: restore_from_wild()
    tour.reset_records(); city_index = 0; level = 1; xp = 0; pets.clear(); pet_active = -1; pet_team = []
    skill_points = 0; wild_grade = 0; area_index = 0
    for entry in SKILLS: skill_lv[entry.id] = 1
    owned_gear = ["g0", "a0", "s0", "k0"]; equipped = ["g0", "a0", "s0", "k0"]; bag = { "candy": 3}; next_energy = 0; sheet_tab = 0
    job = 0; cycle = 0; legend_battle = false; gear_slot = 0; tower_battle = false; tower_best = 0; pet_page = 0; gear_lv = {}; stones = 0
    rebuild_city(); photo_file = tour.current_photo_path(); PARTY_HP = party_max(); spawn_pet()
    rival = story_rival; wild_wins = 0; wild_seen = [false, false, false]
    grass_steps = 0; encounter_grace = 6.0; encounter_at = 11.0
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
