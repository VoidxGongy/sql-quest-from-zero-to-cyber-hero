class_name QuestLab
extends Control
signal closed
signal performed(success: bool)
signal reward_requested
const UI = preload("res://scripts/ui/ui_kit.gd")
var campaign: QuestCampaign
var tabs: TabContainer
var checklist: Label
var objective: Label
var title: Label
var output: RichTextLabel
var history_view: RichTextLabel
var query_input: CodeEdit
var user_input: LineEdit
var pass_input: LineEdit
var search_input: LineEdit
var predicate_input: CodeEdit
var login_edit: CodeEdit
var document_edit: CodeEdit
var report_edit: TextEdit
var patch_result: Label
var report_result: Label
var hint_label: Label
var hint_button: Button
var claim: Button
var restore_button: Button
var reset_pending := false
var reset_deadline := 0.0
var shown_mission := -1

func _ready() -> void:
    theme = UI.theme()
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var background := ColorRect.new()
    background.color = Color("081320")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(background)
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 20)
    add_child(margin)
    var main := VBoxContainer.new()
    main.add_theme_constant_override("separation", 10)
    margin.add_child(main)
    var header := HBoxContainer.new()
    main.add_child(header)
    title = UI.label(header, "Laboratorio SQL", 24, UI.GREEN)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    UI.button(header, "Volver al mundo · Esc", close_lab)
    objective = UI.paragraph(main, "", 16)
    var body := HSplitContainer.new()
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.split_offset = 690
    main.add_child(body)
    var left := VBoxContainer.new()
    left.custom_minimum_size.x = 500
    left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.add_child(left)
    tabs = TabContainer.new()
    tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
    left.add_child(tabs)
    tabs.tab_changed.connect(func(index):
        if output != null: output.custom_minimum_size.y = 145 if index == 4 else 200)
    _build_query()
    _build_login()
    _build_search()
    _build_blind()
    _build_patch()
    _build_report()
    _build_reference()
    UI.label(left, "Ejecución simulada · entrada → consulta → resultado → explicación", 14, UI.MUTED)
    output = RichTextLabel.new()
    output.bbcode_enabled = false
    output.custom_minimum_size.y = 175
    output.size_flags_vertical = Control.SIZE_FILL
    output.selection_enabled = true
    output.add_theme_font_override("normal_font", preload("res://assets/fonts/DejaVuSansMono.ttf"))
    output.add_theme_font_size_override("normal_font_size", 14)
    output.add_theme_stylebox_override("normal", UI.texture_style(preload("res://assets/ui/terminal_frame.png"), 14, false))
    left.add_child(output)
    var side_scroll := ScrollContainer.new()
    side_scroll.custom_minimum_size.x = 280
    side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    body.add_child(side_scroll)
    var evidence_panel := PanelContainer.new()
    evidence_panel.add_theme_stylebox_override("panel", UI.texture_style(preload("res://assets/ui/mission_panel.png"), 14, false))
    side_scroll.add_child(evidence_panel)
    var side := VBoxContainer.new()
    side.add_theme_constant_override("separation", 12)
    side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    evidence_panel.add_child(side)
    UI.label(side, "Evidencias de la misión", 18, UI.GREEN)
    checklist = UI.paragraph(side, "", 15)
    claim = UI.button(side, "Entregar misión", func(): reward_requested.emit())
    hint_button = UI.button(side, "Pedir pista al instructor", _hint)
    hint_label = UI.paragraph(side, "", 14)
    restore_button = UI.button(side, "Restaurar laboratorio", _reset)
    UI.label(side, "Historial de pruebas", 18)
    history_view = RichTextLabel.new()
    history_view.custom_minimum_size = Vector2(250, 230)
    history_view.selection_enabled = true
    side.add_child(history_view)
    UI.paragraph(main, "Datos ficticios · SQL en memoria · Sin red ni comandos del sistema · Ctrl+Enter ejecuta la pestaña actual", 13)
    hide()

func _build_query() -> void:
    var box := UI.scroll_page(tabs, "SQL")
    UI.paragraph(box, "Escribe una consulta. Puedes usar SELECT, WHERE, AND, OR, LIKE, ORDER BY y LIMIT. INSERT y UPDATE se habilitan durante las prácticas.")
    query_input = UI.editor(box, 130)
    query_input.placeholder_text = "Escribe SQL aquí…"
    UI.button(box, "Ejecutar consulta", func(): _run("query", query_input.text))

func _build_login() -> void:
    var box := UI.scroll_page(tabs, "Login")
    UI.paragraph(box, "Aplicación vulnerable de entrenamiento. Credenciales de prueba: nova / nova123. La consulta concatena directamente las dos entradas.")
    UI.label(box, "Usuario")
    user_input = LineEdit.new()
    user_input.placeholder_text = "Nombre o entrada de investigación"
    box.add_child(user_input)
    UI.label(box, "Clave ficticia")
    pass_input = LineEdit.new()
    pass_input.placeholder_text = "Visible para inspeccionar el experimento"
    box.add_child(pass_input)
    UI.button(box, "Probar inicio de sesión", func(): _run("login", user_input.text, pass_input.text))
    pass_input.text_submitted.connect(func(_value): _run("login", user_input.text, pass_input.text))

func _build_search() -> void:
    var box := UI.scroll_page(tabs, "Búsqueda")
    UI.paragraph(box, "Directorio público de estudiantes. El alcance autorizado de este buscador es id y nombre. Inspecciona qué sucede al modificar la entrada.")
    search_input = LineEdit.new()
    search_input.placeholder_text = "Nombre para buscar"
    box.add_child(search_input)
    UI.button(box, "Ejecutar búsqueda", func(): _run("search", search_input.text))
    search_input.text_submitted.connect(func(_value): _run("search", search_input.text))

func _build_blind() -> void:
    var box := UI.scroll_page(tabs, "Sensores")
    UI.paragraph(box, "Modelo de inferencia ciega. Introduce solo una condición sobre documentos. Los sensores no muestran filas. La latencia es virtual; no se usa ninguna función de espera SQL.")
    predicate_input = UI.editor(box, 100)
    predicate_input.placeholder_text = "Condición para investigar una hipótesis…"
    UI.button(box, "Medir presencia · booleano", func(): _run("boolean", predicate_input.text))
    UI.button(box, "Medir latencia · temporal", func(): _run("time", predicate_input.text))

func _build_patch() -> void:
    var box := UI.scroll_page(tabs, "Reparación")
    UI.paragraph(box, "Edita SQL con marcadores ?. La aplicación enlaza los valores por orden, fuera del código SQL. No uses interpolación ni comillas alrededor del marcador.")
    UI.label(box, "Login · parámetros: [usuario, clave]", 15, UI.GREEN)
    login_edit = UI.editor(box, 72)
    UI.label(box, "Documentos · parámetros: [id solicitado, id de sesión]", 15, UI.GREEN)
    document_edit = UI.editor(box, 72)
    UI.button(box, "Aplicar y ejecutar regresión", _test_patch)
    patch_result = UI.paragraph(box, "Las pruebas incluyen casos válidos, inválidos y acceso entre cuentas.", 14)
    login_edit.text_changed.connect(_patch_changed)
    document_edit.text_changed.connect(_patch_changed)

func _build_report() -> void:
    var box := UI.scroll_page(tabs, "Informe")
    UI.paragraph(box, "Documenta un experimento que hayas reproducido. Escribe una línea por sección, con al menos 15 caracteres de explicación. El juego verifica estructura y evidencia capturada; el análisis técnico se puede revisar con un docente.")
    report_edit = UI.editor(box, 210)
    report_edit.placeholder_text = "Evidencia: describe la entrada y el resultado observado\nCausa: explica dónde se mezcla código con datos\nCorrección: describe el control y su prueba"
    UI.button(box, "Adjuntar informe a evidencias", _report)
    report_result = UI.paragraph(box, "", 14)

func _build_reference() -> void:
    var box := UI.scroll_page(tabs, "Esquema")
    UI.label(box, "Tablas del entorno ficticio", 20, UI.GREEN)
    for table in campaign.db.SCHEMA:
        UI.paragraph(box, table + " (" + ", ".join(campaign.db.SCHEMA[table]) + ")", 16)
    UI.paragraph(box, "Primeros registros de estudiantes: Leo (1), Nova (2), Ada (3), Iris (4). Los nombres distinguen mayúsculas. Usuarios de prueba: nova / nova123; admin / supersecreto.")
    UI.paragraph(box, "SELECT columna FROM tabla WHERE condición;\nComparaciones: = != <> < > <= >= LIKE\nCombina: condición AND condición / condición OR condición\nOrden: ORDER BY columna ASC o DESC; límite: LIMIT número\nUNION: dos SELECT con igual cantidad de columnas\nINSERT INTO tabla (columnas) VALUES (valores);\nUPDATE tabla SET columna = valor WHERE condición;")
    UI.paragraph(box, "Texto entre comillas simples; dos comillas simples representan una comilla literal. -- comenta hasta el salto de línea. ? recibe un valor separado. Este dialecto educativo no admite JOIN, subconsultas, funciones SQL ni DDL.", 14)
    UI.paragraph(box, "Las contraseñas visibles son una simplificación del laboratorio SQL. Una aplicación real almacena hashes de contraseña y verifica la clave con un algoritmo adecuado; parametrizar no sustituye ese control.", 14)

func open_lab() -> void:
    if shown_mission != campaign.current:
        query_input.text = ""
        user_input.text = ""
        pass_input.text = ""
        search_input.text = ""
        predicate_input.text = ""
        report_edit.text = campaign.reports.get(str(campaign.current), "")
        patch_result.text = "Aplica tus cambios y ejecuta la batería de regresión."
        report_result.text = ""
        _refresh_tutor()
        output.text = campaign.mission().lesson
        shown_mission = campaign.current
    login_edit.text = campaign.login_patch
    document_edit.text = campaign.document_patch
    var m := campaign.current
    var available: Array = []
    for tool in ["query", "login", "search", "sensors", "patch", "report", "schema"]:
        available.append((m >= campaign.missions.size() and tool != "report") or tool == "schema" or (m < campaign.missions.size() and tool in campaign.mission().tools))
    for i in range(available.size()): tabs.set_tab_hidden(i, not available[i])
    for i in range(available.size()):
        if available[i]: tabs.current_tab = i; break
    show()
    refresh()
    match tabs.current_tab:
        0: query_input.grab_focus()
        1: user_input.grab_focus()
        2: search_input.grab_focus()
        3: predicate_input.grab_focus()
        4: login_edit.grab_focus()

func refresh() -> void:
    title.text = "Laboratorio · %02d / %02d" % [mini(campaign.current + 1, campaign.missions.size()), campaign.missions.size()]
    objective.text = campaign.mission().objective
    if campaign.current >= campaign.missions.size():
        title.text = "Laboratorio · práctica libre"
        objective.text = "Campaña completada. Experimenta con todas las herramientas, restaura los datos y sigue aprendiendo."
    var lines: PackedStringArray = []
    var keys := campaign.goals()
    for i in range(keys.size()): lines.append(("[OK]  " if campaign.evidence.has(keys[i]) else "[  ]  ") + campaign.mission().goals[i])
    checklist.text = "\n\n".join(lines)
    if campaign.current >= campaign.missions.size(): checklist.text = "Certificación conseguida. Tu progreso está a salvo; este entorno queda abierto para practicar."
    claim.disabled = not campaign.can_complete()
    var entries: PackedStringArray = []
    for entry in campaign.history:
        entries.append(("OK · " if entry.ok else "ERROR · ") + entry.kind + "\n" + entry.input + "\n" + entry.message)
    history_view.text = "\n\n".join(entries)
    history_view.scroll_to_line(maxi(0, history_view.get_line_count() - 1))

func _run(kind: String, text: String, extra: String = "") -> void:
    var result := campaign.submit(kind, text, extra)
    var rendered: String = "ENTRADA\n" + text + (" / " + extra if kind == "login" else "") + "\n\nCONSULTA CONSTRUIDA\n" + result.query
    rendered += "\n\nRESULTADO\n"
    if result.ok and not result.columns.is_empty():
        rendered += " | ".join(result.columns) + "\n"
        for row in result.rows:
            var values: PackedStringArray = []
            for col in result.columns: values.append(str(row[col]))
            rendered += " | ".join(values) + "\n"
    rendered += "\n" + result.message + _teacher_feedback(result)
    if kind == "login" and result.ok and not result.rows.is_empty():
        rendered += "\nSesión simulada: " + str(result.rows[0].usuario) + ". Se usa la primera fila, no se eleva automáticamente a administrador."
    output.text = rendered
    output.scroll_to_line(maxi(0, output.get_line_count() - 1))
    performed.emit(result.ok)
    refresh()

func _patch_changed() -> void:
    if not visible: return
    campaign.login_patch = login_edit.text
    campaign.document_patch = document_edit.text
    campaign.evidence.erase("login_fixed")
    campaign.evidence.erase("access_fixed")
    refresh()

func _test_patch() -> void:
    campaign.login_patch = login_edit.text
    campaign.document_patch = document_edit.text
    var results := campaign.test_patches()
    output.text = "REGRESIÓN · consultas con parámetros separados\n\n" + "\n".join(results)
    patch_result.text = "Resultados de las pruebas en el panel de ejecución."
    performed.emit(campaign.evidence.has("login_fixed") and campaign.evidence.has("access_fixed"))
    refresh()

func _report() -> void:
    var valid := campaign.save_report(report_edit.text)
    report_result.text = "Informe adjunto. La calidad de la explicación queda disponible para revisión docente." if valid else "Incluye Evidencia:, Causa: y Corrección: con explicaciones. Primero reproduce un hallazgo; mínimo 100 caracteres en total."
    performed.emit(valid)
    refresh()

func _hint() -> void:
    var message := campaign.hint()
    var mentor: String = campaign.mission().get("mentor", "Instructor")
    var count := int(campaign.hints.get(str(campaign.current), 0))
    hint_label.text = "%s · Pista %d de 3\n%s" % [mentor, count, message]
    hint_button.text = "Pistas completas · 3/3" if count >= 3 else "Pedir otra pista · %d/3" % count
    hint_button.disabled = count >= 3

func _refresh_tutor() -> void:
    var count := int(campaign.hints.get(str(campaign.current), 0))
    var mentor: String = campaign.mission().get("mentor", "Instructor")
    if count > 0:
        hint_label.text = "%s · Última pista · %d de 3\n%s" % [mentor, count, campaign.mission().hints[mini(count - 1, 2)]]
    else:
        hint_label.text = "%s: Vamos paso a paso. Prueba, observa el resultado y vuelve a intentar; pedir pistas no reduce tu experiencia." % mentor
    hint_button.text = "Pistas completas · 3/3" if count >= 3 else ("Pedir otra pista · %d/3" % count if count > 0 else "Pedir pista al instructor")
    hint_button.disabled = count >= 3

func _teacher_feedback(result: Dictionary) -> String:
    var mentor: String = campaign.mission().get("mentor", "Instructor")
    if campaign.current >= campaign.missions.size():
        return "\n\n%s: La campaña terminó. En práctica libre puedes seguir experimentando y explicando tus resultados." % mentor
    if not result.ok:
        return "\n\n%s: No pasa nada: un error también enseña. %s Revisa el esquema y la consulta construida; puedes cambiar una cosa por vez. Las pruebas no restan experiencia." % [mentor, _explain_error(str(result.error))]
    if campaign.can_complete():
        return "\n\n%s: ¡Reuniste toda la evidencia! Antes de entregar, comprueba que puedes explicar qué resultado confirma tu conclusión." % mentor
    var goals: Array = campaign.mission().get("goals", [])
    var criteria: Array = campaign.mission().get("criteria", [])
    for index in range(criteria.size()):
        if not campaign.evidence.has(criteria[index]):
            return "\n\n%s: La prueba se ejecutó. Compárala con el objetivo «%s»; esa es la próxima evidencia que falta. Si te atascas, pide una pista." % [mentor, goals[index]]
    return "\n\n%s: Observa el resultado y anótalo como evidencia antes de continuar." % mentor

func _explain_error(message: String) -> String:
    var lower := message.to_lower()
    if lower.contains("texto sin cerrar"):
        return "Parece que una comilla simple quedó abierta."
    if lower.contains("columna"):
        return "Parece que el nombre de una columna no coincide con el esquema."
    if lower.contains("tabla"):
        return "Comprueba el nombre de la tabla en Esquema."
    if lower.contains("se esperaba") or lower.contains("operación no disponible"):
        return "El orden de la sentencia no coincide con lo que espera este laboratorio."
    if lower.contains("parámetro"):
        return "Revisa cuántos marcadores ? hay y cuántos valores recibe cada uno."
    return "Lee el mensaje del simulador para identificar qué parte revisar."

func _reset() -> void:
    if not reset_pending or Time.get_ticks_msec() > reset_deadline:
        reset_pending = true
        reset_deadline = Time.get_ticks_msec() + 5000
        restore_button.text = "Confirmar reinicio de evidencias"
        return
    campaign.reset_lab()
    reset_pending = false
    restore_button.text = "Restaurar laboratorio"
    output.text = "Datos y evidencias de esta misión restaurados. Tu experiencia y las misiones anteriores se conservan."
    refresh()

func _process(_delta: float) -> void:
    if reset_pending and Time.get_ticks_msec() > reset_deadline:
        reset_pending = false
        restore_button.text = "Restaurar laboratorio"

func close_lab() -> void:
    hide()
    closed.emit()

func _input(event: InputEvent) -> void:
    if not visible or not event is InputEventKey or not event.pressed or event.echo: return
    if event.keycode == KEY_ESCAPE:
        close_lab()
        get_viewport().set_input_as_handled()
    if event.keycode == KEY_ENTER and event.ctrl_pressed:
        match tabs.current_tab:
            0: _run("query", query_input.text)
            1: _run("login", user_input.text, pass_input.text)
            2: _run("search", search_input.text)
            3: _run("boolean", predicate_input.text)
            4: _test_patch()
            5: _report()
        get_viewport().set_input_as_handled()
