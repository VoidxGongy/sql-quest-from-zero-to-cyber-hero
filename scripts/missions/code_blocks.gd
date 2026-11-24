class_name QuestCodeBlocks
extends RefCounted
## Controlled building blocks: no user code is executed.

const PIECES := {
	"login_query": "query = \"SELECT * FROM users WHERE user = ? AND pass = ?\"",
	"login_run": "cursor.execute(query, (username, password))",
	"search_query": "query = \"SELECT id, name, price FROM products WHERE name LIKE ?\"",
	"search_run": "cursor.execute(query, (f\"%{search}%\",))",
	"allow": "ALLOWED_COLUMNS = {\"id\": \"id\", \"name\": \"name\", \"budget\": \"budget\"}",
	"choose": "column = ALLOWED_COLUMNS.get(sort_by, \"id\")",
	"order_run": "query = f\"SELECT * FROM projects ORDER BY {column}\"",
	"blind_query": "query = \"SELECT id FROM documents WHERE id = ? AND owner_id = ?\"",
	"blind_run": "cursor.execute(query, (probe, authorized_user_id))",
	"unsafe_login": "query = \"SELECT * FROM users WHERE user = '\" + username + \"'\"",
	"unsafe_search": "query = \"SELECT * FROM products WHERE name LIKE '%\" + search + \"%'\"",
	"unsafe_order": "query = \"SELECT * FROM projects ORDER BY \" + sort_by",
	"unsafe_blind": "cursor.execute(query, (probe, supplied_user_id))"
}
const REQUIRED := {
	"login": ["login_query", "login_run"],
	"search": ["search_query", "search_run"],
	"order": ["allow", "choose", "order_run"],
	"blind": ["blind_query", "blind_run"],
	"final": ["login_query", "login_run", "search_query", "search_run", "allow", "choose", "order_run"]
}

static func available(kind: String) -> Array:
	var pieces: Array = REQUIRED.get(kind, []).duplicate()
	match kind:
		"login": pieces.append("unsafe_login")
		"search": pieces.append("unsafe_search")
		"order": pieces.append("unsafe_order")
		"blind": pieces.append("unsafe_blind")
		"final": pieces.append_array(["unsafe_login", "unsafe_search", "unsafe_order"])
	pieces.reverse()
	return pieces

static func evaluate(kind: String, selected: Array, db: QuestSQL) -> Dictionary:
	for id in selected:
		if str(id).begins_with("unsafe_"):
			return {"ok": false, "message": "Ese bloque usa entrada sin validar o concatena datos en SQL. Retíralo y busca una alternativa que separe los valores."}
	var required: Array = REQUIRED.get(kind, [])
	for id in required:
		if id not in selected:
			return {"ok": false, "message": _missing_message(id)}
	if selected.size() != required.size():
		return {"ok": false, "message": "Retira los bloques adicionales antes de verificar."}
	for pair in [["login_query", "login_run"], ["search_query", "search_run"], ["blind_query", "blind_run"], ["allow", "choose"], ["choose", "order_run"]]:
		if pair[0] in required and selected.find(pair[0]) > selected.find(pair[1]):
			return {"ok": false, "message": "Una instrucción usa un valor antes de definirlo. Mueve el bloque de definición antes del bloque que lo utiliza."}
	var checks: Array[String] = []
	if kind in ["login", "final"]:
		var normal := db.execute("SELECT * FROM usuarios WHERE usuario = ? AND clave = ?", ["visitante", "visitante"], false)
		var attack := db.execute("SELECT * FROM usuarios WHERE usuario = ? AND clave = ?", ["admin' --", "x"], false)
		if not normal.ok or normal.rows.size() != 1 or not attack.ok or not attack.rows.is_empty(): return {"ok": false, "message": "Falló la simulación de autenticación."}
		checks.append("✓ Login legítimo permitido; entrada manipulada tratada como dato")
	if kind in ["search", "final"]:
		var normal := db.execute("SELECT id, name, price FROM products WHERE name LIKE ?", ["%Terminal%"], false)
		var attack := db.execute("SELECT id, name, price FROM products WHERE name LIKE ?", ["%' UNION SELECT id, secret, 0 FROM vault --%"], false)
		if not normal.ok or normal.rows.is_empty() or not attack.ok or not attack.rows.is_empty(): return {"ok": false, "message": "Falló la simulación de búsqueda."}
		checks.append("✓ Búsqueda legítima funciona; UNION permanece en el parámetro")
	if kind in ["order", "final"]:
		var allowed := {"id": "id", "name": "name", "budget": "budget"}
		if allowed.get("name", "id") != "name" or allowed.get("CASE WHEN 1=1 THEN name END", "id") != "id": return {"ok": false, "message": "Falló la lista blanca."}
		checks.append("✓ Columna permitida aceptada; expresión no autorizada sustituida por id")
	if kind == "blind":
		var normal := db.execute("SELECT id FROM documentos WHERE id = ? AND owner_id = ?", [1, 1], false)
		var other := db.execute("SELECT id FROM documentos WHERE id = ? AND owner_id = ?", [2, 1], false)
		var injected := db.execute("SELECT id FROM documentos WHERE id = ? AND owner_id = ?", ["1 OR 1=1", 1], false)
		if not normal.ok or normal.rows.is_empty() or not other.ok or not other.rows.is_empty() or not injected.ok or not injected.rows.is_empty(): return {"ok": false, "message": "Falló la simulación de acceso autorizado."}
		checks.append("✓ Propietario autorizado; documento ajeno y entrada manipulada bloqueados")
	return {"ok": true, "message": "\n".join(checks) + "\nSimulación de bloques conocidos: no se ejecuta Python."}

static func _missing_message(id: String) -> String:
	if str(id).ends_with("_run"): return "Falta ejecutar la consulta con los valores separados como parámetros."
	if id == "allow" or id == "choose": return "Falta definir o consultar la lista blanca de columnas autorizadas."
	return "Falta una consulta que use marcadores para mantener los datos separados del SQL."
