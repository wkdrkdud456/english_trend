extends RefCounted

func heading(c, title: String, sub: String) -> void:
    c.panel(Rect2(0, 0, c.w, c.h), c.cream, 0)
    c.txt(sub, 26, 42, 12, c.muted)
    c.txt(title, 24, 86, 29)

func photo(c, texture, rect: Rect2, label: String, card: int = -1) -> void:
    c.panel(rect, Color("d1ddcc"), 5)
    if card >= 0:
        c.flat_art.postcard(c, rect, card, c.game)
    elif texture:
        var s = texture.get_size(); var crop = s.x * rect.size.y / rect.size.x
        c.draw_texture_rect_region(texture, rect, Rect2(0, maxf(0, (s.y - crop) * 0.6), s.x, minf(s.y, crop)))
    else: c.txt(label, rect.position.x, rect.get_center().y, 26, c.muted, rect.size.x, HORIZONTAL_ALIGNMENT_CENTER)

func draw(c) -> void:
    var g = c.game; var t = g.tour; var d = g.city(); var w = c.w; var h = c.h
    match g.state:
        "arrival":
            c.panel(Rect2(0, 0, w, 150), Color("294b46ed"), 0)
            c.txt("CHAPTER %02d / %s" % [g.city_index + 1, d.english], 26, 44, 13, c.gold)
            c.txt(d.name, 24, 96, 38, c.cream); c.txt(d.subtitle, 27, 130, 17, c.cream)
            var y = h - 330; c.panel(Rect2(0, y, w, 330), c.cream, 0)
            var line_y = y + 35
            for line in d.intro: line_y = c.para(line, 28, line_y, w - 56, 17, c.ink, 1.5) + 8
            c.button("arrival_go", "이 도시의 이야기 시작  →", Rect2(26, h - 86, w - 52, 60), true)
        "passport":
            heading(c, "둘의 여행 여권", "OUR LITTLE JOURNEY / TEN CITIES")
            c.txt("도장 %d / 10 · 도시를 눌러 추억과 만남을 확인해요" % t.completed.count(true), 26, 117, 13, c.muted)
            var bw = (w - 62) / 2; var row_h = minf(103, (h - 250) / 5)
            for i in range(10):
                var ci = g.CityData.CITIES[i]; var x = 24 + (i % 2) * (bw + 14); var y = 140 + int(i / 2) * row_h
                c.button("city_" + str(i), "", Rect2(x, y, bw, row_h - 12), i == g.city_index)
                var fg = c.cream if i == g.city_index else c.ink
                c.txt("%02d  %s" % [i + 1, ci.name], x + 14, y + 29, 19, fg)
                c.txt("도장 완료 ✓" if t.completed[i] else "여행 가능" if i <= t.unlocked else "이전 도시 도장 필요", x + 14, y + 55, 12, fg)
            c.button("passport_close", "지금 도시에서 계속 걷기", Rect2(24, h - 88, w - 48, 60), true)
        "journal":
            var i = t.selected; var ci = g.CityData.CITIES[i]; var r = t.records[i]
            heading(c, ci.name + "의 여행 수첩", "%02d / %s" % [i + 1, ci.english])
            var ph = minf(205, h * 0.24); photo(c, null, Rect2(24, 112, w - 48, ph), ci.english, i if t.completed[i] or g.cycle > 0 else -1)
            var y = 142 + ph
            y = c.para(ci.memory if t.completed[i] else ci.hint, 26, y, w - 52, 17, c.ink, 1.5) + 13
            c.txt("만난 몬스터  %d / 3" % r.wild_seen.count(true), 26, y, 14, c.rose); y += 28
            for m in range(3): c.txt(ci.mobs[m].name if r.wild_seen[m] else "아직 만나지 못한 친구", 28, y + m * 27, 14, c.muted)
            if i == 6:
                var bw = (w - 68) / 3
                for v in range(3):
                    var rect = Rect2(24 + v * (bw + 10), h - 251, bw, 75)
                    c.button("vista_album_" + str(v), "풍경 " + str(v + 1), rect, false, bool(r.marks[v]), 13)
                    var im = t.read_photo(i, "-vista" + str(v)) if r.marks[v] else null
                    if im: photo(c, im, rect.grow(-3), "")
            c.button("travel_selected", "이 도시로 이동" if i <= t.unlocked else "이전 도시를 먼저 마쳐 주세요", Rect2(24, h - 158, w - 48, 60), true, i <= t.unlocked, 16)
            c.button("passport", "← 여권으로", Rect2(24, h - 86, w - 48, 60))
        "vista_album":
            heading(c, g.CityData.CITIES[6].labels[t.vista], "SANTORINI / VIEWFINDER %02d" % (t.vista + 1))
            var im = t.read_photo(6, "-vista" + str(t.vista))
            if im:
                var area = Rect2(24, 112, w - 48, h - 230); var factor = minf(area.size.x / im.get_width(), area.size.y / im.get_height())
                var dims = im.get_size() * factor; c.draw_texture_rect(im, Rect2(area.get_center() - dims / 2, dims), false)
            c.button("journal_back", "← 산토리니 여행 수첩", Rect2(24, h - 86, w - 48, 60), true)
        "city_help":
            heading(c, d.name + " 여행 안내", d.english + " / FIELD NOTES")
            var y = c.para(t.objective(), 26, 133, w - 52, 24, c.ink, 1.4) + 16
            y = c.para(d.hint, 26, y, w - 52, 17, c.ink, 1.6) + 18
            c.txt("이 지역의 대결", 26, y, 16, c.rose); y += 31
            y = c.para(d.rule, 26, y, w - 52, 17, c.ink, 1.5) + 18
            if g.city_index == 7:
                for i in range(3):
                    if t.record().marks[i]: y = c.para("• " + t.WITNESSES[i], 26, y, w - 52, 14, c.muted, 1.5) + 6
            else:
                y = c.para("도장을 모을 때마다 동훈의 최대 체력 +3. 도장 3개마다 설거지의 각 타격과 야근 회복이 1씩 강해져요.", 26, y, w - 52, 15, c.muted, 1.5) + 14
                c.para("지역 음식은 노점에서 포장해 다음 대결에 사용해요. 길에서는 안전하고, 잔디밭은 언제든 야생 대결이 열려요.", 26, y, w - 52, 15, c.muted, 1.5)
            c.button("help_close", "알겠어, 가보자!", Rect2(24, h - 86, w - 48, 60), true)
        "deduction", "memory_question":
            heading(c, "우산의 주인을 찾아라" if g.state == "deduction" else "잊지 않기로 한 말", "LITTLE MYSTERY / OUR MEMORIES")
            var y = 139; var choices = []
            if g.state == "deduction":
                for clue in t.WITNESSES: y = c.para(clue, 26, y, w - 52, 18, c.ink, 1.6) + 18
                choices = t.SUSPECTS
            else:
                c.txt("질문 " + str(t.quiz_step + 1) + " / 2", 26, y - 14, 12, c.rose)
                y = c.para(t.QUESTIONS[t.question * 2 + t.quiz_step][0], 26, y + 14, w - 52, 23, c.ink, 1.5)
                choices = t.QUESTIONS[t.question * 2 + t.quiz_step][1]
            var gap = 62.0 if choices.size() > 3 else 75.0
            for i in range(choices.size()): c.button("answer_" + str(i), choices[i], Rect2(26, h - 100 - choices.size() * gap + i * gap, w - 52, gap - 10), false, true, 15)
            c.button("puzzle_close", "조금 더 생각해 볼게", Rect2(26, h - 87, w - 52, 60), false, true, 14)
        "food_shop":
            c.panel(Rect2(0, 0, w, h), c.cream, 0)
            c.txt(d.english + " / 앨리의 가게", 26, 40, 11, c.muted)
            c.txt(d.shop, 24, 76, 26)
            c.icon_coin(Vector2(w - 96, 64), 10)
            c.txt(str(g.coins) + "원", w - 80, 71, 18, c.rose)
            c.tabs(["shoptab_0", "shoptab_1", "shoptab_2"], ["도시락", "장비", "소모품"], g.shop_tab, 96, 0)
            var sy = 152
            if g.shop_tab == 0:
                var cost = 12 + g.city_index * 2
                c.txt("한 번에 한 끼만 포장할 수 있어요. 다음 대결에서 자동으로 먹어요.", 24, sy, 12, c.muted)
                for i in range(3):
                    var my = sy + 20 + i * 86
                    var ok = g.coins >= cost and t.meal == 0
                    c.plate(Rect2(16, my, w - 32, 76), c.ink if ok else Color("b4ada0"), c.cream if ok else Color("ece6da"), 15, 3)
                    c.item_icon("meal", Vector2(50, my + 37))
                    c.txt(d.menu[i], 82, my + 32, 19)
                    c.txt( ["뽀뽀사탕 1개 추가", "기력 1칸으로 시작", "이번 대결의 사탕 회복 +4"][i], 82, my + 54, 11, c.muted)
                    c.button("meal_" + str(i), str(cost) + "원", Rect2(w - 118, my + 16, 94, 44), false, ok, 15)
                if t.meal > 0: c.txt("이미 도시락을 챙겼어요.", 24, sy + 290, 13, c.rose)
            elif g.shop_tab == 1:
                c.tabs(["gearslot_0", "gearslot_1", "gearslot_2", "gearslot_3"], ["무기", "옷", "신발", "소품"], g.gear_slot, sy - 8, 0)
                var gy = sy + 44
                for entry in g.GEAR:
                    if int(entry.cost) <= 0 or int(entry.slot) != g.gear_slot or int(entry.get("cycle", 0)) > g.cycle: continue
                    var id = String(entry.id)
                    var have = g.owned_gear.has(id)
                    var afford = g.coins >= int(entry.cost)
                    c.plate(Rect2(16, gy, w - 32, 58), Color("4a8a38") if have else (c.ink if afford else Color("b4ada0")), c.cream if afford or have else Color("ece6da"), 14, 3)
                    c.gear_icon(entry, Vector2(46, gy + 28))
                    c.txt(String(entry.name), 78, gy + 25, 16)
                    c.txt(String(entry.line), 78, gy + 44, 11, c.muted)
                    if have: c.txt("보유 중", w - 110, gy + 34, 13, Color("3f7a32"), 86, HORIZONTAL_ALIGNMENT_RIGHT)
                    else: c.button("buygear_" + id, str(int(entry.cost)) + "원", Rect2(w - 112, gy + 9, 88, 40), false, afford, 14)
                    gy += 64
            else:
                c.txt("가방에 넣어 두고 필요할 때 써요.", 24, sy, 12, c.muted)
                var zy = sy + 16 + g.ITEMS.size() * 74
                c.plate(Rect2(16, zy, w - 32, 66), c.ink if g.coins >= 150 else Color("b4ada0"), c.cream, 15, 3)
                c.draw_colored_polygon(PackedVector2Array([Vector2(48, zy + 16), Vector2(62, zy + 32), Vector2(48, zy + 50), Vector2(34, zy + 32)]), Color("7fd0e8"))
                c.draw_colored_polygon(PackedVector2Array([Vector2(48, zy + 16), Vector2(55, zy + 32), Vector2(48, zy + 50)]), Color("b8ecf8"))
                c.txt("강화석", 80, zy + 28, 17)
                c.txt("장비 강화에 써요 (내 정보 → 장비)", 80, zy + 50, 11, c.muted)
                c.txt("보유 " + str(g.stones), w - 196, zy + 32, 12, c.muted, 70, HORIZONTAL_ALIGNMENT_RIGHT)
                c.button("buystone", "150원", Rect2(w - 118, zy + 13, 94, 42), false, g.coins >= 150, 14)
                for i in range(g.ITEMS.size()):
                    var entry2 = g.ITEMS[i]
                    var iid = String(entry2.id)
                    var count = g.bag_count(iid)
                    var full = count >= int(entry2.cap)
                    var can = g.coins >= int(entry2.cost) and not full
                    var iy = sy + 16 + i * 74
                    c.plate(Rect2(16, iy, w - 32, 66), c.ink if can else Color("b4ada0"), c.cream if can else Color("ece6da"), 15, 3)
                    c.item_icon(iid, Vector2(48, iy + 32))
                    c.txt(String(entry2.name), 80, iy + 28, 17)
                    c.txt(String(entry2.line), 80, iy + 50, 11, c.muted)
                    c.txt("보유 " + str(count), w - 196, iy + 32, 12, c.muted, 70, HORIZONTAL_ALIGNMENT_RIGHT)
                    c.button("buyitem_" + iid, "가득" if full else str(int(entry2.cost)) + "원", Rect2(w - 118, iy + 13, 94, 42), false, can, 14)
            c.button("food_close", "고마워요, 다시 산책", Rect2(26, h - 86, w - 52, 60), true)
        "vista":
            c.chip(d.labels[t.vista] + " · 풍경 수집", Rect2(24, 32, w - 48, 40))
            c.panel(Rect2(0, h - 191, w, 191), c.cream, 0)
            c.centered("섬을 다른 각도에서 기억해 봐요.", h - 155, 18)
            c.button("vista_capture", "이 풍경 담기 ◎", Rect2(26, h - 133, w - 52, 60), true)
            c.button("vista_close", "뒤로", Rect2(26, h - 63, w - 52, 48), false, true, 14)

func ending(c) -> void:
    var g = c.game; var d = g.city(); var w = c.w; var h = c.h
    heading(c, "다시 기억하게 된 " + d.name, "OUR LITTLE JOURNEY / %02d" % [g.city_index + 1])
    var ph = minf(260, h * 0.29); photo(c, null, Rect2(24, 114, w - 48, ph), d.english, g.city_index)
    var y = 143 + ph; c.chip("도장 %d / 10 · 최대 체력 +3" % g.tour.completed.count(true), Rect2(24, y - 9, w - 48, 37), c.gold)
    c.para(d.memory, 26, y + 62, w - 52, 19, c.ink, 1.55)
    if g.city_index == 9: c.centered("열 도시의 끝. 우리의 내일은 이제 시작.", h - 273, 15, c.rose)
    c.button("next_city" if g.city_index < 9 else "passport", "다음 도시, " + g.CityData.CITIES[mini(9, g.city_index + 1)].name + "로 →" if g.city_index < 9 else "열 도시의 추억 돌아보기", Rect2(24, h - 228, w - 48, 62), true)
    c.button("passport" if g.city_index < 9 else "wander", "여권 · 도시별 앨범" if g.city_index < 9 else "서울에서 조금 더 걷기", Rect2(24, h - 154, w - 48, 60))
    c.button("wander" if g.city_index < 9 else "new_cycle", "이 도시에서 조금 더 걷기" if g.city_index < 9 else str(g.cycle + 2) + "회차 여행 떠나기 · 상대가 더 강해져요", Rect2(24, h - 82, w - 48, 60), false, true, 15)

func map_screen(c) -> void:
    var g = c.game; var w = c.w; var h = c.h
    heading(c, g.city().name + " 산책 지도", "FIELD MAP / " + g.city().english)
    var r = Rect2(24, 120, w - 48, minf(440, h - 326)); c.panel(r, Color(g.city().pal.g0), 6)
    var scale_xy = r.size / Vector2(27, 29); var origin = r.get_center()
    for zone in g.world.water_zones: c.draw_rect(Rect2(origin + zone.position * scale_xy, zone.size * scale_xy), Color(g.city().pal.a1))
    for zone in g.world.grass_zones: c.draw_rect(Rect2(origin + zone.position * scale_xy, zone.size * scale_xy), Color("608851"))
    for zone in g.world.roads: c.draw_rect(Rect2(origin + zone.position * scale_xy, zone.size * scale_xy), Color(g.city().pal.p0))
    for zone in g.world.solid: c.draw_rect(Rect2(origin + zone.position * scale_xy, zone.size * scale_xy), Color(g.city().pal.w2))
    for p in g.city().points: c.draw_circle(origin + Vector2(p[0], p[1]) * scale_xy, 5, c.rose)
    var s = g.city().shop_at; c.draw_circle(origin + Vector2(s[0], s[1]) * scale_xy, 6, c.cream)
    c.draw_arc(origin + Vector2(g.target.x, g.target.z) * scale_xy, 11, 0, TAU, 24, c.gold, 4, true)
    c.draw_circle(origin + Vector2(g.hero.position.x, g.hero.position.z) * scale_xy, 7, c.ink)
    c.txt("● 나   ◯ 목표   ● 지역 행사   ○ 음식 노점", 26, r.end.y + 33, 13, c.ink)
    c.button("passport", "여권 열기 · 다른 도시 / 앨범", Rect2(24, h - 158, w - 48, 60), false, true, 16)
    c.button("close_map", "산책으로 돌아가기", Rect2(24, h - 86, w - 48, 60), true)

func weather(c) -> void:
    var g = c.game
    if not g.effects_on or g.state not in ["explore", "arrival", "photo", "vista"]: return
    var kind = g.city().weather
    if kind not in ["snow", "rain", "petals"]: return
    for i in range(18):
        var x = fmod(i * 97 + sin(g.game_time * 0.6 + i) * 12, c.w)
        var y = fmod(i * 73 + g.game_time * (65 if kind == "rain" else 17), c.h)
        if kind == "rain": c.draw_line(Vector2(x, y), Vector2(x - 3, y + 12), Color("c7dde368"), 1)
        else: c.draw_rect(Rect2(x, y, 4, 3), Color("fff4edb0" if kind == "snow" else "f6bfceb0"))
