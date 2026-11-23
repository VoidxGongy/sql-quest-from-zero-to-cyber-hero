class_name QuestSave
extends RefCounted
const PATH := "user://sql_quest_v2.json"
var last_error := ""

func write(data: Dictionary, path: String = PATH) -> bool:
    last_error = ""
    var temp := path + ".tmp"
    var file := FileAccess.open(temp, FileAccess.WRITE)
    if file == null: last_error = "No se pudo abrir el archivo de guardado."; return false
    file.store_string(JSON.stringify({"version": 2, "data": data}))
    file.flush()
    var status := file.get_error()
    file.close()
    if status != OK: last_error = "No se pudo escribir la partida."; return false
    var absolute := ProjectSettings.globalize_path(path)
    if FileAccess.file_exists(path) and not _decode(path).is_empty():
        var backup_status := DirAccess.copy_absolute(absolute, absolute + ".bak")
        if backup_status != OK: last_error = "No se pudo conservar la copia de respaldo."; return false
    var renamed := DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), absolute)
    # POSIX replaces atomically; Windows needs removal after preserving the backup.
    if renamed != OK and FileAccess.file_exists(path):
        if DirAccess.remove_absolute(absolute) == OK:
            renamed = DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), absolute)
    if renamed != OK:
        last_error = "No se pudo finalizar el guardado; se conserva el respaldo."
        return false
    return true

func read(path: String = PATH) -> Dictionary:
    last_error = ""
    for candidate in [path, path + ".bak"]:
        var data := _decode(candidate)
        if not data.is_empty():
            if candidate != path: last_error = "Se recuperó la copia de respaldo."
            return data
    last_error = "No hay una partida válida. Puedes iniciar una nueva aventura."
    return {}

func _decode(path: String) -> Dictionary:
    if not FileAccess.file_exists(path): return {}
    var parser := JSON.new()
    if parser.parse(FileAccess.get_file_as_string(path)) != OK: return {}
    var envelope = parser.data
    if not envelope is Dictionary or envelope.get("version") != 2: return {}
    return envelope.data if _valid(envelope.get("data")) else {}

func _valid(data: Variant) -> bool:
    if not data is Dictionary or not data.get("campaign") is Dictionary: return false
    var total: int = JSON.parse_string(FileAccess.get_file_as_string("res://data/missions/campaign.json")).size()
    var c: Dictionary = data.campaign
    for key in ["current", "xp"]:
        if not c.get(key) is float and not c.get(key) is int: return false
    if c.current < 0 or c.current > total or c.current != floor(c.current) or c.xp < 0: return false
    for key in ["completed", "collected", "history"]:
        if not c.get(key) is Array: return false
    for key in ["evidence", "hints", "reports", "tables"]:
        if not c.get(key) is Dictionary: return false
    if c.completed.size() != int(c.current): return false
    for i in range(c.completed.size()):
        if c.completed[i] != i: return false
    for value in c.collected:
        if not _number(value) or value < 0 or value > 7 or value != floor(value): return false
    for value in c.evidence.values():
        if not value is bool: return false
    for value in c.hints.values():
        if not _number(value) or value < 0 or value > 3: return false
    for value in c.reports.values():
        if not value is String: return false
    for key in c.reports:
        if not str(key).is_valid_int() or int(key) < 0 or int(key) >= total: return false
    for item in c.history:
        if not item is Dictionary: return false
        for key in ["kind", "input", "query", "message"]:
            if not item.get(key) is String: return false
        if not item.get("ok") is bool: return false
    for key in ["login_patch", "document_patch"]:
        if not c.get(key) is String: return false
    if not c.get("earned_evidence", []) is Array: return false
    for value in c.get("earned_evidence", []):
        if not value is String: return false
    if data.has("position"):
        var point = data.position
        if not point is Array or point.size() != 2 or not _number(point[0]) or not _number(point[1]): return false
    if data.has("room") and (not _number(data.room) or data.room < 0 or data.room > 7): return false
    var schema = preload("res://scripts/sql_simulator/query_engine.gd").SCHEMA
    for table in schema:
        if not c.tables.get(table) is Array: return false
        for row in c.tables[table]:
            if not row is Dictionary: return false
            for column in schema[table]:
                if not row.has(column): return false
                if column in ["id", "owner_id"]:
                    if not _number(row[column]): return false
                elif not row[column] is String: return false
    return true

func _number(value: Variant) -> bool:
    return (value is int or value is float) and is_finite(float(value))
