class_name SQLSimulator
extends RefCounted
## Motor didáctico de SQL en memoria.
##
## No se conecta a ningún DBMS ni ejecuta SQL real: interpreta un subconjunto
## mínimo de consultas de login para mostrar, de forma segura y visual, por qué
## la concatenación de entradas permite un bypass y por qué los parámetros lo
## evitan. La tabla `usuarios` es completamente ficticia y editable.

const DEFAULT_USERS := [
    {"id": 1, "usuario": "nova", "clave": "nova123", "rol": "ANALISTA", "dato": "Token de análisis NV-77"},
    {"id": 2, "usuario": "gongy", "clave": "cyber2026", "rol": "INVESTIGADOR", "dato": "Acceso al núcleo"},
    {"id": 3, "usuario": "admin", "clave": "supersecreto", "rol": "ADMIN", "dato": "Llave maestra NULL-ROOT"},
    {"id": 4, "usuario": "visitante", "clave": "visitante", "rol": "LECTURA", "dato": "Sin datos sensibles"}
]

var users: Array[Dictionary] = []
var next_id := 1



func _init() -> void:
    reset_data()


func reset_data() -> void:
    users.clear()
    for row in DEFAULT_USERS:
        users.append(row.duplicate(true))
    next_id = 1
    for row in users:
        next_id = maxi(next_id, int(row.id) + 1)


func add_user(usuario: String, clave: String, rol: String) -> Dictionary:
    var name := usuario.strip_edges()
    var password := clave.strip_edges()
    var role := rol.strip_edges().to_upper()
    if name.is_empty() or password.is_empty() or role.is_empty():
        return {"ok": false, "message": "Usuario, clave y rol son obligatorios."}
    if name.contains("'") or password.contains("'"):
        return {"ok": false, "message": "Por claridad didáctica, evita comillas en los datos de la tabla."}
    if find_user(name) >= 0:
        return {"ok": false, "message": "Ese usuario ya existe en la tabla."}
    users.append({
        "id": next_id,
        "usuario": name,
        "clave": password,
        "rol": role,
        "dato": "Registro ficticio creado por el jugador."
    })
    next_id += 1
    return {"ok": true, "message": "Usuario ficticio añadido a la tabla."}


func delete_user(id: int) -> bool:
    for i in range(users.size()):
        if int(users[i].id) == id:
            users.remove_at(i)
            return true
    return false


func find_user(name: String) -> int:
    for i in range(users.size()):
        if str(users[i].usuario) == name:
            return i
    return -1


## Compatibility adapter for the existing standalone login laboratory.
func execute(usuario: String, clave: String, vulnerable: bool) -> Dictionary:
    var interpreter = preload("res://scripts/sql_simulator/query_engine.gd").new()
    interpreter.tables.usuarios = _all_rows()
    var template := "SELECT * FROM usuarios WHERE usuario = ? AND clave = ?"
    var literal: Dictionary = interpreter.execute(template, [usuario, clave], false)
    var result: Dictionary = literal
    if vulnerable:
        result = interpreter.execute("SELECT * FROM usuarios WHERE usuario = '%s' AND clave = '%s'" % [usuario, clave], [], false)
    var injected: bool = vulnerable and result.ok and not result.rows.is_empty() and literal.rows.is_empty()
    var suspicious: bool = usuario.contains("'") or clave.contains("'")
    return {
        "rows": result.rows,
        "injected": injected,
        "error": result.error,
        "kind": ("tautology" if result.rows.size() > 1 else "comment") if injected else ("normal" if vulnerable else "secure"),
        "message": ("La consulta interpretó parte de la entrada como SQL y cambió el filtro." if injected else
            ("Los parámetros se comparan como datos literales." if not vulnerable else "La consulta devolvió %d fila(s)." % result.rows.size())),
        "session": result.rows[0] if not result.rows.is_empty() else {},
        "blocked_attempt": not vulnerable and suspicious and result.rows.is_empty()
    }

func _all_rows() -> Array:
    return users.duplicate(true)
