extends SceneTree
var failures := 0
var checks := 0
func _init() -> void: call_deferred("_run")
func check(value: bool, label: String) -> void:
    checks += 1
    if not value: failures += 1; push_error(label)
    else: print("OK · ", label)
func _run() -> void:
    var scene = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    check(scene.menu.visible and not scene.started, "Menu before gameplay")
    # Avoid touching a player's real save; headless runner uses a separate user directory.
    scene._new_game()
    check(scene.started and scene.overlay.visible, "Intro dialogue")
    check(scene.dialogue_portrait.texture != null and scene.dialogue_speaker.text == "Profesor Byte", "Intro shows Byte portrait and speaker")
    check(scene.dialogue_portrait.texture.resource_path == "res://assets/portraits/professor_byte.png", "Byte dialogue uses the packaged portrait")
    check(scene.overlay.get_theme_stylebox("panel").texture.resource_path == "res://assets/ui/dialogue_frame.png", "Dialogue uses the packaged frame")
    check(scene.dialogue_demo.visible and scene.dialogue_demo.text.contains("SELECT") and scene.dialogue_demo.text.contains("3 filas"), "Intro teaches SELECT and WHERE with a result demo")
    scene._close_overlay()
    scene._dialogue(["Nova: Estoy lista para la siguiente prueba."])
    check(scene.dialogue_portrait.texture.resource_path == "res://assets/portraits/nova.png", "NPC dialogue selects the matching portrait")
    scene._close_overlay()
    check(scene.hero.sprite.texture.resource_path == "res://assets/characters/protagonist_walk_sheet.png", "Hero uses the packaged walk sheet")
    check(scene.world.walkable(Vector2(464, 400)), "Spawn is walkable")
    check(not scene.world.walkable(Vector2(10, 10)), "Walls collide")
    check(not scene.world.walkable(Vector2(17.5,7.5)*32), "Furniture collides")
    for room in range(8):
        scene.world.setup(room)
        var queue: Array[Vector2i] = [Vector2i(14,12)]
        var visited: Dictionary = {}
        while not queue.is_empty():
            var cell: Vector2i = queue.pop_front()
            if visited.has(cell): continue
            visited[cell] = true
            for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
                var next: Vector2i = cell + offset
                if not visited.has(next) and scene.world.walkable(Vector2(next)*32+Vector2(16,16)): queue.append(next)
        check(visited.has(Vector2i(17,8)) and visited.has(Vector2i(1,11)) and visited.has(Vector2i(28,11)), "Room %d: terminal and exits reachable" % room)
    scene.world.setup(2)
    scene.hero.position = Vector2(17.5,8.5)*32
    scene._interact()
    check(scene.lab.visible, "World interaction opens terminal")
    check(scene.lab.output.get_theme_stylebox("normal").texture.resource_path == "res://assets/ui/terminal_frame.png", "SQL output uses the packaged terminal frame")
    check(scene.lab.hint_label.text.contains("paso a paso"), "Instructor offers supportive guidance")
    scene.lab._run("query", "SELECT desconocida FROM estudiantes")
    check(scene.lab.output.text.contains("Byte:") and scene.lab.output.text.contains("no restan experiencia"), "SQL errors get an explanation and reassurance")
    scene.lab._hint()
    check(scene.lab.hint_label.text.contains("Pista 1 de 3"), "Instructor hints are progressive and labeled")
    scene.lab.query_input.text = "SELECT * FROM estudiantes WHERE nombre='Nova'"
    scene.lab._run("query", scene.lab.query_input.text)
    check(scene.campaign.can_complete() and not scene.lab.claim.disabled, "SQL result enables delivery")
    scene.lab.reward_requested.emit()
    check(scene.campaign.current == 1 and scene.campaign.xp == 160, "Mission reward via UI signal")
    check(scene.overlay.visible and not scene.lab.visible, "Reward ceremony")
    check(not (scene.overlay.get_theme_stylebox("panel") is StyleBoxTexture), "Reward panel restores the standard opaque style")
    scene._close_overlay()
    await scene._travel(3)
    check(scene.room == 3 and scene.world.unlocked == 3, "Next location unlocks")
    scene.hero.position = Vector2(17.5,8.5)*32
    scene._interact()
    check(scene.lab.tabs.current_tab == 1 and scene.lab.tabs.is_tab_hidden(0), "Login mission shows correct tools")
    scene.lab.close_lab()
    scene._notebook("Mapa")
    check(scene.overlay.visible, "Map opens")
    scene._close_overlay()
    scene._pause()
    scene._settings()
    check(scene.menu.visible, "Audio settings open")
    scene.menu.hide()
    scene._save()
    scene.campaign.xp = 0
    scene._continue()
    check(scene.campaign.xp == 160 and scene.campaign.current == 1 and scene.room == 3, "Continue restores progress and location")
    scene.audio.set_volumes(0, 0)
    check(scene.audio.music_volume == 0 and scene.audio.effects_volume == 0, "Independent mute")
    # Focus must not leak movement keys from the editor.
    scene.lab.open_lab()
    await process_frame
    check(scene.hero.locked, "Movement blocked while typing SQL")
    scene.queue_free()
    await process_frame
    await create_timer(0.15).timeout
    print("Integration: %d checks, %d failures" % [checks, failures])
    quit(1 if failures else 0)
