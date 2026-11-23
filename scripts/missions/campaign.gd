class_name QuestCampaign
extends RefCounted
signal mission_completed(index: int, earned_xp: int)
signal changed
const SQL = preload("res://scripts/sql_simulator/query_engine.gd")
const DATA_PATH := "res://data/missions/campaign.json"
var missions: Array = []
var current := 0
var xp := 0
var completed: Array = []
var evidence: Dictionary = {}
var hints: Dictionary = {}
var history: Array = []
var reports: Dictionary = {}
var collected: Array = []
var earned_evidence: Array = []
var db = SQL.new()
var login_patch := "SELECT * FROM usuarios WHERE usuario = 'entrada' AND clave = 'entrada'"
var document_patch := "SELECT id, titulo, contenido FROM documentos WHERE id = 1"
var last_attack := ""

func _init() -> void:
    missions = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))

func mission() -> Dictionary:
    return missions[mini(current, missions.size() - 1)]

func mark(key: String) -> void:
    if current < missions.size() and key not in goals(): return
    evidence[key] = true
    var reward_id := str(current) + ":" + key
    if current < missions.size() and reward_id not in earned_evidence:
        earned_evidence.append(reward_id)
        xp += 10

func goals() -> Array:
    return mission().criteria if current < missions.size() else []

func submit(kind: String, input: String, extra: String = "") -> Dictionary:
    var result: Dictionary
    var query := input
    match kind:
        "query":
            result = db.execute(input, [], current >= missions.size() or mission().get("writable", false))
            if result.ok:
                if mission().has("target_record") and result.operation == "SELECT" and result.rows.size() == 1:
                    var row: Dictionary = result.rows[0]
                    var matches := true
                    for column in mission().target_record:
                        matches = matches and row.get(column) == mission().target_record[column]
                    if matches: mark("found")
                if result.operation == "UPDATE" and result.table == "incidentes":
                    var solved := 0
                    var required: Array = mission().get("resolved_ids", [1, 2])
                    for row in db.tables.incidentes:
                        if required.any(func(id): return int(id) == int(row.id)) and row.estado == "resuelto": solved += 1
                    if solved == required.size(): mark("resolved")
                if result.operation == "INSERT" and result.table == "incidentes":
                    for row in result.rows:
                        if row.estado == "certificado" and str(row.titulo).strip_edges().length() >= 5: mark("certificate")
        "login":
            query = "SELECT * FROM usuarios WHERE usuario = '%s' AND clave = '%s'" % [input, extra]
            result = db.execute(query, [], false)
            var literal := db.execute("SELECT * FROM usuarios WHERE usuario = ? AND clave = ?", [input, extra], false)
            if result.ok:
                if not result.rows.is_empty() and literal.rows.is_empty():
                    mark("bypass"); last_attack = input
                    result["message"] = "La entrada alteró WHERE: hubo acceso sin credenciales literales válidas. La concatenación mezcló datos con SQL."
                elif not result.rows.is_empty():
                    mark("valid")
                    result["message"] = "Las credenciales coincidieron con una cuenta ficticia. Esta prueba legítima será necesaria para verificar la reparación."
                else:
                    mark("invalid")
                    if evidence.has("bypass"): mark("negative")
                    result["message"] = "No hubo coincidencias. Compara esta condición con la prueba anterior para explicar la diferencia."
            else: mark("syntax")
        "search":
            query = "SELECT id, nombre FROM estudiantes WHERE nombre = '%s'" % input
            result = db.execute(query, [], false)
            if result.ok:
                for row in result.rows:
                    if "AURORA-42" in row.values():
                        mark("leak")
                        result["message"] = "El resultado incluye información ajena al directorio público. UNION amplió la proyección porque la entrada cambió la sentencia. Documenta esta evidencia."
        "boolean", "time":
            query = "SELECT id FROM documentos WHERE " + input
            result = db.execute(query, [], false)
            if result.ok:
                var yes: bool = not result.rows.is_empty()
                var investigates_content := false
                for token in db.tokens:
                    if token.kind == "word" and str(token.value).to_lower() == "contenido": investigates_content = true
                if investigates_content:
                    mark(("bool_" if kind == "boolean" else "time_") + ("yes" if yes else "no"))
                result = {"ok": true, "rows": [], "columns": [], "error": "", "signal": yes,
                    "message": ("Indicador: presente" if yes else "Indicador: ausente") if kind == "boolean" else ("Latencia virtual: 850 ms" if yes else "Latencia virtual: 40 ms")}
                if not investigates_content: result.message += " · Para aportar evidencia, investiga la columna contenido; una constante no comprueba la hipótesis."
        _: return {"ok": false, "error": "Acción desconocida.", "rows": [], "columns": []}
    result["query"] = query
    if not result.has("message"):
        result["message"] = ("%d fila(s). Observa cómo cambió el filtro y compara otra entrada." % result.rows.size()) if result.ok else result.error
    _record(kind, input, result)
    changed.emit()
    return result

func _record(kind: String, input: String, result: Dictionary) -> void:
    history.append({"kind": kind, "input": input, "query": result.get("query", ""), "ok": result.ok, "message": result.get("message", result.get("error", ""))})
    if history.size() > 60: history.pop_front()

func hint() -> String:
    var key := str(current)
    var count := int(hints.get(key, 0))
    hints[key] = mini(count + 1, 3)
    changed.emit()
    return mission().hints[mini(count, 2)]

func save_report(body: String) -> bool:
    if current >= missions.size(): return false
    # This checks structured coverage; prose quality remains an instructor judgement.
    var lower := body.to_lower()
    var valid := body.strip_edges().length() >= 100 and lower.contains("evidencia:") and lower.contains("causa:") and lower.contains("corrección:")
    valid = valid and (evidence.has("bypass") or evidence.has("leak"))
    if valid:
        for section in ["evidencia:", "causa:", "corrección:"]:
            var line := lower.get_slice(section, 1).get_slice("\n", 0).strip_edges()
            if line.length() < 15: valid = false
    if valid:
        reports[str(current)] = body
        mark("report")
    changed.emit()
    return valid

func test_patches() -> Array:
    var isolated = SQL.new()
    var output: Array = []
    var login_ok := true
    var access_ok := true
    var cases := [
        ["Credenciales legítimas", "nova", "nova123", [1]],
        ["Segunda cuenta legítima", "admin", "supersecreto", [3]],
        ["Clave incorrecta", "nova", "incorrecta", []],
        ["Usuario inexistente", "nadie", "nova123", []],
        ["Condición inyectada", "' OR 2=2 --", "x", []],
        ["Comentario inyectado", "admin' --", "x", []],
        ["Inyección en contraseña", "nadie", "' OR 1=1 --", []]]
    for c in cases:
        var r: Dictionary = isolated.execute(login_patch, [c[1], c[2]], false)
        var ids: Array = []
        for row in r.rows: ids.append(row.get("id"))
        var passed: bool = r.ok and ids == c[3]
        login_ok = login_ok and passed
        output.append(("OK  " if passed else "FALLO  ") + c[0] + (" · " + r.error if not r.ok else ""))
    for c in [["Documento propio", 1, 1, [1]], ["Segundo documento propio", 3, 1, [3]], ["Documento ajeno", 2, 1, []], ["Propietario legítimo", 2, 3, [2]], ["ID con inyección", "1 OR 1=1", 1, []]]:
        var r: Dictionary = isolated.execute(document_patch, [c[1], c[2]], false)
        var ids: Array = []
        var has_content := true
        for row in r.rows:
            ids.append(row.get("id"))
            has_content = has_content and row.has("titulo") and row.has("contenido")
        var passed: bool = r.ok and ids == c[3] and has_content
        access_ok = access_ok and passed
        output.append(("OK  " if passed else "FALLO  ") + c[0] + (" · " + r.error if not r.ok else ""))
    evidence.erase("login_fixed")
    evidence.erase("access_fixed")
    if login_ok: mark("login_fixed")
    if access_ok: mark("access_fixed")
    _record("regresión", login_patch + "\n" + document_patch, {"ok": login_ok and access_ok, "message": "\n".join(output)})
    changed.emit()
    return output

func can_complete() -> bool:
    if current >= missions.size(): return false
    for key in goals():
        if not evidence.has(key): return false
    return true

func complete() -> bool:
    if not can_complete(): return false
    var earned: int = mission().xp
    var index := current
    completed.append(index)
    xp += earned
    current += 1
    evidence.clear()
    history.clear()
    db.reset_data()
    login_patch = "SELECT * FROM usuarios WHERE usuario = 'entrada' AND clave = 'entrada'"
    document_patch = "SELECT id, titulo, contenido FROM documentos WHERE id = 1"
    mission_completed.emit(index, earned)
    changed.emit()
    return true

func reset_lab() -> void:
    db.reset_data()
    evidence.clear()
    history.clear()
    changed.emit()

func collect(id: int) -> bool:
    if id in collected: return false
    collected.append(id)
    xp += 25
    changed.emit()
    return true

func rank_name() -> String:
    return "Estudiante principiante" if current == 0 else str(missions[mini(current - 1, missions.size() - 1)].rank)

func serialize() -> Dictionary:
    return {"current": current, "xp": xp, "completed": completed, "evidence": evidence, "hints": hints,
        "history": history, "reports": reports, "collected": collected, "earned_evidence": earned_evidence, "tables": db.tables,
        "login_patch": login_patch, "document_patch": document_patch}

func restore(data: Dictionary) -> void:
    current = clampi(int(data.get("current", 0)), 0, missions.size())
    xp = maxi(0, int(data.get("xp", 0)))
    completed = []
    for value in data.get("completed", []): completed.append(int(value))
    evidence = data.get("evidence", {})
    hints = data.get("hints", {})
    history = data.get("history", [])
    reports = data.get("reports", {})
    collected = []
    for value in data.get("collected", []): collected.append(int(value))
    earned_evidence = data.get("earned_evidence", [])
    db.tables = data.get("tables", db.tables)
    login_patch = data.get("login_patch", login_patch)
    document_patch = data.get("document_patch", document_patch)
    changed.emit()
