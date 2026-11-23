extends SceneTree
var failures := 0
var checks := 0
const SQL = preload("res://scripts/sql_simulator/query_engine.gd")
const Campaign = preload("res://scripts/missions/campaign.gd")
const Save = preload("res://scripts/save_system/save_store.gd")
const LOGIN := "SELECT id, usuario FROM usuarios WHERE (usuario = ?) AND (clave = ?)"
const DOCUMENT := "SELECT id, titulo, contenido FROM documentos WHERE id = ? AND owner_id = ?"
const LEAK := "nadie' UNION SELECT titulo, contenido FROM documentos --"
const REPORT := "Evidencia: reproduje acceso sin clave y recuperé AURORA-42 mediante el buscador.\nCausa: la aplicación concatena entradas dentro de la sentencia SQL y permite modificar WHERE.\nCorrección: enlazar parámetros separados y exigir propietario de sesión; probé casos válidos e inválidos."

func _init() -> void: call_deferred("_run")
func check(value: bool, label: String) -> void:
    checks += 1
    if not value: failures += 1; push_error(label)
    else: print("OK · ", label)

func _run() -> void:
    var db = SQL.new()
    check(db.execute("select id, nombre from estudiantes where nombre='Nova';").rows == [{"id": 2, "nombre": "Nova"}], "SELECT case insensitive, projection and WHERE")
    check(db.execute("SELECT * FROM estudiantes WHERE id=2 OR id=3 AND estado='becada'").rows.size() == 1, "AND before OR")
    check(db.execute("SELECT * FROM estudiantes WHERE (id=2 OR id=3) AND estado='activo'").rows.size() == 1, "Parentheses")
    check(db.execute("SELECT nombre FROM estudiantes WHERE nombre LIKE 'N%' ORDER BY id DESC LIMIT 1").rows.size() == 1, "LIKE, ordering and limit")
    check(db.execute("SELECT * FROM estudiantes WHERE nombre = 'OR 1=1'").rows.is_empty(), "SQL inside a string is data")
    check(db.execute("SELECT * FROM estudiantes WHERE nombre = 'O''Brien'").ok, "Escaped quote")
    check(not db.execute("SELECT * FROM estudiantes WHERE nombre = 'Nova").ok, "Unclosed literal")
    check(not db.execute("SELECT bad FROM estudiantes WHERE id=999").ok, "Unknown column even on empty results")
    check(not db.execute("SELECT * FROM estudiantes; SELECT * FROM usuarios").ok, "Stacked statements rejected")
    check(not db.execute("SELECT * FROM estudiantes UNION SELECT id FROM usuarios").ok, "UNION arity")
    check(db.execute("SELECT id FROM estudiantes UNION SELECT id FROM estudiantes").rows.size() == 4, "UNION distinct")
    check(db.execute("SELECT id FROM estudiantes UNION ALL SELECT id FROM estudiantes").rows.size() == 8, "UNION ALL")
    check(db.execute("SELECT * FROM usuarios WHERE usuario = ? AND clave = ?", ["admin' --", "x"]).rows.is_empty(), "Bound injection literal")
    check(not db.execute("SELECT * FROM usuarios WHERE usuario = ?", []).ok, "Missing binding")
    check(not db.execute("SELECT * FROM usuarios", [1]).ok, "Extra binding")
    var before: Dictionary = db.tables.duplicate(true)
    check(not db.execute("UPDATE incidentes SET estado='roto' WHERE id=1; SELECT * FROM usuarios").ok and db.tables == before, "Invalid mutation rolls back")
    check(not db.execute("UPDATE incidentes SET estado='roto'").ok and db.tables == before, "Mutation requires WHERE")
    check(db.execute("INSERT INTO incidentes (id,titulo,estado) VALUES (3,'Prueba','abierto')").ok, "INSERT data")
    check(not db.execute("INSERT INTO incidentes (id,titulo) VALUES (3,'Duplicado')").ok, "Duplicate id rejected")
    check(not db.execute("DROP TABLE usuarios").ok, "No DDL")
    check(not db.execute("UPDATE incidentes SET estado='x' WHERE id=1", [], false).ok, "Read-only scope")
    check(not db.execute("UPDATE estudiantes SET nombre=123 WHERE id=1").ok, "Column types preserved")
    check(not db.execute("SELECT * FROM estudiantes WHERE " + "(".repeat(25) + "id=1" + ")".repeat(25)).ok, "Bounded expression nesting")
    for input in ["", "SELECT", "SELECT *", "SELECT * FROM", "SELECT * FROM estudiantes WHERE", "SELECT * FROM estudiantes WHERE )", "INSERT INTO incidentes (id) VALUES (", "UPDATE incidentes SET", "SELECT * FROM estudiantes WHERE NOT", "SELECT * FROM estudiantes WHERE id ="]:
        check(not db.execute(input).ok, "Incomplete input returns feedback: " + input)
    var c = Campaign.new()
    check(not c.complete(), "Cannot skip mission")
    c.submit("query", "SELECT nombre, id FROM estudiantes WHERE id >= 2 AND id < 3")
    check(c.can_complete(), "Equivalent first mission solution accepted")
    check(c.complete() and c.current == 1 and c.xp == 160, "Reward and unlock")
    check(not c.complete() and c.xp == 160, "No duplicate reward")
    var assisted = Campaign.new()
    assisted.hint()
    assisted.submit("query", "SELECT id, nombre FROM estudiantes WHERE nombre='Nova'")
    check(assisted.complete() and assisted.xp == 160, "Using instructor hints does not reduce XP")
    c.submit("login", "nova", "nova123")
    c.submit("login", "nova", "incorrecta")
    c.submit("login", "'", "x")
    check(c.complete(), "Mission 2: observe valid, invalid, syntax")
    c.submit("login", "' OR 7=7 --", "x")
    c.submit("login", "' OR 7=8 --", "x")
    check(c.complete(), "Mission 3: attack and counterexample")
    c.submit("search", LEAK)
    check(not c.complete(), "Leak requires report")
    check(not c.save_report("Evidencia: nada\nCausa: nada\nCorrección: nada"), "Empty report rejected")
    check(c.save_report(REPORT) and c.complete(), "Mission 4: UNION and documentation")
    c.submit("boolean", "1=1")
    check(not c.evidence.has("bool_yes"), "Constant predicate is not evidence about contents")
    for kind in ["boolean", "time"]:
        var r: Dictionary = c.submit(kind, "contenido LIKE 'AURORA%'")
        check(r.rows.is_empty() and r.signal, "Blind output hides rows: " + kind)
        c.submit(kind, "contenido LIKE 'NUNCA%'")
    check(c.complete(), "Mission 5: paired sensors")
    c.login_patch = "SELECT * FROM usuarios WHERE usuario = ? OR clave = ?"
    c.document_patch = DOCUMENT
    c.test_patches()
    check(not c.evidence.has("login_fixed"), "Unsafe OR patch fails regression")
    c.login_patch = LOGIN
    c.document_patch = "SELECT id,titulo,contenido FROM documentos WHERE id = ? OR owner_id = ?"
    c.test_patches()
    check(not c.evidence.has("access_fixed"), "Cross-account leak fails regression")
    c.document_patch = DOCUMENT
    c.test_patches()
    check(c.complete(), "Mission 6: semantic patch validation")
    for stage in [6, 7]:
        c.submit("login", "admin' --", "x")
        c.submit("search", LEAK)
        c.login_patch = LOGIN
        c.document_patch = DOCUMENT
        c.test_patches()
        c.save_report(REPORT)
        if stage == 6: c.submit("query", "UPDATE incidentes SET estado='resuelto' WHERE id >= 1")
        else: c.submit("query", "INSERT INTO incidentes (id,titulo,estado) VALUES (9,'Certificación de Nova','certificado')")
        check(c.complete(), "Professional mission " + str(stage + 1))
    check(c.current == 8 and c.completed.size() == 8, "Campaign reaches hiring")
    check(c.collect(2) and not c.collect(2), "Collectible XP once")
    var store = Save.new()
    var path := "user://test_campaign_save.json"
    check(store.write({"campaign": c.serialize(), "room": 7}, path), "Save writes")
    var restored = Campaign.new()
    var saved: Dictionary = store.read(path)
    restored.restore(saved.campaign)
    check(restored.current == 8 and restored.xp == c.xp and restored.reports == c.reports, "Save restores progress and reports")
    check(not restored.collect(2) and 0 in restored.completed, "JSON numeric restoration preserves unique rewards and badges")
    store.write({"campaign": c.serialize()}, path)
    var corrupt := FileAccess.open(path, FileAccess.WRITE)
    corrupt.store_string("{truncated")
    corrupt.close()
    check(not store.read(path).is_empty(), "Corrupt save recovers backup")
    check(not store._valid({"campaign": {"current": 2}}), "Malformed save rejected")
    var broken := {"campaign": c.serialize()}
    broken.campaign.reports["7"] = ["incorrect type"]
    check(not store._valid(broken), "Malformed nested save rejected")
    var practice = Campaign.new()
    practice.submit("query", "SELECT * FROM estudiantes WHERE id=2")
    var earned: int = practice.xp
    practice.reset_lab()
    practice.submit("query", "SELECT * FROM estudiantes WHERE nombre='Nova'")
    check(practice.xp == earned, "Reset cannot farm evidence XP")
    var restored_mid = Campaign.new()
    restored_mid.restore(practice.serialize())
    check(restored_mid.can_complete() and restored_mid.history.size() == 1, "Restore unfinished mission with evidence and history")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".bak"))
    print("Campaign/SQL: %d checks, %d failures" % [checks, failures])
    quit(1 if failures else 0)
