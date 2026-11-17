extends RefCounted
var failures = []
var checks = 0
var g

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("FAIL ", label)

func reachable(world, source: Vector3) -> Dictionary:
    var start = Vector2i(roundi(source.x * 2), roundi(source.z * 2)); var queue = [start]; var found = { start: true}; var head = 0
    while head < queue.size():
        var p = queue[head]; head += 1
        for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
            var n = p + offset
            if found.has(n) or not world.can_walk(Vector3(n.x * 0.5, 0, n.y * 0.5)): continue
            found[n] = true; queue.append(n)
    return found

func battle_win(salary: bool = false) -> bool:
    for turn in range(90):
        if g.state != "battle": break
        var choice = "strike"
        if g.health < g.PARTY_HP - g.candy_heal() and g.battle_berries > 0: choice = "heal"
        elif g.enemy_heavy() or g.battle_intent in ["sand", "chill", "gust", "mist"]: choice = "guard"
        elif salary and g.battle_energy == 3 and g.coins >= 40: choice = "team"
        g.choose_battle(choice)
        for tick in range(100):
            if g.state == "battle": g.battle_tick(0.04)
    return g.state == "battle_won"

func point(i: int) -> void:
    g.hero.position = g.tour.v(g.city().points[i]); g.partner.position = g.hero.position + Vector3(0.7, 0, 0)
    g.reset_follow_path(); g.state = "explore"; g.tour.interact_mission()

func run(game) -> void:
    g = game
    check("--test-isolated" in OS.get_cmdline_user_args(), "isolated save required")
    if not failures.is_empty(): g.get_tree().quit(1); return
    g.restart(); g.state = "explore"

    var old = { "version": 1, "stage": 4, "coins": 317, "position": [0, -6.5], "wild_wins": 7, "wild_seen": [true, false, true], "perfects": 2, "collected": [true, true, true], "best_combo": 5, "tutorial_seen": true, "sound": false}
    var file = FileAccess.open(g.SAVE_FILE, FileAccess.WRITE); file.store_string(JSON.stringify(old)); file.close()
    g.load_progress()
    check(g.tour.completed[0] and g.tour.unlocked == 1 and g.coins == 317 and g.wild_wins == 7 and not g.sound_on, "v1 migration preserves Paris and settings")
    check(FileAccess.file_exists(g.SAVE_FILE + ".v1-backup"), "v1 original backed up")
    g.tour.reset_records(); g.coins = 1000
    for ci in range(10):
        g.state = "explore"; g.tour.apply_city(ci); g.stage = 0; g.tour.completed.fill(false)
        for previous in range(ci): g.tour.completed[previous] = true
        g.PARTY_HP = g.party_max()
        var d = g.city(); var world = g.world; var label = d.english
        check(world.can_walk(g.hero.position), label + " spawn walkable")
        var found = reachable(world, g.hero.position)
        var targets = d.points.duplicate(); targets.append(d.boss_at); targets.append(d.photo_at); targets.append(d.shop_at)
        for i in range(targets.size()):
            var p = targets[i]; check(world.can_walk(Vector3(p[0], 0, p[1])), label + " target walkable " + str(i))
            check(found.has(Vector2i(roundi(p[0] * 2), roundi(p[1] * 2))), label + " target reachable " + str(i))
        var lawn = false
        for p in found:
            if world.in_grass(Vector3(p.x * 0.5, 0, p.y * 0.5)): lawn = true; break
        check(lawn, label + " repeatable wild encounter terrain")
        for monster in range(3):
            g.state = "explore"; g.meet_wild(); g.rival.visible = false; g.wild_index = monster; g.rival = g.creatures[monster]; g.begin_battle()
            check(battle_win(), label + " wild monster " + str(monster) + " beatable without paid skills")
            g.claim_battle_win(); check(g.world.can_walk(g.hero.position), label + " wild return walkable " + str(monster))
        check(g.wild_seen.count(true) == 3, label + " full local monster journal")

        match ci:
            0:
                for pickup in world.pickups: g.hero.position = pickup.position; g.check_pickups()
                g.state = "cook"; g.orders = 0
                for i in range(5): g.order_wait = 0; g.cook_choice(g.recipe_order[i])
            1:
                point(0); check(g.tour.record().sequence == 0, "Kyoto wrong order resets")
                for i in [1, 0, 2]: point(i)
            2:
                point(0); point(0); point(2)
            3:
                g.meet_wild(); g.begin_battle(); check(battle_win(), "Roma ordinary wild win"); g.claim_battle_win()
                check(g.stage == 0 and g.tour.progress_count() == 0, "Roma grass win does not award arena trial")
                for i in range(3):
                    point(i); g.begin_battle(); check(battle_win(), "Roma trial " + str(i)); g.claim_battle_win()
            4:
                point(2); check(g.tour.record().deliveries == 0, "NY cannot deliver without parcel")
                for i in range(3): point(0); point(i + 1)
            5:
                for i in range(4): point(i)
            6:

                for i in range(3):
                    point(i); check(g.state == "vista", "Santorini opens viewpoint " + str(i)); g.tour.record().marks[i] = true; g.state = "explore"; g.tour.finish_step()
            7:
                for i in range(3): point(i); g.finish_dialogue()
                check(g.state == "deduction", "London three witnesses unlock deduction")
                g.tour.puzzle_choice(0); check(g.stage == 0, "London wrong answer preserves puzzle"); g.tour.puzzle_choice(2)
            8:
                g.game_time = 5; point(0); check(g.tour.progress_count() == 0, "Sydney high tide blocks retrieval")
                g.game_time = 0
                for i in range(3): point(i)
            9:
                for i in range(3):
                    point(i); g.tour.puzzle_choice( (i + 1) % 3); check(not g.tour.record().marks[i], "Seoul wrong memory " + str(i)); g.tour.puzzle_choice(i)
        check(g.stage == 2, label + " mission unlocks boss")
        g.state = "explore"; g.hero.position = g.tour.v(d.boss_at) + Vector3(0, 0, 1); g.partner.position = g.hero.position + Vector3(0.7, 0, 0)
        var origin = g.hero.position; g.wild_battle = false; g.rival = g.story_rival; g.begin_battle()
        g.save_progress(); var saved = JSON.parse_string(FileAccess.get_file_as_string(g.SAVE_FILE))
        check(absf(saved.cities[ci].position[0] - origin.x) < 0.01 and absf(saved.cities[ci].position[1] - origin.z) < 0.01, label + " boss saves field position")
        check(battle_win(), label + " boss beatable without paid skill")
        g.claim_battle_win(); check(g.stage == 3 and g.hero.position.distance_to(origin) < 0.01, label + " boss reward and return")
        g.state = "ending"; g.stage = 4; g.tour.stamp_city(); var cash = g.coins; g.tour.stamp_city()
        check(g.coins == cash and g.tour.unlocked >= mini(ci + 1, 9), label + " one stamp reward and next unlock")
        g.state = "explore"; g.save_progress(); check(g.save_ok, label + " atomic save")
        print("CITY_CHECK_DONE ", label, " checks=", checks)

    g.tour.unlocked = 9; g.tour.store_current(); g.tour.apply_city(1); g.state = "explore"
    check(g.stage == 4 and g.tour.record().marks.count(true) == 3, "revisit retains mission and chapter")
    g.state = "food_shop"; g.tour.buy_meal(2); check(g.tour.meal == 3, "regional food purchase")
    g.state = "explore"; g.meet_wild(); g.begin_battle(); check(g.battle_food == 3 and g.tour.meal == 0, "meal consumed once at battle entry")
    var saved = JSON.parse_string(FileAccess.get_file_as_string(g.SAVE_FILE)); check(saved.meal == 0, "meal consumption persisted")
    g.leave_battle(); g.save_progress(); var expected = g.coins; g.save_progress()
    file = FileAccess.open(g.SAVE_FILE, FileAccess.WRITE); file.store_string("{bad json"); file.close(); g.coins = 0; g.load_progress()
    check(g.coins == expected, "backup restores corrupt save")
    g.state = "explore"; g.save_progress()
    for intent in ["sand", "chill", "gust", "mist", "wave", "rest", "brace"]:
        for guarded in [false, true]:
            g.state = "explore"; g.begin_battle(); g.battle_intent = intent; var before = g.health; var base_damage = g.enemy_damage()
            g.choose_battle("guard" if guarded else "strike")
            for tick in range(100):
                if g.battle_phase != "choose": g.battle_tick(0.04)
            var damage = (ceili(base_damage * 0.25) if guarded else base_damage + (2 if intent == "sand" else 0))
            check(g.health == before - damage, intent + " exact counter damage guarded=" + str(guarded))
            if intent in ["chill", "gust"]: check(g.battle_energy == (1 if guarded else 0), intent + " energy loss is guardable")
            if intent == "mist": check(g.battle_fog == not guarded, "mist debuff is guardable")
            if intent == "brace": check(g.battle_enemy_guard, "brace persists for next player turn")
    var report = FileAccess.open("res://tour-check-results.json", FileAccess.WRITE); report.store_string(JSON.stringify({ "checks": checks, "failures": failures}, "  ")); report.close()
    print("TOUR_CHECKS ", checks, " FAILURES ", failures)
    g.get_tree().quit(0 if failures.is_empty() else 1)
