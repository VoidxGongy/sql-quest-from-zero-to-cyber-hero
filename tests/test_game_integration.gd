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
	check(scene.started and scene.overlay.visible, "La nueva partida muestra la introducción antes del laboratorio")
	check(scene.dialogue_portrait.texture != null and scene.dialogue_speaker.text == "Profesor Byte", "La introducción muestra retrato y nombre de Profesor Byte")
	check(not scene.dialogue_demo.visible and not scene.dialogue_lines[0].contains("cursor.execute"), "Byte presenta la clase sin revelar el ataque ni la solución")
	scene._close_overlay()

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

	check(scene.world.walkable(Vector2(464, 400)), "La posición inicial es transitable")
	check(not scene.world.walkable(Vector2(10, 10)), "Las paredes conservan colisión")
	check(not scene.world.walkable(Vector2(17.5, 7.5) * 32), "El mobiliario conserva colisión")

	scene.world.setup(2)
	scene.hero.position = Vector2(17.5, 8.5) * 32
	scene.campaign.briefed.clear()
	scene._interact()
	check(scene.lab.visible == false and scene.overlay.visible, "La interacción con el terminal abre primero el briefing de Byte")
	scene._close_overlay()
	scene.lab.open_lab()
	await process_frame
	check(scene.lab.visible, "El laboratorio se abre desde la academia")
	check(scene.lab.query_view != null and scene.lab.result_view != null and scene.lab.patch_edit != null, "El laboratorio tiene consulta, impacto y editor de defensa")
	check(scene.lab.grid.columns == 2, "El laboratorio usa dos columnas en la resolución base")

	for i in range(6): scene.lab._next_step()
	check(scene.campaign.lesson_state().stage == 2, "Aprender y observar preceden la práctica guiada")
	scene.lab.normal_example_button.pressed.emit()
	check(scene.campaign.lesson_state().normal, "La práctica guiada exige una prueba normal")
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
	scene.lab.reward_requested.emit()
	check(scene.campaign.current == 1 and scene.world.unlocked == 3, "Completar el laboratorio desbloquea la siguiente zona")
	check(scene.overlay.visible, "La misión completada muestra ceremonia de recompensa")

	scene.queue_free()
	await process_frame
	print("RPG integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
