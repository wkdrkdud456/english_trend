extends RefCounted
# ── 도시 미션용 퍼즐 ──────────────────────────────────────────
# lights : 누르면 자신과 이웃이 뒤집힌다. 전부 켜면 성공
# code   : 숨은 문양 순서를 추리한다 (자리까지 맞음 / 문양만 맞음)
# simon  : 불이 켜진 순서를 외워서 따라 누른다
# match  : 같은 그림 두 장을 찾는다. 실수 한도를 넘으면 다시 섞인다
# timing : 움직이는 표시가 구간 안에 있을 때 누른다

var game
var kind = ""
var title = ""
var note = ""
var message = ""
var solved = false
var done_t = 0.0
var moves = 0
# lights
var n = 3
var cells: Array = []
var start_cells: Array = []
# code
var slots = 4
var symbols = 4
var tries = 6
var secret: Array = []
var guess: Array = []
var history: Array = []
# simon
var seq: Array = []
var round_len = 3
var goal_len = 5
var show_i = 0
var show_t = 0.0
var input_i = 0
var showing = true
var flash_pad = -1
var flash_t = 0.0
var pad_names: Array = []
# match
var cols = 4
var open_a = -1
var open_b = -1
var hide_t = 0.0
var found: Array = []
var misses = 0
var miss_limit = 8
# timing
var pos = 0.0
var dir = 1.0
var speed = 0.8
var zone_c = 0.5
var zone_w = 0.26
var hits = 0
var need = 3

const SYM_COLOR = ["e5b33c", "4a8fb8", "c8553d", "5fa55a", "8a5fc0", "d977a8", "3aa39a", "8a6a4c"]
const PAD_COLOR = ["c8553d", "4a8fb8", "e5b33c", "5fa55a"]

func _init(owner) -> void:
    game = owner

func start(k: String, level: int, heading: String, guide: String) -> void:
    kind = k; title = heading; note = guide; message = ""
    solved = false; done_t = 0.0; moves = 0
    level = clampi(level, 0, 3)
    match kind:
        "lights":
            n = 4 if level >= 3 else 3
            cells = []
            for i in range(n * n): cells.append(true)
            var presses = [3, 4, 5, 6][level]
            var used = []
            while used.size() < presses:
                var pick = randi_range(0, n * n - 1)
                if used.has(pick): continue
                used.append(pick); flip(pick)
            if not cells.has(false): flip(0)
            start_cells = cells.duplicate()
        "code":
            slots = [3, 4, 4, 4][level]; symbols = [4, 4, 5, 6][level]; tries = [6, 7, 8, 8][level]
            new_secret()
        "simon":
            goal_len = [4, 5, 6, 7][level]; round_len = 3
            seq = []
            for i in range(goal_len): seq.append(randi_range(0, 3))
            begin_show()
        "match":
            cols = 4
            var pairs = 8 if level >= 2 else 6
            miss_limit = [9, 8, 10, 9][level]
            shuffle_cards(pairs)
        "timing":
            need = [3, 4, 5, 6][level]; hits = 0
            speed = 0.75 + level * 0.12; zone_w = 0.28 - level * 0.02
            pos = 0.0; dir = 1.0; zone_c = randf_range(0.25, 0.75)

func flip(i: int) -> void:
    var x = i % n
    var y = int(i / n)
    for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
        var cx = x + d.x
        var cy = y + d.y
        if cx < 0 or cy < 0 or cx >= n or cy >= n: continue
        cells[cy * n + cx] = not cells[cy * n + cx]

func new_secret() -> void:
    secret = []; guess = []; history = []
    for i in range(slots): secret.append(randi_range(0, symbols - 1))

func begin_show() -> void:
    showing = true; show_i = 0; show_t = 0.6; input_i = 0; flash_pad = -1; flash_t = 0.0

func shuffle_cards(pairs: int) -> void:
    cells = []
    for i in range(pairs):
        cells.append(i); cells.append(i)
    cells.shuffle()
    found = []
    for i in range(cells.size()): found.append(false)
    open_a = -1; open_b = -1; hide_t = 0.0; misses = 0

func win(text: String) -> void:
    solved = true; done_t = 1.0; message = text
    game.chime(1174)

func tick(dt: float) -> void:
    if solved:
        done_t -= dt
        if done_t <= 0: game.tour.puzzle_done()
        return
    if kind == "simon":
        flash_t = maxf(0.0, flash_t - dt)
        if flash_t <= 0: flash_pad = -1
        if showing:
            show_t -= dt
            if show_t <= 0:
                if show_i >= round_len:
                    showing = false; message = "이제 같은 순서로 눌러요."
                else:
                    flash_pad = int(seq[show_i]); flash_t = 0.42; show_i += 1; show_t = 0.62
                    game.chime(440 + flash_pad * 110)
    elif kind == "match":
        if hide_t > 0:
            hide_t -= dt
            if hide_t <= 0:
                open_a = -1; open_b = -1
                if misses > miss_limit:
                    shuffle_cards(int(cells.size() / 2)); message = "실수가 많아 카드가 다시 섞였어요."
    elif kind == "timing":
        pos += dir * speed * dt
        if pos >= 1.0:
            pos = 1.0; dir = -1.0
        elif pos <= 0.0:
            pos = 0.0; dir = 1.0

func press(id: String) -> void:
    if solved: return
    if id == "close":
        game.tour.puzzle_cancel(); return
    match kind:
        "lights":
            if id == "reset":
                cells = start_cells.duplicate(); moves = 0; message = "처음 모양으로 되돌렸어요."; return
            var i = int(id)
            if i < 0 or i >= cells.size(): return
            flip(i); moves += 1; game.chime(520 + (i % 3) * 60)
            if not cells.has(false): win("모두 밝혀졌어요!  " + str(moves) + "번 만에 성공")
        "code":
            if id == "back":
                if not guess.is_empty(): guess.pop_back()
                return
            if id == "ok":
                if guess.size() < slots: return
                var exact = 0
                var near = 0
                var rest_secret = []
                var rest_guess = []
                for i in range(slots):
                    if int(guess[i]) == int(secret[i]): exact += 1
                    else:
                        rest_secret.append(int(secret[i])); rest_guess.append(int(guess[i]))
                for value in rest_guess:
                    var at = rest_secret.find(value)
                    if at >= 0:
                        near += 1; rest_secret.remove_at(at)
                history.append([guess.duplicate(), exact, near]); guess = []
                if exact == slots: win("정답!  " + str(history.size()) + "번 만에 풀었어요"); return
                game.chime(330)
                if history.size() >= tries:
                    new_secret(); message = "기회를 다 썼어요. 문양이 새로 바뀌었어요."
                return
            if id.begins_with("s") and guess.size() < slots:
                guess.append(clampi(int(id.trim_prefix("s")), 0, symbols - 1)); game.chime(600)
        "simon":
            if showing or not id.begins_with("p"): return
            var pad = int(id.trim_prefix("p"))
            flash_pad = pad; flash_t = 0.2
            if pad != int(seq[input_i]):
                game.chime(220); message = "순서가 달라요. 다시 보여줄게요."; begin_show(); return
            game.chime(440 + pad * 110); input_i += 1
            if input_i >= round_len:
                if round_len >= goal_len: win("완벽해요!  " + str(goal_len) + "개를 모두 외웠어요"); return
                round_len += 1; message = "좋아요! 하나 더 길어져요."; begin_show()
        "match":
            if hide_t > 0: return
            var card = int(id)
            if card < 0 or card >= cells.size() or found[card] or card == open_a: return
            game.chime(560)
            if open_a < 0:
                open_a = card; return
            open_b = card; moves += 1
            if int(cells[open_a]) == int(cells[open_b]):
                found[open_a] = true; found[open_b] = true; open_a = -1; open_b = -1; game.chime(880)
                if not found.has(false): win("모두 찾았어요!  " + str(moves) + "번 뒤집었어요")
            else:
                misses += 1; hide_t = 0.7
        "timing":
            if id != "hit": return
            if absf(pos - zone_c) <= zone_w / 2.0:
                hits += 1; game.chime(700 + hits * 80)
                if hits >= need: win("딱 맞췄어요!"); return
                zone_w = maxf(0.1, zone_w * 0.86); speed *= 1.1; zone_c = randf_range(0.2, 0.8)
                message = "좋아요!  " + str(hits) + " / " + str(need)
            else:
                hits = maxi(0, hits - 1); game.chime(220)
                message = "빗나갔어요. 성공 횟수가 하나 줄었어요."

# ── 그리기 ────────────────────────────────────────────────
func sym(c, id: int, p: Vector2, r: float) -> void:
    var tone = Color(SYM_COLOR[id % SYM_COLOR.size()])
    match id % 5:
        0: c.draw_circle(p, r, tone)
        1: c.draw_rect(Rect2(p.x - r * 0.85, p.y - r * 0.85, r * 1.7, r * 1.7), tone)
        2: c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, - r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(- r, 0)]), tone)
        3: c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, - r), p + Vector2(r, r * 0.85), p + Vector2(- r, r * 0.85)]), tone)
        _:
            c.draw_circle(p, r, tone); c.draw_circle(p, r * 0.5, c.cream)
    if id >= 5: c.draw_rect(Rect2(p.x - 2, p.y - 2, 4, 4), c.ink)

func draw(c) -> void:
    var w = c.w
    var h = c.h
    c.panel(Rect2(0, 0, w, h), c.cream, 0)
    c.panel(Rect2(0, 0, w, 150), Color("294b46"), 0)
    c.txt(String(game.city().name) + "의 수수께끼", 26, 52, 12, c.gold)
    c.txt(title, 24, 92, 26, c.cream)
    c.txt(note, 26, 124, 13, Color("cfdcd4"))
    match kind:
        "lights": draw_lights(c, w, h)
        "code": draw_code(c, w, h)
        "simon": draw_simon(c, w, h)
        "match": draw_match(c, w, h)
        _: draw_timing(c, w, h)
    if message != "": c.txt(message, 24, h - 108, 14, c.rose, w - 48, HORIZONTAL_ALIGNMENT_CENTER)
    if solved:
        c.panel(Rect2(40, h / 2 - 50, w - 80, 100), Color("294b46"), 18)
        c.txt("성공!", 40, h / 2 + 12, 34, c.cream, w - 80, HORIZONTAL_ALIGNMENT_CENTER)
    else:
        c.button("pz_close", "나중에 다시 할게", Rect2(24, h - 82, w - 48, 54), false, true, 14)

func draw_lights(c, w: float, h: float) -> void:
    var gap = 10.0
    var cell = minf(104.0, (w - 60 - gap * (n - 1)) / n)
    var x0 = (w - (cell * n + gap * (n - 1))) / 2.0
    var y0 = 196.0
    for i in range(cells.size()):
        var r = Rect2(x0 + (i % n) * (cell + gap), y0 + int(i / n) * (cell + gap), cell, cell)
        var on = bool(cells[i])
        c.plate(r, Color("c79233") if on else Color("4c565e"), Color("f6d98b") if on else Color("6a757d"), 16, 4)
        if on: c.draw_circle(r.get_center(), cell * 0.2, Color("fff4cd"))
        if not solved: c.buttons["pz_" + str(i)] = r
    var by = y0 + n * (cell + gap) + 8
    c.txt("누른 횟수 " + str(moves), 24, by + 24, 14, c.muted)
    c.txt("누르면 자신과 위·아래·양옆이 함께 바뀌어요", 24, by + 46, 12, c.muted)
    if not solved: c.button("pz_reset", "처음으로", Rect2(w - 132, by, 108, 44), false, true, 13)

func draw_code(c, w: float, h: float) -> void:
    var y = 172.0
    c.txt("남은 기회 " + str(tries - history.size()), 24, y + 4, 13, c.muted)
    c.txt("● 자리까지 맞음   ○ 문양만 맞음", w - 250, y + 4, 12, c.muted, 226, HORIZONTAL_ALIGNMENT_RIGHT)
    y += 16
    var row_h = minf(40.0, (h - 510.0) / tries)
    for i in range(history.size()):
        var entry = history[i]
        c.panel(Rect2(24, y + i * row_h, w - 48, row_h - 4), Color("f1e6cf"), 10)
        for k in range(slots): sym(c, int(entry[0][k]), Vector2(52 + k * 40, y + i * row_h + row_h / 2 - 2), row_h * 0.3)
        c.txt("● " + str(entry[1]) + "   ○ " + str(entry[2]), w - 150, y + i * row_h + row_h / 2 + 3, 15, c.ink, 120, HORIZONTAL_ALIGNMENT_RIGHT)
    var gy = h - 316.0
    c.plate(Rect2(24, gy, w - 48, 62), c.ink)
    for k in range(slots):
        var p = Vector2(64 + k * 56, gy + 30)
        if k < guess.size(): sym(c, int(guess[k]), p, 17)
        else: c.draw_arc(p, 16, 0, TAU, 24, Color("c9bfa8"), 2, true)
    if solved: return
    c.button("pz_back", "지우기", Rect2(w - 124, gy + 9, 92, 44), false, not guess.is_empty(), 13)
    var bw = (w - 48 - (symbols - 1) * 8) / float(symbols)
    for k in range(symbols):
        var r = Rect2(24 + k * (bw + 8), gy + 74, bw, 56)
        c.plate(r, Color("8d8578"), c.cream, 14, 3)
        sym(c, k, r.get_center() - Vector2(0, 1), 15)
        c.buttons["pz_s" + str(k)] = r
    c.button("pz_ok", "이 순서로 확인", Rect2(24, gy + 140, w - 48, 50), true, guess.size() == slots, 15)

func draw_simon(c, w: float, h: float) -> void:
    var size = minf(170.0, (w - 70) / 2.0)
    var x0 = (w - size * 2 - 14) / 2.0
    var y0 = 210.0
    for i in range(4):
        var r = Rect2(x0 + (i % 2) * (size + 14), y0 + int(i / 2) * (size + 14), size, size)
        var tone = Color(PAD_COLOR[i])
        var lit = flash_pad == i
        c.plate(r, tone.darkened(0.3), tone.lightened(0.45) if lit else tone.darkened(0.12), 22, 5)
        if pad_names.size() == 4: c.txt(String(pad_names[i]), r.position.x, r.get_center().y + 7, 20, c.cream, size, HORIZONTAL_ALIGNMENT_CENTER)
        if not solved and not showing: c.buttons["pz_p" + str(i)] = r
    var by = y0 + size * 2 + 34
    c.txt("잘 보고 외워요…" if showing else "따라 누르기  " + str(input_i) + " / " + str(round_len), 24, by, 18, c.ink, w - 48, HORIZONTAL_ALIGNMENT_CENTER)
    c.txt("목표 " + str(goal_len) + "개 · 지금 " + str(round_len) + "개", 24, by + 26, 12, c.muted, w - 48, HORIZONTAL_ALIGNMENT_CENTER)

func draw_match(c, w: float, h: float) -> void:
    var gap = 8.0
    var rows = int(cells.size() / cols)
    var cell = minf((w - 48 - gap * (cols - 1)) / cols, (h - 330.0 - gap * (rows - 1)) / rows)
    var x0 = (w - (cell * cols + gap * (cols - 1))) / 2.0
    var y0 = 176.0
    for i in range(cells.size()):
        var r = Rect2(x0 + (i % cols) * (cell + gap), y0 + int(i / cols) * (cell + gap), cell, cell)
        var face = bool(found[i]) or i == open_a or i == open_b
        if face:
            c.plate(r, Color("4a8a38") if bool(found[i]) else c.ink, c.cream, 12, 3)
            sym(c, int(cells[i]), r.get_center(), cell * 0.26)
        else:
            c.plate(r, Color("1f3a36"), Color("294b46"), 12, 3)
            c.txt("?", r.position.x, r.get_center().y + 9, 24, Color("6f8a84"), cell, HORIZONTAL_ALIGNMENT_CENTER)
            if not solved: c.buttons["pz_" + str(i)] = r
    c.txt("남은 실수 " + str(maxi(0, miss_limit - misses + 1)) + "   ·   뒤집은 횟수 " + str(moves), 24, y0 + rows * (cell + gap) + 20, 13, c.muted, w - 48, HORIZONTAL_ALIGNMENT_CENTER)

func draw_timing(c, w: float, h: float) -> void:
    var bar = Rect2(36, 300, w - 72, 46)
    c.plate(Rect2(bar.position.x - 4, bar.position.y - 4, bar.size.x + 8, bar.size.y + 8), c.ink, Color("6fa3a8"), 14, 3)
    c.panel(Rect2(bar.position.x + (zone_c - zone_w / 2.0) * bar.size.x, bar.position.y + 4, zone_w * bar.size.x, bar.size.y - 8), Color("f6d98b"), 8)
    c.panel(Rect2(bar.position.x + pos * bar.size.x - 5, bar.position.y - 12, 10, bar.size.y + 24), c.cream, 5, c.ink)
    c.txt("노란 구간에 들어왔을 때 눌러요", 24, 250, 15, c.ink, w - 48, HORIZONTAL_ALIGNMENT_CENTER)
    for i in range(need): c.panel(Rect2(w / 2 - need * 15 + i * 30, 380, 22, 22), c.gold if i < hits else Color("e0d8c6"), 7, c.ink)
    if not solved: c.button("pz_hit", "지금!", Rect2(w / 2 - 100, 440, 200, 110), true, true, 30)
