class_name QuestSQL
extends RefCounted
## A bounded SQL interpreter. Tokens and syntax trees, never eval or external SQL.
const SCHEMA := {
    "estudiantes": ["id", "nombre", "carrera", "estado"],
    "usuarios": ["id", "usuario", "clave", "rol", "dato"],
    "documentos": ["id", "titulo", "contenido", "owner_id"],
    "incidentes": ["id", "titulo", "estado"],
    "products": ["id", "name", "price"],
    "vault": ["id", "secret", "access"],
    "projects": ["id", "name", "budget"],
}
var tables: Dictionary = {}
var tokens: Array = []
var pos := 0
var error := ""
var bindings: Array = []
var bind_index := 0

func _init() -> void:
    reset_data()

func reset_data() -> void:
    tables = {
        "estudiantes": [
            {"id": 1, "nombre": "Leo", "carrera": "Sistemas", "estado": "activo"},
            {"id": 2, "nombre": "Nova", "carrera": "Sistemas", "estado": "becada"},
            {"id": 3, "nombre": "Ada", "carrera": "Diseño", "estado": "activo"},
            {"id": 4, "nombre": "Iris", "carrera": "Sistemas", "estado": "activo"}],
        "usuarios": [
            {"id": 1, "usuario": "nova", "clave": "nova123", "rol": "ANALISTA", "dato": "NV-77"},
            {"id": 2, "usuario": "gongy", "clave": "cyber2026", "rol": "INVESTIGADOR", "dato": "Academia"},
            {"id": 3, "usuario": "admin", "clave": "supersecreto", "rol": "ADMIN", "dato": "LAB-ROOT"},
            {"id": 4, "usuario": "visitante", "clave": "visitante", "rol": "LECTURA", "dato": "Público"}],
        "documentos": [
            {"id": 1, "titulo": "Bienvenida", "contenido": "Tu primer día", "owner_id": 1},
            {"id": 2, "titulo": "Proyecto Aurora", "contenido": "AURORA-42", "owner_id": 3},
            {"id": 3, "titulo": "Guía", "contenido": "Aprender haciendo", "owner_id": 1}],
        "incidentes": [{"id": 1, "titulo": "Login vulnerable", "estado": "abierto"},
            {"id": 2, "titulo": "Documento ajeno", "estado": "abierto"}],
        "products": [
            {"id": 1, "name": "Terminal segura", "price": 120},
            {"id": 2, "name": "Teclado mecánico", "price": 80},
            {"id": 3, "name": "Monitor SOC", "price": 240}],
        "vault": [
            {"id": 91, "secret": "AURORA-42", "access": "NULLSEC-CHALLENGE"},
            {"id": 92, "secret": "KEY-ROTATE", "access": "RESTRICTED"}],
        "projects": [
            {"id": 1, "name": "Aurora", "budget": 90000},
            {"id": 2, "name": "Beacon", "budget": 42000},
            {"id": 3, "name": "Cipher", "budget": 150000}]
    }

func execute(sql: String, params: Array = [], writable: bool = true) -> Dictionary:
    error = ""
    pos = 0
    bind_index = 0
    bindings = params
    tokens = _lex(sql)
    if error != "": return _failure()
    var snapshot := tables.duplicate(true)
    var result: Dictionary
    if _eat("SELECT"):
        result = _select()
    elif writable and _eat("INSERT"):
        result = _insert()
    elif writable and _eat("UPDATE"):
        result = _update()
    else:
        error = "Operación no disponible. Usa SELECT" + (", INSERT o UPDATE." if writable else ".")
        return _failure()
    _eat(";")
    if pos < tokens.size() and error == "": error = "Una sola sentencia por ejecución. Revisa el texto restante."
    if bind_index != params.size() and error == "": error = "La cantidad de parámetros no coincide con los marcadores ?."
    if error != "":
        tables = snapshot
        return _failure()
    result["ok"] = true
    result["error"] = ""
    result["query"] = sql
    return result

func _failure() -> Dictionary:
    return {"ok": false, "error": error, "rows": [], "columns": [], "affected": 0}

func _lex(sql: String) -> Array:
    var out: Array = []
    if sql.length() > 4096:
        error = "Máximo 4096 caracteres por consulta."
        return out
    var i := 0
    var nesting := 0
    while i < sql.length():
        if out.size() > 256:
            error = "Máximo 256 tokens por consulta. Divide el experimento."
            return []
        var c := sql[i]
        if c in [" ", "\n", "\r", "\t"]: i += 1; continue
        if sql.substr(i, 2) == "--":
            while i < sql.length() and sql[i] != "\n": i += 1
            continue
        if c == "'":
            i += 1
            var value := ""
            var closed := false
            while i < sql.length():
                if sql[i] == "'":
                    if i + 1 < sql.length() and sql[i + 1] == "'": value += "'"; i += 2; continue
                    closed = true; i += 1; break
                value += sql[i]; i += 1
            if not closed: error = "Texto sin cerrar: revisa las comillas simples."; return []
            out.append({"kind": "literal", "value": value})
        elif c in "0123456789" or (c == "-" and i + 1 < sql.length() and sql[i + 1] in "0123456789"):
            var start := i
            i += 1
            while i < sql.length() and sql[i] in "0123456789.": i += 1
            var number := sql.substr(start, i - start)
            if not number.is_valid_float(): error = "Número no válido."; return []
            out.append({"kind": "literal", "value": number.to_float()})
        elif c.to_lower() in "abcdefghijklmnopqrstuvwxyz_":
            var start := i
            while i < sql.length() and sql[i].to_lower() in "abcdefghijklmnopqrstuvwxyz_0123456789": i += 1
            out.append({"kind": "word", "value": sql.substr(start, i - start)})
        elif c in "*=<>!(),;?":
            if c == "(": nesting += 1
            if c == ")": nesting -= 1
            if nesting > 24:
                error = "Máximo 24 niveles de paréntesis. Simplifica la condición."
                return []
            var op := c
            if sql.substr(i, 2) in ["<=", ">=", "!=", "<>"]: op = sql.substr(i, 2); i += 1
            out.append({"kind": "symbol", "value": op}); i += 1
        else:
            error = "Símbolo no admitido: %s. Consulta la referencia SQL." % c
            return []
    return out

func _peek() -> String:
    if pos >= tokens.size() or tokens[pos].kind == "literal": return ""
    return str(tokens[pos].value).to_upper()

func _eat(value: String) -> bool:
    if _peek() == value: pos += 1; return true
    return false

func _expect(value: String) -> void:
    if not _eat(value) and error == "": error = "Se esperaba %s cerca del token %d." % [value, pos + 1]

func _identifier() -> String:
    if pos >= tokens.size() or tokens[pos].kind != "word":
        if error == "": error = "Se esperaba un nombre de tabla o columna."
        return ""
    var value := str(tokens[pos].value).to_lower()
    pos += 1
    return value

func _value() -> Array:
    if _eat("("):
        var expr := _or_expr()
        _expect(")")
        return expr
    if _eat("?"):
        var value = bindings[bind_index] if bind_index < bindings.size() else null
        if bind_index >= bindings.size(): error = "Falta un valor para el parámetro ?."
        bind_index += 1
        return ["literal", value]
    if _eat("TRUE"): return ["literal", true]
    if _eat("FALSE"): return ["literal", false]
    if pos < tokens.size() and tokens[pos].kind == "literal":
        var value = tokens[pos].value
        pos += 1
        return ["literal", value]
    return ["column", _identifier()]

func _comparison() -> Array:
    if _eat("NOT"): return ["not", _comparison()]
    var left := _value()
    if _peek() in ["=", "!=", "<>", "<", ">", "<=", ">=", "LIKE"]:
        var op := _peek()
        pos += 1
        return [op, left, _value()]
    return left

func _and_expr() -> Array:
    var left := _comparison()
    while _eat("AND"): left = ["and", left, _comparison()]
    return left

func _or_expr() -> Array:
    var left := _and_expr()
    while _eat("OR"): left = ["or", left, _and_expr()]
    return left

func _validate(expr: Array, columns: Array) -> void:
    if expr[0] == "column":
        if expr[1] not in columns: error = "Columna desconocida: %s." % expr[1]
    elif expr[0] != "literal":
        for child in expr.slice(1): _validate(child, columns)

func _eval(expr: Array, row: Dictionary) -> Variant:
    match expr[0]:
        "literal": return expr[1]
        "column": return row.get(expr[1])
        "not": return not _truth(_eval(expr[1], row))
        "and": return _truth(_eval(expr[1], row)) and _truth(_eval(expr[2], row))
        "or": return _truth(_eval(expr[1], row)) or _truth(_eval(expr[2], row))
    var a = _eval(expr[1], row)
    var b = _eval(expr[2], row)
    if a == null or b == null: return false
    # Unlike a DBMS, this subset performs no implicit text/number casts.
    if (a is String) != (b is String): return expr[0] in ["!=", "<>"]
    match expr[0]:
        "=": return a == b
        "!=", "<>": return a != b
        "<": return a < b
        ">": return a > b
        "<=": return a <= b
        ">=": return a >= b
        "LIKE":
            return _like(str(a), str(b))
    return false

func _truth(value: Variant) -> bool:
    if value is bool: return value
    if value is int or value is float: return value != 0
    return false

func _like(value: String, pattern: String) -> bool:
    # Dynamic programming keeps wildcard matching bounded, without regex injection.
    var previous: Array = []
    previous.resize(value.length() + 1)
    previous.fill(false)
    previous[0] = true
    for c in pattern:
        var current: Array = []
        current.resize(value.length() + 1)
        current.fill(false)
        current[0] = previous[0] and c == "%"
        for j in range(1, current.size()):
            current[j] = (previous[j] or current[j - 1]) if c == "%" else (previous[j - 1] and (c == "_" or c == value[j - 1]))
        previous = current
    return previous[value.length()]

func _select() -> Dictionary:
    var projections: Array = []
    var star := _eat("*")
    if not star:
        projections.append(_value())
        while _eat(","): projections.append(_value())
    _expect("FROM")
    var table := _identifier()
    if not SCHEMA.has(table): error = "Tabla desconocida: %s." % table; return _failure()
    var columns: Array = SCHEMA[table].duplicate() if star else []
    if not star:
        for expression in projections:
            _validate(expression, SCHEMA[table])
            columns.append(str(expression[1]))
        if columns.size() != _unique(columns).size(): error = "Usa columnas de salida distintas en este laboratorio."; return _failure()
    var condition: Array = ["literal", true]
    if _eat("WHERE"): condition = _or_expr()
    _validate(condition, SCHEMA[table])
    if error != "": return _failure()
    var source: Array = []
    for row in tables[table]:
        if _truth(_eval(condition, row)): source.append(row)
    if _eat("ORDER"):
        _expect("BY")
        var column := _identifier()
        if column not in SCHEMA[table]: error = "Columna de orden desconocida."; return _failure()
        var descending := _eat("DESC")
        if not descending: _eat("ASC")
        source.sort_custom(func(a, b): return a[column] > b[column] if descending else a[column] < b[column])
    if _eat("LIMIT"):
        var limit := _value()
        if limit[0] != "literal" or not (limit[1] is float) or limit[1] < 0 or limit[1] != floor(limit[1]):
            error = "LIMIT requiere un entero positivo o cero."; return _failure()
        source = source.slice(0, mini(int(limit[1]), source.size()))
    var rows: Array = []
    for row in source:
        var output: Dictionary = {}
        for i in range(columns.size()): output[columns[i]] = row[columns[i]] if star else _eval(projections[i], row)
        rows.append(output)
    if _eat("UNION"):
        var all_rows := _eat("ALL")
        _expect("SELECT")
        var other := _select()
        if error != "": return _failure()
        if other.columns.size() != columns.size(): error = "UNION requiere el mismo número de columnas en ambos SELECT."; return _failure()
        for row in other.rows:
            var mapped: Dictionary = {}
            for i in range(columns.size()): mapped[columns[i]] = row[other.columns[i]]
            rows.append(mapped)
        if not all_rows: rows = _unique(rows)
    return {"rows": rows, "columns": columns, "affected": 0, "operation": "SELECT", "table": table}

func _unique(items: Array) -> Array:
    var result: Array = []
    for item in items:
        if item not in result: result.append(item)
    return result

func _insert() -> Dictionary:
    _expect("INTO")
    var table := _identifier()
    if not SCHEMA.has(table): error = "Tabla desconocida."; return _failure()
    _expect("(")
    var columns: Array = [_identifier()]
    while _eat(","): columns.append(_identifier())
    _expect(")")
    _expect("VALUES")
    _expect("(")
    var values: Array = [_value()]
    while _eat(","): values.append(_value())
    _expect(")")
    if columns.size() != values.size() or _unique(columns).size() != columns.size(): error = "Revisa columnas y cantidad de valores."; return _failure()
    var row: Dictionary = {}
    for c in SCHEMA[table]: row[c] = ""
    for i in range(columns.size()):
        if columns[i] not in SCHEMA[table] or values[i][0] != "literal": error = "INSERT requiere columnas válidas y valores literales."; return _failure()
        row[columns[i]] = values[i][1]
        if not _valid_type(columns[i], values[i][1]): error = "Tipo incorrecto para " + columns[i]; return _failure()
    if not (row.id is float) or row.id < 1 or row.id != floor(row.id): error = "id debe ser un entero positivo."; return _failure()
    for column in SCHEMA[table]:
        if not _valid_type(column, row[column]): error = "Falta un valor válido para " + column; return _failure()
    for existing in tables[table]:
        if existing.id == row.id: error = "Ese id ya existe."; return _failure()
    if tables[table].size() >= 100: error = "Límite del laboratorio: 100 filas por tabla."; return _failure()
    tables[table].append(row)
    return {"rows": [row], "columns": SCHEMA[table], "affected": 1, "operation": "INSERT", "table": table}

func _update() -> Dictionary:
    var table := _identifier()
    if not SCHEMA.has(table): error = "Tabla desconocida."; return _failure()
    _expect("SET")
    var assignments: Dictionary = {}
    while true:
        var column := _identifier()
        _expect("=")
        var value := _value()
        if column not in SCHEMA[table] or column == "id" or value[0] != "literal": error = "Solo puedes actualizar columnas no id con valores literales."; return _failure()
        if not _valid_type(column, value[1]): error = "Tipo incorrecto para " + column; return _failure()
        assignments[column] = value[1]
        if not _eat(","): break
    _expect("WHERE")
    var condition := _or_expr()
    _validate(condition, SCHEMA[table])
    if error != "": return _failure()
    var affected: Array = []
    for row in tables[table]:
        if _truth(_eval(condition, row)):
            for column in assignments: row[column] = assignments[column]
            affected.append(row.duplicate())
    return {"rows": affected, "columns": SCHEMA[table], "affected": affected.size(), "operation": "UPDATE", "table": table}

func _valid_type(column: String, value: Variant) -> bool:
    if column in ["id", "owner_id"]:
        return (value is float or value is int) and value >= 1 and value == floor(value)
    return value is String
