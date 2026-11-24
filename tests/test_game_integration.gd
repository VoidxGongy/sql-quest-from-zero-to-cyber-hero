extends SceneTree
## RPG integration checks: world, professor briefing, movement and laboratory.

var failures := 0
var checks := 0

func _init() -> void:
	call_deferred("_run")

func check(value: bool, label: String) -> void:
	checks += 1
	if value:
		print("OK · ", label)
	else:
		failures += 1
		push_error("FAIL · " + label)

func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	check(scene.menu.visible and not scene.started, "El mundo RPG inicia en el menú")

	scene._new_game()
	check(scene.started and scene.room == 0 and not scene.overlay.visible, "Una nueva partida comienza libremente en el cuarto")
	check(InputMap.has_action("touch_left") and InputMap.has_action("touch_right") and scene.touch_controls.get_child_count() == 5, "La cruceta táctil y la interacción están configuradas")
	check(scene.world.NAMES[0] == "Casa · mi cuarto" and scene.world.walkable(scene.hero.position), "El HUD identifica el cuarto y la posición inicial es transitable")
	check(not scene.world.walkable(Vector2(330, 330)) and not scene.world.walkable(Vector2(535, 275)) and not scene.world.walkable(Vector2(620, 270)), "La cama, el escritorio y el librero tienen colisión")
	check(scene.world.interaction(Vector2(432, 304)) != "npc", "No hay un profesor físico en el cuarto")
	scene.hero.position = Vector2(535, 310)
	check(scene.world.walkable(scene.hero.position) and scene.world.interaction(scene.hero.position) == "bedroom_message", "El computador se puede usar desde delante")
	scene._interact()
	check(scene.overlay.visible and scene.dialogue_lines[0].contains("CyberAcademy"), "El mensaje explica el objetivo inicial")
	scene._close_overlay()
	scene.hero.position = Vector2(610, 390)
	check(scene.world.walkable(scene.hero.position) and scene.world.interaction(scene.hero.position) == "bedroom_exit", "La puerta es accesible desde el cuarto")
	scene._interact()
	await create_timer(0.7).timeout
	check(scene.room == 1 and scene.world.walkable(scene.hero.position), "La puerta conduce al campus sin bloquear al jugador")
	scene.hero.position = Vector2(80, 100)
	scene._process(0.016)
	var camera_half: Vector2 = scene.get_viewport_rect().size / scene.camera.zoom / 2.0
	check(scene.camera.position.x - camera_half.x >= -0.1 and scene.camera.position.y - camera_half.y >= -0.1, "La cámara no muestra fuera del borde superior izquierdo")
	scene.hero.position = Vector2(1400, 820)
	scene._process(0.016)
	check(scene.camera.position.x + camera_half.x <= 1536.1 and scene.camera.position.y + camera_half.y <= 928.1, "La cámara no muestra fuera del borde inferior derecho")
	check(scene.world.walkable(Vector2(1050, 450)) and scene.world.walkable(Vector2(1100, 800)) and not scene.world.walkable(Vector2(1200, 180)), "El campus ampliado ofrece caminos y edificios con colisión")
	scene._travel(2)
	await create_timer(0.7).timeout
	check(scene.room == 2 and scene.world.walkable(scene.hero.position) and scene.hero.position == Vector2(480, 600), "Viajar al aula desde el mapa evita la estantería")
	scene.room = 2
	scene.hero.position = Vector2(464, 400)
	scene.world.setup(2)
	check(is_equal_approx(scene.hero.sprite.scale.x, 0.68 * scene.world.INTERIOR_CHARACTER_SCALE), "El protagonista usa el mismo aumento moderado que los NPC del interior")
	scene._brief_current()
	check(scene.started and scene.overlay.visible, "La nueva partida muestra la introducción antes del laboratorio")
	check(scene.dialogue_portrait.texture != null and scene.dialogue_speaker.text == "Profesor Byte", "La introducción muestra retrato y nombre de Profesor Byte")
	check(scene.audio.ducked and scene.audio.players[scene.audio.active].bus == "Music" and scene.audio.effects.bus == "SFX", "El diálogo reduce la música y el audio usa buses separados")
	check(not scene.dialogue_demo.visible and not scene.dialogue_lines[0].contains("cursor.execute"), "Byte presenta la clase sin revelar el ataque ni la solución")
	scene._close_overlay()
	check(not scene.audio.ducked, "Al terminar el diálogo se restaura el nivel musical")
	await create_timer(0.4).timeout
	check(absf(scene.audio.players[scene.audio.active].volume_db - scene.audio._music_level()) < 0.1, "El volumen vuelve al nivel configurado tras cerrar el diálogo")

	check(scene.hero.sprite is AnimatedSprite2D, "El protagonista usa AnimatedSprite2D")
	for expected in ["walk_down", "walk_up", "walk_left", "walk_right"]:
		var vector: Vector2 = {"walk_down": Vector2.DOWN, "walk_up": Vector2.UP, "walk_left": Vector2.LEFT, "walk_right": Vector2.RIGHT}[expected]
		scene.hero._set_facing(vector)
		scene.hero.state = scene.hero.State.WALK
		scene.hero._apply_animation()
		check(scene.hero.sprite.animation == expected, "Movimiento direccional usa " + expected)
	check(scene.hero.sprite.flip_h, "La orientación derecha invierte únicamente la fila lateral verificada")
	scene.hero.state = scene.hero.State.IDLE
	scene.hero._apply_animation()
	check(scene.hero.sprite.animation == "idle_right", "Al detenerse conserva la última dirección")
	scene.hero.state = scene.hero.State.WALK
	scene.hero.action_time = 0
	scene.hero.locked = true
	scene.hero._physics_process(0.016)
	check(scene.hero.state == scene.hero.State.IDLE and scene.hero.sprite.animation == "idle_right", "El personaje deja de caminar al abrir una interfaz")
	scene.hero.locked = false
	check(scene.world.npc_state == scene.world.NPCState.IDLE, "El profesor permanece en reposo")
	scene.world.begin_npc_interaction(scene.world.npc_pos + Vector2.LEFT * 32)
	check(scene.world.npc_state == scene.world.NPCState.INTERACT and scene.world.npc_looks_left, "Byte se orienta hacia el jugador durante la conversación")
	scene.world.end_npc_interaction()
	check(scene.world.npc_state == scene.world.NPCState.IDLE, "Byte vuelve a reposo tras la conversación")

	check(scene.world.walkable(Vector2(464, 400)), "La posición inicial es transitable")
	check(not scene.world.walkable(Vector2(10, 10)), "Las paredes conservan colisión")
	check(not scene.world.walkable(Vector2(17.5, 7.5) * 32), "El mobiliario conserva colisión")
	for obstacle in [Vector2(100, 300), Vector2(480, 180), Vector2(560, 320), Vector2(850, 500), Vector2(300, 450)]:
		check(not scene.world.walkable(obstacle), "El obstáculo del aula bloquea la posición " + str(obstacle))
	check(scene.world.walkable(Vector2(480, 390)), "El pasillo central del aula permanece transitable")
	check(scene.world.walkable(Vector2(560, 390)) and scene.world.interaction(Vector2(560, 390)) == "terminal", "La terminal se puede usar desde el exterior del escritorio")
	check(scene.world.walkable(Vector2(440, 350)) and scene.world.interaction(Vector2(440, 350)) == "npc", "Byte puede atender desde una posición accesible")
	var desk_path_clear := true
	for x in range(464, 561, 16):
		if not scene.world.walkable(Vector2(x, 400)): desk_path_clear = false
	check(desk_path_clear and not scene.world.walkable(Vector2(560, 330)), "Hay un camino hasta la mesa sin atravesar su colisión")

	scene.world.setup(2)
	scene.hero.position = Vector2(560, 390)
	scene.campaign.briefed.clear()
	scene._process(0.016)
	check(scene.prompt.visible and scene.prompt.text == "[E] Abrir laboratorio de SQL Injection", "La mesa indica cómo abrir el laboratorio")
	var interact_key := InputEventKey.new()
	interact_key.keycode = KEY_E
	interact_key.pressed = true
	scene._unhandled_key_input(interact_key)
	check(scene.lab.visible == false and scene.overlay.visible, "La interacción con el terminal abre primero el briefing de Byte")
	scene._close_overlay()
	check(scene.hero.action_time < 10, "Cerrar el briefing no deja bloqueado al jugador en modo trabajo")
	scene._interact()
	await process_frame
	check(scene.lab.visible and scene.lab.campaign.mission().kind == "login", "La mesa abre el laboratorio de login")
	check(scene.lab.query_view != null and scene.lab.result_view != null and scene.lab.patch_edit != null, "El laboratorio tiene consulta, impacto y editor de defensa")
	check(scene.lab.grid.columns == 2, "El laboratorio usa dos columnas en la resolución base")

	for i in range(6): scene.lab._next_step()
	check(scene.campaign.lesson_state().stage == 2, "Aprender y observar preceden la práctica guiada")
	scene.lab.normal_example_button.pressed.emit()
	check(scene.campaign.lesson_state().normal, "La práctica guiada exige una prueba normal")
	scene.lab.reduced_motion = true
	scene.lab.close_lab()
	check(not scene.lab.visible and scene.hero.action_time == 0, "Salir al mundo libera al protagonista")
	scene._interact()
	check(scene.lab.visible and scene.campaign.lesson_state().normal and scene.campaign.lesson_state().stage == 2, "La mesa reabre la práctica exactamente donde quedó")
	scene.lab.primary_input.text = "admin' --"
	scene.lab._run_attack()
	check(scene.campaign.lesson_state().guided and not scene.campaign.evidence.has("attack"), "La demostración guiada no completa la misión independiente")
	scene.lab._next_step()
	check(scene.lab.primary_input.text.is_empty(), "La misión independiente no rellena el payload")
	scene.lab.primary_input.text = "admin' --"
	scene.lab.secondary_input.text = "x"
	scene.lab._run_attack()
	check(scene.campaign.evidence.has("attack") and scene.lab.query_view.text.contains("FF7B72"), "El ataque resalta la parte manipulada y registra evidencia")
	scene.lab._next_step()
	scene.lab._next_step()
	scene.lab.close_lab()
	scene._interact()
	check(scene.lab.visible and int(scene.campaign.lesson_state().stage) == 5, "Tras salir durante la defensa, la mesa vuelve a abrir la verificación")
	scene.lab._add_block("login_run")
	scene.lab._add_block("login_query")
	scene.lab._move_selected(-1)
	check(scene.lab.selected_blocks == ["login_query", "login_run"], "Los bloques pueden reorganizarse con controles alternativos")
	scene.lab._add_block("unsafe_login")
	scene.lab._test_patch()
	check(not scene.campaign.evidence.has("defense") and scene.lab.tutor_message.text.contains("concatena"), "Byte explica por qué un bloque inseguro falla")
	scene.lab._remove_selected()
	scene.lab._test_patch()
	check(scene.campaign.evidence.has("defense") and not scene.lab.claim.disabled, "El parche seguro habilita la entrega")
	scene.lab._select_block(0)
	scene.lab._remove_selected()
	check(not scene.campaign.evidence.has("defense") and scene.lab.claim.disabled and scene.lab.phase.text == "VERIFICAR DEFENSA", "Cambiar el parche invalida las pruebas anteriores y actualiza el estado")
	scene.lab._add_block("login_query")
	scene.lab._move_selected(-1)
	scene.lab._test_patch()
	scene.lab.reward_requested.emit()
	check(scene.campaign.current == 1 and scene.world.unlocked == 3, "Completar el laboratorio desbloquea la siguiente zona")
	check(scene.overlay.visible, "La misión completada muestra ceremonia de recompensa")
	scene._close_overlay()
	check(scene.world.interaction(scene.hero.position) == "terminal" and scene._terminal_prompt().contains("laboratorio"), "La mesa sigue accesible cuando se desbloquea la misión siguiente")
	scene._resume_mission()
	for i in range(8):
		if scene.dialogue_active: scene._advance_dialogue()
	check(scene.lab.visible and scene.lab.campaign.mission().kind == "search", "La mesa abre la misión UNION desde el aula")
	for i in range(6): scene.lab._next_step()
	check(scene.lab.current_objective.text.contains("normal"), "CyberStore indica cómo iniciar la prueba normal")
	scene.lab.normal_example_button.pressed.emit()
	check(scene.campaign.lesson_state().normal and scene.lab.comparison_view.text.contains("Terminal"), "CyberStore conserva el resultado normal")
	scene.lab.primary_input.text = "' UNION SELECT id, secret, 0 FROM vault --"
	scene.lab._run_attack()
	check(scene.campaign.lesson_state().guided and scene.lab.comparison_view.text.contains("AURORA-42"), "CyberStore compara el producto con los datos sintéticos expuestos")
	scene.lab._next_step()
	scene.lab.primary_input.text = "' UNION SELECT id, secret, 0 FROM vault --"
	scene.lab._run_attack()
	scene.lab._next_step()
	scene.lab._next_step()
	scene.lab._add_block("search_query")
	scene.lab._add_block("search_run")
	scene.lab._test_patch()
	check(scene.campaign.evidence.has("defense") and scene.lab.verification_view.text.contains("UNION"), "CyberStore comprueba la búsqueda normal y la entrada UNION parametrizada")
	check(scene.campaign.complete(), "CyberStore se completa tras ataque y defensa")
	for kind in ["order", "blind", "final"]:
		scene.lab.hide()
		scene._resume_mission()
		for i in range(8):
			if scene.dialogue_active: scene._advance_dialogue()
		check(scene.lab.visible and scene.lab.campaign.mission().kind == kind, "La terminal o respaldo reanuda la misión " + kind)
		for i in range(6): scene.lab._next_step()
		scene.lab.normal_example_button.pressed.emit()
		check(scene.campaign.lesson_state().normal, kind + ": la prueba normal guiada funciona")
		for attempt in range(2):
			if kind == "order": scene.lab.sort_input.text = "CASE WHEN budget > 0 THEN name END"
			elif kind == "blind": scene.lab.predicate_input.text = "contenido LIKE 'AURORA%'"
			else:
				scene.lab.primary_input.text = "admin' --"
				scene.lab.secondary_input.text = "' UNION SELECT id, secret, 0 FROM vault --"
				scene.lab.sort_input.text = "CASE WHEN budget > 0 THEN name END"
			scene.lab._run_attack()
			if attempt == 0: scene.lab._next_step()
		check(scene.campaign.evidence.has("attack"), kind + ": el desafío independiente funciona")
		scene.lab._next_step()
		scene.lab._next_step()
		for block in scene.lab.Blocks.REQUIRED[kind]: scene.lab._add_block(block)
		scene.lab._test_patch()
		check(scene.campaign.evidence.has("defense"), kind + ": la solución por bloques supera las pruebas")
		if kind == "final":
			scene.lab.report_edit.text = "Evidencia: reproduje el bypass y UNION en la aplicación ficticia del laboratorio. Causa: se concatenaban entradas en SQL. Corrección: usar parámetros y lista blanca para proteger el sistema."
			scene.lab._save_report()
		check(scene.campaign.complete(), kind + ": la misión se puede completar")
	scene.lab.hide()
	scene._resume_mission()
	check(scene.overlay.visible and scene.dialogue_lines[0].contains("Completaste"), "Al finalizar la campaña, la terminal muestra el siguiente paso sin abrir un laboratorio inválido")

	# Full door route, using the real interaction and transition methods.
	scene._close_overlay()
	scene.campaign.restore(preload("res://scripts/missions/campaign.gd").new().serialize())
	scene.reduce_motion = true
	scene.room = 1
	scene.world.setup(1)
	scene._refresh()
	scene.hero.position = Vector2(480, 320)
	check(scene.world.walkable(scene.hero.position) and scene.world.interaction(scene.hero.position) == "academy_entry", "La entrada de CyberAcademy es accesible desde el camino")
	check(not scene.world.walkable(Vector2(300, 180)) and not scene.world.walkable(Vector2(90, 420)), "La fachada y los árboles del campus bloquean el paso")
	scene._process(0.016)
	check(scene.prompt.text == "[E] Entrar a CyberAcademy", "El campus indica cómo entrar al edificio")
	scene._interact()
	await create_timer(0.65).timeout
	check(scene.room == 2 and scene.world.walkable(scene.hero.position), "La entrada conduce al aula por una posición transitable")
	var hall_clear := true
	for y in range(400, 601, 16):
		if not scene.world.walkable(Vector2(480, y)): hall_clear = false
	check(hall_clear, "El pasillo central conecta la salida del aula con el profesor")
	scene.hero.position = Vector2(560, 390)
	scene._interact()
	for i in range(8):
		if scene.dialogue_active: scene._advance_dialogue()
	check(scene.lab.visible and scene.campaign.mission().kind == "login", "Desde el aula la mesa abre el laboratorio SQL Injection")
	scene.lab.reduced_motion = true
	scene.lab.close_lab()
	check(not scene.lab.visible and scene.room == 2, "Cerrar el laboratorio devuelve al aula")
	scene.hero.position = Vector2(480, 600)
	check(scene.world.interaction(scene.hero.position) == "campus_exit", "La salida del aula está junto al pasillo")
	scene._interact()
	await create_timer(0.65).timeout
	check(scene.room == 1 and scene.world.walkable(scene.hero.position), "La salida devuelve al jugador al campus sin atraparlo")

	scene.queue_free()
	await process_frame
	print("RPG integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
