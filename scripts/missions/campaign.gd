class_name QuestCampaign
extends RefCounted
## Campaign state and safe, in-memory SQL Injection simulations.

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
var briefed: Array = []
var db = SQL.new()
var patch_text := ""
var last_attack := ""
var lessons: Dictionary = {}
var guided_mode := false

func lesson_state() -> Dictionary:
	var key := str(current)
	if not lessons.has(key):
		lessons[key] = {"stage": 0, "step": 0, "normal": false, "guided": false, "compared": false}
	return lessons[key]

func save_lesson() -> void:
	changed.emit()

func _init() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	missions = parsed if parsed is Array else []
	patch_text = _vulnerable_patch("login")

func mission() -> Dictionary:
	return missions[mini(current, missions.size() - 1)]

func goals() -> Array:
	return mission().get("criteria", []) if current < missions.size() else []

func brief_current() -> void:
	if current not in briefed:
		briefed.append(current)
		changed.emit()

func mark(key: String) -> void:
	if guided_mode and key == "attack": return
	if current < missions.size() and key not in goals(): return
	if evidence.has(key): return
	evidence[key] = true
	var reward_id := str(current) + ":" + key
	if current < missions.size() and reward_id not in earned_evidence:
		earned_evidence.append(reward_id)
		xp += 10
	changed.emit()

func submit(kind: String, input: String, extra: String = "") -> Dictionary:
	var result: Dictionary
	match kind:
		"login": result = _login_attack(input, extra)
		"search": result = _search_attack(input)
		"order": result = _order_attack(input)
		"blind": result = _blind_attack(input, extra)
		_: result = _failure("Acción de laboratorio desconocida.")
	if result.has("query"):
		_record(kind, input, result)
	changed.emit()
	return result

func submit_final(login_input: String, union_input: String, sort_input: String) -> Dictionary:
	var previous_attack := evidence.has("attack")
	var login := _login_attack(login_input, "x", false)
	var union := _search_attack(union_input, false)
	var order := _order_attack(sort_input, false)
	var success := bool(login.get("attack", false)) and bool(union.get("attack", false)) and bool(order.get("attack", false))
	if not success and not previous_attack: evidence.erase("attack")
	if success: mark("attack")
	var query := "LOGIN\n" + str(login.query) + "\n\nUNION SEARCH\n" + str(union.query) + "\n\nORDER BY\n" + str(order.query)
	var message := "Cadena NullSec reproducida: bypass, exposición UNION y estructura ORDER BY fueron demostrados en el laboratorio aislado." if success else "La cadena está incompleta. Revisa cada superficie y vuelve a ejecutar la demostración."
	var result := {"ok": success, "attack": success, "query": query, "rows": [], "columns": [], "error": "", "message": message,
		"highlight": str(login.get("highlight", "")) + " | " + str(union.get("highlight", "")),
		"input": "login=%s · union=%s · sort_by=%s" % [login_input, union_input, sort_input]}
	_record("final", query, result)
	changed.emit()
	return result

func _login_attack(user: String, password: String, record := true) -> Dictionary:
	var query := "SELECT * FROM usuarios WHERE usuario = '%s' AND clave = '%s'" % [user, password]
	var vulnerable := db.execute(query, [], false)
	var safe := db.execute("SELECT * FROM usuarios WHERE usuario = ? AND clave = ?", [user, password], false)
	var injected: bool = vulnerable.ok and not vulnerable.rows.is_empty() and safe.rows.is_empty()
	var result := vulnerable
	result["query"] = query
	result["input"] = user + " / " + password
	result["attack"] = injected
	result["highlight"] = user if user.contains("'") or password.contains("'") else ""
	result["message"] = "Acceso no autorizado: la entrada cerró el literal y -- anuló la comprobación de contraseña." if injected else ("Credenciales legítimas aceptadas en la simulación." if not vulnerable.rows.is_empty() else "Acceso rechazado. Compara la consulta con una entrada manipulada.")
	if injected:
		mark("attack")
		last_attack = user
	if record: _record("login", user + " / " + password, result)
	return result

func _search_attack(term: String, record := true) -> Dictionary:
	var query := "SELECT id, name, price FROM products WHERE name LIKE '%%%s%%'" % term
	var vulnerable := db.execute(query, [], false)
	var safe := db.execute("SELECT id, name, price FROM products WHERE name LIKE ?", ["%" + term + "%"], false)
	var exposed := false
	for row in vulnerable.rows:
		if row.values().any(func(value): return str(value).contains("AURORA-42") or str(value).contains("NULLSEC")): exposed = true
	var result := vulnerable
	result["query"] = query
	result["input"] = term
	result["attack"] = exposed and safe.rows.size() != vulnerable.rows.size()
	result["highlight"] = term if term.contains("UNION") or term.contains("'") else ""
	result["message"] = "Exposición no autorizada: UNION añadió una fila del vault sintético al buscador público." if result.attack else ("La búsqueda solo devuelve productos públicos." if vulnerable.ok else vulnerable.error)
	if result.attack: mark("attack")
	if record: _record("search", term, result)
	return result

func _order_attack(sort_by: String, record := true) -> Dictionary:
	var query := "SELECT id, name, budget FROM projects ORDER BY " + sort_by
	var suspicious := sort_by.to_lower().contains("case") or sort_by.to_lower().contains("when") or sort_by.contains(";") or sort_by.contains("--")
	var result := {"ok": true, "rows": [], "columns": ["id", "name", "budget"], "error": "", "query": query,
		"attack": suspicious, "highlight": sort_by, "input": sort_by, "message": "La expresión no autorizada altera la estructura del ordenamiento y puede actuar como sensor booleano." if suspicious else "La columna solicitada parece normal; prueba el caso controlado para observar la vulnerabilidad."}
	if suspicious: mark("attack")
	if record: _record("order", sort_by, result)
	return result

func _blind_attack(predicate: String, mode: String, record := true) -> Dictionary:
	var query := "SELECT id FROM documentos WHERE " + predicate
	var raw := db.execute(query, [], false)
	var investigates_content := predicate.to_lower().contains("contenido")
	var has_signal: bool = raw.ok and not raw.rows.is_empty()
	var result := {"ok": raw.ok, "rows": [], "columns": [], "error": raw.error, "query": query, "attack": investigates_content,
		"signal": has_signal, "highlight": predicate, "input": predicate, "message": "Señal booleana: PRESENTE · latencia virtual: 850 ms" if has_signal else "Señal booleana: AUSENTE · latencia virtual: 40 ms"}
	if investigates_content: mark("attack")
	if not investigates_content: result.message += "\nInvestiga contenido para demostrar una inferencia sobre datos, no una constante."
	if record: _record("blind", predicate, result)
	return result

func _failure(message: String) -> Dictionary:
	return {"ok": false, "rows": [], "columns": [], "error": message, "query": "", "message": message}

func _record(kind: String, input: String, result: Dictionary) -> void:
	history.append({"kind": kind, "input": input, "query": result.get("query", ""), "ok": result.get("ok", false), "message": result.get("message", result.get("error", ""))})
	if history.size() > 40: history.pop_front()

func hint() -> String:
	var key := str(current)
	var count := int(hints.get(key, 0))
	hints[key] = mini(count + 1, 3)
	changed.emit()
	return mission().hints[mini(count, 2)]

func save_report(body: String) -> bool:
	if current >= missions.size(): return false
	var lower := body.to_lower()
	var valid := body.strip_edges().length() >= 100 and lower.contains("evidencia:") and lower.contains("causa:") and lower.contains("corrección:")
	if valid:
		reports[str(current)] = body
		mark("report")
	changed.emit()
	return valid

func test_patches(code: String = "") -> Array:
	if not code.is_empty(): patch_text = code
	var kind: String = mission().get("kind", "login")
	var output: Array = []
	var valid := _patch_is_safe(kind, patch_text)
	var tests := ["Patrón educativo de entrada legítima", "Separación de entrada manipulada", "Control esperado para este ejercicio"]
	for label in tests: output.append(("OK  " if valid else "FALLO  ") + label)
	if valid:
		mark("defense")
		output.append("PATRÓN RECONOCIDO · simulación educativa; el código no se ejecutó")
	_record("defense", patch_text, {"ok": valid, "message": "\n".join(output), "query": patch_text})
	changed.emit()
	return output

func _patch_is_safe(kind: String, code: String) -> bool:
	var text := code.to_lower()
	match kind:
		"login": return text.contains("cursor.execute") and text.count("?") >= 2 and not text.contains("+ username") and not text.contains("+ password")
		"search": return text.contains("cursor.execute") and text.contains("like ?") and text.contains("%{search}%") and not text.contains("+ search")
		"order": return text.contains("allowed_columns") and text.contains("get(sort_by") and text.contains("\"id\"") and not text.contains("+ sort_by")
		"blind": return text.contains("cursor.execute") and text.count("?") >= 2 and text.contains("authorized_user_id") and not text.contains("+ probe")
		"final": return _patch_is_safe("login", code) and _patch_is_safe("search", code) and _patch_is_safe("order", code)
	return false

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
	patch_text = _vulnerable_patch(mission().get("kind", "login") if current < missions.size() else "login")
	db.reset_data()
	mission_completed.emit(index, earned)
	changed.emit()
	return true

func reset_lab() -> void:
	db.reset_data()
	evidence.clear()
	history.clear()
	patch_text = _vulnerable_patch(mission().get("kind", "login"))
	changed.emit()

func _default_patch(kind: String) -> String:
	match kind:
		"login": return "cursor.execute(\n    \"SELECT * FROM users WHERE user = ? AND pass = ?\",\n    (username, password)\n)"
		"search": return "query = \"SELECT id, name, price FROM products WHERE name LIKE ?\"\ncursor.execute(query, (f\"%{search}%\",))"
		"order": return "ALLOWED_COLUMNS = {\n    \"id\": \"id\",\n    \"name\": \"name\",\n    \"budget\": \"budget\"\n}\ncolumn = ALLOWED_COLUMNS.get(sort_by, \"id\")\nquery = f\"SELECT * FROM projects ORDER BY {column}\""
		"blind": return "cursor.execute(\n    \"SELECT id FROM documents WHERE id = ? AND owner_id = ?\",\n    (probe, authorized_user_id)\n)"
		"final": return _default_patch("login") + "\n\n" + _default_patch("search") + "\n\n" + _default_patch("order")
	return ""

func _vulnerable_patch(kind: String) -> String:
	match kind:
		"login": return "query = \"SELECT * FROM users WHERE user = '\" + username + \"' AND pass = '\" + password + \"'\"\ncursor.execute(query)"
		"search": return "query = \"SELECT id, name, price FROM products WHERE name LIKE '%\" + search + \"%'\"\ncursor.execute(query)"
		"order": return "query = \"SELECT * FROM projects ORDER BY \" + sort_by\ncursor.execute(query)"
		"blind": return "query = \"SELECT id FROM documents WHERE id = \" + probe + \" AND owner_id = \" + authorized_user_id\ncursor.execute(query)"
		"final": return _vulnerable_patch("login") + "\n\n" + _vulnerable_patch("search") + "\n\n" + _vulnerable_patch("order")
	return ""

func collect(id: int) -> bool:
	if id in collected: return false
	collected.append(id)
	xp += 25
	changed.emit()
	return true

func rank_name() -> String:
	return "Auditor en entrenamiento" if current == 0 else str(missions[mini(current - 1, missions.size() - 1)].rank)

func serialize() -> Dictionary:
	return {"current": current, "xp": xp, "completed": completed, "evidence": evidence, "hints": hints, "history": history,
		"reports": reports, "collected": collected, "earned_evidence": earned_evidence, "briefed": briefed, "tables": db.tables, "patch_text": patch_text, "lessons": lessons}

func restore(data: Dictionary) -> void:
	current = clampi(int(data.get("current", 0)), 0, missions.size())
	xp = maxi(0, int(data.get("xp", 0)))
	completed = []
	for value in data.get("completed", []): completed.append(int(value))
	evidence = data.get("evidence", {})
	hints = data.get("hints", {})
	history = data.get("history", [])
	reports = data.get("reports", {})
	lessons = data.get("lessons", {})
	collected = []
	for value in data.get("collected", []): collected.append(int(value))
	earned_evidence = data.get("earned_evidence", [])
	briefed = []
	for value in data.get("briefed", []): briefed.append(int(value))
	db.tables = data.get("tables", db.tables)
	patch_text = str(data.get("patch_text", _vulnerable_patch(mission().get("kind", "login") if current < missions.size() else "login")))
	changed.emit()
