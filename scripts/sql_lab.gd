class_name SQLLab
extends Control
## Laboratorio SQL interactivo de SQL Quest: Cyber Defense.
##
## Presenta una tabla ficticia editable, una consulta de login vulnerable y su
## versión parametrizada, ejecuta ambas en memoria y explica visualmente qué
## cambió. Se abre desde la terminal LABORATORIO SQL del mapa.

signal lab_completed
signal closed

const SimulatorScript = preload("res://scripts/sql_simulator.gd")

const CYAN := Color("48e5d4")
const LIME := Color("a5ee83")
const GOLD := Color("f9c66b")
const RED := Color("f76e80")
const TEXT := Color("edf7fb")
const MUTED := Color("8ba4b5")
const ORANGE := Color("ffb86b")
const PANEL := Color("0b1827")
const BORDER := Color("244b5a")

var engine = SimulatorScript.new()
var vulnerable := true
var seen_bypass := false
var blocked_bypass := false
var completed := false

var user_input: LineEdit
var pass_input: LineEdit
var query_view: RichTextLabel
var result_tree: Tree
var result_title: Label
var explain_view: RichTextLabel
var db_tree: Tree
var checklist: RichTextLabel
var feedback: Label
var mode_tag: Label
var vuln_btn: Button
var safe_btn: Button
var add_user_input: LineEdit
var add_pass_input: LineEdit
var add_role: OptionButton


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    visible = false
    _build_ui()
    _refresh_db()
    _refresh_query()
    _clear_result()
    _update_checklist()
    _set_mode(true)


func open_lab() -> void:
    visible = true
    _refresh_db()
    _refresh_query()
    _clear_result()
    if user_input != null:
        user_input.grab_focus()


func close_lab() -> void:
    if not visible:
        return
    visible = false
    closed.emit()


func _input(event: InputEvent) -> void:
    if not visible:
        return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        get_viewport().set_input_as_handled()
        close_lab()


func _build_ui() -> void:
    var dim := ColorRect.new()
    dim.color = Color(0.01, 0.03, 0.06, 0.88)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(dim)

    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 14)
    margin.add_theme_constant_override("margin_right", 14)
    margin.add_theme_constant_override("margin_top", 12)
    margin.add_theme_constant_override("margin_bottom", 12)
    add_child(margin)

    var main_panel := PanelContainer.new()
    main_panel.add_theme_stylebox_override("panel", _panel_style(Color("0a1522"), CYAN, 2, 10))
    margin.add_child(main_panel)

    var content_margin := MarginContainer.new()
    content_margin.add_theme_constant_override("margin_left", 14)
    content_margin.add_theme_constant_override("margin_right", 14)
    content_margin.add_theme_constant_override("margin_top", 10)
    content_margin.add_theme_constant_override("margin_bottom", 10)
    main_panel.add_child(content_margin)

    var root_box := VBoxContainer.new()
    root_box.add_theme_constant_override("separation", 7)
    content_margin.add_child(root_box)

    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 10)
    root_box.add_child(header)

    var title := Label.new()
    title.text = "LABORATORIO SQL"
    title.add_theme_font_size_override("font_size", 24)
    title.add_theme_color_override("font_color", CYAN)
    header.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "// CYBERNOVA · ENTORNO AISLADO"
    subtitle.add_theme_font_size_override("font_size", 13)
    subtitle.add_theme_color_override("font_color", MUTED)
    subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    header.add_child(subtitle)

    var header_spacer := Control.new()
    header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(header_spacer)

    var close_btn := Button.new()
    close_btn.text = "CERRAR [ESC]"
    close_btn.add_theme_font_size_override("font_size", 13)
    close_btn.pressed.connect(close_lab)
    header.add_child(close_btn)

    var intro := Label.new()
    intro.text = "Construye un login, ejecútalo contra la tabla ficticia usuarios y compara la concatenación con los parámetros. Nada sale de este juego."
    intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    intro.add_theme_font_size_override("font_size", 13)
    intro.add_theme_color_override("font_color", MUTED)
    root_box.add_child(intro)

    var body := HBoxContainer.new()
    body.add_theme_constant_override("separation", 12)
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root_box.add_child(body)
    _build_data_panel(body)
    _build_console_panel(body)

    var footer := Label.new()
    footer.text = "SIMULACIÓN LOCAL · Ninguna consulta se ejecuta contra un servidor real. Los datos ficticios se reinician al cerrar el juego."
    footer.add_theme_font_size_override("font_size", 11)
    footer.add_theme_color_override("font_color", Color("617b8c"))
    root_box.add_child(footer)


func _build_data_panel(parent: HBoxContainer) -> void:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", _panel_style(PANEL, BORDER, 1, 7))
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.size_flags_stretch_ratio = 0.78
    parent.add_child(panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 9)
    margin.add_theme_constant_override("margin_right", 9)
    margin.add_theme_constant_override("margin_top", 8)
    margin.add_theme_constant_override("margin_bottom", 8)
    panel.add_child(margin)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 5)
    margin.add_child(box)

    var title := Label.new()
    title.text = "TABLA usuarios"
    title.add_theme_font_size_override("font_size", 15)
    title.add_theme_color_override("font_color", GOLD)
    box.add_child(title)

    var hint := Label.new()
    hint.text = "Datos ficticios. Selecciona una fila para borrarla; los cambios afectan las consultas."
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.add_theme_font_size_override("font_size", 10)
    hint.add_theme_color_override("font_color", MUTED)
    box.add_child(hint)

    db_tree = Tree.new()
    db_tree.columns = 4
    db_tree.hide_root = true
    db_tree.column_titles_visible = true
    db_tree.set_column_title(0, "ID")
    db_tree.set_column_title(1, "USUARIO")
    db_tree.set_column_title(2, "CLAVE")
    db_tree.set_column_title(3, "ROL")
    db_tree.set_column_custom_minimum_width(0, 32)
    db_tree.set_column_custom_minimum_width(2, 70)
    db_tree.set_column_custom_minimum_width(3, 100)
    db_tree.set_column_expand(1, true)
    db_tree.set_column_expand(3, true)
    db_tree.scroll_horizontal_enabled = true
    db_tree.custom_minimum_size = Vector2(0, 118)
    db_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
    db_tree.add_theme_font_size_override("font_size", 12)
    db_tree.add_theme_stylebox_override("panel", _code_style(BORDER))
    db_tree.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    box.add_child(db_tree)

    var add_row := HBoxContainer.new()
    add_row.add_theme_constant_override("separation", 4)
    box.add_child(add_row)

    add_user_input = LineEdit.new()
    add_user_input.placeholder_text = "usuario"
    add_user_input.custom_minimum_size.x = 64
    add_user_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_user_input.add_theme_font_size_override("font_size", 11)
    add_user_input.text_submitted.connect(_on_add_submitted)
    add_row.add_child(add_user_input)

    add_pass_input = LineEdit.new()
    add_pass_input.placeholder_text = "clave"
    add_pass_input.custom_minimum_size.x = 64
    add_pass_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_pass_input.add_theme_font_size_override("font_size", 11)
    add_pass_input.text_submitted.connect(_on_add_submitted)
    add_row.add_child(add_pass_input)

    add_role = OptionButton.new()
    for role in ["ANALISTA", "INVESTIGADOR", "ADMIN", "LECTURA"]:
        add_role.add_item(role)
    add_role.custom_minimum_size.x = 88
    add_role.add_theme_font_size_override("font_size", 10)
    add_row.add_child(add_role)

    var add_btn := Button.new()
    add_btn.text = "+"
    add_btn.tooltip_text = "Añadir usuario ficticio"
    add_btn.custom_minimum_size.x = 30
    add_btn.add_theme_font_size_override("font_size", 14)
    add_btn.pressed.connect(_on_add_user)
    add_row.add_child(add_btn)

    feedback = Label.new()
    feedback.text = " "
    feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    feedback.add_theme_font_size_override("font_size", 10)
    feedback.add_theme_color_override("font_color", MUTED)
    feedback.custom_minimum_size.y = 24
    box.add_child(feedback)

    var actions := HBoxContainer.new()
    actions.add_theme_constant_override("separation", 4)
    box.add_child(actions)

    var delete_btn := Button.new()
    delete_btn.text = "BORRAR FILA"
    delete_btn.add_theme_font_size_override("font_size", 10)
    delete_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    delete_btn.pressed.connect(_on_delete_user)
    actions.add_child(delete_btn)

    var reset_btn := Button.new()
    reset_btn.text = "RESTAURAR"
    reset_btn.add_theme_font_size_override("font_size", 10)
    reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    reset_btn.pressed.connect(_on_reset_data)
    actions.add_child(reset_btn)

    checklist = RichTextLabel.new()
    checklist.bbcode_enabled = true
    checklist.fit_content = true
    checklist.scroll_active = false
    checklist.custom_minimum_size.y = 52
    checklist.add_theme_font_size_override("normal_font_size", 11)
    box.add_child(checklist)


func _build_console_panel(parent: HBoxContainer) -> void:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", _panel_style(PANEL, BORDER, 1, 7))
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.size_flags_stretch_ratio = 1.25
    parent.add_child(panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 9)
    margin.add_theme_constant_override("margin_right", 9)
    margin.add_theme_constant_override("margin_top", 8)
    margin.add_theme_constant_override("margin_bottom", 8)
    panel.add_child(margin)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 5)
    margin.add_child(box)

    var mode_row := HBoxContainer.new()
    mode_row.add_theme_constant_override("separation", 5)
    box.add_child(mode_row)

    var mode_label := Label.new()
    mode_label.text = "MODO:"
    mode_label.add_theme_font_size_override("font_size", 12)
    mode_label.add_theme_color_override("font_color", MUTED)
    mode_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    mode_row.add_child(mode_label)

    var mode_group := ButtonGroup.new()

    vuln_btn = Button.new()
    vuln_btn.text = "VULNERABLE"
    vuln_btn.toggle_mode = true
    vuln_btn.button_pressed = true
    vuln_btn.button_group = mode_group
    vuln_btn.add_theme_font_size_override("font_size", 12)
    vuln_btn.add_theme_stylebox_override("pressed", _button_style(RED.darkened(0.45)))
    vuln_btn.add_theme_color_override("font_pressed_color", TEXT)
    vuln_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vuln_btn.pressed.connect(_set_mode.bind(true))
    mode_row.add_child(vuln_btn)

    safe_btn = Button.new()
    safe_btn.text = "SEGURO (?)"
    safe_btn.toggle_mode = true
    safe_btn.button_group = mode_group
    safe_btn.add_theme_font_size_override("font_size", 12)
    safe_btn.add_theme_stylebox_override("pressed", _button_style(CYAN.darkened(0.55)))
    safe_btn.add_theme_color_override("font_pressed_color", TEXT)
    safe_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    safe_btn.pressed.connect(_set_mode.bind(false))
    mode_row.add_child(safe_btn)

    var inputs := HBoxContainer.new()
    inputs.add_theme_constant_override("separation", 5)
    box.add_child(inputs)

    user_input = LineEdit.new()
    user_input.placeholder_text = "usuario (prueba admin)"
    user_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    user_input.add_theme_font_size_override("font_size", 13)
    user_input.text_changed.connect(_on_input_changed)
    user_input.text_submitted.connect(_on_submit)
    inputs.add_child(user_input)

    pass_input = LineEdit.new()
    pass_input.placeholder_text = "clave"
    pass_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    pass_input.add_theme_font_size_override("font_size", 13)
    pass_input.text_changed.connect(_on_input_changed)
    pass_input.text_submitted.connect(_on_submit)
    inputs.add_child(pass_input)

    var payload_row := HBoxContainer.new()
    payload_row.add_theme_constant_override("separation", 4)
    box.add_child(payload_row)

    var payload_label := Label.new()
    payload_label.text = "ATAJOS:"
    payload_label.add_theme_font_size_override("font_size", 11)
    payload_label.add_theme_color_override("font_color", MUTED)
    payload_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    payload_row.add_child(payload_label)

    var payload_a := Button.new()
    payload_a.text = "' OR '1'='1' --"
    payload_a.tooltip_text = "Rellena una tautología clásica en el usuario"
    payload_a.add_theme_font_size_override("font_size", 10)
    payload_a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    payload_a.pressed.connect(_use_payload.bind(0))
    payload_row.add_child(payload_a)

    var payload_b := Button.new()
    payload_b.text = "admin' --"
    payload_b.tooltip_text = "Rellena un bypass por comentario"
    payload_b.add_theme_font_size_override("font_size", 10)
    payload_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    payload_b.pressed.connect(_use_payload.bind(1))
    payload_row.add_child(payload_b)

    var clear_btn := Button.new()
    clear_btn.text = "LIMPIAR"
    clear_btn.add_theme_font_size_override("font_size", 10)
    clear_btn.pressed.connect(_use_payload.bind(2))
    payload_row.add_child(clear_btn)

    var code_header := HBoxContainer.new()
    box.add_child(code_header)

    var code_label := Label.new()
    code_label.text = "CONSULTA GENERADA"
    code_label.add_theme_font_size_override("font_size", 11)
    code_label.add_theme_color_override("font_color", MUTED)
    code_header.add_child(code_label)

    var code_spacer := Control.new()
    code_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    code_header.add_child(code_spacer)

    mode_tag = Label.new()
    mode_tag.add_theme_font_size_override("font_size", 11)
    mode_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    code_header.add_child(mode_tag)

    query_view = RichTextLabel.new()
    query_view.bbcode_enabled = true
    query_view.scroll_active = true
    query_view.custom_minimum_size.y = 82
    query_view.add_theme_font_size_override("normal_font_size", 12)
    box.add_child(query_view)

    var execute_btn := Button.new()
    execute_btn.text = "▶  EJECUTAR CONSULTA"
    execute_btn.custom_minimum_size.y = 36
    execute_btn.add_theme_font_size_override("font_size", 16)
    execute_btn.add_theme_color_override("font_color", Color("06131c"))
    execute_btn.add_theme_stylebox_override("normal", _button_style(CYAN))
    execute_btn.add_theme_stylebox_override("hover", _button_style(LIME))
    execute_btn.add_theme_stylebox_override("pressed", _button_style(Color("2fb8aa")))
    execute_btn.pressed.connect(_execute)
    box.add_child(execute_btn)

    var result_header := HBoxContainer.new()
    box.add_child(result_header)

    var result_label := Label.new()
    result_label.text = "RESULTADO"
    result_label.add_theme_font_size_override("font_size", 11)
    result_label.add_theme_color_override("font_color", MUTED)
    result_header.add_child(result_label)

    var result_spacer := Control.new()
    result_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    result_header.add_child(result_spacer)

    result_title = Label.new()
    result_title.text = "—"
    result_title.add_theme_font_size_override("font_size", 11)
    result_title.add_theme_color_override("font_color", MUTED)
    result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    result_header.add_child(result_title)

    result_tree = Tree.new()
    result_tree.columns = 4
    result_tree.hide_root = true
    result_tree.column_titles_visible = true
    result_tree.set_column_title(0, "USUARIO")
    result_tree.set_column_title(1, "ROL")
    result_tree.set_column_title(2, "CLAVE")
    result_tree.set_column_title(3, "DATO PRIVADO")
    result_tree.set_column_custom_minimum_width(0, 78)
    result_tree.set_column_custom_minimum_width(1, 88)
    result_tree.set_column_custom_minimum_width(2, 80)
    result_tree.set_column_custom_minimum_width(3, 150)
    result_tree.set_column_expand(3, true)
    result_tree.scroll_horizontal_enabled = true
    result_tree.custom_minimum_size = Vector2(0, 92)
    result_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
    result_tree.add_theme_font_size_override("font_size", 11)
    result_tree.add_theme_stylebox_override("panel", _code_style(BORDER))
    result_tree.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    box.add_child(result_tree)

    explain_view = RichTextLabel.new()
    explain_view.bbcode_enabled = true
    explain_view.scroll_active = true
    explain_view.custom_minimum_size.y = 58
    explain_view.add_theme_font_size_override("normal_font_size", 11)
    box.add_child(explain_view)


func _set_mode(is_vulnerable: bool) -> void:
    vulnerable = is_vulnerable
    if vuln_btn != null:
        vuln_btn.set_pressed_no_signal(vulnerable)
        vuln_btn.text = ("● " if vulnerable else "") + "VULNERABLE"
        vuln_btn.add_theme_color_override("font_color", RED if vulnerable else MUTED)
    if safe_btn != null:
        safe_btn.set_pressed_no_signal(not vulnerable)
        safe_btn.text = ("● " if not vulnerable else "") + "SEGURO (?)"
        safe_btn.add_theme_color_override("font_color", CYAN if not vulnerable else MUTED)
    _refresh_query()
    _clear_result()


func _on_input_changed(_text: String) -> void:
    _refresh_query()
    _clear_result()


func _on_submit(_text: String) -> void:
    _execute()


func _on_add_submitted(_text: String) -> void:
    _on_add_user()


func _refresh_query() -> void:
    if query_view == null or mode_tag == null:
        return
    var user := _bb(user_input.text)
    var password := _bb(pass_input.text)
    if vulnerable:
        query_view.text = "[color=#f76e80][b]SELECT[/b][/color] * [color=#f76e80][b]FROM[/b][/color] usuarios [color=#f76e80][b]WHERE[/b][/color] usuario = '[color=#ffb86b]%s[/color]' [color=#f76e80][b]AND[/b][/color] clave = '[color=#ffb86b]%s[/color]';" % [user, password]
        query_view.add_theme_stylebox_override("normal", _code_style(RED.darkened(0.35)))
        mode_tag.text = "CONCATENACIÓN DIRECTA"
        mode_tag.add_theme_color_override("font_color", RED)
    else:
        query_view.text = "[color=#48e5d4][b]SELECT[/b][/color] * [color=#48e5d4][b]FROM[/b][/color] usuarios [color=#48e5d4][b]WHERE[/b][/color] usuario = [color=#f9c66b][b]?[/b][/color] [color=#48e5d4][b]AND[/b][/color] clave = [color=#f9c66b][b]?[/b][/color];\n[color=#7f96a8]Parámetro 1:[/color] [color=#a5ee83]\"%s\"[/color]\n[color=#7f96a8]Parámetro 2:[/color] [color=#a5ee83]\"%s\"[/color]" % [user, password]
        query_view.add_theme_stylebox_override("normal", _code_style(CYAN.darkened(0.45)))
        mode_tag.text = "PARÁMETROS SEPARADOS"
        mode_tag.add_theme_color_override("font_color", CYAN)


func _execute() -> void:
    if user_input == null:
        return
    _refresh_query()
    var report: Dictionary = engine.execute(user_input.text, pass_input.text, vulnerable)
    _render_result(report)
    if vulnerable and report.injected and not seen_bypass:
        seen_bypass = true
        _update_checklist()
    elif not vulnerable and report.blocked_attempt and seen_bypass and not blocked_bypass:
        blocked_bypass = true
        _update_checklist()
        if not completed:
            completed = true
            lab_completed.emit()
            _update_checklist()


func _render_result(report: Dictionary) -> void:
    result_tree.clear()
    var root := result_tree.create_item()
    var rows: Array = report.rows
    var injected: bool = report.injected
    var error: String = report.error

    if not error.is_empty():
        result_title.text = "ERROR DE SINTAXIS"
        result_title.add_theme_color_override("font_color", RED)
        explain_view.text = "[color=#f76e80][b]✖ La consulta no se pudo ejecutar[/b][/color]\n" + _bb(error)
        return

    var count := rows.size()
    if count == 0:
        result_title.text = "0 FILAS"
        result_title.add_theme_color_override("font_color", GOLD)
    elif injected:
        result_title.text = "⚠ %d FILAS EXPUESTAS" % count
        result_title.add_theme_color_override("font_color", RED)
    else:
        result_title.text = "%d FILA%s" % [count, "" if count == 1 else "S"]
        result_title.add_theme_color_override("font_color", LIME)

    for row in rows:
        var item := result_tree.create_item(root)
        item.set_text(0, str(row.usuario))
        item.set_text(1, str(row.rol))
        item.set_text(2, str(row.clave))
        item.set_text(3, str(row.dato))
        item.set_tooltip_text(3, str(row.dato))
        if injected:
            item.set_custom_color(0, RED)
            item.set_custom_color(2, RED)
            item.set_custom_color(3, RED)

    var lines: Array[String] = []
    if injected:
        lines.append("[color=#f76e80][b]⚠ INYECCIÓN EXITOSA[/b][/color]")
    elif report.blocked_attempt:
        lines.append("[color=#48e5d4][b]✔ ATAQUE NEUTRALIZADO[/b][/color]")
    elif count > 0:
        lines.append("[color=#a5ee83][b]✔ CONSULTA EJECUTADA[/b][/color]")
    else:
        lines.append("[color=#f9c66b][b]● SIN COINCIDENCIAS[/b][/color]")

    lines.append(_bb(str(report.message)))

    if report.kind == "tautology":
        lines.append("[color=#8ba4b5]Filtro efectivo:[/color] [color=#ffb86b]'' OR '1'='1'[/color] → siempre verdadero.")
    elif report.kind == "comment":
        lines.append("[color=#8ba4b5]El comentario -- ignoró:[/color] [color=#ffb86b]' AND clave = '...';[/color]")

    if injected and not report.session.is_empty():
        lines.append("[color=#f9c66b]Sesión iniciada como:[/color] [b]%s[/b] (%s)" % [_bb(str(report.session.usuario)), _bb(str(report.session.rol))])
    elif count > 0 and not report.session.is_empty():
        lines.append("[color=#a5ee83]Sesión iniciada como:[/color] [b]%s[/b] (%s)" % [_bb(str(report.session.usuario)), _bb(str(report.session.rol))])

    if report.blocked_attempt:
        lines.append("[color=#8ba4b5]Los parámetros no son texto SQL: son valores enlazados después de compilar la consulta.[/color]")

    explain_view.text = "\n".join(lines)


func _clear_result() -> void:
    if result_tree != null:
        result_tree.clear()
    if result_title != null:
        result_title.text = "—"
        result_title.add_theme_color_override("font_color", MUTED)
    if explain_view != null:
        explain_view.text = "[color=#8ba4b5]Ejecuta la consulta para ver las filas devueltas y la explicación.[/color]"


func _update_checklist() -> void:
    if checklist == null:
        return
    var mark_one := "[color=#a5ee83]✔[/color]" if seen_bypass else "[color=#8ba4b5]□[/color]"
    var mark_two := "[color=#a5ee83]✔[/color]" if blocked_bypass else "[color=#8ba4b5]□[/color]"
    var text := "%s 1. Provoca un bypass en modo vulnerable.\n%s 2. Bloquea el mismo ataque en modo seguro." % [mark_one, mark_two]
    if completed:
        text += "\n[color=#a5ee83][b]✔ Laboratorio completado: +150 puntos.[/b][/color]"
    checklist.text = text


func _use_payload(index: int) -> void:
    if index == 0:
        user_input.text = "' OR '1'='1' --"
        pass_input.text = "cualquiera"
    elif index == 1:
        user_input.text = "admin' --"
        pass_input.text = ""
    else:
        user_input.text = ""
        pass_input.text = ""
    _refresh_query()
    _clear_result()
    user_input.grab_focus()


func _on_add_user() -> void:
    var role := add_role.get_item_text(add_role.selected)
    var report: Dictionary = engine.add_user(add_user_input.text, add_pass_input.text, role)
    feedback.text = str(report.message)
    feedback.add_theme_color_override("font_color", LIME if report.ok else RED)
    if report.ok:
        add_user_input.text = ""
        add_pass_input.text = ""
        _refresh_db()
        _clear_result()


func _on_delete_user() -> void:
    var selected := db_tree.get_selected()
    if selected == null:
        feedback.text = "Selecciona una fila de la tabla para borrarla."
        feedback.add_theme_color_override("font_color", GOLD)
        return
    var id := int(selected.get_metadata(0))
    if engine.delete_user(id):
        feedback.text = "Fila ficticia eliminada."
        feedback.add_theme_color_override("font_color", LIME)
        _refresh_db()
        _clear_result()


func _on_reset_data() -> void:
    engine.reset_data()
    feedback.text = "Datos ficticios restaurados."
    feedback.add_theme_color_override("font_color", CYAN)
    _refresh_db()
    _clear_result()


func _refresh_db() -> void:
    if db_tree == null:
        return
    db_tree.clear()
    var root := db_tree.create_item()
    for row in engine.users:
        var item := db_tree.create_item(root)
        item.set_text(0, str(row.id))
        item.set_text(1, str(row.usuario))
        item.set_text(2, str(row.clave))
        item.set_text(3, str(row.rol))
        item.set_metadata(0, int(row.id))
        item.set_tooltip_text(0, str(row.dato))
        if str(row.rol) == "ADMIN":
            item.set_custom_color(3, RED)
        else:
            item.set_custom_color(3, GOLD)


func _bb(value: String) -> String:
    return value.replace("[", "[lb]").replace("]", "[rb]")


func _panel_style(bg: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.set_border_width_all(width)
    style.set_corner_radius_all(radius)
    style.set_content_margin_all(6)
    return style


func _code_style(border: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("06101a")
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(4)
    style.set_content_margin_all(6)
    return style


func _button_style(color: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.set_corner_radius_all(5)
    style.set_content_margin_all(6)
    return style
