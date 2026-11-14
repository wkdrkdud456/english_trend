extends RefCounted
const CityData = preload ("res://scripts/city_data.gd")
var game: Node3D
var records: Array = []
var completed: Array = []
var unlocked = 0
var selected = 0
var question = 0
var trial = -1
var vista = -1
var meal = 0
var pending_vista = false
var photo_cache: Dictionary = {}
const LANTERN_ORDER = [1, 0, 2]
const RUNE_ANSWER = [2, 0, 1]
const WITNESSES = ["우산 주인은 찻잔을 들고 있지 않았어요.", "모자를 쓴 사람은 두 손이 비어 있었어요.", "후보는 찻잔을 든 티룸 주인, 중절모를 쓴 경비, 신문 배달부예요."]
const QUESTIONS = [
    ["파리에서 되찾은 첫 집의 약속은?", ["설거지는 내가 할게", "그릇은 내일 씻자", "식기세척기를 기다리자"], 0],
    ["런던의 우산 아래에서 했던 말은?", ["비 그칠 때까지 혼자 갈게", "내가 들게. 너 어깨 젖어", "우산은 장식이야"], 1],
    ["서울에 돌아와 내일부터 할 일은?", ["약속을 다시 미루기", "알람을 열 번 끄기", "아침밥과 설거지 함께하기"], 2]
]

func _init(owner: Node3D) -> void:
    game = owner; reset_records()

func reset_records() -> void:
    records.clear(); completed.clear(); unlocked = 0; selected = 0; meal = 0; trial = -1
    for i in range(10):
        var marks = []
        for point in CityData.CITIES[i].points: marks.append(false)
        records.append({ "stage": 0, "collected": [false, false, false], "marks": marks, "runes": [0, 0, 0], "sequence": 0, "deliveries": 0, "carrying": false, "solved": false, "visited": false, "wild_wins": 0, "wild_seen": [false, false, false], "best_combo": 0, "perfects": 0, "position": CityData.CITIES[i].spawn.duplicate()})
        completed.append(false)

func record() -> Dictionary:
    return records[game.city_index]

func city() -> Dictionary:
    return CityData.CITIES[game.city_index]

func v(point: Array) -> Vector3:
    var p = Vector3(point[0], 0, point[1]); p.y = game.world.surface_height(p) + 0.015
    return p

func current_photo_path(city_index: int = -1, extra: String = "") -> String:
    var ci = game.city_index if city_index < 0 else city_index
    var base = "user://"; var prefix = "tour"
    if game.SAVE_FILE.begins_with("res://"): base = "res://"; prefix = "test-tour"
    elif "qa-" in game.SAVE_FILE: prefix = "qa-tour"
    if ci == 0 and extra == "":
        if prefix == "tour": return "user://paris-memory.png"
        return base + ("qa-photo.png" if prefix == "qa-tour" else "test-memory.png")
    return base + prefix + "-" + CityData.CITIES[ci].id + extra + ".png"

func store_current() -> void:
    var r = record(); r.stage = game.stage; r.collected = game.collected.duplicate()
    r.wild_wins = game.wild_wins; r.wild_seen = game.wild_seen.duplicate(); r.best_combo = game.best_combo
    r.perfects = game.story_perfects if game.wild_battle else game.perfects
    var in_battle = game.state in ["battle", "battle_ready", "battle_lost", "battle_won"] or (game.state == "pause" and game.previous_state in ["battle", "battle_ready"])
    var p = game.battle_return if game.wild_battle or in_battle else game.hero.position
    r.position = [p.x, p.z]

func apply_city(index: int) -> void:
    game.city_index = clampi(index, 0, 9); game.rebuild_city()
    var r = record(); game.stage = clampi(int(r.get("stage", 0)), 0, 4)
    game.collected = r.get("collected", [false, false, false]).duplicate()
    game.wild_wins = int(r.get("wild_wins", 0)); game.wild_seen = r.get("wild_seen", [false, false, false]).duplicate()
    game.best_combo = int(r.get("best_combo", 0)); game.perfects = int(r.get("perfects", 0))
    game.hero.position = v(r.get("position", city().spawn))
    if not game.world.can_walk(game.hero.position): game.hero.position = v(city().spawn)
    game.partner.position = game.hero.position
    for offset in [Vector3(0.8, 0, 0.5), Vector3(-0.8, 0, 0.5), Vector3(0, 0, 1)]:
        if game.world.can_walk(game.hero.position + offset): game.partner.position = game.hero.position + offset; break
    game.wild_battle = false; game.grass_steps = 0; game.encounter_grace = 2.8; trial = -1
    game.PARTY_HP = game.party_max()
    game.photo_file = current_photo_path(); game.photo = read_photo(game.city_index)
    game.reset_follow_path(); sync_props(); game.update_target(); game.set_camera(1, true)

func read_photo(index: int, extra: String = "") -> ImageTexture:
    var path = current_photo_path(index, extra)
    if photo_cache.has(path): return photo_cache[path]
    if FileAccess.file_exists(path):
        var im = Image.load_from_file(path)
        if im and not im.is_empty():
            var tex = ImageTexture.create_from_image(im); photo_cache[path] = tex; return tex
    return null

func travel(index: int) -> void:
    if game.state not in ["passport", "journal", "ending", "explore"] or index < 0 or index > unlocked: return
    store_current(); game.save_progress(); game.joystick = Vector2.ZERO; game.hud.release_all()
    apply_city(index)
    game.state = "arrival" if not bool(record().visited) else "explore"
    record().visited = true; game.save_progress()

func stamp_city() -> void:
    if not completed[game.city_index]:
        completed[game.city_index] = true; unlocked = maxi(unlocked, mini(9, game.city_index + 1))
        var reward = 40 + game.city_index * 10
        if game.bag_count("film") > 0:
            game.bag_add("film", -1); reward += 30
            game.toast("기념 필름을 썼어요. 사진 보상 +30원")
        game.coins += reward
    photo_cache.erase(current_photo_path())
    store_current()

func progress_count() -> int:
    if game.city_index == 0: return game.collected.count(true)
    var r = record()
    if city().kind == "runes":
        var count = 0
        for i in range(3):
            if int(r.runes[i]) == RUNE_ANSWER[i]: count += 1
        return count
    if city().kind == "delivery": return int(r.deliveries)
    return r.marks.count(true)

func progress_total() -> int:
    return 4 if city().kind == "fire" else 3

func nearest_point(include_done: bool = true) -> int:
    var best = -1; var distance = 999.0
    for i in range(city().points.size()):
        if not include_done and bool(record().marks[i]): continue
        var d = game.hero.position.distance_to(v(city().points[i]))
        if d < distance: distance = d; best = i
    return best

func mission_target() -> int:
    var r = record()
    match city().kind:
        "lantern": return LANTERN_ORDER[mini(2, int(r.sequence))]
        "delivery": return int(r.deliveries) + 1 if r.carrying else 0
        "runes":
            for i in range(3):
                if int(r.runes[i]) != RUNE_ANSWER[i]: return i
    var next = nearest_point(false)
    return next if next >= 0 else 0

func objective() -> String:
    if game.stage == 0: return city().goal
    if game.stage == 1: return "빵집에서 첫 주문 받아보기"
    if game.stage == 2: return city().boss.name + "의 도전"
    if game.stage == 3: return city().name + "의 추억 사진 남기기"
    return "도장을 모았어요 · 다음 도시로 떠나기"

func target_name() -> String:
    if city().kind == "delivery" and record().carrying: return city().labels[int(record().deliveries) + 1] + " 배달"
    return city().labels[mission_target()]

func point_done(i: int) -> bool:
    var marks = record().marks
    if i < 0 or i >= marks.size(): return false
    return bool(marks[i])

func near_shop() -> bool:
    return game.hero.position.distance_to(v(city().shop_at)) < 2.05

func action_label() -> String:
    if game.stage == 0:
        var nearest = nearest_point()
        if nearest >= 0 and game.hero.position.distance_to(v(city().points[nearest])) < 2.05:
            return { "lantern": "등불 켜기", "runes": "문양 돌리기", "arena": "훈련장 도전", "delivery": "상자 받기" if not record().carrying else "상자 전달", "fire": "불 붙이기", "vista": "풍경 촬영", "detective": "목격담 듣기", "tide": "보드 회수", "memories": "기억 고르기"}.get(city().kind, "행동")
    if near_shop(): return "지역 음식"
    return "도전하기" if game.stage == 2 else "추억 촬영" if game.stage >= 3 else "목표 안내"

func interact_mission() -> void:
    var i = nearest_point()
    if i < 0 or game.hero.position.distance_to(v(city().points[i])) > 2.05:
        if near_shop(): game.state = "food_shop"
        else: game.toast(city().hint)
        return
    var r = record()
    match city().kind:
        "lantern":
            if i == LANTERN_ORDER[int(r.sequence)]:
                r.marks[i] = true; r.sequence += 1; game.chime(600 + int(r.sequence) * 180)
                game.toast(city().labels[i] + "이 켜졌어요. " + str(r.sequence) + " / 3")
            else: r.sequence = 0; r.marks = [false, false, false]; game.toast("등불이 다시 꺼졌어요. 초록 → 분홍 → 금빛 순서예요.")
        "runes":
            r.runes[i] = (int(r.runes[i]) + 1) % 3; game.chime(520 + int(r.runes[i]) * 120)
            game.toast(city().labels[i] + ": " + ["태양", "달", "별"][int(r.runes[i])] + " · 석판은 별 / 태양 / 달")
        "arena":
            if r.marks[i]: game.toast("이미 통과한 훈련장이에요."); return
            game.meet_wild(); game.wild_grade = 0; game.rival.visible = false; game.wild_index = i; game.rival = game.creatures[i]; game.rival.visible = true; trial = i
            game.toast_time = 0; return
        "delivery":
            if i == 0 and not r.carrying:
                r.carrying = true; game.toast(city().menu[int(r.deliveries)] + " 포장 완료! " + city().labels[int(r.deliveries) + 1] + "로 가요.")
            elif r.carrying and i == int(r.deliveries) + 1:
                r.marks[i] = true; r.deliveries += 1; r.carrying = false; game.coins += 12; game.chime(880); game.toast("배달 완료! 포장대에서 다음 상자를 받아요. +12원")
            else: game.toast("이 상자는 " + city().labels[int(r.deliveries) + 1] + "에 전해 주세요.")
        "fire":
            if r.marks[i]: game.toast("이미 따뜻하게 타고 있어요."); return
            r.marks[i] = true; game.chime(620); game.toast("모닥불이 밝혀졌어요. 어둠 속 길이 하나 더 보이네요.")
        "vista":
            vista = i; game.state = "vista"; game.joystick = Vector2.ZERO; game.set_camera(1, true); return
        "detective":
            r.marks[i] = true; sync_props(); game.save_progress()
            game.show_dialogue( [ [city().labels[i], WITNESSES[i]], ["소현", "단서는 여행 수첩에서 다시 볼 수 있어."]], "deduction" if r.marks.count(true) == 3 else "explore"); return
        "tide":
            if r.marks[i]: game.toast("이미 회수한 보드예요."); return
            if not low_tide(): game.toast("지금은 높은 파도예요. 파도가 낮아질 때 회수해요."); return
            r.marks[i] = true; game.chime(740); game.toast("보드 회수 성공! 파도가 오기 전에 안전하게 챙겼어요.")
        "memories": question = i; game.state = "memory_question"; game.joystick = Vector2.ZERO; return
    finish_step()

func low_tide() -> bool:
    return fmod(game.game_time, 7.0) < 4.0

func finish_step() -> void:
    sync_props()
    if progress_count() >= progress_total() and city().kind not in ["detective", "memories"]: complete_mission()
    game.update_target(); game.save_progress()

func complete_mission() -> void:
    if game.stage != 0: return
    record().solved = true; game.stage = 2; game.coins += 35 + game.city_index * 5
    game.show_dialogue( [ ["소현", city().goal + " — 완료!"], [city().boss.name, city().boss.intro], ["동훈", "이번에도 내가 나갈게. 수세미는 챙겼어."]], "explore")
    game.update_target(); game.save_progress()

func wild_victory() -> void:
    if trial >= 0 and city().kind == "arena" and game.stage == 0:
        record().marks[trial] = true; trial = -1; finish_step()
    else: trial = -1

func puzzle_choice(answer: int) -> void:
    if game.state == "deduction":
        if answer == 2: complete_mission()
        else: game.toast("찻잔을 든 사람도, 두 손이 빈 사람도 아니에요. 단서를 다시 읽어봐요.")
    elif game.state == "memory_question":
        if answer == QUESTIONS[question][2]:
            record().marks[question] = true; game.chime(988); game.state = "explore"; sync_props()
            if progress_count() == 3: complete_mission()
            else: game.toast("그 약속, 이번엔 기억해 둘게."); game.update_target(); game.save_progress()
        else: game.toast("그날의 말을 다시 떠올려 봐요. 여행 수첩에 추억이 남아 있어요.")

func capture_vista() -> void:
    if game.state != "vista" or pending_vista: return
    pending_vista = true; game.hud.visible = false
    await game.get_tree().process_frame
    await RenderingServer.frame_post_draw
    var im = game.get_viewport().get_texture().get_image()
    game.hud.visible = true; pending_vista = false
    if im == null or im.is_empty(): game.toast("사진을 읽지 못했어요. 한 번 더 눌러 주세요."); return
    var err = im.save_png(current_photo_path(-1, "-vista" + str(vista)))
    if err != OK: game.toast("사진 저장 공간을 확인해 주세요."); return
    photo_cache.erase(current_photo_path(-1, "-vista" + str(vista)))
    record().marks[vista] = true; game.state = "explore"; game.flash = 0.7; finish_step(); game.set_camera(1, true)

func sync_props() -> void:
    if game.city_index == 0: return
    var r = record()
    for i in range(game.world.mission_nodes.size()):
        var n = game.world.mission_nodes[i]; var done = bool(r.marks[i])
        if city().kind == "runes":
            done = int(r.runes[i]) == RUNE_ANSWER[i]
            n.get_node("Rune").text = ["태양", "달", "별"][int(r.runes[i])]
        n.get_node("Done").visible = done
        if city().kind == "fire": n.get_node("Flame").visible = done
        if city().kind == "tide": n.get_node("Board").visible = not done

func buy_meal(index: int) -> void:
    var cost = 12 + game.city_index * 2
    if game.state != "food_shop" or game.coins < cost or meal != 0: return
    meal = index + 1; game.coins -= cost; game.save_progress(); game.state = "explore"
    game.toast(city().menu[index] + " 포장! 다음 대결에 " + ["뽀뽀사탕 1개 추가", "기력 1칸으로 시작", "사탕 회복량 +4"][index])
