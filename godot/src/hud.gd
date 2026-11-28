extends Control

const BattleArt = preload ("res://scripts/battle_art.gd")
var battle_art = BattleArt.new()
const TourHud = preload ("res://scripts/tour_hud.gd")
var tour_hud = TourHud.new()
const FlatArt = preload ("res://scripts/flat_art.gd")
var flat_art = FlatArt.new()
var game: Node3D
var font: Font
var buttons: Dictionary = {}
var pressed: Dictionary = {}
var stick_id = -99
var stick_center = Vector2.ZERO
var stick_delta = Vector2.ZERO
var stick_radius = 62.0
var stick_reach = 44.0
var cream = Color("fff8e8")
var ink = Color("294b46")
var muted = Color("788277")
var gold = Color("e5b96f")
var rose = Color("cf8d77")
var safe_top = 22.0
var safe_bottom = 22.0
var w = 432.0
var h = 864.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP

func panel(rect: Rect2, color: Color = cream, radius: float = 22, border: Color = Color.TRANSPARENT) -> void:
    if game and (game.state in ["battle", "battle_ready", "battle_won", "battle_lost"] or (game.state == "pause" and game.previous_state == "battle")):
        radius = minf(radius, 5)
    var s = StyleBoxFlat.new(); s.bg_color = color
    s.set_corner_radius_all(int(radius)); s.border_color = border
    if border.a > 0: s.set_border_width_all(1)
    draw_style_box(s, rect)

func txt(text: String, x: float, y: float, size_px: int = 18, color: Color = ink, width_px: float = -1, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
    draw_string(font, Vector2(x, y), text, align, width_px, size_px, color)

func para(text: String, x: float, y: float, width_px: float, size_px: int = 18, color: Color = ink, leading: float = 1.65) -> float:
    var line = ""
    for ch in text:
        if ch == "\n" or (font.get_string_size(line + ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x > width_px and line != ""):
            txt(line, x, y, size_px, color); y += size_px * leading; line = ""
            if ch == "\n": continue
        line += ch
    if line != "": txt(line, x, y, size_px, color); y += size_px * leading
    return y

func centered(text: String, y: float, size_px: int = 18, color: Color = ink) -> void:
    txt(text, 0, y, size_px, color, w, HORIZONTAL_ALIGNMENT_CENTER)

func button(id: String, label: String, rect: Rect2, primary: bool = false, enabled: bool = true, size_px: int = 17) -> void:
    var minimum = Vector2(maxf(48, rect.size.x), maxf(44, rect.size.y))
    rect = Rect2(rect.position - (minimum - rect.size) / 2, minimum)
    var active = pressed.values().has(id)
    var face = ink if primary else cream
    var edge = Color("17302c") if primary else ink
    if not enabled:
        face = Color("dcd7c9"); edge = Color("aaa698")
    if active: face = face.darkened(0.12)
    var radius = minf(16.0, rect.size.y / 2.0)
    var lift = 0.0 if active else 3.0
    panel(Rect2(rect.position + Vector2(0, 3), rect.size), edge.darkened(0.25), radius)
    panel(Rect2(rect.position + Vector2(0, 3 - lift), rect.size), edge, radius)
    panel(Rect2(rect.position + Vector2(2, 5 - lift), rect.size - Vector2(4, 4)), face, maxf(3.0, radius - 2))
    var fg = cream if primary else ink
    if not enabled: fg = Color("8f8b7e")
    txt(label, rect.position.x, rect.position.y + 3 - lift + rect.size.y / 2 + size_px * 0.36, size_px, fg, rect.size.x, HORIZONTAL_ALIGNMENT_CENTER)
    if enabled: buttons[id] = rect

# 화면 위에 떠 있는 둥근 버튼
func float_button(id: String, label: String, center: Vector2, radius: float, tone: Color, icon: int, enabled: bool = true) -> void:
    var active = pressed.values().has(id)
    var face = cream if enabled else Color(0.86, 0.84, 0.78, 0.8)
    var edge = tone if enabled else Color(0.55, 0.54, 0.5, 0.8)
    if active: face = face.darkened(0.1)
    draw_circle(center + Vector2(0, 4), radius, Color(0.08, 0.1, 0.09, 0.3))
    draw_circle(center, radius, edge)
    draw_circle(center, radius - 3.5, face)
    var mid = center - Vector2(0, radius * 0.16 if label != "" else 0.0)
    var glyph = radius * 0.36
    match icon:
        0: icon_spark(mid, glyph)
        1: icon_book(mid, glyph)
        2: icon_map(mid, glyph)
        4: icon_pack(mid, glyph)
        _: icon_lens(mid, glyph)
    if label != "": txt(label, center.x - radius, center.y + radius * 0.62, 9, edge, radius * 2, HORIZONTAL_ALIGNMENT_CENTER)
    if enabled: buttons[id] = Rect2(center - Vector2(radius, radius), Vector2(radius * 2, radius * 2))

func chip(text: String, rect: Rect2, color: Color = cream) -> void:
    panel(rect, color, 30)
    txt(text, rect.position.x, rect.position.y + rect.size.y / 2 + 5, 13, ink, rect.size.x, HORIZONTAL_ALIGNMENT_CENTER)

func progress(rect: Rect2, value: float, color: Color = gold) -> void:
    panel(rect, Color("e3e6d6"), 8)
    if value > 0: panel(Rect2(rect.position, Vector2(maxf(8, rect.size.x * clampf(value, 0, 1)), rect.size.y)), color, 8)

const FLAT_STATES = ["reward_pick", "ride", "explore", "dialogue", "cook", "food_shop", "status", "city_help", "map", "title", "intro", "arrival"]

func flat_backdrop() -> bool:
    if not game or not game.world or game.world.flat.is_empty(): return false
    if game.state in FLAT_STATES: return true
    return game.state == "pause" and game.previous_state in FLAT_STATES

func col_deck() -> Color:
    return Color(game.city().pal.g2) if game.state in ["title", "intro", "arrival"] else Color("2a1c18")

func deck_height() -> float:
    return clampf(h * 0.33, 226, 304)

func flat_bottom() -> float:
    return h

func plate(rect: Rect2, border: Color, fill: Color = cream, radius: float = 16, lip: float = 3.0) -> void:
    panel(Rect2(rect.position + Vector2(2, 5), rect.size), Color(0.11, 0.07, 0.04, 0.20), radius)
    panel(rect, border, radius)
    panel(Rect2(rect.position + Vector2(lip, lip), rect.size - Vector2(lip * 2, lip * 2 + 1)), fill, maxf(4, radius - lip))

func bar(rect: Rect2, value: float, fg: Color, bg: Color = Color("e4d9c2")) -> void:
    panel(rect, bg, rect.size.y / 2)
    if value > 0: panel(Rect2(rect.position, Vector2(maxf(rect.size.y, rect.size.x * clampf(value, 0, 1)), rect.size.y)), fg, rect.size.y / 2)

func icon_coin(p: Vector2, s: float) -> void:
    draw_circle(p, s, Color("c79233")); draw_circle(p, s * 0.78, Color("f0c768"))
    draw_circle(p, s * 0.42, Color("e0ae4a"))

func icon_star(p: Vector2, s: float) -> void:
    var n = maxi(2, int(s))
    for i in range(n):
        var k = s * (1.0 - float(i) / n)
        draw_rect(Rect2(p.x - k, p.y - i - 1, k * 2, 2), Color("f0c052"))
        draw_rect(Rect2(p.x - k, p.y + i - 1, k * 2, 2), Color("f0c052"))

func icon_goal(p: Vector2, s: float) -> void:
    draw_circle(p, s, rose); draw_circle(p, s * 0.64, cream); draw_circle(p, s * 0.3, rose)

func icon_leaf(p: Vector2, s: float) -> void:
    draw_circle(p + Vector2(0, - s * 0.2), s, Color("7fae5e"))
    draw_rect(Rect2(p.x - 1, p.y - s, 2, s * 2), Color("46703a"))

func icon_book(p: Vector2, s: float) -> void:
    draw_rect(Rect2(p.x - s, p.y - s * 0.8, s * 2, s * 1.6), Color("4a8a9c"))
    draw_rect(Rect2(p.x - s + 2, p.y - s * 0.8 + 2, s * 2 - 4, s * 1.6 - 4), cream)
    draw_rect(Rect2(p.x - 1, p.y - s * 0.8, 2, s * 1.6), Color("4a8a9c"))

func icon_map(p: Vector2, s: float) -> void:
    draw_rect(Rect2(p.x - s, p.y - s * 0.8, s * 2, s * 1.6), Color("8aa86a"))
    draw_rect(Rect2(p.x - s * 0.34, p.y - s * 0.8, 2, s * 1.6), cream)
    draw_rect(Rect2(p.x + s * 0.34, p.y - s * 0.8, 2, s * 1.6), cream)

func icon_lens(p: Vector2, s: float) -> void:
    draw_arc(p + Vector2(- s * 0.2, - s * 0.2), s * 0.72, 0, TAU, 20, Color("5a7f93"), 3, true)
    draw_line(p + Vector2(s * 0.3, s * 0.3), p + Vector2(s * 0.95, s * 0.95), Color("5a7f93"), 3, true)

func icon_pack(p: Vector2, s: float) -> void:
    draw_rect(Rect2(p.x - s * 0.85, p.y - s * 0.55, s * 1.7, s * 1.5), Color("c85068"))
    draw_rect(Rect2(p.x - s * 0.85 + 2, p.y - s * 0.55 + 2, s * 1.7 - 4, s * 1.5 - 4), cream)
    draw_rect(Rect2(p.x - s * 0.4, p.y - s, s * 0.8, s * 0.45), Color("c85068"))
    draw_rect(Rect2(p.x - s * 0.3, p.y - s * 0.1, s * 0.6, s * 0.55), Color("c85068"))

func icon_spark(p: Vector2, s: float) -> void:
    draw_rect(Rect2(p.x - 2, p.y - s, 4, s * 2), Color("e8974d"))
    draw_rect(Rect2(p.x - s, p.y - 2, s * 2, 4), Color("e8974d"))
    draw_rect(Rect2(p.x - s * 0.55, p.y - s * 0.55, s * 1.1, s * 1.1), Color("f6c98a"))

func deck_button(id: String, label: String, sub: String, rect: Rect2, tone: Color, icon: int, enabled: bool = true) -> void:
    var face = cream if enabled else Color("cfc7b6")
    var edge = tone if enabled else Color("9d978a")
    var active = pressed.values().has(id)
    if active: face = face.darkened(0.10)
    panel(Rect2(rect.position + Vector2(3, 7), rect.size), Color(0.05, 0.03, 0.02, 0.40), 18)
    panel(rect, edge, 18)
    panel(Rect2(rect.position + Vector2(5, 5), rect.size - Vector2(10, 13)), face, 14)
    var mid = rect.position + Vector2(rect.size.x / 2, rect.size.y * 0.40)
    match icon:
        0: icon_spark(mid, 11)
        1: icon_book(mid, 11)
        2: icon_map(mid, 11)
        4: icon_pack(mid, 11)
        _: icon_lens(mid, 11)
    txt(label, rect.position.x, rect.position.y + rect.size.y - 17, 14, edge, rect.size.x, HORIZONTAL_ALIGNMENT_CENTER)
    if sub != "": txt(sub, rect.position.x, rect.position.y + rect.size.y - 4, 10, muted, rect.size.x, HORIZONTAL_ALIGNMENT_CENTER)
    if enabled: buttons[id] = rect

func _draw() -> void:
    if not game or not font: return
    w = get_viewport_rect().size.x; h = get_viewport_rect().size.y
    buttons.clear()
    if w > h:
        panel(Rect2(0, 0, w, h), cream, 0)
        centered("휴대폰을 세로로 돌려주세요", h / 2, 25)
        centered("이야기는 잠시 멈춰 있어요.", h / 2 + 40, 16, muted)
        return
    if game.state in ["battle", "battle_ready", "battle_won", "battle_lost"] or (game.state == "pause" and game.previous_state == "battle"):
        if game.shake > 0.3 and game.effects_on:
            draw_set_transform(Vector2(sin(game.clock_time * 91.0), cos(game.clock_time * 73.0)) * game.shake * 0.55, 0, Vector2.ONE)
        battle_art.draw(self)
        draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
    elif game.state == "photo":
        flat_art.postcard(self, Rect2(0, 0, w, h - 186), game.city_index, game)
    elif flat_backdrop():
        flat_art.draw(self, game)
    match game.state:
        "arrival", "passport", "journal", "city_help", "deduction", "memory_question", "food_shop", "vista", "vista_album": tour_hud.draw(self)
        "title": draw_title()
        "intro": draw_intro()
        "tutorial": draw_tutorial()
        "explore": draw_explore()
        "ride":
            plate(Rect2(40, safe_top + 10, w - 80, 46), ink, cream, 14)
            txt(String(game.ERRANDS[game.city_index].tool) + "을(를) 타고 건너는 중…", 40, safe_top + 39, 16, ink, w - 80, HORIZONTAL_ALIGNMENT_CENTER)
        "dialogue": draw_dialogue()
        "cook": draw_cook()
        "battle_ready": draw_battle_ready()
        "battle": draw_battle()
        "battle_lost": draw_battle_lost()
        "battle_won": draw_battle_won()
        "photo": draw_photo()
        "ending": tour_hud.ending(self)
        "puzzle": game.tour.pz.draw(self)
        "racing": game.racing.draw(self)
        "reward_pick": draw_reward_pick()
        "pause": draw_pause()
        "status": draw_status()
        "map": tour_hud.map_screen(self)
    tour_hud.weather(self)
    if game.toast_time > 0 and game.state not in ["ending", "title", "pause", "dialogue", "intro", "tutorial", "battle", "battle_ready", "battle_lost", "battle_won", "puzzle"]:
        var y = h * 0.32
        panel(Rect2(24, y, w - 48, 72), Color("294b46ef"), 17)
        para(game.toast_text, 40, y + 28, w - 80, 15, cream, 1.55)
    if game.flash > 0: draw_rect(Rect2(0, 0, w, h), Color(1, 0.97, 0.86, game.flash * 0.6))

func draw_title() -> void:
    panel(Rect2(0, 0, w, 226), Color("fff8e8ef"), 0)
    txt("OUR LITTLE JOURNEY", 28, 49, 12, muted)
    txt("너와 함께,", 26, 105, 43)
    txt("열 개의 도시.", 26, 157, 43)
    txt("가라! 동훈!  ·  둘의 세계여행", 29, 193, 15, muted)
    chip("%02d / 10     %s" % [game.route_pos() + 1, game.city().english], Rect2(w - 175, 242, 150, 34))
    var y = h - 350
    panel(Rect2(16, y, w - 32, 330), cream, 25)
    txt("잊었던 약속이, 다시 시작되는 곳.", 36, y + 36, 19)
    txt("서른 가지 야생 몬스터 · 열 개의 추억 도장", 36, y + 65, 13, muted)
    button("start", "여행 이어가기  →" if game.has_save else "파리로 출발  →", Rect2(32, y + 88, w - 64, 62), true)
    button("intro_replay", "처음 이야기 · 조작법 보기", Rect2(32, y + 160, w - 64, 54), false, true, 14)
    button("racing_open", "번외편 · 동훈 경마장", Rect2(32, y + 222, w - 64, 54), false, true, 14)
    txt("파리부터 서울까지  ·  터치 / 키보드  ·  자동 저장", 32, y + 308, 12, muted, w - 64, HORIZONTAL_ALIGNMENT_CENTER)

func top_bar(subtitle: String = "파리 · 첫 번째 도시") -> void:
    panel(Rect2(18, safe_top, 220, 52), cream, 18)
    txt(game.city().english, 32, safe_top + 23, 18)
    txt(game.city().subtitle if subtitle == "파리 · 첫 번째 도시" else subtitle, 32, safe_top + 42, 10, muted)
    chip(str(game.coins) + " 원", Rect2(w - 266, safe_top + 4, 84, 44))
    button("status", "Lv." + str(game.level), Rect2(w - 176, safe_top + 4, 92, 44), false, true, 15)
    button("pause", "Ⅱ", Rect2(w - 76, safe_top + 4, 54, 44), false, true, 19)

func draw_explore() -> void:
    var dy = flat_bottom()
    var top = safe_top + 6
    # ── 위쪽 카드들 (월드를 덜 가리게 얇게) ─────────────────
    var cw = w * 0.30
    plate(Rect2(14, top, cw, 44), ink, cream, 14)
    txt(game.city().name if game.area_index == 0 else String(game.world.AREA_NAMES[game.city_index][game.area_index - 1]), 26, top + 28, 17 if game.area_index == 0 else 13)
    var coin_x = 14 + cw + 6
    var coin_w = w * 0.20
    plate(Rect2(coin_x, top, coin_w, 44), rose, cream, 14)
    icon_coin(Vector2(coin_x + 17, top + 21), 8)
    txt(str(game.coins), coin_x + 30, top + 27, 16, rose)
    var lv_x = coin_x + coin_w + 6
    var lv_w = w - 14 - 48 - 6 - lv_x
    var lv_rect = Rect2(lv_x, top, lv_w, 44)
    plate(lv_rect, Color("4a8a38"), cream, 14)
    icon_star(Vector2(lv_x + 16, top + 16), 6)
    txt("Lv." + str(game.level), lv_x + 28, top + 21, 14, Color("3f7a32"))
    txt("도장 " + str(game.stamps()) + "/10", lv_x + lv_w - 70, top + 20, 10, muted, 60, HORIZONTAL_ALIGNMENT_RIGHT)
    bar(Rect2(lv_x + 10, top + 28, lv_w - 20, 7), float(game.xp) / maxf(1, game.exp_needed()), Color("86cc5e"))
    buttons["status_card"] = lv_rect
    var pause_rect = Rect2(w - 62, top, 48, 44)
    plate(pause_rect, ink, cream, 14)
    txt("Ⅱ", pause_rect.position.x, top + 29, 17, ink, 48, HORIZONTAL_ALIGNMENT_CENTER)
    buttons["pause"] = pause_rect

    # ── 목표 카드 ───────────────────────────────────────
    var oy = top + 50
    plate(Rect2(14, oy, w - 28, 44), ink, cream, 14)
    icon_goal(Vector2(34, oy + 21), 9)
    txt(game.tour.objective() if game.area_index == 0 else ("상자와 기억 조각을 찾아보기" if game.area_index == 2 else "골목을 둘러보고 상자 찾기"), 52, oy + 27, 15)
    var done = game.tour.progress_count() if game.stage == 0 else game.stage
    var total = game.tour.progress_total() if game.stage == 0 else 4
    for i in range(mini(total, 5)):
        var bx = w - 24 - (mini(total, 5) - i) * 19
        panel(Rect2(bx, oy + 14, 15, 15), Color("ffe36c") if i < done else Color("e6dcc6"), 5, ink)

    # ── 상황 칩 ─────────────────────────────────────────
    var sy = oy + 52
    if false:
        var low = game.tour.low_tide()
        var remaining = (4.0 if low else 7.0) - fmod(game.game_time, 7.0)
        plate(Rect2(14, sy, 206, 36), Color("4a8a38") if low else Color("c08a4e"))
        icon_leaf(Vector2(32, sy + 18), 7)
        txt( ("낮은 파도 · 회수 " if low else "높은 파도 · 대기 ") + str(ceili(remaining)) + "초", 46, sy + 23, 13, ink)
    elif game.chased():
        plate(Rect2(14, sy, 230, 40), rose)
        icon_leaf(Vector2(32, sy + 20), 7)
        txt("들켰다! 맞서거나 달아나요", 46, sy + 26, 13, ink)
    else:
        # 오늘의 의뢰와 여행 패스 — 누르면 목표 화면
        var done_q = game.daily_done()
        var goal_rect = Rect2(14, sy, 236, 40)
        plate(goal_rect, gold if done_q < 3 else Color("4a8a38"), cream, 12, 3)
        icon_star(Vector2(32, sy + 16), 6)
        txt("의뢰 " + str(done_q) + "/3 · 패스 Lv." + str(mini(game.pass_level, game.PASS_MAX)) + (" · 티켓 " + str(game.tickets) if game.tickets > 0 else ""), 46, sy + 19, 12, ink)
        bar(Rect2(46, sy + 26, 186, 6), float(game.pass_points % 100) / 100.0, gold)
        buttons["goals_open"] = goal_rect

    # ── 목표 방향 표시 ──────────────────────────────────
    var distance = game.hero.position.distance_to(game.target)
    if distance > 2 and game.world.marker and game.world.marker.visible:
        var tp = flat_art.at(game.target.x, game.target.z)
        tp.x = clampf(tp.x, 76, w - 76)
        tp.y = clampf(tp.y, sy + 58, h - 230)
        var tip = game.target_name + " · " + str(int(distance)) + "m"
        var tipw = minf(w - 28, font.get_string_size(tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 24)
        tp.x = clampf(tp.x, 14 + tipw / 2, w - 14 - tipw / 2)
        plate(Rect2(tp.x - tipw / 2, tp.y - 15, tipw, 30), Color("c08a4e"), Color("fff1c9"), 14, 2)
        txt(tip, tp.x - tipw / 2, tp.y + 5, 12, ink, tipw, HORIZONTAL_ALIGNMENT_CENTER)

    # ── 떠 있는 조작부 (월드를 가리지 않는다) ───────────────
    var base = h - maxf(14.0, safe_bottom)
    stick_radius = 58.0
    stick_reach = 38.0
    stick_center = Vector2(86, base - 84)
    draw_circle(stick_center, stick_radius, Color(1.0, 0.97, 0.91, 0.26))
    draw_arc(stick_center, stick_radius, 0, TAU, 44, Color(0.16, 0.29, 0.27, 0.55), 3, true)
    draw_circle(stick_center + stick_delta + Vector2(0, 4), 25, Color(0.08, 0.1, 0.09, 0.3))
    draw_circle(stick_center + stick_delta, 25, ink)
    draw_circle(stick_center + stick_delta, 22, cream)
    draw_circle(stick_center + stick_delta, 7, Color("c9bfa8"))

    var near_shop = game.tour.near_shop()
    var label = game.target_name if distance < 2.05 else "목표 안내"
    if game.stage == 4: label = "다시 사진"
    if near_shop and distance > 2.05: label = game.city().shop
    if game.city_index > 0 and game.area_index == 0: label = game.tour.action_label()
    var can_act = distance < 2.05 or near_shop
    var special = game.near_label()
    if special != "":
        label = special; can_act = special != "둘러보기"
    var act = Vector2(w - 64, base - 70)
    float_button("interact", "", act, 44, Color("e8974d"), 0, true)
    var lw = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 22
    var chip_rect = Rect2(minf(act.x - lw / 2, w - 12 - lw), act.y - 82, lw, 28)
    plate(chip_rect, Color("e8974d") if can_act else Color("8d8578"), cream, 12, 2)
    txt(label, chip_rect.position.x, chip_rect.position.y + 19, 13, ink if can_act else muted, lw, HORIZONTAL_ALIGNMENT_CENTER)
    float_button("status", "내 정보", Vector2(w - 146, base - 36), 27, Color("c85068"), 4)
    if game.skill_points > 0: draw_circle(Vector2(w - 126, base - 56), 6, rose)
    float_button("map", "지도", Vector2(w - 208, base - 36), 27, Color("6f9a4e"), 2)
    float_button("tour_help", "수첩", Vector2(w - 150, base - 98), 27, Color("4a8a9c"), 1)
    var zoom_rect = Rect2(w - 98, sy, 84, 32)
    plate(zoom_rect, Color("8a7fb0"), cream, 12, 2)
    txt("넓게 보기" if not game.overview else "가까이 보기", zoom_rect.position.x, sy + 21, 12, ink, 84, HORIZONTAL_ALIGNMENT_CENTER)
    buttons["zoom"] = zoom_rect
    if game.stage == 4: button("album", "추억 앨범", Rect2(14, base - 200, 108, 36), false, true, 13)
    if not game.save_ok: txt("저장 공간을 확인해 주세요.", 14, sy + 52, 10, rose, w - 28, HORIZONTAL_ALIGNMENT_CENTER)

func draw_dialogue() -> void:
    if game.dialogue.is_empty(): return
    chip(game.city().name + " · 둘의 이야기", Rect2(22, 28, 180, 36))
    var y = h - 326
    panel(Rect2(16, y, w - 32, 306), cream, 25)
    var line = game.dialogue[mini(game.dialogue_index, game.dialogue.size() - 1)]
    txt(line[0], 35, y + 37, 15, rose)
    para(line[1], 35, y + 75, w - 70, 21, ink, 1.55)
    txt(str(game.dialogue_index + 1) + " / " + str(game.dialogue.size()), 35, y + 276, 12, muted)
    button("next", "계속  →", Rect2(w - 156, y + 241, 120, 48), true)
    button("skip", "건너뛰기", Rect2(w - 116, 26, 94, 44), false, true, 12)

func food(index: int, pos: Vector2, s: float) -> void:
    if index == 0:

        draw_arc(pos, s * 0.42, 0.1, PI - 0.1, 20, Color("d59d53"), s * 0.47, true)
        for i in range(5):
            var a = 0.35 + i * 0.6
            draw_line(pos + Vector2(cos(a), sin(a)) * s * 0.25, pos + Vector2(cos(a), sin(a)) * s * 0.61, Color("f5ce83"), s * 0.065, true)
    elif index == 1:
        panel(Rect2(pos - Vector2(s * 0.6, s * 0.19), Vector2(s * 1.2, s * 0.42)), Color("dbaa62"), int(s * 0.2))
        for i in range(4): draw_line(pos + Vector2(- s * 0.35 + i * s * 0.23, - s * 0.08), pos + Vector2(- s * 0.25 + i * s * 0.23, s * 0.1), cream, s * 0.06, true)
    else:
        draw_arc(pos + Vector2(s * 0.35, 0), s * 0.2, - PI / 2, PI / 2, 12, Color("f5e6c9"), s * 0.08, true)
        panel(Rect2(pos - Vector2(s * 0.37, s * 0.3), Vector2(s * 0.73, s * 0.65)), Color("f4e6c7"), int(s * 0.1))
        draw_ellipse(pos - Vector2(0, s * 0.27), Vector2(s * 0.36, s * 0.12), Color("725440"))
        draw_line(pos - Vector2(s * 0.12, s * 0.55), pos - Vector2(s * 0.08, s * 0.83), Color("fff8e8"), 2, true)

func draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
    var points = PackedVector2Array()
    for i in range(32): points.append(center + Vector2(cos(i * TAU / 32), sin(i * TAU / 32)) * radii)
    draw_colored_polygon(points, color)

func draw_cook() -> void:
    top_bar("MAISON MIEL · 작은 빵집")
    var y = h - 430
    panel(Rect2(16, y, w - 32, 408), cream, 26)
    txt("BONJOUR, CHEF!", 35, y + 34, 11, rose)
    txt("손님의 주문", 35, y + 65, 25)
    txt(str(mini(game.orders + 1, 5)) + " / 5", w - 97, y + 62, 18, muted)
    var recipe = game.recipe_order[mini(game.orders, 4)]
    food(recipe, Vector2(w / 2, y + 116), 43)
    centered( ["따뜻한 크루아상", "갓 구운 바게트", "향긋한 커피"][recipe], y + 175, 20)
    progress(Rect2(37, y + 196, w - 74, 7), game.order_time / 8)
    centered("주문과 같은 메뉴를 눌러주세요", y + 230, 13, muted)
    var bw = (w - 88) / 3
    for i in range(3):
        var x = 28 + i * (bw + 16)
        button("recipe" + str(i), "", Rect2(x, y + 248, bw, 105), false, game.order_wait <= 0)
        food(i, Vector2(x + bw / 2, y + 280), 30)
        txt( ["크루아상", "바게트", "커피"][i], x, y + 332, 13, ink, bw, HORIZONTAL_ALIGNMENT_CENTER)
    centered(str(game.cooking_streak) + " 연속 성공 · 실수해도 다시 할 수 있어요", y + 382, 12, muted)

# 큰 승리 뒤: 기념품 세 개 중 하나 (슬레이 더 스파이어의 유물 고르기처럼)
func draw_reward_pick() -> void:
    panel(Rect2(0, 0, w, h), Color("1d1512e0"), 0)
    var top = maxf(safe_top + 20, h / 2 - 300)
    txt("여행 기념품", 24, top + 10, 13, gold, w - 48, HORIZONTAL_ALIGNMENT_CENTER)
    txt("하나를 골라 가방에 달아요", 24, top + 44, 22, cream, w - 48, HORIZONTAL_ALIGNMENT_CENTER)
    txt("고른 효과는 여행 내내 계속돼요 · 모은 기념품 " + str(game.relics.size()) + " / " + str(game.RELICS.size()), 24, top + 68, 11, Color("cfc5b4"), w - 48, HORIZONTAL_ALIGNMENT_CENTER)
    for i in range(game.pick_options.size()):
        var one = game.relic_of(String(game.pick_options[i]))
        var tone = Color(String(one.color))
        var r = Rect2(24, top + 92 + i * 132, w - 48, 120)
        var rise = maxf(0.0, 1.0 - game.scene_time * 3.0 + i * 0.3) * 30.0
        r.position.y += rise
        button("pick_" + str(i), "", r, false, true)
        panel(Rect2(r.position.x + 16, r.position.y + 22, 76, 76), tone, 18)
        panel(Rect2(r.position.x + 22, r.position.y + 28, 64, 64), tone.lightened(0.35), 14)
        txt(String(one.name).left(1), r.position.x + 16, r.position.y + 72, 34, tone.darkened(0.45), 76, HORIZONTAL_ALIGNMENT_CENTER)
        txt(String(one.name), r.position.x + 108, r.position.y + 48, 19)
        para(String(one.line), r.position.x + 108, r.position.y + 76, r.size.x - 124, 13, muted, 1.4)
        if game.effects_on:
            for k in range(4):
                var a = game.clock_time * 1.8 + k * TAU / 4.0 + i
                draw_rect(Rect2(Vector2(r.position.x + 54, r.position.y + 60) + Vector2(cos(a), sin(a)) * 50 - Vector2(3, 3), Vector2(6, 6)), tone)

func draw_battle_ready() -> void:
    var grade = game.wild_grade if game.wild_battle else 0
    chip( game.ready_chip() if game.ready_chip() != "" else ("도전의 탑 " + str(game.tower_floor) + "층" + (" · 수호자!" if game.legend_battle else "") if game.tower_battle else "전설의 괴물이 깨어났다!" if game.legend_battle else String(game.GRADES[grade].tag) + " 등급 출현!" if grade > 0 else "야생의 적이 나타났다!") if game.wild_battle else game.city().boss.name + "의 도전", Rect2(24, 30, w - 48, 38), Color(game.GRADES[grade].color).lightened(0.55) if grade > 0 else cream)
    var y = h - 430
    panel(Rect2(16, y, w - 32, 408), cream, 25)
    txt(game.wild_name() if game.wild_battle else "장동훈, 출전!", 35, y + 44, 24 if grade == 0 else 21, Color(game.GRADES[grade].color).darkened(0.25) if grade > 0 else ink)
    para( game.ready_line() if game.ready_line() != "" else "층마다 상대가 강해져요. 5층마다 수호자가 지켜요.\n체력은 층마다 가득 차지만 뽀뽀사탕은 돌아오지 않아요.\n지면 그 층에 다시 도전하거나 내려올 수 있어요. 최고 기록 " + str(game.tower_best) + "층" if game.tower_battle else "도시마다 단 한 마리뿐인 전설이에요.\n이기면 반드시 친구가 되고, 기술 포인트 2개를 얻어요.\n냄비를 불려 두고 퐁퐁을 뿌린 뒤 크게 터뜨려요." if game.legend_battle else ("평소보다 훨씬 강해요. 체력 ×" + str(game.GRADES[grade].hp) + " · 보상 ×" + str(game.GRADES[grade].gold) + "\n이기면 친구가 될 확률도 높아요.\n냄비 불리기와 퐁퐁으로 크게 한 방을 노려요." if grade > 0 else "공격이 닿는 순간 화면을 톡! (최대 1.5배)\n반격 직전에 톡! 하면 피해가 줄어요.\n야근 버티기로 지키고, 가방에서 회복해요.\n월급 박치기는 기력 3칸과 40원을 써요.")
    , 35, y + 83, w - 70, 16)
    para(game.city().rule, 35, y + 180, w - 70, 16, rose, 1.45)
    var kinds2 = game.foe_types()
    if String(kinds2[0]) != "": txt("약점 " + String(game.CAT_NAME[kinds2[0]]) + " · 저항 " + String(game.CAT_NAME[kinds2[1]]), w - 220, y + 44, 12, rose, 185, HORIZONTAL_ALIGNMENT_RIGHT)
    if game.tower_battle:
        button("battle_start", "동훈, 가라!", Rect2(33, y + 271, (w - 76) * 0.5, 60), true)
        button("auto_toggle", "자동으로 오르기", Rect2(33 + (w - 76) * 0.5 + 10, y + 271, (w - 76) * 0.5, 60), false, true, 15)
    else: button("battle_start", "동훈, 가라!", Rect2(33, y + 271, w - 66, 60), true)
    button("leave_battle", "지금은 지나가기", Rect2(33, y + 340, w - 66, 54), false, true, 14)

func battle_command(id: String, title: String, detail: String, rect: Rect2, primary: bool = false, enabled: bool = true) -> void:
    button(id, "", rect, primary, enabled)
    var fg = cream if primary and enabled else ink
    txt(title, rect.position.x + 14, rect.position.y + 30, 18, fg)
    txt(detail, rect.position.x + 14, rect.position.y + 54, 12, fg if enabled else muted)

func draw_battle() -> void:
    panel(Rect2(18, 24, w - 108, 104), cream, 19)
    var grade = game.wild_grade if game.wild_battle else 0
    txt( (String(game.GRADES[grade].tag) + " 등급" if grade > 0 else "WILD ENCOUNTER") if game.wild_battle else game.city().english + " / RIVAL", 32, 48, 11, Color(game.GRADES[grade].color) if grade > 0 else muted)
    txt(game.foe_title(), 32, 75, 21 if grade == 0 and game.battle_trait == "" else 17)
    if game.battle_trait != "": txt(String(game.TRAITS[game.battle_trait].line), 150, 115, 11, rose)
    elif game.foe_trick() != "": txt(String(game.TRICK_LINE[game.foe_trick()]), 150, 115, 11, rose)
    var marks2 = ""
    if game.battle_poison > 0: marks2 += "중독 " + str(game.battle_poison) + "  "
    if game.battle_spicy > 0: marks2 += "화끈 " + str(game.battle_spicy) + "  "
    if game.battle_luck > 0: marks2 += "행운  "
    if game.win_streak > 0 and game.wild_battle: marks2 += str(game.win_streak) + "연승"
    var kinds = game.foe_types()
    if String(kinds[0]) != "": txt("약점 " + String(game.CAT_NAME[kinds[0]]) + " · 저항 " + String(game.CAT_NAME[kinds[1]]), w - 300, 48, 11, Color("9e4f4b"), 196, HORIZONTAL_ALIGNMENT_RIGHT)
    progress(Rect2(32, 87, w - 136, 9), float(game.battle_hp) / game.battle_max_hp, rose)
    txt("HP  " + str(game.battle_hp) + " / " + str(game.battle_max_hp), 32, 115, 12, muted)
    button("pause", "Ⅱ", Rect2(w - 78, 28, 60, 60))
    if game.tower_battle: button("auto_toggle", "자동 끄기" if game.auto_battle else "자동", Rect2(w - 84, 94, 72, 38), game.auto_battle, true, 12)
    var intent = "다음 반격: " + game.enemy_attack_name() + ("    " + marks2 if marks2 != "" else "")
    chip(intent, Rect2(18, 140, w - 36, 34), Color("f4d8bc") if game.enemy_heavy() else cream)
    var party_y = h - 402
    panel(Rect2(16, party_y, w - 32, 84), cream, 19)
    txt("장동훈 · 도장 " + str(game.tour.completed.count(true)), 32, party_y + 27, 17)
    txt(str(game.health) + " / " + str(game.PARTY_HP), w - 103, party_y + 27, 14, rose if game.health < 13 else ink)
    progress(Rect2(32, party_y + 38, w - 64, 9), float(game.health) / game.PARTY_HP, Color("b2c481") if game.health >= 13 else rose)
    txt("기력", 32, party_y + 70, 12, muted)
    for i in range(3): panel(Rect2(70 + i * 28, party_y + 57, 22, 12), gold if i < game.battle_energy else Color("e3e6d6"), 4)
    var marks = ""
    if game.battle_bomb > 0: marks += "냄비 " + str(game.battle_bomb) + "턴  "
    if game.battle_vuln > 0: marks += "미끌 " + str(mini(2, game.battle_vuln)) + "턴  "
    if game.battle_charge: marks += "각성"
    if marks != "": txt(marks, 165, party_y + 69, 12, rose)
    else: txt("기력 충전 완료" if game.battle_energy == 3 else "설거지·야근으로 +1", 165, party_y + 69, 12, ink if game.battle_energy == 3 else muted)
    var y = h - 308
    panel(Rect2(16, y, w - 32, 286), cream, 24)
    txt("TURN " + str(game.battle_turn) + ("  ·  나의 선택" if game.battle_phase == "choose" else "  ·  대결 중"), 32, y + 26, 11, muted)
    var wide_menu = game.battle_phase == "choose" and game.battle_menu in ["fight", "job"] and game.job > 0
    if not wide_menu: txt("여행비 " + str(game.coins) + "원", w - 141, y + 26, 11, muted)
    para(game.battle_result, 32, y + 53, w - 64, 16, ink, 1.35)
    if game.battle_phase != "choose":
        para("“" + game.battle_quote + "”", 36, y + 145, w - 72, 21, ink, 1.4)
        centered("수세미 " + str(game.battle_volley_hits) + " / " + str(game.volley_total) if (game.battle_choice == "strike" or game.ult_kind() == "volley") and game.battle_phase == "player" else "동훈의 차례" if game.battle_phase == "player" else "상대의 차례", y + 225, 14, muted)
        var tap_hint = "여행비 " + str(game.coins) + "원"
        if game.auto_battle: tap_hint = "자동 전투 중"
        elif game.battle_phase == "player" and game.land_times().size() > 0: tap_hint = "닿는 순간 화면을 톡!  (최대 1.5배)"
        elif game.battle_phase in ["windup", "enemy"]: tap_hint = "반격이 닿기 직전에 톡! 하면 막아요"
        centered(tap_hint, y + 258, 13, rose if tap_hint.contains("톡") else muted)
        return
    var bw = (w - 76) / 2
    var left = Rect2(32, y + 100, bw, 72)
    var right = Rect2(w / 2 + 6, y + 100, bw, 72)
    var low_left = Rect2(32, y + 184, bw, 72)
    var low_right = Rect2(w / 2 + 6, y + 184, bw, 72)
    if game.battle_menu == "main":
        left = Rect2(32, y + 96, bw, 58); right = Rect2(w / 2 + 6, y + 96, bw, 58)
        low_left = Rect2(32, y + 220, bw, 58); low_right = Rect2(w / 2 + 6, y + 220, bw, 58)
        battle_command("fight_menu", "싸운다", "기술 고르기", left, true)
        var stock = game.battle_berries
        for one in game.BATTLE_ITEMS:
            if String(one) != "candy": stock += game.bag_count(String(one))
        battle_command("bag_menu", "가방", "쓸 수 있는 물건 " + str(stock) + "개", right)
        var ready_pets = 0
        for n0 in range(game.pet_team.size()):
            if game.pet_uses_left(n0) > 0: ready_pets += 1
        battle_command("pet_menu", "친구 기술", ("함께 걷는 친구가 없어요" if game.pet_team.is_empty() else "남은 친구 " + str(ready_pets) + " · 턴을 안 써요"), Rect2(32, y + 158, w - 64, 58), false, ready_pets > 0)
        battle_command("team", "월급 박치기", ("40원 필요 · 현재 " + str(game.coins) + "원" if game.coins < 40 else "기력 3 · 40원 사용"), low_left, game.battle_energy == 3 and game.coins >= 40, game.battle_energy == 3 and game.coins >= 40)
        battle_command("leave_battle", "도망간다" if game.wild_battle else "잠시 쉬기", "산책으로 돌아가기", low_right)
    elif game.battle_menu == "fight":
        var cells = [
            ["strike", str(game.strike_hits()) + "연타 · 기력 +1", true],
            ["guard", "피해 75%↓ · 체력 +" + str(game.guard_heal()), true],
            ["soak", "기력 1 · " + str(game.fuse_turns()) + "턴 뒤 " + str(game.soak_damage()), game.battle_energy >= 1 and game.battle_bomb == 0],
            ["soap", "기력 1 · 피해 +" + str(int((game.soap_mul() - 1.0) * 100)) + "%", game.battle_energy >= 1],
            ["coffee", "기력 +2 · 다음 공격 ×" + str(snappedf(game.coffee_mul(), 0.1)), not game.battle_charge],
        ]
        if game.job > 0: cells.append(["jobs_menu", game.job_name() + "의 기술 " + str(game.job_open_count()) + "개", true])
        for i in range(cells.size()):
            var cell = Rect2(32 + (i % 2) * (bw + 12), y + 96 + int(i / 2) * 62, bw, 58)
            var id = String(cells[i][0])
            var special = id == "jobs_menu"
            var open = special or game.skill_open(id)
            var ok = open and bool(cells[i][2])
            var strong = (i == 0 or special) and ok
            button(id, "", cell, i == 0 or special, ok)
            var fg = cream if strong else (ink if ok else muted)
            var label = "직업 기술  →" if special else String(game.skill_of(id).name) + ("  Lv." + str(game.sk(id)) if open else "")
            txt(label, cell.position.x + 12, cell.position.y + 24, 15, fg)
            txt(String(cells[i][1]) if open else "레벨 " + str(int(game.skill_of(id).need)) + "에 배워요", cell.position.x + 12, cell.position.y + 44, 10, fg if strong else muted)
        if wide_menu: button("battle_back", "← 뒤로", Rect2(w - 32 - 84, y + 4, 84, 40), false, true, 13)
        else: button("battle_back", "← 뒤로", Rect2(32 + bw + 12, y + 220, bw, 58), false, true, 14)
    elif game.battle_menu == "job":
        # 전직하면 '싸운다'가 이 화면으로 열린다. 아래 차수부터 위로 쌓인다.
        for i in range(6):
            var info = game.ult_info(i)
            var cell = Rect2(32 + (i % 2) * (bw + 12), y + 96 + int(i / 2) * 62, bw, 58)
            var unlocked = game.ult_open(i)
            var ok = unlocked and game.battle_energy >= int(info.energy)
            button("ult" + str(i), "", cell, true, ok)
            txt(String(info.name) + ("  Lv." + str(game.sk(game.job_skill_id(i))) if unlocked else ""), cell.position.x + 12, cell.position.y + 24, 14, cream if ok else muted)
            txt("기력 " + str(int(info.energy)) + " · " + String(info.line) if unlocked else game.ult_lock(i), cell.position.x + 12, cell.position.y + 44, 10, cream if ok else muted)
        button("base_menu", "기본 기술", Rect2(w - 32 - 84 - 92, y + 4, 86, 40), false, true, 13)
        button("battle_back", "← 뒤로", Rect2(w - 32 - 84, y + 4, 84, 40), false, true, 13)
    elif game.battle_menu == "pets":
        for n in range(mini(6, game.pet_team.size())):
            var p = game.pets[int(game.pet_team[n])]
            var cell = Rect2(32 + (n % 2) * (bw + 12), y + 96 + int(n / 2) * 62, bw, 58)
            var free = game.pet_uses_left(n) > 0
            button("petskill_" + str(n), "", cell, false, free)
            panel(Rect2(cell.position.x + 6, cell.position.y + 8, 42, 42), Color("f1e6cf"), 8)
            var art = game.pet_art(p)
            var dims = flat_art.mob_size(art)
            flat_art.mob(self, art, Vector2(cell.position.x + 27, cell.position.y + 46), 34.0 / maxf(1.0, maxf(dims.x, dims.y)), 0.0 if free else 0.6, game.pet_tint(p))
            txt(game.pet_skill_name(p), cell.position.x + 54, cell.position.y + 24, 13, ink if free else muted)
            txt(game.pet_skill_line(p) if free else "이번 대결엔 썼어요", cell.position.x + 54, cell.position.y + 44, 10, muted)
        button("battle_back", "← 뒤로", Rect2(w - 32 - 84, y + 4, 84, 40), false, true, 13)
    else:
        # 가방: 쓸 수 있는 물건을 두 줄로 늘어놓는다 (쓰면 한 턴)
        for k in range(game.BATTLE_ITEMS.size()):
            var what = String(game.BATTLE_ITEMS[k])
            var cell = Rect2(32 + (k % 2) * (bw + 12), y + 92 + int(k / 2) * 48, bw, 44)
            var count = game.battle_berries if what == "candy" else game.bag_count(what)
            var ok = count > 0
            if what == "candy": ok = ok and game.health < game.PARTY_HP
            if what == "instantpot": ok = ok and game.battle_bomb == 0
            if what == "charm": ok = ok and game.battle_luck <= 0.0
            button("heal" if what == "candy" else "bitem_" + what, "", cell, false, ok)
            item_icon(what, Vector2(cell.position.x + 24, cell.position.y + 22))
            txt(String(game.item_of(what).name) + " ×" + str(count), cell.position.x + 52, cell.position.y + 19, 13, ink if ok else muted)
            txt(("체력 +" + str(game.candy_heal())) if what == "candy" else String(game.item_of(what).line), cell.position.x + 52, cell.position.y + 36, 9, muted)
        button("battle_back", "← 뒤로", Rect2(32 + bw + 12, y + 92 + 3 * 48, bw, 44), false, true, 13)

func draw_battle_won() -> void:
    chip("VICTORY / 동훈이 해냈다!", Rect2(24, 30, w - 48, 38))
    var y = h - 300
    panel(Rect2(16, y, w - 32, 278), cream, 25)
    txt("장동훈, 승리!", 34, y + 43, 26)
    var grow = clampf(game.win_time / 0.8, 0, 1)
    icon_coin(Vector2(46, y + 80), 11)
    txt("+" + str(int(game.battle_reward * grow)) + "원", 66, y + 89, 25 + (4 if grow < 1.0 else 0), rose)
    txt("월급 박치기 " + str(game.perfects) + "회 · " + str(game.battle_turn) + "턴의 대결", 34, y + 122, 14, muted)
    if game.last_drop != "" and game.loot.has(game.last_drop):
        var drop = game.loot[game.last_drop]
        var tone = Color(String(game.LOOT_GRADES[int(drop.grade)].color))
        var pulse = 0.5 + 0.5 * sin(game.win_time * 8.0)
        if int(drop.grade) >= 2 and game.effects_on:
            for i in range(12):
                var a = i * TAU / 12.0 + game.win_time * 1.5
                draw_rect(Rect2(Vector2(58, y + 172) + Vector2(cos(a), sin(a)) * (30 + pulse * 6) - Vector2(3, 3), Vector2(6, 6)), tone)
        plate(Rect2(24, y + 140, w - 48, 52), tone, cream, 12, 3)
        gear_icon(drop, Vector2(58, y + 166))
        txt(String(game.LOOT_GRADES[int(drop.grade)].tag) + " 장비!  " + String(drop.name), 90, y + 160, 14, tone.darkened(0.2))
        txt(String(drop.line) + ("  · 가방에 " + String(game.item_of(game.last_item).name) + "도" if game.last_item != "" else ""), 90, y + 180, 10, muted)
    elif game.last_item != "":
        plate(Rect2(24, y + 140, w - 48, 44), Color("8d8578"), cream, 12, 3)
        item_icon(game.last_item, Vector2(56, y + 162))
        txt(String(game.item_of(game.last_item).name) + "을(를) 주웠어요!", 90, y + 168, 14)
    else: para("다음 층이 기다려요. 계속 올라갈까요?" if game.tower_battle else "전설을 이겼어요! 이제 함께 걷는 친구예요." if game.legend_battle else "만남 기록에 남기고 산책을 이어가요." if game.wild_battle else game.city().boss.win, 34, y + 160, w - 68, 15)
    if game.effects_on:
        for i in range(30):
            var fall = fposmod(game.win_time * (120.0 + (i % 5) * 34.0) + i * 61.0, y + 40.0) - 30.0
            var sway = fposmod(i * 97.3, w) + sin(game.win_time * 3.0 + i) * 12.0
            draw_rect(Rect2(sway, fall, 6, 10 if i % 2 == 0 else 6), [Color("ffd84a"), Color("ff8fb0"), Color("8fd9ff"), Color("b6f09a")][i % 4])
    button("battle_continue", "보상 받고 다음 층으로  →" if game.tower_battle else "보상 받고 계속하기  →", Rect2(33, y + 195, w - 66, 60), true, true, 17)

func draw_battle_lost() -> void:
    panel(Rect2(0, 0, w, h), Color("294b4666"), 0)
    var y = h / 2 - 150
    panel(Rect2(22, y, w - 44, 320), cream, 25)
    txt("이번엔 숨을 고르고.", 42, y + 49, 26)
    para("쓴 돈과 사탕은 돌아오지 않아요.\n재도전하면 체력은 가득 채워져요.", 42, y + 91, w - 84, 16)
    button("retry", "체력을 채워 재도전", Rect2(42, y + 166, w - 84, 60), true)
    button("leave_battle", "잠깐 산책하기", Rect2(42, y + 240, w - 84, 54))

func draw_photo() -> void:
    chip("%02d  ·  기억이 되는 순간" % (game.city_index + 1), Rect2(24, 30, 210, 38))
    for corner in [Vector2(34, 160), Vector2(w - 34, 160), Vector2(34, h - 230), Vector2(w - 34, h - 230)]:
        var dx = 1 if corner.x < w / 2 else -1
        var dy = 1 if corner.y < h / 2 else -1
        draw_line(corner, corner + Vector2(dx * 28, 0), cream, 2, true)
        draw_line(corner, corner + Vector2(0, dy * 28), cream, 2, true)
    panel(Rect2(16, h - 191, w - 32, 169), cream, 24)
    centered("“이번엔 미루지 말자. 지금 찍자.”", h - 151, 19)
    centered(game.city().name + "의 기억을 여행 앨범에 남겨요.", h - 122, 13, muted)
    button("photo", "오늘을 기억하기  ◎", Rect2(33, h - 99, w - 66, 57), true)

func draw_ending() -> void:
    panel(Rect2(0, 0, w, h), Color("ede7d5"), 0)
    txt("OUR LITTLE JOURNEY / 01", 26, 46, 12, muted)
    txt("오늘, 우리였던 파리.", 24, 91, 30)
    var ph = minf(h * 0.35, 310)
    panel(Rect2(24, 119, w - 48, ph + 28), cream, 4)
    if game.photo:
        var tex_size = game.photo.get_size()
        var rect = Rect2(36, 131, w - 72, ph)

        var crop_h = tex_size.x * rect.size.y / rect.size.x
        draw_texture_rect_region(game.photo, rect, Rect2(0, (tex_size.y - crop_h) * 0.62, tex_size.x, crop_h))
    else:
        panel(Rect2(36, 131, w - 72, ph), Color("c8d7c0"), 3)
        txt("PARIS", 36, 131 + ph / 2, 38, ink, w - 72, HORIZONTAL_ALIGNMENT_CENTER)
    var y = 147 + ph
    chip("PARIS  ·  첫 추억 해금", Rect2(w - 226, y - 20, 196, 37), gold)
    para("기억을 찾으러 왔다가,\n함께할 내일을 하나 더 만들었다.", 28, y + 53, w - 56, 21, ink, 1.65)
    txt("빵집 최고 연속  " + str(game.best_combo) + "회     월급 박치기  " + str(game.perfects) + "회", 28, y + 126, 12, muted)
    txt("첫 도시 체험 완료 · 다음 도시는 아직 준비 중이에요.", 28, y + 155, 12, muted)
    button("wander", "파리에서 조금 더 걷기", Rect2(24, h - 150, w - 48, 58), true)
    button("title", "첫 화면으로", Rect2(24, h - 78, w - 48, 47), false, true, 14)

func draw_pause() -> void:
    panel(Rect2(0, 0, w, h), Color("294b4677"), 0)
    var y = maxf(30, h / 2 - 250)
    panel(Rect2(20, y, w - 40, 500), cream, 26)
    txt("잠깐, 쉬어가요.", 40, y + 50, 29)
    txt("진행은 자동으로 저장됩니다." if game.save_ok else "저장 실패 · 현재 진행은 앱을 닫으면 사라질 수 있어요.", 40, y + 82, 12, muted)
    button("resume", "여행 계속하기", Rect2(40, y + 111, w - 80, 57), true)
    button("sound", "소리  " + ("켜짐" if game.sound_on else "꺼짐"), Rect2(40, y + 183, w - 80, 49))
    button("effects", "화면 효과  " + ("켜짐" if game.effects_on else "간소화"), Rect2(40, y + 243, w - 80, 49), false, true, 15)
    button("reset", "열 도시의 진행을 모두 지울까요?" if game.reset_confirm else "처음부터 다시 시작", Rect2(40, y + 303, w - 80, 49), false, true, 14)
    var open = game.previous_state == "explore" and game.stamps() + game.cycle >= 1
    button("tower_start", "도전의 탑  ·  최고 " + str(game.tower_best) + "층" if game.stamps() + game.cycle >= 1 else "도전의 탑  ·  첫 도장을 찍으면 열려요", Rect2(40, y + 363, w - 80, 49), false, open, 14)
    para("왼손 이동 · 오른손 행동\n키보드 WASD / 방향키 · E 행동 · Esc 쉬기\n전투는 버튼 선택 / 요리는 1·2·3", 40, y + 436, w - 80, 12, muted, 1.8)

# 물건 그림: 소모품은 id, 장비는 칸(slot)과 단계(tier)로 고른다
func item_icon(kind: String, p: Vector2, tier: int = 0) -> void:
    panel(Rect2(p.x - 22, p.y - 22, 44, 44), Color("f1e6cf"), 10, Color("d8c9a8"))
    match kind:
        "candy":
            draw_rect(Rect2(p.x - 17, p.y - 5, 8, 10), Color("ff9ec8")); draw_rect(Rect2(p.x + 9, p.y - 5, 8, 10), Color("ff9ec8"))
            draw_circle(p, 9, Color("e8548c")); draw_circle(p + Vector2(-3, -3), 3, Color("ffd0e2"))
        "drink":
            draw_rect(Rect2(p.x - 8, p.y - 14, 16, 28), Color("3f8fa8")); draw_rect(Rect2(p.x - 8, p.y - 14, 16, 5), Color("c9d6dc"))
            draw_rect(Rect2(p.x - 2, p.y - 6, 5, 7), Color("ffe36c")); draw_rect(Rect2(p.x - 4, p.y, 5, 7), Color("ffe36c"))
        "treat":
            draw_rect(Rect2(p.x - 10, p.y - 3, 20, 6), Color("c9a66b"))
            for q in [Vector2(-11, -4), Vector2(-11, 4), Vector2(11, -4), Vector2(11, 4)]: draw_circle(p + q, 5, Color("c9a66b"))
        "film":
            draw_rect(Rect2(p.x - 15, p.y - 11, 30, 22), Color("3a3f4a")); draw_rect(Rect2(p.x - 9, p.y - 6, 18, 12), Color("a6d8e8"))
            for i in range(4): draw_rect(Rect2(p.x - 13 + i * 8, p.y - 10, 3, 3), cream); draw_rect(Rect2(p.x - 13 + i * 8, p.y + 7, 3, 3), cream)
        "bread":
            draw_colored_polygon(PackedVector2Array([p + Vector2(-16, 0), p + Vector2(-6, -9), p + Vector2(10, -7), p + Vector2(16, 0), p + Vector2(10, 7), p + Vector2(-6, 9)]), Color("c98a3c"))
            draw_colored_polygon(PackedVector2Array([p + Vector2(14, 0), p + Vector2(21, -7), p + Vector2(21, 7)]), Color("c98a3c"))
            draw_circle(p + Vector2(-9, -2), 2, Color("3a2a1e"))
            for i in range(3): draw_rect(Rect2(p.x - 3 + i * 5, p.y - 5, 2, 10), Color("a86a2c"))
        "spicy":
            draw_rect(Rect2(p.x - 15, p.y - 2, 30, 13), Color("e9e2d4")); draw_rect(Rect2(p.x - 13, p.y - 6, 26, 7), Color("d8482c"))
            for i in range(4): draw_rect(Rect2(p.x - 12 + i * 7, p.y - 10, 5, 9), Color("f6e0c8"))
        "icewater":
            draw_colored_polygon(PackedVector2Array([p + Vector2(-11, -14), p + Vector2(11, -14), p + Vector2(8, 14), p + Vector2(-8, 14)]), Color("bfe6f2"))
            draw_rect(Rect2(p.x - 7, p.y - 6, 7, 7), Color("ffffff")); draw_rect(Rect2(p.x + 1, p.y + 2, 6, 6), Color("e6f8ff"))
        "firework":
            draw_rect(Rect2(p.x - 5, p.y - 8, 10, 22), Color("c8323c")); draw_colored_polygon(PackedVector2Array([p + Vector2(-7, -8), p + Vector2(0, -17), p + Vector2(7, -8)]), Color("ffd84a"))
            for q in [Vector2(-14, -12), Vector2(13, -14), Vector2(-12, 6), Vector2(14, 4)]: draw_rect(Rect2(p + q - Vector2(2, 2), Vector2(4, 4)), Color("ffd84a"))
        "charm":
            draw_rect(Rect2(p.x - 10, p.y - 10, 20, 24), Color("c8323c")); draw_rect(Rect2(p.x - 6, p.y - 16, 12, 7), Color("e5b33c"))
            draw_rect(Rect2(p.x - 5, p.y - 4, 10, 2), Color("ffd84a")); draw_rect(Rect2(p.x - 1, p.y - 8, 2, 12), Color("ffd84a"))
        "instantpot":
            draw_rect(Rect2(p.x - 13, p.y - 4, 26, 15), Color("9aa4ad")); draw_rect(Rect2(p.x - 16, p.y - 8, 32, 5), Color("c9d2d6"))
            draw_rect(Rect2(p.x - 3, p.y - 13, 6, 5), Color("5a646c")); draw_rect(Rect2(p.x - 9, p.y + 1, 18, 4), Color("ffd84a"))
        "meal":
            draw_rect(Rect2(p.x - 15, p.y - 4, 30, 14), Color("c8553d")); draw_rect(Rect2(p.x - 15, p.y - 9, 30, 6), Color("e9dcc0"))
            draw_rect(Rect2(p.x - 3, p.y - 14, 6, 6), Color("7a5230"))
        "slot0":
            if tier == 0:
                draw_rect(Rect2(p.x - 14, p.y - 8, 28, 16), Color("f0d04a")); draw_rect(Rect2(p.x - 14, p.y - 8, 28, 6), Color("5fa55a"))
            elif tier == 1:
                for i in range(4): draw_arc(p, 4 + i * 3.4, 0, TAU, 14, Color("8f9aa5"), 2, true)
            else:
                var glove = Color("ff5f8f") if tier == 2 else Color("ffcf3a")
                draw_rect(Rect2(p.x - 9, p.y - 2, 18, 16), glove)
                for i in range(4): draw_rect(Rect2(p.x - 9 + i * 5, p.y - 14, 4, 13), glove)
                draw_rect(Rect2(p.x - 15, p.y, 7, 5), glove); draw_rect(Rect2(p.x - 9, p.y + 10, 18, 4), glove.darkened(0.25))
                if tier == 3:
                    draw_rect(Rect2(p.x + 10, p.y - 18, 3, 9), Color("fff4b0")); draw_rect(Rect2(p.x + 7, p.y - 15, 9, 3), Color("fff4b0"))
        "slot3":
            if tier == 0:
                draw_rect(Rect2(p.x - 15, p.y - 6, 30, 14), Color("c9d6dc")); draw_rect(Rect2(p.x - 11, p.y - 2, 22, 8), Color("9fb4c4")); draw_rect(Rect2(p.x + 6, p.y - 14, 4, 9), Color("8f9aa5"))
            elif tier <= 3:
                var potc = [Color("d8d2a8"), Color("d8d2a8"), Color("4a4f58"), Color("e5b33c")][tier]
                draw_rect(Rect2(p.x - 13, p.y - 5, 26, 16), potc); draw_rect(Rect2(p.x - 16, p.y - 8, 32, 5), potc.lightened(0.25))
                draw_rect(Rect2(p.x - 19, p.y - 3, 4, 4), potc.darkened(0.2)); draw_rect(Rect2(p.x + 15, p.y - 3, 4, 4), potc.darkened(0.2))
                draw_rect(Rect2(p.x - 3, p.y - 12, 6, 4), potc.darkened(0.3))
                if tier == 3:
                    draw_rect(Rect2(p.x + 9, p.y - 18, 3, 9), Color("fff4b0")); draw_rect(Rect2(p.x + 6, p.y - 15, 9, 3), Color("fff4b0"))
            elif tier == 4:
                draw_rect(Rect2(p.x - 9, p.y - 6, 18, 20), Color("7fd0a0")); draw_rect(Rect2(p.x - 4, p.y - 14, 8, 8), Color("f6f6f6")); draw_rect(Rect2(p.x - 6, p.y, 12, 6), Color("fff4b0"))
                draw_circle(p + Vector2(12, -10), 3, Color("d6f3ff")); draw_circle(p + Vector2(16, -3), 2, Color("d6f3ff"))
            elif tier == 5:
                draw_rect(Rect2(p.x - 8, p.y - 10, 16, 24), Color("5a7a9a")); draw_rect(Rect2(p.x - 9, p.y - 15, 18, 6), Color("3a4a5a")); draw_rect(Rect2(p.x - 8, p.y - 2, 16, 5), Color("c9d6dc"))
            else:
                draw_rect(Rect2(p.x - 15, p.y - 10, 30, 20), Color("fdf6e0")); draw_rect(Rect2(p.x - 15, p.y - 10, 30, 5), Color("c8553d"))
                for i in range(5): draw_circle(p + Vector2(-10 + i * 5, 3), 2, Color("e5b33c") if i % 2 == 0 else Color("4a8fb8"))
        "slot1":
            var cloth = [Color("9fb4c4"), Color("f3a6c0"), Color("c8553d"), Color("7a5fc0")][clampi(tier, 0, 3)]
            draw_rect(Rect2(p.x - 9, p.y - 11, 18, 24), cloth); draw_rect(Rect2(p.x - 16, p.y - 11, 8, 9), cloth); draw_rect(Rect2(p.x + 8, p.y - 11, 8, 9), cloth)
            draw_rect(Rect2(p.x - 4, p.y - 11, 8, 4), Color("f1e6cf"))
            if tier == 1:
                for q in [Vector2(-4, -1), Vector2(4, 4), Vector2(-3, 8)]: draw_circle(p + q, 2, Color("fff4b0"))
            elif tier == 3:
                for q in [Vector2(-4, 0), Vector2(4, 6)]: draw_rect(Rect2(p.x + q.x - 2, p.y + q.y - 2, 4, 4), Color("ffe36c"))
        _:
            var shoe = [Color("3a4a6a"), Color("f6f6f6"), Color("8a5a2c"), Color("5fbf6a")][clampi(tier, 0, 3)]
            draw_rect(Rect2(p.x - 14, p.y + 2, 28, 8), shoe); draw_rect(Rect2(p.x - 14, p.y - 8, 13, 11), shoe)
            draw_rect(Rect2(p.x - 14, p.y + 9, 28, 3), Color("2a1c18"))
            if tier == 0:
                for i in range(3): draw_rect(Rect2(p.x - 2 + i * 5, p.y + 3, 2, 6), cream)
            elif tier == 3:
                draw_rect(Rect2(p.x - 20, p.y - 6, 7, 4), cream); draw_rect(Rect2(p.x - 22, p.y - 11, 8, 4), cream)

func gear_icon(entry: Dictionary, p: Vector2) -> void:
    item_icon(String(entry.get("icon", "slot" + str(int(entry.slot)))), p, int(entry.get("icon_tier", entry.tier)))
    if entry.has("grade"):
        var tone = Color(String(game.LOOT_GRADES[int(entry.grade)].color))
        draw_rect(Rect2(p.x - 22, p.y - 22, 44, 44), tone, false, 3.0)

func sheet_head(title: String, sub: String) -> float:
    panel(Rect2(0, 0, w, h), Color("1d1512e8"), 0)
    plate(Rect2(12, safe_top, w - 24, 62), ink)
    txt(title, 28, safe_top + 30, 22)
    txt(sub, 28, safe_top + 48, 11, muted)
    icon_coin(Vector2(w - 92, safe_top + 28), 9)
    txt(str(game.coins) + "원", w - 80, safe_top + 34, 16, rose)
    button("status_close", "닫기", Rect2(w - 74, safe_top + 70, 62, 40), false, true, 13)
    return safe_top + 70

func tabs(ids: Array, labels: Array, active: int, y: float, right_pad: float) -> void:
    var count = labels.size()
    var tw = (w - 24 - right_pad - (count - 1) * 6) / count
    for i in range(count):
        var r = Rect2(12 + i * (tw + 6), y, tw, 40)
        var on = i == active
        panel(Rect2(r.position + Vector2(2, 4), r.size), Color(0.05, 0.03, 0.02, 0.35), 13)
        panel(r, ink if on else Color("6d6054"), 13)
        panel(Rect2(r.position + Vector2(3, 3), r.size - Vector2(6, 8)), ink if on else cream, 10)
        txt(labels[i], r.position.x, r.position.y + 26, 14, cream if on else Color("6d6054"), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
        buttons[ids[i]] = r

func row(rect: Rect2, title: String, line: String, tone: Color, right: String, tag: String) -> void:
    plate(rect, tone, cream, 15, 3)
    txt(title, rect.position.x + 16, rect.position.y + 26, 17)
    txt(line, rect.position.x + 16, rect.position.y + 46, 12, muted)
    if right != "": txt(right, rect.end.x - 122, rect.position.y + 28, 16, tone, 110, HORIZONTAL_ALIGNMENT_RIGHT)
    if tag != "": txt(tag, rect.end.x - 122, rect.position.y + 47, 11, muted, 110, HORIZONTAL_ALIGNMENT_RIGHT)

func draw_status() -> void:
    var top = sheet_head("장동훈 · " + game.job_name(), "레벨 " + str(game.level) + " · 도장 " + str(game.stamps()) + " / 10" + (" · " + str(game.cycle + 1) + "회차" if game.cycle > 0 else ""))
    tabs(["tab_0", "tab_1", "tab_2", "tab_3", "tab_4", "tab_5", "tab_7"], ["스텟", "기술" + ("●" if game.skill_points > 0 else ""), "가방", "장비", "동행", "도감", "목표" + ("●" if game.daily_done() < 3 else "")], 6 if game.sheet_tab == 7 else (0 if game.sheet_tab == 6 else game.sheet_tab), top, 74)
    var y = top + 52
    match game.sheet_tab:
        0: status_stats(y)
        1: status_skills(y)
        2: status_bag(y)
        3: status_gear(y)
        4: status_pets(y)
        5: status_dex(y)
        7: status_goals(y)
        _: status_job(y)

func status_job(y: float) -> void:
    txt("전직: Lv.10 + 기본 기술 하나 마스터 · 2차·3차: Lv.20·30 + 직업 기술 마스터", 16, y + 16, 11, Color("cfc5b4"))
    var card = clampf((h - y - 90) / 3.0, 128, 150)
    for i in range(1, 4):
        var entry = game.JOBS[i]
        var mine = game.job == i
        var rank = game.job_rank() if mine else 0
        var r = Rect2(12, y + 28 + (i - 1) * card, w - 24, card - 8)
        plate(r, Color(String(entry.color)) if mine else Color("8d8578"), cream, 15, 3)
        panel(Rect2(r.position.x + 8, r.position.y + 10, 7, r.size.y - 24), Color(String(entry.color)), 3)
        txt(String(entry.names[maxi(0, rank - 1)]), 36, r.position.y + 26, 17)
        if mine: txt(str(rank) + "차 · 현재 직업", w - 250, r.position.y + 25, 12, Color("3f7a32"), 138, HORIZONTAL_ALIGNMENT_RIGHT)
        else: txt("→ " + String(entry.names[2]), w - 250, r.position.y + 25, 11, muted, 138, HORIZONTAL_ALIGNMENT_RIGHT)
        button("job_" + str(i), "전직" if game.job == 0 else "변경 200", Rect2(w - 104, r.position.y + 6, 80, 34), true, not mine and game.level >= game.JOB_LEVEL and ((game.job == 0 and game.base_mastered()) or (game.job > 0 and game.coins >= 200)), 12)
        var step = (r.size.y - 40) / 3.0
        for k in range(3):
            var ly = r.position.y + 44 + k * step
            var reached = mine and rank > k
            var pair = game.JOB_SKILLS[i]
            txt(str(k + 1) + "차  " + String(game.JOB_PASSIVE[i][k]), 36, ly, 11, ink if reached else muted)
            txt("새 기술 「" + String(pair[k * 2].name) + "」 「" + String(pair[k * 2 + 1].name) + "」", 36, ly + 14, 10, rose if reached else Color("b0a898"))
    button("tab_0", "← 스텟으로", Rect2(12, y + 28 + 3 * card, 130, 40), false, true, 13)

# 도감: 도시마다 만난 친구 셋 + 전설 하나, 숨은 발견, 기억 조각
# 목표: 여행 패스 30단계와 오늘의 의뢰 세 개
func status_goals(y: float) -> void:
    game.refresh_daily()
    var lv = mini(game.pass_level, game.PASS_MAX)
    plate(Rect2(12, y, w - 24, 112), gold)
    txt("여행 패스 Lv." + str(lv) + " / " + str(game.PASS_MAX), 28, y + 28, 18)
    txt("뽑기 티켓 " + str(game.tickets) + "장", w - 200, y + 28, 13, rose, 172, HORIZONTAL_ALIGNMENT_RIGHT)
    bar(Rect2(28, y + 40, w - 56, 10), float(game.pass_points % 100) / 100.0, Color("e5b33c"))
    txt("다음 보상: " + (game.pass_reward_text(lv + 1) if lv < game.PASS_MAX else "티켓 1장씩 계속"), 28, y + 70, 12, muted)
    txt("점수: 의뢰 50 · 업적 20 · 라이벌 30 · 전설·그림자 40 · 야생 3", 28, y + 92, 10, muted)
    var ry = y + 124
    var cw = (w - 24) / 5.0
    for k in range(5):
        var nl = lv + 1 + k
        if nl > game.PASS_MAX: break
        var cell = Rect2(12 + k * cw, ry, cw - 6, 60)
        var big = nl % 10 == 0
        plate(cell, Color("e0a020") if big else Color("8d8578"), Color("fff1c8") if big else cream, 10, 2)
        txt("Lv." + str(nl), cell.position.x, cell.position.y + 20, 12, ink, cell.size.x, HORIZONTAL_ALIGNMENT_CENTER)
        txt(game.pass_reward_short(nl), cell.position.x, cell.position.y + 42, 10, rose if big else muted, cell.size.x, HORIZONTAL_ALIGNMENT_CENTER)
    var qy = ry + 84
    txt("오늘의 의뢰 · 내일 새로 바뀌어요", 16, qy, 12, cream)
    for i in range(game.daily.size()):
        var q = game.daily[i]
        var finished = bool(q[4])
        var r = Rect2(12, qy + 12 + i * 62, w - 24, 56)
        plate(r, Color("4a8a38") if finished else ink, Color("e8f2dc") if finished else cream, 13, 3)
        txt(String(q[2]), 28, r.position.y + 24, 15)
        var prog = game.quest_progress(q)
        bar(Rect2(28, r.position.y + 34, w - 160, 8), float(prog) / maxf(1.0, float(q[1])), Color("86cc5e"))
        txt("완료!" if finished else str(prog) + " / " + str(int(q[1])), w - 124, r.position.y + 34, 13, Color("3f7a32") if finished else rose, 96, HORIZONTAL_ALIGNMENT_RIGHT)
    var ty = qy + 12 + 3 * 62 + 16
    txt("의뢰마다 티켓 +1 · 패스 +50 · 셋 다 끝내면 티켓 +2", 16, ty, 11, Color("cfc5b4"))
    txt("뽑기 전설 확정까지 " + str(maxi(0, 50 - game.gacha_pity)) + "번", 16, ty + 20, 11, gold)

func status_ach(y: float) -> void:
    var pitch = minf(48.0, (h - y - 70) / 12.0)
    var cw = (w - 30) / 2.0
    for i in range(game.ACHS.size()):
        var one = game.ACHS[i]
        var done = game.ach_done.has(String(one.id))
        var have = game.stat_value(String(one.key))
        var r = Rect2(12 + (i % 2) * (cw + 6), y + 50 + int(i / 2) * pitch, cw, pitch - 4)
        plate(r, Color("4a8a38") if done else Color("8d8578"), cream if done else Color("e6e0d2"), 10, 2)
        txt(String(one.name), r.position.x + 10, r.position.y + 17, 12, ink if done else muted)
        var prize = ("+" + str(int(one.coins)) + "원") if one.has("coins") else (("강화석 " + str(int(one.stones))) if one.has("stones") else ("기술 포인트 " + str(int(one.sp))))
        txt(("달성 · " if done else str(mini(have, int(one.need))) + " / " + str(int(one.need)) + " · ") + prize, r.position.x + 10, r.position.y + pitch - 12, 9, Color("3f7a32") if done else muted)

func status_dex(y: float) -> void:
    var got = 0
    for rec in game.tour.records:
        got += rec.get("wild_seen", []).count(true) + rec.get("extra_seen", []).count(true) + rec.get("eggs", []).count(true) + (1 if bool(rec.get("legend", false)) else 0)
    plate(Rect2(12, y, w - 24, 40), gold)
    txt("수집률 " + str(int(got * 100 / 100)) + "%", 28, y + 26, 16)
    button("dexview_0", "도감", Rect2(w - 170, y + 3, 70, 34), game.dex_view == 0, true, 13)
    button("dexview_1", "업적", Rect2(w - 94, y + 3, 70, 34), game.dex_view == 1, true, 13)
    if game.dex_view == 1:
        status_ach(y); return
    var pitch = minf(46, (h - y - 60) / 10.0)
    for i in range(10):
        var rec2 = game.tour.records[i]
        var data = game.CityData.CITIES[i]
        var ry = y + 48 + i * pitch
        plate(Rect2(12, ry, w - 24, pitch - 4), ink if i == game.city_index else Color("8d8578"), cream, 12, 2)
        txt(String(data.name), 24, ry + pitch * 0.5 + 3, 13)
        var seen = rec2.get("wild_seen", [false, false, false])
        var seen2 = rec2.get("extra_seen", [false, false, false])
        for k in range(7):
            var box = Rect2(86 + k * 29, ry + 3, 26, pitch - 12)
            var known = bool(rec2.get("legend", false)) if k == 6 else (bool(seen[k]) if k < 3 else bool(seen2[k - 3]))
            panel(box, Color("f1e6cf") if known else Color("cfc6b4"), 6, Color("e0a020") if k == 6 else (Color("8fbf7a") if k >= 3 else Color("d8c9a8")))
            if known:
                var art = "legend" + str(i) if k == 6 else (String(data.mobs[k].art) if k < 3 else String(game.AREA_MOBS[i][k - 3].art))
                var dims = flat_art.mob_size(art)
                flat_art.mob(self, art, Vector2(box.get_center().x, box.end.y - 3), (box.size.y - 6) / maxf(1.0, maxf(dims.x, dims.y)), 0.0, String(game.AREA_MOBS[i][k - 3].tint) if k >= 3 and k < 6 else "")
            else: txt("?", box.position.x, box.get_center().y + 6, 15, Color("9d978a"), box.size.x, HORIZONTAL_ALIGNMENT_CENTER)
        txt("발견 " + str(rec2.get("eggs", []).count(true)) + "/3", w - 122, ry + pitch * 0.5 - 2, 11, rose, 98, HORIZONTAL_ALIGNMENT_RIGHT)
        txt("기억 조각 " + ("찾음" if bool(rec2.get("shard", false)) else "—"), w - 122, ry + pitch * 0.5 + 12, 10, muted, 98, HORIZONTAL_ALIGNMENT_RIGHT)

func status_skills(y: float) -> void:
    plate(Rect2(12, y, w - 24, 44), gold if game.skill_points > 0 else Color("8d8578"))
    txt("기술 포인트 " + str(game.skill_points), 28, y + 28, 17)
    if game.job > 0:
        button("skillview_0", "기본", Rect2(w - 170, y + 5, 70, 34), game.skill_view == 0, true, 13)
        button("skillview_1", "직업", Rect2(w - 94, y + 5, 70, 34), game.skill_view == 1, true, 13)
        if game.skill_view == 1:
            status_job_skills(y); return
    else: txt("레벨업 +1 · 라이벌 승리 +1", w - 200, y + 27, 11, muted, 172, HORIZONTAL_ALIGNMENT_RIGHT)
    for i in range(game.SKILLS.size()):
        var entry = game.SKILLS[i]
        var id = String(entry.id)
        var open = game.skill_open(id)
        var lv = game.sk(id)
        var r = Rect2(12, y + 54 + i * 70, w - 24, 62)
        plate(r, ink if open else Color("8d8578"), cream if open else Color("e6e0d2"), 15, 3)
        txt(String(entry.name), 28, r.position.y + 25, 16, ink if open else muted)
        if open:
            txt("Lv." + str(lv) + (" · 최고" if lv >= game.SKILL_MAX else ""), 28 + font.get_string_size(String(entry.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 8, r.position.y + 25, 12, rose)
            txt(game.skill_line(id), 28, r.position.y + 46, 11, muted)
            for k in range(game.SKILL_MAX): panel(Rect2(28 + k * 13, r.position.y + 51, 10, 4), gold if k < lv else Color("e0d8c6"), 2)
            button("skillup_" + id, "강화", Rect2(w - 92, r.position.y + 12, 68, 38), true, game.skill_points > 0 and lv < game.SKILL_MAX, 13)
        else:
            txt("레벨 " + str(int(entry.need)) + "에 배워요", 28, r.position.y + 46, 11, muted)

# 직업 기술: 차수마다 두 개씩 새로 생기고 Lv.1 부터 키운다. 하나를 마스터하면 다음 차수로 전직한다.
func status_job_skills(y: float) -> void:
    var tone = Color(String(game.JOBS[game.job].color))
    for i in range(6):
        var info = game.ult_info(i)
        var open = game.ult_open(i)
        var id = game.job_skill_id(i)
        var lv = game.sk(id)
        var r = Rect2(12, y + 52 + i * 62, w - 24, 56)
        plate(r, tone if open else Color("8d8578"), cream if open else Color("e6e0d2"), 15, 3)
        var head = str(int(info.tier)) + "차  " + String(info.name)
        txt(head, 28, r.position.y + 22, 15, ink if open else muted)
        if open:
            txt("Lv." + str(lv) + (" · 마스터" if lv >= game.SKILL_MAX else ""), 28 + font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 8, r.position.y + 22, 12, rose)
            txt("기력 " + str(int(info.energy)) + " · " + String(info.line) + " · 위력 +" + str(int(round((game.job_mul(i) - 1.0) * 100))) + "%", 28, r.position.y + 40, 10, muted)
            for k in range(game.SKILL_MAX): panel(Rect2(28 + k * 13, r.position.y + 46, 10, 4), tone if k < lv else Color("e0d8c6"), 2)
            button("jskill_" + str(i), "강화", Rect2(w - 92, r.position.y + 9, 68, 38), true, game.skill_points > 0 and lv < game.SKILL_MAX, 13)
        else: txt(game.ult_lock(i) + " · " + String(info.line), 28, r.position.y + 41, 10, muted)
    var ay = y + 52 + 6 * 62 + 2
    var t = game.job_rank()
    if t >= 3:
        plate(Rect2(12, ay, w - 24, 48), tone)
        txt("3차 전직 완료 · " + game.job_name(), 28, ay + 30, 15)
        return
    var need = game.advance_need()
    plate(Rect2(12, ay, w - 24, 58), gold if need == "" else Color("8d8578"))
    txt(str(t + 1) + "차 전직 → " + String(game.JOBS[game.job].names[t]), 28, ay + 24, 15)
    txt("조건: 레벨 " + str((t + 1) * 10) + " · " + str(t) + "차 기술 하나 마스터" if need != "" else "준비 완료! 새 기술 2개와 기술 포인트 3개", 28, ay + 44, 10, muted if need != "" else rose)
    button("job_advance", "전직", Rect2(w - 92, ay + 10, 68, 38), true, need == "", 13)

func status_stats(y: float) -> void:
    plate(Rect2(12, y, w - 24, 76), ink)
    if game.level < game.LEVEL_MAX:
        txt("레벨 " + str(game.level), 28, y + 28, 18)
        txt("다음 레벨까지 " + str(game.exp_needed() - game.xp), w - 168, y + 28, 12, muted, 140, HORIZONTAL_ALIGNMENT_RIGHT)
        bar(Rect2(28, y + 40, w - 56, 11), float(game.xp) / maxf(1, game.exp_needed()), Color("86cc5e"))
    else:
        txt("만렙 — 더 오를 곳이 없어요", 28, y + 30, 18)
        bar(Rect2(28, y + 40, w - 56, 11), 1.0, Color("86cc5e"))
    txt("체력 " + str(game.health) + " / " + str(game.PARTY_HP), 28, y + 66, 11, muted)
    var rows = [
        ["최대 체력", str(game.party_max()), "옷 +" + str(game.gear_sum("hp"))],
        ["설거지 연타", str(game.dish_damage(0)) + " / " + str(game.dish_damage(1)) + " / " + str(game.dish_damage(2)), "도구 +" + str(game.gear_sum("atk")) + " · 치명타 " + str(int(game.crit_rate() * 100)) + "%"],
        ["냄비 불리기", str(game.soak_damage()), "무기 +" + str(game.gear_sum("soak")) + "% · " + str(game.fuse_turns()) + "턴 뒤 폭발"],
        ["월급 박치기", str(game.salary_damage()), "기력 3 · 40원"],
        ["야근 버티기 회복", str(game.guard_heal()), "뽀뽀사탕 " + str(game.candy_heal()) + " · 가방 " + str(game.bag_count("candy")) + "개"],
        ["이동 속도", str(int(game.speed_mul() * 100)) + "%", String(game.slot_gear(2).name) + " · 기념품 " + str(game.souvenirs()) + " / 10"],
    ]
    var can_job = game.level >= game.JOB_LEVEL
    row(Rect2(12, y + 84, w - 24, 52), game.job_name(), (str(game.job_rank()) + "차 · 패시브 " + str(game.job_rank()) + "개 · 직업 기술 " + str(game.job_open_count()) + " / 6" if game.job > 0 else ("레벨 " + str(game.JOB_LEVEL) + "에 전직할 수 있어요" if not can_job else ("전직해서 새 기술을 배워요" if game.base_mastered() else "기본 기술 하나를 Lv.10까지 올리면 전직"))), Color(String(game.JOBS[game.job].color)), "", "")
    button("openjobs", "전직" if game.job == 0 else "변경", Rect2(w - 96, y + 91, 72, 38), game.job == 0 and can_job, can_job, 13)
    for i in range(rows.size()):
        row(Rect2(12, y + 140 + i * 56, w - 24, 52), rows[i][0], rows[i][2], Color("6d8a62"), rows[i][1], "")
    var ly = y + 140 + rows.size() * 56
    if game.pet_team.is_empty(): row(Rect2(12, ly, w - 24, 52), "동행 없음", "잔디밭에서 몬스터를 이기면 친구가 돼요", Color("9d978a"), "", "")
    else: row(Rect2(12, ly, w - 24, 52), "동행 " + str(game.pet_team.size()) + " / " + str(game.team_max()), "기력 +" + str(game.pet_bonus("energy")) + " · 설거지 +" + str(game.pet_bonus("dish")) + " · 회복 +" + str(game.pet_bonus("care")), rose, "", "")

func status_bag(y: float) -> void:
    txt("대결과 여행에 쓰는 물건이에요. 상점에서 더 살 수 있어요.", 16, y + 16, 11, Color("cfc5b4"))
    for i in range(game.ITEMS.size()):
        var entry = game.ITEMS[i]
        var count = game.bag_count(String(entry.id))
        var r = Rect2(12, y + 26 + i * 52, w - 24, 48)
        plate(r, ink if count > 0 else Color("6d6054"), cream if count > 0 else Color("e6e0d2"), 13, 3)
        item_icon(String(entry.id), Vector2(42, r.position.y + 24))
        txt(String(entry.name), 74, r.position.y + 21, 15)
        txt(String(entry.line), 74, r.position.y + 39, 10, muted)
        txt(str(count) + "개", w - 162, r.position.y + 28, 15, rose if count > 0 else muted, 56, HORIZONTAL_ALIGNMENT_RIGHT)
        var usable = count > 0 and String(entry.id) in ["drink", "treat"]
        if String(entry.id) in ["drink", "treat"]: button("useitem_" + String(entry.id), "사용", Rect2(w - 88, r.position.y + 6, 64, 36), false, usable, 13)
        elif String(entry.id) in game.BATTLE_ITEMS: txt("대결용", w - 88, r.position.y + 28, 11, muted, 64, HORIZONTAL_ALIGNMENT_CENTER)
    var ny = y + 26 + game.ITEMS.size() * 52
    if game.next_energy > 0: txt("기력 드링크를 마셨어요 — 다음 대결은 기력 1칸으로 시작해요.", 16, ny + 20, 11, gold)
    if not game.relics.is_empty():
        var names = []
        for id in game.relics: names.append(String(game.relic_of(String(id)).name))
        txt("여행 기념품 " + str(game.relics.size()) + "개", 16, ny + 66, 12, gold)
        para(" · ".join(PackedStringArray(names)), 16, ny + 86, w - 32, 10, Color("cfc5b4"), 1.4)
    txt("도시락: " + ["없음", "뽀뽀사탕 1개 추가", "기력 1칸으로 시작", "사탕 회복 +4"][clampi(game.tour.meal, 0, 3)], 16, ny + 42, 11, Color("cfc5b4"))

func status_gear(y: float) -> void:
    tabs(["gearslot_0", "gearslot_1", "gearslot_2", "gearslot_3"], ["무기", "옷", "신발", "소품"], game.gear_slot, y, 0)
    var slot = game.gear_slot
    txt(String(game.SLOT_NAME[slot]) + " — 하나만 착용", 16, y + 62, 11, Color("cfc5b4"))
    txt("강화석 " + str(game.stones) + "개 · 한 단계마다 효과 +20%", w - 236, y + 62, 11, gold, 220, HORIZONTAL_ALIGNMENT_RIGHT)
    var cursor = y + 72
    var mine = []
    for id0 in game.owned_gear:
        var one = game.gear_of(String(id0))
        if int(one.slot) == slot and String(one.id) == String(id0): mine.append(one)
    var per = clampi(int((h - cursor - 60) / 56.0), 3, 10)
    var pages = maxi(1, int(ceil(mine.size() / float(per))))
    game.gear_page = clampi(game.gear_page, 0, pages - 1)
    for n in range(game.gear_page * per, mini(mine.size(), (game.gear_page + 1) * per)):
        var entry = mine[n]
        var id = String(entry.id)
        var on = String(game.equipped[slot]) == id
        var lv = game.enhance_lv(id)
        var r = Rect2(12, cursor, w - 24, 52)
        var edge = Color(String(game.LOOT_GRADES[int(entry.grade)].color)) if entry.has("grade") else Color("8d8578")
        plate(r, Color("4a8a38") if on else edge, cream, 14, 3)
        gear_icon(entry, Vector2(40, cursor + 25))
        txt(String(entry.name) + (" +" + str(lv) if lv > 0 else ""), 70, cursor + 19, 13, rose if lv > 0 else (edge.darkened(0.25) if entry.has("grade") else ink))
        txt(String(entry.line), 70, cursor + 33, 10, muted)
        if lv >= game.ENHANCE_MAX: txt("강화 완료", 70, cursor + 46, 10, Color("3f7a32"))
        else: txt(str(game.enhance_cost(id)) + "원 · 강화석 " + str(game.enhance_stones(id)) + " · 성공 " + str(game.ENHANCE_RATE[lv]) + "%", 70, cursor + 46, 10, rose)
        button("enh_" + id, "강화", Rect2(w - 150, cursor + 7, 58, 36), true, lv < game.ENHANCE_MAX and game.coins >= game.enhance_cost(id) and game.stones >= game.enhance_stones(id), 12)
        if on: txt("착용 중", w - 88, cursor + 30, 11, Color("3f7a32"), 64, HORIZONTAL_ALIGNMENT_CENTER)
        else: button("equip_" + id, "착용", Rect2(w - 88, cursor + 7, 64, 36), false, true, 12)
        if entry.has("grade") and not on: button("salvage_" + id, "분해", Rect2(w - 208, cursor + 7, 54, 36), false, true, 11)
        cursor += 56
    if pages > 1:
        button("gearpage_prev", "←", Rect2(w - 196, cursor + 2, 52, 38), false, game.gear_page > 0, 15)
        txt(str(game.gear_page + 1) + " / " + str(pages), w - 140, cursor + 27, 13, cream, 68, HORIZONTAL_ALIGNMENT_CENTER)
        button("gearpage_next", "→", Rect2(w - 68, cursor + 2, 52, 38), false, game.gear_page < pages - 1, 15)
        cursor += 44
    txt("새 장비와 강화석은 도시의 앨리 가게에서 팔아요.", 16, cursor + 14, 11, Color("cfc5b4"))

func status_pets(y: float) -> void:
    if game.pets.is_empty():
        plate(Rect2(12, y + 20, w - 24, 90), Color("8d8578"))
        txt("아직 동행이 없어요", 28, y + 52, 17)
        txt("돌아다니는 몬스터에 닿으면 대결해요. 이기면 따라올 수도 있어요.", 28, y + 76, 11, muted)
        return
    txt("도장을 모으면 칸이 늘어요 (" + str(game.pet_team.size()) + " / " + str(game.team_max()) + "). 눌러서 넣고 빼요.", 16, y + 16, 11, Color("cfc5b4"))
    # 한 화면에 들어가는 만큼만 보여 주고 쪽을 넘긴다
    var per = clampi(int((h - y - 110) / 60.0), 3, 9)
    var pages = maxi(1, int(ceil(game.pets.size() / float(per))))
    game.pet_page = clampi(game.pet_page, 0, pages - 1)
    var first = game.pet_page * per
    var shown = mini(game.pets.size() - first, per)
    for n in range(shown):
        var i = first + n
        var p = game.pets[i]
        var on = game.pet_team.has(i)
        var grade = int(p.get("g", 0))
        var r = Rect2(12, y + 28 + n * 60, w - 24, 54)
        plate(r, rose if on else Color("8d8578"), cream, 15, 3)
        panel(Rect2(22, r.position.y + 6, 42, 42), Color("f1e6cf"), 10, Color(game.GRADES[grade].color))
        flat_art.mob(self, game.pet_art(p), Vector2(43, r.position.y + 44), 34.0 / maxf(1.0, maxf(flat_art.mob_size(game.pet_art(p)).x, flat_art.mob_size(game.pet_art(p)).y)), 0.0, game.pet_tint(p))
        txt(game.pet_name(p), 74, r.position.y + 24, 15)
        if grade > 0: txt(String(game.GRADES[grade].tag), 74 + font.get_string_size(game.pet_name(p), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 6, r.position.y + 24, 11, Color(game.GRADES[grade].color))
        txt(String(game.pet_role(p).tag) + " +" + str(game.pet_power(p)) + (" · 모든 능력" if int(p.i) == 3 else " · 친밀도 " + str(p.lv) + "/5"), 74, r.position.y + 43, 11, muted)
        if on: txt("동행 중", w - 96, r.position.y + 33, 13, rose, 72, HORIZONTAL_ALIGNMENT_RIGHT)
        buttons["petpick_" + str(i)] = r
    var fy = y + 30 + shown * 60
    txt("모은 친구 " + str(game.pets.size()) + " / 40", 16, fy + 26, 11, Color("cfc5b4"))
    if pages > 1:
        button("petpage_prev", "←", Rect2(w - 196, fy, 52, 42), false, game.pet_page > 0, 15)
        txt(str(game.pet_page + 1) + " / " + str(pages), w - 140, fy + 27, 13, cream, 68, HORIZONTAL_ALIGNMENT_CENTER)
        button("petpage_next", "→", Rect2(w - 68, fy, 52, 42), false, game.pet_page < pages - 1, 15)

func draw_map() -> void:
    panel(Rect2(0, 0, w, h), Color("294b4670"), 0)
    var y = h / 2 - 270
    panel(Rect2(18, y, w - 36, 540), cream, 25)
    txt("우리의 작은 파리", 38, y + 45, 26)
    txt("● 나  ◎ 목표  초록=잔디 · 만남 " + str(game.wild_seen.count(true)) + "/3", 38, y + 77, 13, muted)
    var r = Rect2(38, y + 105, w - 76, 337)
    panel(r, Color("b9c9a7"), 12)
    var scale_xy = Vector2(r.size.x / 27, r.size.y / 29)
    var origin = r.position + r.size / 2
    draw_rect(Rect2(origin + Vector2(-13.5, 1.4) * scale_xy, Vector2(27, 3.2) * scale_xy), Color("7fb9b6"))
    draw_rect(Rect2(origin + Vector2(-1.7, 1) * scale_xy, Vector2(3.4, 4.3) * scale_xy), Color("eddbb9"))
    for road in [Rect2(-1.55, -9.4, 3.1, 11.2), Rect2(-1.55, 4.75, 3.1, 7.1), Rect2(-10.5, -2.3, 21, 2.6), Rect2(-10.5, 6.3, 21, 2.4)]:
        draw_rect(Rect2(origin + road.position * scale_xy, road.size * scale_xy), Color("eddbb9"))
    for zone in game.world.grass_zones:
        draw_rect(Rect2(origin + zone.position * scale_xy, zone.size * scale_xy), Color("537e61"))
    for i in range(3):
        var p = [Vector2(-7, -4), Vector2(7, -4), Vector2(0, -9)][i]
        draw_circle(origin + p * scale_xy, 10, rose)
        txt( ["빵집", "카페", "에펠탑"][i], origin.x + p.x * scale_xy.x - 35, origin.y + p.y * scale_xy.y - 16, 12, ink, 70, HORIZONTAL_ALIGNMENT_CENTER)
    var t = Vector2(game.target.x, game.target.z)
    draw_arc(origin + t * scale_xy, 12, 0, TAU, 24, Color("f3d17d"), 4, true)
    var p = Vector2(game.hero.position.x, game.hero.position.z)
    draw_circle(origin + p * scale_xy, 7, ink)
    button("close_map", "산책으로 돌아가기", Rect2(38, y + 462, w - 76, 56), true)

func pointer_down(id: int, pos: Vector2) -> void:
    if w > h: return
    if game.state == "explore" and pos.distance_to(stick_center) < stick_radius + 14 and stick_id == -99:
        stick_id = id; update_stick(pos); return
    for key in buttons:
        if buttons[key].has_point(pos): pressed[id] = key; queue_redraw(); return
    # 대결 중 버튼이 아닌 곳을 톡 — 타이밍 공격과 방어
    if game.state == "battle" and game.battle_phase in ["player", "windup", "enemy"]: game.battle_tap()

func pointer_up(id: int, pos: Vector2) -> void:
    if id == stick_id:
        stick_id = -99; stick_delta = Vector2.ZERO; game.joystick = Vector2.ZERO
    if pressed.has(id):
        var key = pressed[id]; pressed.erase(id)
        if buttons.has(key) and buttons[key].has_point(pos):
            game.joystick = Vector2.ZERO; stick_delta = Vector2.ZERO; stick_id = -99
            game.action(key)
    queue_redraw()

func update_stick(pos: Vector2) -> void:
    stick_delta = (pos - stick_center).limit_length(stick_reach)
    game.joystick = stick_delta / stick_reach if stick_delta.length() > 5 else Vector2.ZERO

func release_all() -> void:
    stick_id = -99; stick_delta = Vector2.ZERO; pressed.clear(); game.joystick = Vector2.ZERO

func _input(event: InputEvent) -> void:
    if not game: return
    if event is InputEventScreenTouch:
        if event.canceled:
            pressed.erase(event.index)
            if event.index == stick_id: release_all()
        elif event.pressed: pointer_down(event.index, event.position)
        else: pointer_up(event.index, event.position)
    elif event is InputEventScreenDrag:
        if event.index == stick_id: update_stick(event.position)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed: pointer_down(-1, event.position)
        else: pointer_up(-1, event.position)
    elif event is InputEventMouseMotion and stick_id == -1: update_stick(event.position)
    elif event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            if game.state == "pause": game.action("resume")
            elif game.state == "map": game.action("close_map")
            elif game.state in ["explore", "cook", "battle"]: game.action("pause")
        elif event.keycode in [KEY_E, KEY_SPACE, KEY_ENTER]:
            match game.state:
                "title": game.action("start")
                "intro": game.action("intro_next")
                "tutorial": game.action("tutorial_next")
                "dialogue": game.action("next")
                "explore": game.action("interact")
                "battle_ready": game.action("battle_start")
                "battle":
                    if game.battle_phase != "choose": game.battle_tap()
                    elif game.battle_menu == "fight": game.action("strike")
                    else: game.action("fight_menu")
                "battle_won": game.action("battle_continue")
                "photo": game.action("photo")
        elif event.keycode in [KEY_1, KEY_2, KEY_3] and game.state == "cook": game.action("recipe" + str(event.keycode - KEY_1))

func draw_intro() -> void:

    var page = game.intro_page
    panel(Rect2(0, 0, w, 112), Color("294b46f2"), 0)
    txt("OUR LITTLE JOURNEY", 26, 39, 11, Color("d9c68f"))
    txt( ["PROLOGUE  /  잃어버린 약속", "SOHYUN & DONGHOON", "CHAPTER 01  /  작은 용기"][page], 26, 72, 14, cream)
    for i in range(3): panel(Rect2(26 + i * (w - 52) / 3, 94, (w - 64) / 3, 3), gold if i <= page else Color("587069"), 2)
    var y = h - 304

    panel(Rect2(0, y, w, h - y), cream, 0)
    txt( ["파리, 함께 도착한 첫 도시", "소현이 동훈에게", "두 사람의 새로운 여행"][page], 28, y + 31, 12, rose)
    para( ["다시, 너와 파리.", "천천히 기억해도 괜찮아.", "낯선 만남도, 함께라면."][page], 26, y + 73, w - 52, 27, ink, 1.3)
    para( ["동훈의 기억은 사라졌지만,\n함께 떠나기로 한 약속은 남아 있었다.\n첫 번째 기억을 찾아, 파리에 도착했다.", "“좋아하던 빵부터 먹자.\n오늘부터 다시 기억을 쌓으면 되니까.”\n동훈은 조용히 소현의 곁에 섰다.", "동훈은 낯선 적들과 한 수씩 겨루고,\n따뜻한 빵을 굽고, 둘의 사진을 남기자.\n작은 순간들이 다시 기억이 될 것이다."][page], 28, y + 119, w - 56, 17, ink, 1.7)
    button("intro_next", "조작법 알아보기  →" if page == 2 else "다음 장면  →", Rect2(26, h - 86, w - 52, 60), true, true, 17)
    button("intro_skip", "조작법으로", Rect2(w - 124, 126, 100, 48), false, true, 12)

func draw_tutorial() -> void:
    var page = game.tutorial_page
    panel(Rect2(0, 0, w, h), cream, 0)
    txt("BEFORE WE GO", 27, 42, 11, muted)
    txt("함께 여행하는 방법", 25, 86, 29)
    txt(str(page + 1) + " / 3", w - 73, 41, 13, rose)
    var titles = ["왼손으로, 천천히 걸어요.", "반짝이는 목표를 찾아요.", "잔디밭은 언제나 모험 중!"]
    var descriptions = ["왼쪽 스틱을 원하는 방향으로 밀어요.\n소현이가 움직이면 동훈이가 따라와요.\n손을 떼면 두 사람도 멈춰요.", "금색 표시 쪽으로 걸어가요.\n재료는 가까이 가면 자동으로 담고,\n사람과 대화할 땐 오른쪽 버튼을 눌러요.", "초록 잔디를 걸으면 몬스터를 만나요.\n동훈의 기술을 골라 한 번씩 주고받아요.\n길과 다리에서는 안심하고 산책해요."]
    var cy = clampf(h * 0.37, 265, 350)
    panel(Rect2(24, 119, w - 48, cy + 97 - 119), Color("e8eddd"), 26)
    if page == 0:
        var center = Vector2(w / 2, cy)
        draw_circle(center, 73, Color("d5dfc8")); draw_arc(center, 73, 0, TAU, 64, Color("9bad93"), 2, true)
        var delta = Vector2(sin(game.scene_time * 1.5) * 34, -18)
        draw_line(center, center + delta, Color("b1c09d"), 10, true)
        draw_circle(center + delta, 33, cream); draw_circle(center + delta, 8, ink)
        centered("스틱을 밀면 이동 · 손을 떼면 멈춤", 155, 13, muted)
    elif page == 1:
        var center = Vector2(w / 2, cy - 14)
        for i in range(5): draw_circle(center + Vector2(-80 + i * 25, 35 - i * 13), 4, Color("9bab8c"))
        draw_arc(center + Vector2(46, -30), 30, 0, TAU, 48, gold, 6, true)
        draw_circle(center + Vector2(46, -30), 9, rose)
        chip("밀가루 · 3m", Rect2(w / 2 - 90, cy + 37, 180, 34), Color("fff1c9"))
        centered("목표에 가까워지면 행동 버튼이 진해져요", 155, 13, muted)
    else:
        var center = Vector2(w / 2, cy - 30)
        draw_circle(center, 39, Color("94b271")); draw_circle(center + Vector2(-26, -31), 14, Color("94b271")); draw_circle(center + Vector2(26, -31), 14, Color("94b271"))
        draw_ellipse(center + Vector2(0, 13), Vector2(27, 18), cream)
        for side in [-1, 1]: draw_circle(center + Vector2(side * 13, 0), 4, ink)
        chip("공격 → 반격 → 다음 선택", Rect2(48, cy + 35, w - 96, 36), Color("fff1c9"))
        centered("선택 시간은 무제한 · 동훈 혼자 출전해요", 155, 12, muted)
    var text_y = cy + 146
    para(titles[page], 28, text_y, w - 56, 24, ink, 1.4)
    para(descriptions[page], 28, text_y + 49, w - 56, 17, muted, 1.8)
    button("tutorial_next", "이제 파리로 출발!  →" if page == 2 else "다음 안내  →", Rect2(26, h - 140, w - 52, 60), true)
    button("tutorial_skip", "알겠어요, 바로 시작", Rect2(26, h - 70, w - 52, 44), false, true, 13)
