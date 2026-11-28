extends RefCounted
# ── 동훈 경마장 (번외편) ─────────────────────────────────────
# 말 24마리 · 기수 10명 · 하루 6경주 · 마권 7종 (단승 연승 복승 쌍승 복연승 삼복승 삼쌍승)
# 배당은 경주를 미리 여러 번 돌려 본 확률에 최근 전적 인기를 섞어 매긴다 (하빌 모형).
# 돈은 여행비와 따로 — 경마장 지갑에서만 오간다. 저장도 따로 (user://racing.json).
const Spr = preload ("res://scripts/race_sprite_data.gd")
const SAVE = "user://racing.json"

const NAMES = ["소현의 미소", "앨리 스마일", "소현 퇴근길", "소현표 김밥", "보조개 번개", "소현 핑크",
    "소현의 꽃다발", "아침형 소현", "소현 커피 한잔", "소현의 산책", "소현 애교", "소현이 최고야",
    "소현의 첫눈", "소현 생일 케이크", "소현 집밥", "소현 주말 늦잠", "소현의 고양이", "소현 쇼핑 질주",
    "소현 화나면 무서워", "소현의 봄날", "소현 노래방", "소현 떡볶이", "소현의 반지", "소현 프린세스"]
const COATS = [["8a5a3c", "3a2a22", "밤색"], ["b0602e", "8a3a1e", "적갈색"], ["5a3a2a", "2a1c18", "흑갈색"], ["3a3434", "1f1a22", "흑마"],
    ["b8bcc0", "8a8e94", "회색"], ["eeeae0", "c9c4b8", "백마"], ["d8b060", "f4ecd0", "금빛"], ["a8703a", "f4f4f4", "얼룩"]]
const JOCKEYS = [
    { "name": "김번개", "skill": 92, "j": "c8323c", "k": "f4f4f4"}, { "name": "이질주", "skill": 85, "j": "3f6fd0", "k": "ffd84a"},
    { "name": "박채찍", "skill": 80, "j": "3f9a52", "k": "f4f4f4"}, { "name": "최안장", "skill": 76, "j": "8a5fc0", "k": "f4a0c0"},
    { "name": "정코너", "skill": 72, "j": "f08a3c", "k": "2a2a30"}, { "name": "강막판", "skill": 70, "j": "2a2a30", "k": "c8323c"},
    { "name": "장동훈", "skill": 68, "j": "e8548c", "k": "ffd84a"}, { "name": "윤선행", "skill": 64, "j": "74bcb7", "k": "3f6fd0"},
    { "name": "한추입", "skill": 60, "j": "f0d04a", "k": "3f9a52"}, { "name": "오준마", "skill": 55, "j": "a8703a", "k": "f4f4f4"},
]
const CLOTH = ["f4f4f4", "2a2a30", "c8323c", "3f6fd0", "f0d04a", "3f9a52", "f08a3c", "f4a0c0"]
const STYLE_NAME = ["도주", "선행", "선입", "추입"]
const STYLE_LINE = ["출발부터 끝까지 앞에서 버텨요", "앞쪽에서 기회를 봐요", "무리 속에서 힘을 아껴요", "막판에 바깥으로 뚫고 나와요"]
const TRACK_NAME = ["건조", "양호", "다습", "불량"]
const WEATHER = ["맑음", "흐림", "비", "폭우"]
const RACE_NAMES = ["아침 산책 특별", "앨리 일반", "보조개 스테이크스", "소현 컵", "주말 대상", "소현 그랑프리"]
const BETS = [
    { "id": "win", "name": "단승", "n": 1, "order": true, "take": 0.2, "line": "1착할 말 한 마리"},
    { "id": "place", "name": "연승", "n": 1, "order": true, "take": 0.2, "line": "3착 안에 들 말 한 마리"},
    { "id": "quin", "name": "복승", "n": 2, "order": false, "take": 0.22, "line": "1·2착 두 마리 (순서 상관없이)"},
    { "id": "exacta", "name": "쌍승", "n": 2, "order": true, "take": 0.23, "line": "1착 → 2착 순서대로"},
    { "id": "wide", "name": "복연승", "n": 2, "order": false, "take": 0.22, "line": "둘 다 3착 안에 드는 두 마리"},
    { "id": "trio", "name": "삼복승", "n": 3, "order": false, "take": 0.25, "line": "1·2·3착 세 마리 (순서 상관없이)"},
    { "id": "tri", "name": "삼쌍승", "n": 3, "order": true, "take": 0.27, "line": "1착 → 2착 → 3착 순서대로"},
]
const AMOUNTS = [100, 500, 1000, 5000, 10000]

var game
var horses: Array = []          # 능력치(고정) + 기록(저장)
var jwins: Array = []
var day = 1
var money = 10000
var best_money = 10000
var best_hit = 0.0              # 가장 큰 적중 배당
var bought = 0
var hits = 0
var allowance_day = 0
var races: Array = []
var ri = 0                      # 보고 있는 경주
var screen = "lobby"            # lobby · card · horse · bet · race · result
var pick_slot = 0               # 상세 화면에서 보는 출전 번호 (0~7)
var bet_type = 0
var bet_pick: Array = []
var bet_amount = 1000
var slip: Array = []            # 이번 경주에 산 마권
var settle: Dictionary = {}     # 정산 결과
var live: Dictionary = {}
var speedup = 1.0
var note = ""
var note_t = 0.0

func _init(owner) -> void:
    game = owner
    make_horses()
    load_data()
    if races.is_empty(): new_day()

# ── 말과 기수 ──
func make_horses() -> void:
    var rng = RandomNumberGenerator.new(); rng.seed = 20261128
    horses = []
    for i in range(NAMES.size()):
        var h = { "name": NAMES[i], "coat": i % COATS.size(), "spd": rng.randi_range(58, 100), "sta": rng.randi_range(50, 100),
            "acc": rng.randi_range(50, 100), "guts": rng.randi_range(50, 100), "style": rng.randi_range(0, 3),
            "best": [1000, 1200, 1400, 1600, 1800, 2000][rng.randi_range(0, 5)], "wet": rng.randi_range(-10, 10),
            "age": rng.randi_range(3, 7), "sex": ["수", "암", "거"][rng.randi_range(0, 2)], "kg": rng.randi_range(448, 522),
            "starts": 0, "wins": 0, "seconds": 0, "thirds": 0, "recent": []}
        # 지난 다섯 경주: 실력이 좋을수록 앞쪽이지만 들쭉날쭉
        var power = (h.spd + h.sta * 0.5 + h.acc * 0.3 + h.guts * 0.3 - 120.0) / 90.0
        for k in range(5):
            h.recent.append(clampi(int(round(8.0 - power * 6.0 + rng.randfn(0.0, 2.2))), 1, 8))
        horses.append(h)
    jwins = []
    for j in JOCKEYS: jwins.append(0)

func recent_avg(h: Dictionary, n: int = 3) -> float:
    var list = h.recent
    if list.is_empty(): return 4.5
    var total = 0.0
    var count = 0
    for k in range(maxi(0, list.size() - n), list.size()):
        total += float(list[k]); count += 1
    return total / maxf(1.0, count)

# ── 하루 경주표 ──
func new_day() -> void:
    var rng = RandomNumberGenerator.new(); rng.randomize()
    var weather = rng.randi_range(0, 3) if rng.randf() < 0.45 else rng.randi_range(0, 1)
    races = []
    for r in range(6):
        var pool = range(horses.size()); pool.shuffle()
        var field = pool.slice(0, 8)
        var jpool = range(JOCKEYS.size()); jpool.shuffle()
        var conds = []
        var wts = []
        for idx in field:
            # 최근 기세가 좋으면 컨디션도 오른다
            var mom = (4.5 - recent_avg(horses[idx])) * 0.6
            conds.append(clampi(int(round(rng.randfn(mom, 1.8))), -5, 5))
            wts.append(rng.randi_range(-6, 6))
        var dist = 2000 if r == 5 else [1000, 1200, 1400, 1600, 1800][rng.randi_range(0, 4)]
        races.append({ "name": RACE_NAMES[r], "dist": dist, "track": clampi(weather + rng.randi_range(-1, 0), 0, 3), "weather": weather,
            "field": field, "jock": jpool.slice(0, 8), "cond": conds, "wt": wts, "seed": rng.randi(), "done": false, "order": [], "times": [], "p": []})
    ri = 0; slip = []; screen = "lobby"
    save_data()

func race() -> Dictionary:
    return races[ri]

func horse_at(slot: int) -> Dictionary:
    return horses[int(race().field[slot])]

func jockey_at(slot: int) -> Dictionary:
    return JOCKEYS[int(race().jock[slot])]

# ── 경주 모형 (파이썬 시뮬레이터로 맞춘 값: 1번 인기 약 36% 우승) ──
func sim_new(rc: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
    var s = { "pos": [], "st": [], "noise": [], "nt": [], "form": [], "done": [], "t": 0.0, "v": [], "phase": []}
    for k in range(8):
        var h = horses[int(rc.field[k])]
        s.pos.append(0.0); s.noise.append(0.0); s.nt.append(0.0); s.done.append(-1.0); s.v.append(0.0); s.phase.append(randf() * 4.0)
        s.form.append(rng.randfn(0.0, 0.2))
        s.st.append((0.55 + float(h.sta) / 220.0) * pow(1400.0 / float(rc.dist), 0.6) * 40.0)
    return s

func sim_step(s: Dictionary, rc: Dictionary, dt: float, rng: RandomNumberGenerator) -> bool:
    s["t"] = float(s["t"]) + dt
    var dist = float(rc.dist)
    var wet = float(rc.track)
    var left = 0
    for i in range(8):
        if float(s.done[i]) >= 0.0: continue
        left += 1
        var h = horses[int(rc.field[i])]
        var skill = float(JOCKEYS[int(rc.jock[i])].skill)
        var prog = float(s.pos[i]) / dist
        var a = float(h.acc) / 100.0
        var v = 16.4 + (float(h.spd) - 75.0) * 0.005 + float(s.form[i])
        if prog < 0.35: v += [1.0, 0.5, 0.0, -0.5][int(h.style)] * a * 0.18
        elif prog > 0.65: v += [-0.4, 0.15, 0.5, 1.0][int(h.style)] * a * 0.18
        v -= absf(dist - float(h.best)) / 1000.0 * 0.3
        v += wet / 3.0 * float(h.wet) / 10.0 * 0.3
        v += float(rc.cond[i]) * 0.03 + (skill - 70.0) * 0.002 - float(rc.wt[i]) * 0.004
        s.nt[i] = float(s.nt[i]) - dt
        if float(s.nt[i]) <= 0.0:
            s.nt[i] = 0.5; s.noise[i] = float(s.noise[i]) * 0.6 + rng.randfn(0.0, 0.3 * (1.3 - skill / 100.0))
        v += float(s.noise[i])
        if float(s.st[i]) <= 0.0: v -= 0.4 * (1.25 - float(h.guts) / 100.0)
        elif dist - float(s.pos[i]) < 250.0: v += (float(h.guts) - 70.0) * 0.0015
        s.st[i] = float(s.st[i]) - dt * (maxf(0.0, v - 15.8) * 0.8 + 0.45)
        s.v[i] = v
        s.pos[i] = float(s.pos[i]) + v * dt
        if float(s.pos[i]) >= dist: s.done[i] = s.t - (float(s.pos[i]) - dist) / v
    return left == 0

func finish_order(s: Dictionary) -> Array:
    var order = range(8)
    order.sort_custom(func(a, b): return float(s.done[a]) < float(s.done[b]))
    return order

# 배당: 미리 50번 돌려 본 우승 확률 70% + 최근 전적 인기 30%
func ensure_odds(rc: Dictionary) -> void:
    if not rc.p.is_empty(): return
    var wins = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
    var rng = RandomNumberGenerator.new()
    for m in range(50):
        rng.seed = int(rc.seed) + 7919 * (m + 1)
        var s = sim_new(rc, rng)
        var guard = 0
        while not sim_step(s, rc, 0.5, rng) and guard < 600: guard += 1
        wins[finish_order(s)[0]] += 1.0
    var total = 0.0
    for x in wins: total += x
    var form = []
    var ftotal = 0.0
    for k in range(8):
        var f = exp(- recent_avg(horses[int(rc.field[k])]) * 0.35) * (1.0 + float(rc.cond[k]) * 0.04)
        form.append(f); ftotal += f
    var p = []
    for k in range(8): p.append(0.7 * wins[k] / total + 0.3 * form[k] / ftotal)
    rc.p = p

func p_triple(rc: Dictionary, a: int, b: int, c: int) -> float:
    var p = rc.p
    var pa = float(p[a])
    var pb = float(p[b])
    return pa * pb / maxf(0.001, 1.0 - pa) * float(p[c]) / maxf(0.001, 1.0 - pa - pb)

func p_pair(rc: Dictionary, a: int, b: int) -> float:
    var total = 0.0
    for c in range(8):
        if c != a and c != b: total += p_triple(rc, a, b, c)
    return total

func p_top3(rc: Dictionary, i: int) -> float:
    var total = 0.0
    for a in range(8):
        for b in range(8):
            if a == b: continue
            for c in range(8):
                if c == a or c == b: continue
                if a == i or b == i or c == i: total += p_triple(rc, a, b, c)
    return total

func bet_prob(rc: Dictionary, type: int, picks: Array) -> float:
    var p = rc.p
    match String(BETS[type].id):
        "win": return float(p[int(picks[0])])
        "place": return p_top3(rc, int(picks[0]))
        "quin": return p_pair(rc, int(picks[0]), int(picks[1])) + p_pair(rc, int(picks[1]), int(picks[0]))
        "exacta": return p_pair(rc, int(picks[0]), int(picks[1]))
        "wide":
            var t = 0.0
            for a in range(8):
                for b in range(8):
                    if a == b: continue
                    for c in range(8):
                        if c == a or c == b: continue
                        var trio = [a, b, c]
                        if trio.has(int(picks[0])) and trio.has(int(picks[1])): t += p_triple(rc, a, b, c)
            return t
        "trio":
            var t2 = 0.0
            for perm in [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]:
                t2 += p_triple(rc, int(picks[perm[0]]), int(picks[perm[1]]), int(picks[perm[2]]))
            return t2
    return p_triple(rc, int(picks[0]), int(picks[1]), int(picks[2]))

func odds(rc: Dictionary, type: int, picks: Array) -> float:
    ensure_odds(rc)
    var prob = bet_prob(rc, type, picks)
    var o = floorf((1.0 - float(BETS[type].take)) / maxf(prob, 0.0001) * 10.0) / 10.0
    return clampf(o, 1.0, 9999.9)

func popularity(rc: Dictionary, slot: int) -> int:
    ensure_odds(rc)
    var rank = 1
    for k in range(8):
        if float(rc.p[k]) > float(rc.p[slot]): rank += 1
    return rank

func bet_hit(type: int, picks: Array, order: Array) -> bool:
    var top3 = order.slice(0, 3)
    match String(BETS[type].id):
        "win": return int(order[0]) == int(picks[0])
        "place": return top3.has(int(picks[0]))
        "quin": return [int(order[0]), int(order[1])].has(int(picks[0])) and [int(order[0]), int(order[1])].has(int(picks[1]))
        "exacta": return int(order[0]) == int(picks[0]) and int(order[1]) == int(picks[1])
        "wide": return top3.has(int(picks[0])) and top3.has(int(picks[1]))
        "trio": return top3.has(int(picks[0])) and top3.has(int(picks[1])) and top3.has(int(picks[2]))
    return int(order[0]) == int(picks[0]) and int(order[1]) == int(picks[1]) and int(order[2]) == int(picks[2])

# ── 버튼 ──
func press(id: String) -> void:
    var arg = id.trim_prefix("rc_")
    if arg.begins_with("race_"):
        ri = clampi(int(arg.trim_prefix("race_")), 0, 5); slip = []; screen = "result" if bool(race().done) else "card"; ensure_odds(race()); game.sfx("click"); return
    if arg.begins_with("horse_"):
        pick_slot = clampi(int(arg.trim_prefix("horse_")), 0, 7); screen = "horse"; game.sfx("click"); return
    if arg.begins_with("type_"):
        bet_type = clampi(int(arg.trim_prefix("type_")), 0, BETS.size() - 1); bet_pick = []; game.sfx("click"); return
    if arg.begins_with("pick_"):
        var slot = clampi(int(arg.trim_prefix("pick_")), 0, 7)
        if bet_pick.has(slot): bet_pick.erase(slot)
        elif bet_pick.size() < int(BETS[bet_type].n): bet_pick.append(slot)
        game.sfx("click"); return
    if arg.begins_with("amount_"):
        bet_amount = int(arg.trim_prefix("amount_")); game.sfx("click"); return
    match arg:
        "lobby": screen = "lobby"
        "card": screen = "card"
        "bet": screen = "bet"; bet_pick = []
        "quickwin":
            screen = "bet"; bet_type = 0; bet_pick = [pick_slot]
        "buy": buy()
        "start": start_race()
        "fast": speedup = 3.0 if speedup < 2.0 else 1.0
        "skip": skip_race()
        "next":
            if ri < 5:
                ri += 1; slip = []; screen = "card"; ensure_odds(race())
            else: screen = "lobby"
        "newday":
            day += 1; new_day(); game.sfx("job")
        "allowance":
            if money < 100 and allowance_day != day:
                allowance_day = day; money += 5000; save_data(); flash_note("소현이가 용돈 5,000원을 줬어요. “적당히 해!”")
        "exit": game.action("racing_exit")

func flash_note(text: String) -> void:
    note = text; note_t = 2.5

func buy() -> void:
    if bet_pick.size() != int(BETS[bet_type].n): flash_note("말을 " + str(int(BETS[bet_type].n)) + "마리 골라 주세요."); return
    if money < bet_amount:
        game.sfx("bad"); flash_note("지갑에 돈이 모자라요."); return
    var o = odds(race(), bet_type, bet_pick)
    money -= bet_amount; bought += 1
    slip.append({ "type": bet_type, "picks": bet_pick.duplicate(), "amount": bet_amount, "odds": o})
    game.sfx("coin"); flash_note(String(BETS[bet_type].name) + " " + pick_text(bet_type, bet_pick) + " · " + fmt(bet_amount) + "원 구입! (" + str(o) + "배)")
    bet_pick = []; save_data()

func pick_text(type: int, picks: Array) -> String:
    var parts: PackedStringArray = []
    for slot in picks: parts.append(str(int(slot) + 1))
    return (" → " if bool(BETS[type].order) and picks.size() > 1 else " · ").join(parts)

func fmt(n: int) -> String:
    var s = str(absi(n))
    var out = ""
    while s.length() > 3:
        out = "," + s.right(3) + out; s = s.left(s.length() - 3)
    return ("-" if n < 0 else "") + s + out

# ── 경주 진행 ──
func start_race() -> void:
    var rc = race()
    if bool(rc.done): return
    ensure_odds(rc)
    var rng = RandomNumberGenerator.new(); rng.seed = int(rc.seed)
    live = { "s": sim_new(rc, rng), "rng": rng, "gate": 2.8, "leader": -1, "said": {}, "lines": ["출발 준비 중… 게이트에 들어갑니다."], "end": -1.0, "say_t": 0.0, "dust": []}
    speedup = 1.0; screen = "race"; game.sfx("click")

func say(text: String) -> void:
    live.lines.append(text)
    if live.lines.size() > 2: live.lines.pop_front()

func tick(dt: float) -> void:
    note_t = maxf(0.0, note_t - dt)
    if screen != "race" or live.is_empty(): return
    var rc = race()
    if float(live.gate) > 0.0:
        var before = float(live.gate)
        live.gate = before - dt
        if int(ceil(before)) != int(ceil(float(live.gate))) and float(live.gate) > 0.0: game.sfx("click")
        if float(live.gate) <= 0.0:
            say("출발했습니다! " + str(rc.dist) + "m, 여덟 마리가 일제히 뛰쳐나갑니다!"); game.sfx("roar", 1.4)
        return
    var s = live.s
    if float(live.end) >= 0.0:
        live.end = float(live.end) + dt
        if float(live.end) > 1.6: finish_race()
        return
    # 1200m 가 약 35초에 끝나게 시간을 당긴다
    var scale = float(rc.dist) / (16.4 * (30.0 + float(rc.dist) / 200.0)) * speedup
    var remain = dt * scale
    while remain > 0.0:
        var step = minf(0.1, remain); remain -= step
        if sim_step(s, rc, step, live.rng):
            live.end = 0.0; break
        for k in range(8): s.phase[k] = float(s.phase[k]) + float(s.v[k]) * step * 0.55
    commentary(rc, s, dt)

func lead_order(s: Dictionary) -> Array:
    # 들어온 말은 들어온 순서대로, 달리는 말은 앞선 순서대로
    var keyed = []
    for k in range(8):
        var done = float(s.done[k])
        keyed.append([done - 100000.0 if done >= 0.0 else - float(s.pos[k]), k])
    keyed.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
    var order = []
    for one in keyed: order.append(int(one[1]))
    return order

func commentary(rc: Dictionary, s: Dictionary, dt: float) -> void:
    live.say_t = float(live.say_t) - dt
    var order = lead_order(s)
    var top = int(order[0])
    var left = float(rc.dist) - float(s.pos[top])
    var name = str(top + 1) + "번 " + String(horse_at(top).name)
    for mark in [800, 400, 200]:
        if left < mark and not live.said.has(mark) and float(rc.dist) > mark + 100:
            live.said[mark] = true
            match mark:
                800: say("3코너를 돕니다. 선두는 " + name + "!")
                400: say("직선 주로에 들어섭니다! " + name + " 앞장, 뒤에서 추격이 시작됩니다!")
                _: say("남은 200m! 막판 스퍼트!")
            game.sfx("good"); return
    if top != int(live.leader) and float(live.say_t) <= 0.0 and s.t > 2.0:
        live.leader = top; live.say_t = 2.2
        say(name + ", 선두로 나섭니다!")
    if left < 120 and not live.said.has("close"):
        var second = int(order[1])
        if float(s.pos[top]) - float(s.pos[second]) < 2.0:
            live.said["close"] = true; say("치열한 접전! " + str(top + 1) + "번과 " + str(second + 1) + "번이 나란히!")

func skip_race() -> void:
    if live.is_empty(): return
    var rc = race()
    live.gate = 0.0
    var guard = 0
    while not sim_step(live.s, rc, 0.1, live.rng) and guard < 4000: guard += 1
    finish_race()

func margin_text(gap_m: float) -> String:
    var lengths = gap_m / 2.4
    if lengths < 0.1: return "코차"
    if lengths < 0.25: return "머리차"
    if lengths < 0.45: return "목차"
    if lengths < 0.75: return "1/2마신"
    if lengths < 1.0: return "3/4마신"
    if lengths < 10.0: return str(snappedf(lengths, 0.5)) + "마신"
    return "대차"

func finish_race() -> void:
    var rc = race()
    var s = live.s
    var order = finish_order(s)
    rc.done = true; rc.order = order
    var times = []
    for k in range(8): times.append(float(s.done[int(order[k])]) * 1.0)
    rc.times = times
    # 기록
    for place in range(8):
        var h = horse_at(int(order[place]))
        h.starts = int(h.starts) + 1
        if place == 0: h.wins = int(h.wins) + 1
        elif place == 1: h.seconds = int(h.seconds) + 1
        elif place == 2: h.thirds = int(h.thirds) + 1
        h.recent.append(place + 1)
        while h.recent.size() > 5: h.recent.pop_front()
    jwins[int(rc.jock[int(order[0])])] = int(jwins[int(rc.jock[int(order[0])])]) + 1
    # 정산
    var paid = 0
    var spent = 0
    var rows = []
    var top_hit = 0.0
    for b in slip:
        spent += int(b.amount)
        var hit = bet_hit(int(b.type), b.picks, order)
        var won = int(floor(float(b.amount) * float(b.odds))) if hit else 0
        paid += won
        if hit:
            hits += 1; top_hit = maxf(top_hit, float(b.odds))
        rows.append({ "b": b, "hit": hit, "won": won})
    money += paid
    best_money = maxi(best_money, money)
    best_hit = maxf(best_hit, top_hit)
    settle = { "rows": rows, "paid": paid, "spent": spent}
    slip = []; live = {}; screen = "result"
    if paid > spent and top_hit >= 20.0:
        game.flash = 1.0; game.shake = 12; game.sfx("job")
    elif paid > spent: game.sfx("win")
    elif spent > 0: game.sfx("lose")
    else: game.sfx("good")
    save_data()

# ── 저장 (여행 저장과 따로) ──
func save_data() -> void:
    var rec = []
    for h in horses: rec.append([int(h.starts), int(h.wins), int(h.seconds), int(h.thirds), h.recent])
    var data = { "day": day, "money": money, "best_money": best_money, "best_hit": best_hit, "bought": bought, "hits": hits,
        "allowance_day": allowance_day, "horses": rec, "jwins": jwins, "races": races, "ri": ri}
    var f = FileAccess.open(SAVE, FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify(data)); f.close()

func load_data() -> void:
    if not FileAccess.file_exists(SAVE): return
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
    if not parsed is Dictionary: return
    day = maxi(1, int(parsed.get("day", 1))); money = maxi(0, int(parsed.get("money", 10000)))
    best_money = int(parsed.get("best_money", money)); best_hit = float(parsed.get("best_hit", 0.0))
    bought = int(parsed.get("bought", 0)); hits = int(parsed.get("hits", 0)); allowance_day = int(parsed.get("allowance_day", 0))
    var rec = parsed.get("horses", [])
    if rec is Array and rec.size() == horses.size():
        for i in range(horses.size()):
            var r = rec[i]
            if not r is Array or r.size() < 5: continue
            horses[i].starts = int(r[0]); horses[i].wins = int(r[1]); horses[i].seconds = int(r[2]); horses[i].thirds = int(r[3])
            var recent = []
            for x in r[4]: recent.append(clampi(int(x), 1, 8))
            horses[i].recent = recent
    var jw = parsed.get("jwins", [])
    if jw is Array and jw.size() == JOCKEYS.size():
        for i in range(jw.size()): jwins[i] = int(jw[i])
    var saved = parsed.get("races", [])
    if saved is Array and saved.size() == 6:
        races = []
        for r in saved:
            var one = r.duplicate(true)
            for key in ["field", "jock", "cond", "wt", "order"]:
                var ints = []
                for x in one.get(key, []): ints.append(int(x))
                one[key] = ints
            one["dist"] = int(one.get("dist", 1200)); one["track"] = int(one.get("track", 0)); one["weather"] = int(one.get("weather", 0))
            one["seed"] = int(one.get("seed", 1)); one["done"] = bool(one.get("done", false)); one["p"] = []
            if one.field.size() != 8: races = []; break
            races.append(one)
        ri = clampi(int(parsed.get("ri", 0)), 0, 5)

# ══ 그리기 ══════════════════════════════════════════════════
func cloth(c, slot: int, rect: Rect2) -> void:
    var col = Color(CLOTH[slot])
    c.panel(rect, col, 6, Color("1f1a22"))
    var dark = slot in [1, 2, 3, 5]
    c.txt(str(slot + 1), rect.position.x, rect.position.y + rect.size.y * 0.5 + rect.size.y * 0.22, int(rect.size.y * 0.62), Color("f4f4f4") if dark else Color("1f1a22"), rect.size.x, HORIZONTAL_ALIGNMENT_CENTER)

func horse_sprite(c, foot: Vector2, s: float, h: Dictionary, jock: Dictionary, slot: int, frame: int) -> void:
    var coat = COATS[int(h.coat)]
    var pal = { "C": Color(coat[0]), "M": Color(coat[1]), "D": Color("2a2020"), "S": Color(CLOTH[slot]), "J": Color(jock.j), "K": Color(jock.k), "W": Color("f4f4f4"), "B": Color("2a2a30"), "O": Color("1f1a22")}
    var o = foot - Vector2(21, 28) * s
    for key in ["legs" + str(frame % 4), "body"]:
        for part in Spr.PARTS[key]:
            c.draw_rect(Rect2(o + Vector2(part[0], part[1]) * s, Vector2(part[2], part[3]) * s + Vector2(0.4, 0.4)), pal[part[4]])

func header(c, title: String, sub: String) -> void:
    var w = c.w
    c.panel(Rect2(0, 0, w, c.h), Color("1d3a2e"), 0)
    c.panel(Rect2(0, 0, w, 92), Color("13261e"), 0)
    c.txt(sub, 20, 34, 12, Color("e5c46f"))
    c.txt(title, 18, 70, 24, Color("fff8e8"))
    c.txt(fmt(money) + "원", w - 190, 70, 20, Color("ffd84a"), 172, HORIZONTAL_ALIGNMENT_RIGHT)
    c.txt("지갑", w - 190, 34, 11, Color("cfe0d2"), 172, HORIZONTAL_ALIGNMENT_RIGHT)

func draw(c) -> void:
    match screen:
        "card": draw_card(c)
        "horse": draw_horse(c)
        "bet": draw_bet(c)
        "race": draw_race(c)
        "result": draw_result(c)
        _: draw_lobby(c)
    if note_t > 0.0:
        var y = c.h * 0.42
        c.panel(Rect2(20, y, c.w - 40, 60), Color("13261eee"), 16)
        c.para(note, 36, y + 26, c.w - 72, 14, Color("fff8e8"), 1.4)

func draw_lobby(c) -> void:
    var w = c.w
    header(c, "동훈 경마장", "번외편 · " + str(day) + "일차 · " + WEATHER[int(races[0].weather)])
    # 장식: 결승선 앞을 달리는 말 한 마리
    var t = game.clock_time
    c.draw_rect(Rect2(0, 100, w, 120), Color("8fc0d8"))
    c.draw_rect(Rect2(0, 180, w, 40), Color("6fa05a"))
    for k in range(12): c.draw_rect(Rect2(fposmod(k * 44 - t * 60.0, w + 40) - 20, 176, 4, 12), Color("f4f4f4"))
    horse_sprite(c, Vector2(w * 0.5 + sin(t * 0.8) * 60, 214), 2.0, horses[int(t * 0.2) % horses.size()], JOCKEYS[int(t * 0.2) % JOCKEYS.size()], int(t * 0.2) % 8, int(t * 10.0))
    var y = 232
    c.txt("오늘의 경주 · 줄을 누르면 출전표", 20, y + 8, 12, Color("cfe0d2"))
    for r in range(6):
        var rc = races[r]
        var row = Rect2(14, y + 18 + r * 66, w - 28, 60)
        c.button("rc_race_" + str(r), "", row, r == 5 and not bool(rc.done), true)
        var fg = Color("fff8e8") if r == 5 and not bool(rc.done) else c.ink
        c.txt(str(r + 1) + "R  " + String(rc.name), row.position.x + 14, row.position.y + 26, 16, fg)
        c.txt(str(rc.dist) + "m · " + TRACK_NAME[int(rc.track)] + " · 8마리", row.position.x + 14, row.position.y + 48, 11, fg if r == 5 and not bool(rc.done) else c.muted)
        if bool(rc.done):
            var win = int(rc.order[0])
            cloth(c, win, Rect2(row.end.x - 118, row.position.y + 14, 30, 30))
            c.txt(String(horses[int(rc.field[win])].name), row.end.x - 84, row.position.y + 34, 11, c.ink, 76)
        else: c.txt("발매 중", row.end.x - 90, row.position.y + 36, 13, Color("c8323c") if r != 5 else Color("ffd84a"), 76, HORIZONTAL_ALIGNMENT_RIGHT)
    var by = y + 18 + 6 * 66 + 6
    var all_done = true
    for rc2 in races:
        if not bool(rc2.done): all_done = false
    c.txt("최고 잔고 " + fmt(best_money) + "원 · 최고 적중 " + str(snappedf(best_hit, 0.1)) + "배 · 적중 " + str(hits) + " / " + str(bought), 20, by + 14, 11, Color("cfe0d2"), w - 40, HORIZONTAL_ALIGNMENT_CENTER)
    if all_done: c.button("rc_newday", "하루 마감 · 다음 날로", Rect2(20, by + 26, w - 40, 50), true, true, 15)
    elif money < 100: c.button("rc_allowance", "소현이한테 용돈 받기 (+5,000원)", Rect2(20, by + 26, w - 40, 50), true, allowance_day != day, 14)
    c.button("rc_exit", "경마장 나가기", Rect2(20, c.h - 70, w - 40, 50), false, true, 14)

func trend_text(h: Dictionary) -> String:
    var parts: PackedStringArray = []
    for x in h.recent: parts.append(str(int(x)))
    return "-".join(parts)

func draw_card(c) -> void:
    var w = c.w
    var rc = race()
    ensure_odds(rc)
    header(c, str(ri + 1) + "R " + String(rc.name), str(day) + "일차 · " + str(rc.dist) + "m · 주로 " + TRACK_NAME[int(rc.track)] + " · " + WEATHER[int(rc.weather)])
    var y = 100
    c.txt("번호 · 말 · 기수 · 최근 5전(왼쪽이 오래된 것) · 단승 배당", 16, y + 8, 10, Color("cfe0d2"))
    var row_h = minf(64.0, (c.h - 250) / 8.0)
    for k in range(8):
        var h = horse_at(k)
        var j = jockey_at(k)
        var row = Rect2(12, y + 16 + k * row_h, w - 24, row_h - 4)
        c.button("rc_horse_" + str(k), "", row, false, true)
        cloth(c, k, Rect2(row.position.x + 8, row.position.y + 10, 26, 26))
        horse_sprite(c, Vector2(row.position.x + 62, row.position.y + row_h - 8), 1.0, h, j, k, 1)
        c.txt(String(h.name), row.position.x + 92, row.position.y + 22, 14, c.ink, 170)
        var cond = int(rc.cond[k])
        c.txt(String(j.name) + " · " + STYLE_NAME[int(h.style)] + " · " + trend_text(h) + ("  ↑" if cond >= 3 else ("  ↓" if cond <= -3 else "")), row.position.x + 92, row.position.y + 42, 10, Color("c8323c") if cond >= 3 else c.muted, 190)
        var o = odds(rc, 0, [k])
        var pop = popularity(rc, k)
        c.txt(str(o) + "배", row.end.x - 98, row.position.y + 24, 16, Color("c8323c") if pop == 1 else c.ink, 86, HORIZONTAL_ALIGNMENT_RIGHT)
        c.txt(str(pop) + "번 인기", row.end.x - 98, row.position.y + 42, 10, c.muted, 86, HORIZONTAL_ALIGNMENT_RIGHT)
    var by = c.h - 132
    if not slip.is_empty(): c.txt("산 마권 " + str(slip.size()) + "장 · " + fmt(slip_total()) + "원", 20, by - 8, 12, Color("ffd84a"))
    var bw = (w - 52) / 2.0
    c.button("rc_bet", "마권 사기", Rect2(20, by, bw, 54), false, true, 16)
    c.button("rc_start", "출발!" if not slip.is_empty() else "구경만 하기", Rect2(32 + bw, by, bw, 54), true, true, 16)
    c.button("rc_lobby", "← 오늘의 경주", Rect2(20, c.h - 70, w - 40, 50), false, true, 13)

func slip_total() -> int:
    var t = 0
    for b in slip: t += int(b.amount)
    return t

func stat_bar(c, label: String, value: float, y: float, color: Color) -> void:
    c.txt(label, 24, y + 12, 12, c.ink)
    c.bar(Rect2(92, y + 2, c.w - 160, 12), clampf(value / 100.0, 0, 1), color)
    c.txt(str(int(value)), c.w - 62, y + 13, 12, c.muted, 40, HORIZONTAL_ALIGNMENT_RIGHT)

func horse_comment(h: Dictionary, rc: Dictionary, slot: int) -> String:
    var notes: PackedStringArray = []
    var gap = int(rc.dist) - int(h.best)
    if absi(gap) <= 200: notes.append("거리가 딱 맞아요")
    elif gap > 0: notes.append("오늘 거리는 조금 길어요")
    else: notes.append("오늘 거리는 조금 짧아요")
    if int(rc.track) >= 2:
        if int(h.wet) >= 4: notes.append("젖은 주로를 좋아해요")
        elif int(h.wet) <= -4: notes.append("젖은 주로에 약해요")
    var avg = recent_avg(h)
    if avg <= 2.5: notes.append("최근 기세가 무서워요")
    elif avg >= 6.0: notes.append("요즘 부진해요")
    var cond = int(rc.cond[slot])
    if cond >= 3: notes.append("오늘 몸이 가벼워 보여요")
    elif cond <= -3: notes.append("몸이 무거워 보여요")
    return " · ".join(notes)

func draw_horse(c) -> void:
    var w = c.w
    var rc = race()
    var h = horse_at(pick_slot)
    var j = jockey_at(pick_slot)
    var ji = int(rc.jock[pick_slot])
    header(c, String(h.name), str(ri + 1) + "R " + str(pick_slot + 1) + "번 · " + str(int(h.age)) + "세 " + String(h.sex) + " · " + String(COATS[int(h.coat)][2]) + " · " + str(int(h.kg)) + "kg(" + ("+" if int(rc.wt[pick_slot]) >= 0 else "") + str(int(rc.wt[pick_slot])) + ")")
    c.panel(Rect2(12, 100, w - 24, 150), Color("8fc0d8"), 14)
    c.draw_rect(Rect2(12, 200, w - 24, 50), Color("6fa05a"))
    horse_sprite(c, Vector2(w * 0.5, 238), 4.0, h, j, pick_slot, int(game.clock_time * 9.0))
    cloth(c, pick_slot, Rect2(24, 112, 40, 40))
    var y = 262
    c.panel(Rect2(12, y, w - 24, 196), Color("fff8e8"), 14)
    stat_bar(c, "스피드", float(h.spd), y + 12, Color("c8323c"))
    stat_bar(c, "스태미나", float(h.sta), y + 36, Color("3f6fd0"))
    stat_bar(c, "순발력", float(h.acc), y + 60, Color("f08a3c"))
    stat_bar(c, "근성", float(h.guts), y + 84, Color("8a5fc0"))
    stat_bar(c, "컨디션", 50.0 + float(rc.cond[pick_slot]) * 10.0, y + 108, Color("3f9a52"))
    c.txt("습성 " + STYLE_NAME[int(h.style)] + " — " + STYLE_LINE[int(h.style)], 24, y + 146, 11, c.ink)
    c.txt("최적 거리 " + str(int(h.best)) + "m · 젖은 주로 " + ("강함" if int(h.wet) >= 4 else ("약함" if int(h.wet) <= -4 else "보통")), 24, y + 166, 11, c.ink)
    c.txt("통산 " + str(int(h.starts)) + "전 " + str(int(h.wins)) + "승 · 2착 " + str(int(h.seconds)) + " · 3착 " + str(int(h.thirds)), 24, y + 186, 11, c.muted)
    y += 206
    c.panel(Rect2(12, y, w - 24, 74), Color("fff8e8"), 14)
    c.txt("최근 5전", 24, y + 22, 12, c.ink)
    for k in range(h.recent.size()):
        var place = int(h.recent[k])
        var tone = Color("e0a020") if place == 1 else (Color("9aa4ad") if place == 2 else (Color("b0602e") if place == 3 else Color("d8d2c4")))
        c.panel(Rect2(96 + k * 44, y + 8, 38, 26), tone, 6)
        c.txt(str(place) + "착", 96 + k * 44, y + 26, 12, c.ink, 38, HORIZONTAL_ALIGNMENT_CENTER)
    c.txt("기수 " + String(j.name) + " · 실력 " + str(int(j.skill)) + " · 통산 " + str(int(jwins[ji])) + "승", 24, y + 58, 12, c.ink)
    y += 84
    c.para("예상평: " + horse_comment(h, rc, pick_slot), 20, y + 12, w - 40, 12, Color("ffd84a"), 1.4)
    c.txt("단승 " + str(odds(rc, 0, [pick_slot])) + "배 · 연승 " + str(odds(rc, 1, [pick_slot])) + "배 · " + str(popularity(rc, pick_slot)) + "번 인기", 20, y + 48, 13, Color("fff8e8"))
    var bw = (w - 52) / 2.0
    c.button("rc_quickwin", "이 말에 걸기", Rect2(20, c.h - 132, bw, 54), true, not bool(rc.done), 15)
    c.button("rc_card", "← 출전표", Rect2(32 + bw, c.h - 132, bw, 54), false, true, 15)

func draw_bet(c) -> void:
    var w = c.w
    var rc = race()
    ensure_odds(rc)
    header(c, "마권 사기", str(ri + 1) + "R " + String(rc.name) + " · " + str(rc.dist) + "m")
    var y = 100
    var tw = (w - 24 - 3 * 6) / 4.0
    for k in range(BETS.size()):
        var r = Rect2(12 + (k % 4) * (tw + 6), y + int(k / 4) * 46, tw, 40)
        c.button("rc_type_" + str(k), String(BETS[k].name), r, k == bet_type, true, 14)
    y += 98
    c.txt(String(BETS[bet_type].name) + " — " + String(BETS[bet_type].line) + " (" + str(int(BETS[bet_type].n)) + "마리)", 16, y, 12, Color("ffd84a"))
    var cw = (w - 24 - 6) / 2.0
    for k in range(8):
        var r2 = Rect2(12 + (k % 2) * (cw + 6), y + 10 + int(k / 2) * 46, cw, 42)
        var chosen = bet_pick.find(k)
        c.button("rc_pick_" + str(k), "", r2, chosen >= 0, true)
        cloth(c, k, Rect2(r2.position.x + 6, r2.position.y + 8, 26, 26))
        c.txt(String(horse_at(k).name), r2.position.x + 38, r2.position.y + 18, 11, Color("fff8e8") if chosen >= 0 else c.ink, cw - 44)
        c.txt(str(odds(rc, 0, [k])) + "배", r2.position.x + 38, r2.position.y + 34, 10, Color("fff8e8") if chosen >= 0 else c.muted)
        if chosen >= 0 and bool(BETS[bet_type].order) and int(BETS[bet_type].n) > 1:
            c.txt(str(chosen + 1) + "착", r2.end.x - 40, r2.position.y + 28, 13, Color("ffd84a"), 34, HORIZONTAL_ALIGNMENT_RIGHT)
    y += 10 + 4 * 46 + 6
    var ready = bet_pick.size() == int(BETS[bet_type].n)
    var o = odds(rc, bet_type, bet_pick) if ready else 0.0
    c.panel(Rect2(12, y, w - 24, 46), Color("fff8e8"), 12)
    if ready: c.txt(pick_text(bet_type, bet_pick) + "   " + str(o) + "배  →  적중하면 " + fmt(int(floor(bet_amount * o))) + "원", 24, y + 29, 13, Color("c8323c"))
    else: c.txt("말을 " + str(int(BETS[bet_type].n) - bet_pick.size()) + "마리 더 골라 주세요" + (" (누른 순서가 착순)" if bool(BETS[bet_type].order) and int(BETS[bet_type].n) > 1 else ""), 24, y + 29, 13, c.muted)
    y += 54
    var aw = (w - 24 - 4 * 6) / 5.0
    for k in range(AMOUNTS.size()):
        c.button("rc_amount_" + str(AMOUNTS[k]), fmt(AMOUNTS[k]), Rect2(12 + k * (aw + 6), y, aw, 38), bet_amount == AMOUNTS[k], money >= AMOUNTS[k], 12)
    y += 46
    c.button("rc_buy", fmt(bet_amount) + "원 마권 구입", Rect2(12, y, w - 24, 50), true, ready and money >= bet_amount, 16)
    y += 58
    for k in range(mini(slip.size(), int((c.h - 150 - y) / 22.0))):
        var b = slip[k]
        c.txt(String(BETS[int(b.type)].name) + " " + pick_text(int(b.type), b.picks) + " · " + fmt(int(b.amount)) + "원 · " + str(b.odds) + "배", 20, y + 14 + k * 22, 12, Color("cfe0d2"))
    var bw = (w - 52) / 2.0
    c.button("rc_card", "← 출전표", Rect2(20, c.h - 70, bw, 50), false, true, 14)
    c.button("rc_start", "출발!", Rect2(32 + bw, c.h - 70, bw, 50), true, true, 16)

# 경주 화면: 옆에서 보는 주로, 선두를 따라가는 카메라
func draw_race(c) -> void:
    var w = c.w
    var hgt = c.h
    var rc = race()
    if live.is_empty(): return
    var s = live.s
    var order = lead_order(s)
    var lead_m = float(s.pos[int(order[0])])
    var ppm = w / 46.0
    var cam = clampf(lead_m - 30.0, -6.0, float(rc.dist) - 34.0)
    var top = 150.0
    var lane_h = 34.0
    var wet = int(rc.track)
    # 하늘 · 관중석 · 언덕
    c.draw_rect(Rect2(0, 0, w, hgt), Color("8fc0d8") if wet < 2 else Color("8fa4b0"))
    c.draw_rect(Rect2(0, 60, w, top - 60), Color("a8c890") if wet < 2 else Color("90a888"))
    for k in range(8):
        var hx = fposmod(k * 120.0 - cam * ppm * 0.3, w + 160) - 80
        c.draw_rect(Rect2(hx, 70 - (k % 3) * 10, 110, 30 + (k % 3) * 10), Color("7fa86a") if wet < 2 else Color("6f8a66"))
    var stand_x = (float(rc.dist) - 60.0 - cam) * ppm
    if stand_x > - 400 and stand_x < w + 50:
        c.draw_rect(Rect2(stand_x, 52, 380, 90), Color("d8d2c4"))
        c.draw_rect(Rect2(stand_x - 10, 44, 400, 12), Color("c8323c"))
        for k in range(60):
            c.draw_rect(Rect2(stand_x + 8 + (k % 20) * 18, 64 + int(k / 20) * 22 + (2 if int(game.clock_time * 6 + k) % 2 == 0 else 0), 8, 10), Color(CLOTH[k % 8]))
    if wet >= 2:
        for k in range(40):
            var rx = fposmod(k * 53.0 + game.clock_time * 90.0, w)
            var ry = fposmod(k * 37.0 + game.clock_time * 420.0, hgt * 0.6)
            c.draw_rect(Rect2(rx, ry, 2, 10), Color(1, 1, 1, 0.45))
    # 주로
    var ground = [Color("c89a68"), Color("b88a5a"), Color("8a6a48"), Color("6f5238")][wet]
    c.draw_rect(Rect2(0, top, w, lane_h * 8 + 30), ground)
    for k in range(9): c.draw_rect(Rect2(0, top + 12 + k * lane_h, w, 1), Color(0, 0, 0, 0.08))
    # 난간과 거리 표지
    c.draw_rect(Rect2(0, top - 6, w, 4), Color("f4f4f4"))
    c.draw_rect(Rect2(0, top + lane_h * 8 + 26, w, 4), Color("f4f4f4"))
    var first_post = int(floor(cam / 5.0)) * 5
    for m in range(first_post, first_post + 60, 5):
        var px = (m - cam) * ppm
        c.draw_rect(Rect2(px, top - 14, 3, 12), Color("f4f4f4"))
        c.draw_rect(Rect2(px, top + lane_h * 8 + 26, 3, 14), Color("f4f4f4"))
        var to_go = int(rc.dist) - m
        if to_go > 0 and to_go % 200 == 0:
            c.panel(Rect2(px - 18, top - 40, 40, 24), Color("fff8e8"), 4, Color("1f1a22"))
            c.txt(str(to_go), px - 18, top - 22, 12, Color("1f1a22"), 40, HORIZONTAL_ALIGNMENT_CENTER)
    var fin = (float(rc.dist) - cam) * ppm
    if fin > -20 and fin < w + 20:
        for k in range(12): c.draw_rect(Rect2(fin, top - 20 + k * 26, 6, 13), Color("c8323c") if k % 2 == 0 else Color("f4f4f4"))
        c.draw_rect(Rect2(fin - 2, top - 40, 10, 20), Color("ffd84a"))
    if float(live.gate) > 0.0:
        var gx = (0.0 - cam) * ppm
        for k in range(9): c.draw_rect(Rect2(gx, top + 4 + k * lane_h, 18, 8), Color("9aa4ad"))
    # 말 (뒤쪽 칸부터)
    for k in range(8):
        var h = horse_at(k)
        var x = (float(s.pos[k]) - cam) * ppm
        var foot = Vector2(x, top + 34 + k * lane_h)
        if x < -60 or x > w + 60: continue
        var running = float(live.gate) <= 0.0 and float(s.done[k]) < 0.0
        var frame = int(float(s.phase[k])) if running or float(live.end) >= 0.0 else 1
        if running and game.effects_on:
            for d in range(3): c.draw_rect(Rect2(foot.x - 44 - d * 10 - fposmod(game.clock_time * 80.0 + k * 13 + d * 7, 12), foot.y - 4 - d * 2, 6, 4), Color(1, 1, 1, 0.35))
        horse_sprite(c, foot, 1.8, h, jockey_at(k), k, frame)
        cloth(c, k, Rect2(foot.x + 30, foot.y - 46, 20, 20))
    # 위쪽 정보
    c.panel(Rect2(0, 0, w, 44), Color("13261ee6"), 0)
    var to_finish = maxf(0.0, float(rc.dist) - lead_m)
    c.txt(str(ri + 1) + "R " + String(rc.name), 14, 28, 15, Color("fff8e8"))
    c.txt("남은 " + str(int(to_finish)) + "m" if float(live.gate) <= 0.0 else "출발 " + str(int(ceil(float(live.gate)))), w - 150, 28, 15, Color("ffd84a"), 136, HORIZONTAL_ALIGNMENT_RIGHT)
    if float(live.gate) > 0.0:
        c.txt(str(int(ceil(float(live.gate)))), 0, top + 150, 80, Color("fff8e8"), w, HORIZONTAL_ALIGNMENT_CENTER)
    # 아래쪽: 순위 · 전체 지도 · 중계
    var by = top + lane_h * 8 + 50
    c.panel(Rect2(0, by, w, hgt - by), Color("13261e"), 0)
    c.txt("순위", 14, by + 24, 12, Color("cfe0d2"))
    for k in range(8): cloth(c, int(order[k]), Rect2(56 + k * 44, by + 6, 36, 28))
    var map_y = by + 50
    c.draw_rect(Rect2(20, map_y, w - 40, 6), Color("6f8a66"))
    for k in range(8):
        var mx = 20 + (w - 40) * clampf(float(s.pos[k]) / float(rc.dist), 0, 1)
        c.draw_rect(Rect2(mx - 4, map_y - 4, 8, 14), Color(CLOTH[k]))
    var ly = map_y + 36
    for line in live.lines:
        c.para(String(line), 18, ly, w - 36, 14, Color("fff8e8"), 1.35); ly += 40
    var my_y = hgt - 150
    if not slip.is_empty():
        var parts: PackedStringArray = []
        for b in slip: parts.append(String(BETS[int(b.type)].name) + " " + pick_text(int(b.type), b.picks))
        c.para("내 마권: " + ", ".join(parts), 18, my_y, w - 36, 11, Color("ffd84a"), 1.35)
    var bw = (w - 52) / 2.0
    c.button("rc_fast", "빨리 ×3" if speedup < 2.0 else "보통 속도", Rect2(20, hgt - 70, bw, 50), false, true, 14)
    c.button("rc_skip", "결과 바로 보기", Rect2(32 + bw, hgt - 70, bw, 50), false, true, 14)

func draw_result(c) -> void:
    var w = c.w
    var rc = race()
    header(c, str(ri + 1) + "R 결과", String(rc.name) + " · " + str(rc.dist) + "m · " + TRACK_NAME[int(rc.track)])
    var order = rc.order
    var y = 100
    var avg_v = float(rc.dist) / maxf(1.0, float(rc.times[0]))
    for k in range(3):
        var slot = int(order[k])
        var r = Rect2(12, y + k * 58, w - 24, 52)
        c.panel(r, [Color("ffe9a8"), Color("e8ecef"), Color("f0d8c4")][k], 12)
        c.txt(str(k + 1) + "착", r.position.x + 12, r.position.y + 32, 18, c.ink)
        cloth(c, slot, Rect2(r.position.x + 62, r.position.y + 12, 28, 28))
        c.txt(String(horse_at(slot).name), r.position.x + 100, r.position.y + 24, 15, c.ink)
        var gap = "" if k == 0 else margin_text((float(rc.times[k]) - float(rc.times[k - 1])) * avg_v)
        c.txt(String(jockey_at(slot).name) + (" · " + gap if gap != "" else " · " + str(snappedf(float(rc.times[0]), 0.1)) + "초"), r.position.x + 100, r.position.y + 42, 11, c.muted)
        c.txt(str(popularity(rc, slot)) + "번 인기", r.end.x - 96, r.position.y + 32, 12, c.muted, 84, HORIZONTAL_ALIGNMENT_RIGHT)
    y += 3 * 58 + 6
    # 배당표
    c.panel(Rect2(12, y, w - 24, 7 * 24 + 16), Color("fff8e8"), 12)
    var a = int(order[0])
    var b2 = int(order[1])
    var c3 = int(order[2])
    var table = [
        ["단승", [a], 0], ["연승", [a], 1], ["복승", [a, b2], 2], ["쌍승", [a, b2], 3], ["복연승", [a, b2], 4], ["삼복승", [a, b2, c3], 5], ["삼쌍승", [a, b2, c3], 6]]
    for k in range(table.size()):
        var ty = y + 22 + k * 24
        var type = int(table[k][2])
        c.txt(String(table[k][0]), 26, ty, 12, c.ink)
        c.txt(pick_text(type, table[k][1]), 110, ty, 12, c.ink)
        c.txt(str(odds(rc, type, table[k][1])) + "배", w - 130, ty, 13, Color("c8323c"), 104, HORIZONTAL_ALIGNMENT_RIGHT)
    y += 7 * 24 + 26
    if settle.has("rows") and not settle.rows.is_empty():
        for k in range(mini(settle.rows.size(), int((c.h - 210 - y) / 22.0))):
            var row = settle.rows[k]
            var bet = row.b
            c.txt(("적중! " if bool(row.hit) else "낙첨  ") + String(BETS[int(bet.type)].name) + " " + pick_text(int(bet.type), bet.picks) + " · " + fmt(int(bet.amount)) + "원" + (" → " + fmt(int(row.won)) + "원" if bool(row.hit) else ""), 20, y + 14 + k * 22, 12, Color("ffd84a") if bool(row.hit) else Color("9fb3a6"))
        var net = int(settle.paid) - int(settle.spent)
        var big = net > 0
        c.txt(("+" if big else "") + fmt(net) + "원", 0, c.h - 150, 30 if big else 22, Color("ffd84a") if big else Color("cfe0d2"), w, HORIZONTAL_ALIGNMENT_CENTER)
        if big and game.effects_on:
            for k in range(24):
                var fall = fposmod(game.clock_time * (90.0 + (k % 5) * 30.0) + k * 47.0, c.h)
                c.draw_rect(Rect2(fposmod(k * 83.0, w), fall, 6, 8), Color(CLOTH[k % 8]))
    else: c.txt("이번 경주는 구경만 했어요", 0, c.h - 150, 14, Color("cfe0d2"), w, HORIZONTAL_ALIGNMENT_CENTER)
    var bw = (w - 52) / 2.0
    c.button("rc_lobby", "오늘의 경주", Rect2(20, c.h - 70, bw, 50), false, true, 14)
    c.button("rc_next", "다음 경주 →" if ri < 5 else "하루 정리", Rect2(32 + bw, c.h - 70, bw, 50), true, true, 15)
