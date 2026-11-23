extends SceneTree
## Pruebas del motor SQL en memoria. Ejecutar con:
## godot --headless --path . --script res://tests/test_sql_simulator.gd

var failures := 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var SimulatorScript = load("res://scripts/sql_simulator.gd")
    var sim = SimulatorScript.new()
    var total_users: int = sim.users.size()
    _check(total_users == 4, "la tabla inicial tiene 4 usuarios ficticios")

    var normal = sim.execute("admin", "supersecreto", true)
    _check(normal.rows.size() == 1 and not normal.injected, "login normal vulnerable devuelve una fila")

    var tautology = sim.execute("' OR '1'='1' --", "x", true)
    _check(tautology.rows.size() == total_users, "tautología devuelve todas las filas")
    _check(tautology.injected and tautology.kind == "tautology", "tautología marcada como inyección")
    _check(not tautology.session.is_empty() and str(tautology.session.usuario) == "nova", "el login usa la primera fila, no privilegios inventados")

    var numeric = sim.execute("' OR 1=1 --", "", true)
    _check(numeric.rows.size() == total_users and numeric.injected, "variante OR 1=1 también inyecta")

    var comment = sim.execute("admin' --", "", true)
    _check(comment.rows.size() == 1 and comment.injected, "comentario -- evita la comprobación de clave")
    _check(str(comment.session.usuario) == "admin", "comentario inicia sesión como admin")

    var secure = sim.execute("' OR '1'='1' --", "x", false)
    _check(secure.rows.is_empty() and not secure.injected, "modo seguro no devuelve filas con tautología")
    _check(secure.blocked_attempt, "modo seguro marca el ataque como bloqueado")

    var secure_comment = sim.execute("admin' --", "", false)
    _check(secure_comment.rows.is_empty() and secure_comment.blocked_attempt, "modo seguro bloquea el comentario")

    var secure_normal = sim.execute("admin", "supersecreto", false)
    _check(secure_normal.rows.size() == 1 and not secure_normal.blocked_attempt, "modo seguro permite credenciales válidas")

    var syntax = sim.execute("O'Brien", "x", true)
    _check(not syntax.error.is_empty(), "comilla suelta produce error de sintaxis en modo vulnerable")

    var failed_comment = sim.execute("nadie' --", "", true)
    _check(failed_comment.rows.is_empty() and not failed_comment.injected, "comentario sin usuario válido no inicia sesión")

    var added = sim.add_user("ana", "clave123", "ANALISTA")
    _check(added.ok, "se puede añadir un usuario ficticio")
    var ana = sim.execute("ana", "clave123", false)
    _check(ana.rows.size() == 1, "el usuario añadido puede iniciar sesión")
    _check(sim.delete_user(5), "se puede borrar el usuario añadido")
    _check(sim.execute("ana", "clave123", false).rows.is_empty(), "el usuario borrado ya no inicia sesión")

    print("")
    if failures == 0:
        print("OK: 18 comprobaciones del simulador SQL superadas.")
    else:
        print("FALLOS: %d comprobaciones del simulador SQL." % failures)
    quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
    if condition:
        print("  ok  ", label)
    else:
        failures += 1
        print("  FAIL ", label)
