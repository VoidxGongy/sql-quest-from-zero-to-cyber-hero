extends SceneTree
## Prueba de humo de la interfaz del laboratorio, sin interacción manual.
## Ejecutar con:
## godot --headless --path . --script res://tests/test_sql_lab_ui.gd

var failures := 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var LabScript = load("res://scripts/sql_lab.gd")
    var lab = LabScript.new()
    root.add_child(lab)
    await process_frame
    lab.open_lab()
    await process_frame

    _check(lab.visible, "el laboratorio se abre")
    _check(lab.db_tree.get_root() != null, "la tabla de datos se construye")

    var completed_signal := [false]
    lab.lab_completed.connect(func(): completed_signal[0] = true)

    lab._set_mode(true)
    lab.user_input.text = "' OR '1'='1' --"
    lab.pass_input.text = "x"
    lab._execute()
    _check(lab.seen_bypass, "el bypass vulnerable marca el primer paso")
    _check(lab.result_tree.get_root() != null, "el resultado se pinta en el árbol")

    lab._set_mode(false)
    lab.user_input.text = "' OR '1'='1' --"
    lab.pass_input.text = "x"
    lab._execute()
    _check(lab.blocked_bypass, "el ataque se bloquea en modo seguro")
    _check(lab.completed, "el reto del laboratorio se completa")
    _check(completed_signal[0], "se emite la señal de laboratorio completado")

    lab.add_user_input.text = "ana"
    lab.add_pass_input.text = "clave123"
    lab._on_add_user()
    _check(lab.engine.find_user("ana") >= 0, "la interfaz añade usuarios ficticios")

    lab.close_lab()
    _check(not lab.visible, "el laboratorio se cierra")

    lab.queue_free()
    await process_frame

    print("")
    if failures == 0:
        print("OK: 9 comprobaciones de interfaz del laboratorio superadas.")
    else:
        print("FALLOS: %d comprobaciones de interfaz del laboratorio." % failures)
    quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
    if condition:
        print("  ok  ", label)
    else:
        failures += 1
        print("  FAIL ", label)
