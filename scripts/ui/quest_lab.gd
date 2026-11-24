class_name QuestLab
extends Control
## Four-panel SQL Injection laboratory embedded in the RPG world.

signal closed
signal performed(success: bool)
signal reward_requested
signal lesson_progress

const UI = preload("res://scripts/ui/ui_kit.gd")
const MONO = preload("res://assets/fonts/DejaVuSansMono.ttf")
const Blocks = preload("res://scripts/missions/code_blocks.gd")
const BlockButton = preload("res://scripts/ui/code_block_button.gd")
const BG := Color("0D1117")
const PANEL := Color("161B22")
const PANEL_ALT := Color("1C2430")
const GREEN := Color("39D353")
const BLUE := Color("58A6FF")
const RED := Color("FF7B72")
const AMBER := Color("D29922")
const TEXT := Color("E6EDF3")
const MUTED := Color("8B949E")

var campaign: QuestCampaign
var root_panel: PanelContainer
var grid: GridContainer
var body_scroll: ScrollContainer
var title: Label
var objective: Label
var current_objective: Label
var activity_progress: ProgressBar
var lesson: Label
var phase: Label
var primary_input: LineEdit
var secondary_input: LineEdit
var sort_input: LineEdit
var predicate_input: LineEdit
var attack_button: Button
var time_button: Button
var query_view: RichTextLabel
var result_view: RichTextLabel
var comparison_view: Label
var impact_view: Label
var patch_edit: CodeEdit
var verify_button: Button
var verification_view: RichTextLabel
var report_edit: TextEdit
var report_result: Label
var report_button: Button
var checklist: Label
var hint_label: Label
var hint_button: Button
var claim: Button
var status_label: Label
var reset_button: Button
var reset_pending := false
var reset_deadline := 0
var shown_mission := -1
var reduced_motion := false
var lab_tween: Tween
var output_tween: Tween
var cards: Array[Control] = []
var previous_button: Button
var next_button: Button
var repeat_button: Button
var normal_example_button: Button
var practice_feedback: Label
var lesson_text: RichTextLabel
var lesson_visual: RichTextLabel
var stage_tween: Tween
var tutor_message: Label
var available_blocks: VBoxContainer
var selected_blocks_box: VBoxContainer
var selected_blocks: Array = []
var selected_index := -1
var block_feedback: String = ""
const STAGES := ["APRENDER", "OBSERVAR", "PRACTICAR", "ATACAR", "DEFENDER", "VERIFICAR"]

const LESSONS := {
	"login": ["Un inicio de sesión debe permitir el acceso solo cuando coinciden usuario y contraseña. La aplicación consulta sus registros para comprobarlos.", "Una inyección SQL ocurre cuando una entrada pasa de ser un dato a formar parte de las instrucciones de la consulta. Esto puede ocurrir si la aplicación concatena el texto sin separarlo.", "Una comilla puede cerrar el dato y -- inicia un comentario SQL. Si la contraseña queda comentada, el riesgo es acceder sin autorización."],
	"search": ["CyberStore es una tienda ficticia. Su buscador debe encontrar productos públicos, nunca mostrar los secretos guardados en otra tabla.", "La tienda construye una consulta para buscar el texto que escribes. Si pega ese texto dentro de las instrucciones, una entrada manipulada puede cambiar lo que la consulta solicita.", "UNION une resultados compatibles de dos consultas. Un atacante podría añadir filas de otra tabla; el riesgo es exponer información que no pertenece al catálogo."],
	"order": ["Una lista de proyectos permite elegir por qué columna se ordenan los resultados, por ejemplo nombre o presupuesto.", "Si la aplicación pega esa elección directamente en ORDER BY, la entrada puede convertirse en una expresión SQL en lugar de un nombre de columna.", "Una condición CASE WHEN puede cambiar el orden según un dato. Un atacante podría comparar los órdenes e inferir información privada."],
	"blind": ["Una aplicación puede responder de manera distinta sin mostrar ningún dato privado. Es como una puerta que solo responde sí o no.", "Si una entrada modifica la condición de una consulta, una diferencia de respuesta puede revelar si la condición es verdadera.", "Este laboratorio muestra señales y tiempos virtuales: no espera realmente ni consulta servidores. El riesgo es inferir información poco a poco."],
	"final": ["NullSec reta a CyberAcademy en una competición autorizada. Investigarás sistemas ficticios, no aplicaciones reales.", "Un login vulnerable puede dejar entrar; un buscador puede añadir filas de otra tabla; un ordenamiento inseguro puede aceptar expresiones.", "Reproduce las tres señales, usa parámetros para valores y una lista blanca para columnas; después escribe un reporte con evidencia y corrección."]
}

func _ready() -> void:
	theme = UI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var preferences := ConfigFile.new()
	if preferences.load("user://settings.cfg") == OK:
		reduced_motion = bool(preferences.get_value("display", "reduce_motion", false))
	_build_ui()
	hide()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 18)
	add_child(margin)
	root_panel = PanelContainer.new()
	root_panel.add_theme_stylebox_override("panel", UI.style(PANEL, Color("30363D"), 1))
	margin.add_child(root_panel)
	var content_margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]: content_margin.add_theme_constant_override("margin_" + edge, 16)
	root_panel.add_child(content_margin)
	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 10)
	content_margin.add_child(main)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	main.add_child(header)
	title = UI.label(header, "LABORATORIO SQL INJECTION", 26, GREEN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phase = UI.label(header, "ATAQUE AUTORIZADO", 14, RED)
	phase.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UI.button(header, "Volver al mundo · Esc", close_lab)
	objective = UI.paragraph(main, "", 17)
	objective.add_theme_color_override("font_color", TEXT)
	current_objective = UI.paragraph(main, "", 16)
	current_objective.add_theme_color_override("font_color", GREEN)
	activity_progress = ProgressBar.new()
	activity_progress.min_value = 0
	activity_progress.max_value = 5
	activity_progress.show_percentage = false
	activity_progress.custom_minimum_size.y = 8
	main.add_child(activity_progress)
	lesson = UI.paragraph(main, "", 15)
	lesson.add_theme_color_override("font_color", MUTED)
	var tutor_row := HBoxContainer.new()
	tutor_row.add_theme_constant_override("separation", 12)
	main.add_child(tutor_row)
	var portrait := TextureRect.new()
	portrait.texture = preload("res://assets/portraits/professor_byte.png")
	portrait.custom_minimum_size = Vector2(64, 64)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tutor_row.add_child(portrait)
	tutor_message = UI.paragraph(tutor_row, "Byte: investiguemos juntos.", 16)
	tutor_message.add_theme_color_override("font_color", BLUE)
	lesson_text = RichTextLabel.new()
	lesson_text.bbcode_enabled = true
	lesson_text.fit_content = true
	lesson_text.add_theme_font_size_override("normal_font_size", 18)
	main.add_child(lesson_text)
	lesson_visual = RichTextLabel.new()
	lesson_visual.bbcode_enabled = true
	lesson_visual.fit_content = true
	lesson_visual.add_theme_font_size_override("normal_font_size", 16)
	main.add_child(lesson_visual)
	normal_example_button = UI.button(main, "Probar entrada normal de ejemplo", _try_normal_example)
	practice_feedback = UI.paragraph(main, "", 16)
	practice_feedback.add_theme_color_override("font_color", AMBER)
	practice_feedback.visible = false

	body_scroll = ScrollContainer.new()
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(body_scroll)
	grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_scroll.add_child(grid)
	_build_attack_panel()
	_build_query_panel()
	_build_result_panel()
	_build_defense_panel()

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	main.add_child(footer)
	previous_button = UI.button(footer, "Anterior", _previous_step)
	repeat_button = UI.button(footer, "Repetir", _repeat_step)
	next_button = UI.button(footer, "Continuar", _next_step)
	status_label = UI.label(footer, "SIMULACIÓN LOCAL · sin red, servidor ni procesos externos", 13, MUTED)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_label = UI.label(footer, "", 13, AMBER)
	hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_button = UI.button(footer, "Pedir pista", _hint)
	claim = UI.button(footer, "Entregar misión", func(): reward_requested.emit())
	claim.disabled = true
	body_scroll.resized.connect(_layout_responsive)
	get_viewport().size_changed.connect(_layout_responsive)

func _card(heading: String, accent: Color, minimum_height := 250) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.style(PANEL_ALT, accent.darkened(0.45), 1))
	panel.custom_minimum_size = Vector2(0, minimum_height)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(panel)
	cards.append(panel)
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 14)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	UI.label(box, heading, 18, accent)
	return box

func _build_attack_panel() -> void:
	var box := _card("A · SIMULACIÓN DEL ATAQUE", RED, 270)
	var intro := UI.paragraph(box, "Introduce datos sintéticos y observa cómo la aplicación vulnerable construye SQL.", 15)
	intro.add_theme_color_override("font_color", TEXT)
	primary_input = LineEdit.new()
	primary_input.custom_minimum_size.y = 38
	primary_input.add_theme_font_size_override("font_size", 16)
	box.add_child(primary_input)
	secondary_input = LineEdit.new()
	secondary_input.custom_minimum_size.y = 38
	secondary_input.add_theme_font_size_override("font_size", 16)
	box.add_child(secondary_input)
	sort_input = LineEdit.new()
	sort_input.custom_minimum_size.y = 38
	sort_input.add_theme_font_size_override("font_size", 16)
	sort_input.visible = false
	box.add_child(sort_input)
	predicate_input = LineEdit.new()
	predicate_input.custom_minimum_size.y = 38
	predicate_input.add_theme_font_size_override("font_size", 16)
	predicate_input.visible = false
	box.add_child(predicate_input)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)
	attack_button = UI.button(actions, "Ejecutar demostración", _run_attack)
	attack_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_button = UI.button(actions, "Medir tiempo", func(): _run_blind("time"))
	time_button.visible = false
	time_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _build_query_panel() -> void:
	var box := _card("B · CONSULTA CONSTRUIDA", BLUE, 270)
	UI.paragraph(box, "La entrada manipulada se resalta para mostrar qué fragmento dejó de ser dato y pasó a actuar como SQL.", 15)
	query_view = RichTextLabel.new()
	query_view.bbcode_enabled = true
	query_view.fit_content = false
	query_view.scroll_active = true
	query_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	query_view.custom_minimum_size.y = 160
	query_view.add_theme_font_override("normal_font", MONO)
	query_view.add_theme_font_size_override("normal_font_size", 15)
	query_view.add_theme_stylebox_override("normal", UI.style(Color("0D1117"), Color("30363D"), 1))
	box.add_child(query_view)

func _build_result_panel() -> void:
	var box := _card("C · RESULTADOS E IMPACTO", AMBER, 270)
	result_view = RichTextLabel.new()
	result_view.bbcode_enabled = false
	result_view.scroll_active = true
	result_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	result_view.custom_minimum_size.y = 120
	result_view.add_theme_font_override("normal_font", MONO)
	result_view.add_theme_font_size_override("normal_font_size", 15)
	result_view.add_theme_stylebox_override("normal", UI.style(Color("0D1117"), Color("30363D"), 1))
	box.add_child(result_view)
	comparison_view = UI.paragraph(box, "", 15)
	impact_view = UI.paragraph(box, "Esperando una prueba autorizada…", 15)
	impact_view.add_theme_color_override("font_color", MUTED)

func _build_defense_panel() -> void:
	var box := _card("D · EL ARREGLO Y LA REGRESIÓN", GREEN, 300)
	UI.paragraph(box, "Elige bloques, arrástralos o pulsa para añadirlos. Selecciona un bloque colocado para moverlo o retirarlo.", 15)
	UI.label(box, "BLOQUES DISPONIBLES", 15, BLUE)
	available_blocks = VBoxContainer.new()
	box.add_child(available_blocks)
	UI.label(box, "TU SOLUCIÓN", 15, GREEN)
	selected_blocks_box = VBoxContainer.new()
	box.add_child(selected_blocks_box)
	var controls := HBoxContainer.new()
	box.add_child(controls)
	UI.button(controls, "Subir", func(): _move_selected(-1))
	UI.button(controls, "Bajar", func(): _move_selected(1))
	UI.button(controls, "Quitar", _remove_selected)
	patch_edit = UI.editor(box, 110)
	patch_edit.add_theme_font_size_override("font_size", 15)
	patch_edit.editable = false
	verify_button = UI.button(box, "Aplicar parche y ejecutar pruebas", _test_patch)
	verification_view = RichTextLabel.new()
	verification_view.bbcode_enabled = false
	verification_view.custom_minimum_size.y = 78
	verification_view.add_theme_font_override("normal_font", MONO)
	verification_view.add_theme_font_size_override("normal_font_size", 14)
	box.add_child(verification_view)
	UI.label(box, "EVIDENCIAS DE MISIÓN", 14, AMBER)
	checklist = UI.paragraph(box, "", 14)
	report_edit = TextEdit.new()
	report_edit.custom_minimum_size.y = 100
	report_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	report_edit.placeholder_text = "Evidencia: ...\nCausa: ...\nCorrección: ..."
	report_edit.add_theme_font_size_override("font_size", 15)
	report_edit.visible = false
	box.add_child(report_edit)
	report_button = UI.button(box, "Guardar reporte de certificación", _save_report)
	report_button.visible = false
	report_result = UI.paragraph(box, "", 14)
	reset_button = UI.button(box, "Restaurar escenario", _reset)

func _layout_responsive() -> void:
	if grid == null: return
	grid.columns = 1 if DisplayServer.is_touchscreen_available() or get_viewport_rect().size.x < 1040.0 else 2

func open_lab() -> void:
	if campaign == null: return
	_setup_mission()
	show()
	_layout_responsive()
	root_panel.pivot_offset = root_panel.size * 0.5
	if lab_tween and lab_tween.is_running(): lab_tween.kill()
	root_panel.modulate.a = 0.0
	root_panel.scale = Vector2(0.985, 0.985)
	lab_tween = create_tween()
	lab_tween.set_parallel()
	lab_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lab_tween.tween_property(root_panel, "modulate:a", 1.0, 0.2 if not reduced_motion else 0.0)
	lab_tween.tween_property(root_panel, "scale", Vector2.ONE, 0.22 if not reduced_motion else 0.0)
	primary_input.grab_focus()

func _setup_mission() -> void:
	practice_feedback.text = ""
	practice_feedback.visible = false
	var data := campaign.mission()
	var kind: String = data.get("kind", "login")
	shown_mission = campaign.current
	title.text = "LABORATORIO %02d / 05 · %s" % [campaign.current + 1, data.get("title", "SQL Injection")]
	objective.text = data.get("objective", "")
	lesson.text = data.get("lesson", "")
	phase.text = "FASE A · ATAQUE AUTORIZADO"
	primary_input.visible = kind in ["login", "search", "final"]
	secondary_input.visible = kind in ["login", "final"]
	sort_input.visible = kind in ["order", "final"]
	predicate_input.visible = kind == "blind"
	primary_input.placeholder_text = "Usuario" if kind == "login" else "Término de búsqueda / usuario"
	secondary_input.placeholder_text = "Contraseña" if kind == "login" else "Término de búsqueda UNION"
	sort_input.placeholder_text = "sort_by / expresión CASE WHEN"
	predicate_input.placeholder_text = "Condición blind, por ejemplo contenido LIKE 'AURORA%'"
	attack_button.text = {"login": "Probar inicio de sesión", "search": "Buscar en CyberStore", "order": "Probar orden", "blind": "Comprobar respuesta", "final": "Probar los tres sistemas"}[kind]
	time_button.visible = kind == "blind"
	if kind == "blind": attack_button.text = "Medir respuesta booleana"
	patch_edit.text = campaign.patch_text
	patch_edit.editable = false
	selected_blocks = campaign.lesson_state().get("blocks", []).duplicate()
	selected_index = -1
	_render_blocks()
	report_edit.visible = kind == "final"
	report_button.visible = kind == "final"
	report_edit.text = str(campaign.reports.get(str(campaign.current), "")) if kind == "final" else ""
	report_result.text = ""
	verification_view.text = "Aún no hay regresión."
	query_view.text = "[color=#8B949E]Esperando la consulta construida…[/color]"
	result_view.text = "Esperando la salida del laboratorio…"
	comparison_view.text = ""
	impact_view.text = "La alerta y su explicación aparecerán después de ejecutar la prueba."
	_set_defaults(kind)
	_refresh_tutor()
	_show_stage()
	_update_comparison()
	refresh()

func _set_defaults(kind: String) -> void:
	primary_input.text = ""
	secondary_input.text = ""
	sort_input.text = ""
	predicate_input.text = ""

func _show_stage() -> void:
	var state := campaign.lesson_state()
	var stage := int(state.stage)
	var step := int(state.step)
	var kind := str(campaign.mission().kind)
	tutor_message.text = "Byte: " + ["Te explicaré una idea a la vez.", "Observa la parte resaltada; puedes repetirla.", "Practiquemos juntos; equivocarse no cuesta vidas.", "Ahora inténtalo tú. Pide una pista si la necesitas.", _defense_explanation(kind), "Construye el arreglo con bloques; pulsar o arrastrar son equivalentes."][mini(stage, 5)]
	phase.text = STAGES[mini(stage, STAGES.size() - 1)]
	objective.text = " > ".join(STAGES)
	activity_progress.value = stage
	current_objective.text = "OBJETIVO ACTUAL: " + _next_action(kind, state)
	lesson.text = "Profesor Byte · " + str(campaign.mission().title)
	for card in cards: card.visible = false
	previous_button.visible = stage <= 1 and step > 0
	repeat_button.visible = true
	next_button.visible = stage <= 1 or (stage == 2 and bool(state.guided)) or (stage == 3 and bool(state.get("independent_done", false))) or stage == 4
	hint_button.visible = stage >= 2
	claim.visible = stage == 5
	normal_example_button.visible = stage == 2 and not bool(state.normal)
	for button in [next_button, normal_example_button, attack_button, verify_button, claim]:
		button.remove_theme_stylebox_override("normal")
	var suggested: Button
	if stage <= 1 or stage == 4 or (stage == 2 and state.guided) or (stage == 3 and state.get("independent_done", false)):
		suggested = next_button
	elif stage == 2 and not state.normal:
		suggested = normal_example_button
	elif stage == 2 or stage == 3:
		suggested = attack_button
	elif stage == 5 and not campaign.evidence.has("defense"):
		suggested = verify_button
	if suggested != null:
		suggested.add_theme_stylebox_override("normal", UI.style(Color("24463B"), GREEN, 2))
	lesson_visual.text = ""
	match stage:
		0:
			lesson_text.text = "[color=#58A6FF]BYTE · APRENDER[/color]\n" + str(LESSONS[kind][mini(step, 2)])
			lesson_visual.text = "[color=#39D353]DATOS[/color]  >  aplicación  >  [color=#58A6FF]INSTRUCCIÓN SQL[/color]"
		1:
			lesson_text.text = "[color=#58A6FF]BYTE · OBSERVAR[/color]\n" + _demo_explanation(kind, step)
			lesson_visual.text = _demo_visual(kind, step)
		2:
			cards[0].visible = true
			cards[1].visible = true
			cards[2].visible = true
			lesson_text.text = "[color=#58A6FF]BYTE · PRÁCTICA GUIADA[/color]\n" + ("Primero comprobaremos cómo responde la aplicación a datos normales." if not state.normal else ("Ahora introduciremos una entrada manipulada en el laboratorio ficticio." if not state.guided else "Compara el resultado normal con el manipulado en el panel C."))
			if state.normal and not state.guided: lesson_visual.text = "Ejemplo guiado: " + _guided_example(kind)
		3:
			cards[0].visible = true
			cards[1].visible = true
			cards[2].visible = true
			lesson_text.text = "[color=#FF7B72]MISIÓN INDEPENDIENTE[/color]\n" + ("La prueba demuestra el riesgo en el laboratorio. Lee el resultado en el panel C antes de continuar." if state.get("independent_done", false) else "Prueba si recuerdas cómo cambiar la consulta. Puedes solicitar pistas sin perder vidas.")
		4:
			lesson_text.text = "[color=#39D353]BYTE · DEFENDER[/color]\n" + _defense_explanation(kind)
			lesson_visual.text = "[color=#58A6FF]ESTRUCTURA SQL[/color]   |   [color=#39D353]VALORES SEPARADOS[/color]"
		5:
			cards[3].visible = true
			lesson_text.text = "[color=#39D353]VERIFICAR[/color]\nOrganiza los bloques y ejecuta las pruebas con datos ficticios. No se ejecuta Python."
	if stage_tween and stage_tween.is_running(): stage_tween.kill()
	lesson_visual.visible_characters = 0
	stage_tween = create_tween()
	stage_tween.tween_property(lesson_visual, "visible_characters", lesson_visual.get_total_character_count(), 0.35 if not reduced_motion else 0.0)
	campaign.save_lesson()
	lesson_progress.emit()

func _next_action(kind: String, state: Dictionary) -> String:
	var stage := int(state.stage)
	if stage <= 1: return "Lee la explicación y pulsa Continuar."
	if stage == 2:
		if not state.normal: return "Pulsa 'Probar entrada normal de ejemplo'. " + _normal_example(kind)
		if not state.guided: return "Escribe el ejemplo guiado en el formulario y pulsa '" + attack_button.text + "'."
		return "Compara las dos pruebas en el panel C y pulsa Continuar."
	if stage == 3: return "Lee el resultado del panel C y pulsa Continuar para aprender la defensa." if state.get("independent_done", false) else "Escribe una entrada que cambie la consulta y pulsa '" + attack_button.text + "'; usa Pedir pista si lo necesitas."
	if stage == 4: return "Lee cómo separar datos e instrucciones y pulsa Continuar."
	if not campaign.evidence.has("defense"): return "Pulsa los bloques para construir la defensa y después pulsa 'Aplicar parche y ejecutar pruebas'."
	if kind == "final" and not campaign.evidence.has("report"): return "Completa el reporte con evidencia, causa y corrección, y pulsa Guardar reporte."
	return "Las pruebas pasaron. Pulsa Entregar misión para desbloquear la siguiente."

func _render_blocks() -> void:
	if available_blocks == null or campaign == null: return
	for child in available_blocks.get_children(): child.queue_free()
	for child in selected_blocks_box.get_children(): child.queue_free()
	var kind := str(campaign.mission().kind)
	for id in Blocks.available(kind):
		if id in selected_blocks: continue
		var button = BlockButton.new()
		button.block_id = id
		button.source = "available"
		button.text = Blocks.PIECES[id]
		button.add_theme_font_override("font", MONO)
		button.add_theme_font_size_override("font_size", 13)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_add_block.bind(id))
		button.on_drop = _drop_block
		available_blocks.add_child(button)
	for i in range(selected_blocks.size()):
		var id: String = selected_blocks[i]
		var button = BlockButton.new()
		button.block_id = id
		button.source = "selected"
		button.text = ("> " if i == selected_index else "   ") + Blocks.PIECES[id]
		button.add_theme_font_override("font", MONO)
		button.add_theme_font_size_override("font_size", 13)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_select_block.bind(i))
		button.on_drop = _drop_block
		selected_blocks_box.add_child(button)
	var lines := PackedStringArray()
	for id in selected_blocks: lines.append(Blocks.PIECES[id])
	patch_edit.text = "\n".join(lines)
	campaign.lesson_state()["blocks"] = selected_blocks.duplicate()

func _add_block(id: String) -> void:
	if id in selected_blocks: return
	_invalidate_defense()
	selected_blocks.append(id)
	selected_index = selected_blocks.size() - 1
	tutor_message.text = "Byte: " + ("Ese bloque incorpora entrada sin validar; observa si es apropiado." if id.begins_with("unsafe_") else "Bloque añadido. Comprueba qué necesita antes de ejecutarse.")
	_render_blocks()
	refresh()
	lesson_progress.emit()

func _select_block(index: int) -> void:
	selected_index = index
	_render_blocks()

func _move_selected(direction: int) -> void:
	var target := selected_index + direction
	if selected_index < 0 or target < 0 or target >= selected_blocks.size(): return
	_invalidate_defense()
	var item = selected_blocks.pop_at(selected_index)
	selected_blocks.insert(target, item)
	selected_index = target
	_render_blocks()
	refresh()
	lesson_progress.emit()

func _remove_selected() -> void:
	if selected_index < 0 or selected_index >= selected_blocks.size(): return
	_invalidate_defense()
	selected_blocks.remove_at(selected_index)
	selected_index = -1
	_render_blocks()
	refresh()
	lesson_progress.emit()

func _drop_block(data: Dictionary, target_id: String) -> void:
	var id := str(data.get("block_id", ""))
	if data.get("source") == "available": _add_block(id)
	var from := selected_blocks.find(id)
	var target := selected_blocks.find(target_id)
	if from < 0 or target < 0 or from == target: return
	_invalidate_defense()
	selected_blocks.remove_at(from)
	selected_blocks.insert(target, id)
	selected_index = target
	_render_blocks()
	refresh()
	lesson_progress.emit()

func _normal_example(kind: String) -> String:
	return {"login": "Prueba usuario visitante y contraseña visitante.", "search": "Busca Terminal.", "order": "Ordena por name.", "blind": "Prueba id = 1.", "final": "Prueba visitante, Terminal y name en los tres campos."}[kind]

func _try_normal_example() -> void:
	if int(campaign.lesson_state().stage) != 2 or campaign.lesson_state().normal: return
	match str(campaign.mission().kind):
		"login":
			primary_input.text = "visitante"
			secondary_input.text = "visitante"
		"search": primary_input.text = "Terminal"
		"order": sort_input.text = "name"
		"blind": predicate_input.text = "id = 1"
		"final":
			primary_input.text = "visitante"
			secondary_input.text = "Terminal"
			sort_input.text = "name"
	_run_attack()

func _demo_explanation(kind: String, step: int) -> String:
	if kind == "login":
		return ["Una entrada normal permanece entre comillas y la contraseña sigue siendo necesaria.", "La comilla simple cierra el valor de usuario antes de lo previsto.", "Los guiones -- inician un comentario: la condición de contraseña queda comentada."][mini(step, 2)]
	if kind == "search":
		return ["En CyberStore, buscar Terminal solo debería devolver productos del catálogo público. Abajo verás un ejemplo del resultado normal.", "UNION une dos conjuntos de resultados si tienen columnas compatibles. Aquí el catálogo tiene tres columnas: identificador, nombre y precio.", "Si se concatena el texto, una comilla cierra el término y UNION puede agregar filas del vault ficticio. Esto expone información ajena al catálogo."][mini(step, 2)]
	return ["Observa cómo se incorpora una entrada normal a la consulta.", "Ahora una entrada manipulada modifica la estructura que controla la aplicación.", str(LESSONS[kind][2])][mini(step, 2)]

func _demo_visual(kind: String, step: int) -> String:
	if kind == "login":
		return ["SELECT ... usuario = '[color=#39D353]admin[/color]' AND clave = '...'", "SELECT ... usuario = 'admin[color=#FF7B72]'[/color] ...", "SELECT ... usuario = 'admin' [color=#FF7B72]-- AND clave = '...'[/color]  (comentado)"][mini(step, 2)]
	if kind == "search":
		return ["Búsqueda normal: Terminal > producto público: Terminal segura", "[color=#58A6FF]CATÁLOGO: id | nombre | precio[/color]  +  [color=#FF7B72]OTRA TABLA: id | secreto | 0[/color]  >  resultados combinados", "WHERE name LIKE '%[color=#FF7B72]' UNION SELECT id, secret, 0 FROM vault --[/color]%'\nLa entrada cierra el texto y añade datos sintéticos; -- comenta el sufijo."][mini(step, 2)]
	return ["[color=#58A6FF]consulta[/color] + [color=#39D353]dato normal[/color]", "[color=#58A6FF]consulta[/color] + [color=#FF7B72]entrada manipulada[/color]", _guided_example(kind)][mini(step, 2)]

func _guided_example(kind: String) -> String:
	return {"login": "usuario: admin' --   contraseña: x", "search": "' UNION SELECT id, secret, 0 FROM vault --", "order": "CASE WHEN budget > 0 THEN name END", "blind": "contenido LIKE 'AURORA%'", "final": "login: admin' -- · búsqueda: ' UNION SELECT id, secret, 0 FROM vault -- · orden: CASE WHEN budget > 0 THEN name END"}[kind]

func _defense_explanation(kind: String) -> String:
	if kind == "order": return "Los nombres de columna no son valores: el servidor debe elegirlos desde una lista blanca de constantes."
	if kind == "search": return "Envía el término como parámetro. Los comodines % pertenecen al valor, no al texto SQL."
	if kind == "blind": return "Separa los valores mediante parámetros y comprueba que el propietario esté autorizado."
	if kind == "final": return "Combina parámetros para valores y una lista blanca para columnas; documenta las evidencias."
	return "No pegues usuario ni contraseña en SQL. Los marcadores reservan posiciones y los valores se envían por separado. En sistemas reales verifica hashes de contraseña."

func _next_step() -> void:
	var state := campaign.lesson_state()
	if int(state.stage) <= 1 and int(state.step) < 2:
		state.step += 1
	elif int(state.stage) == 2 and not state.guided:
		return
	elif int(state.stage) == 3 and not state.get("independent_done", false):
		return
	else:
		if int(state.stage) == 2:
			state.compared = true
			_set_defaults(str(campaign.mission().kind))
		state.stage = mini(int(state.stage) + 1, 5)
		state.step = 0
	_show_stage()
	refresh()

func _previous_step() -> void:
	var state := campaign.lesson_state()
	state.step = maxi(0, int(state.step) - 1)
	_show_stage()

func _repeat_step() -> void:
	_show_stage()

func _run_attack() -> void:
	var kind: String = campaign.mission().get("kind", "login")
	var state := campaign.lesson_state()
	if int(state.stage) not in [2, 3]: return
	campaign.guided_mode = int(state.stage) == 2
	var result: Dictionary
	if kind == "final": result = campaign.submit_final(primary_input.text, secondary_input.text, sort_input.text)
	elif kind == "order": result = campaign.submit(kind, sort_input.text)
	elif kind == "blind": result = campaign.submit(kind, predicate_input.text, "boolean")
	else: result = campaign.submit(kind, primary_input.text, secondary_input.text)
	campaign.guided_mode = false
	_render_result(result)
	_advance_practice(result)
	performed.emit(result.get("attack", false))
	refresh()

func _run_blind(mode: String) -> void:
	var state := campaign.lesson_state()
	if int(state.stage) not in [2, 3]: return
	campaign.guided_mode = int(state.stage) == 2
	var result := campaign.submit("blind", predicate_input.text, mode)
	campaign.guided_mode = false
	_render_result(result)
	_advance_practice(result)
	performed.emit(result.get("attack", false))
	refresh()

func _advance_practice(result: Dictionary) -> void:
	var state := campaign.lesson_state()
	if int(state.stage) == 2:
		if not state.normal:
			var kind := str(campaign.mission().kind)
			var has_input := not str(result.get("input", "")).strip_edges().is_empty()
			if kind == "final": has_input = not primary_input.text.strip_edges().is_empty() and not secondary_input.text.strip_edges().is_empty() and not sort_input.text.strip_edges().is_empty()
			var legitimate := bool(result.get("ok", false))
			if kind in ["login", "search"]: legitimate = legitimate and not result.get("rows", []).is_empty()
			if kind == "final": legitimate = has_input
			if has_input and legitimate and not result.get("attack", false):
				state.normal = true
				state["normal_summary"] = _result_summary(result)
				practice_feedback.text = "Prueba normal completada. Ahora sigue el paso 2."
			else:
				practice_feedback.text = "Todavía estás en el paso 1. Pulsa «Probar entrada normal de ejemplo» arriba; después podrás probar el ataque."
			practice_feedback.visible = true
		elif result.get("attack", false):
			state.guided = true
			state["attack_summary"] = _result_summary(result)
			practice_feedback.text = "Ataque observado. Compara la consulta y pulsa Continuar."
			practice_feedback.visible = true
		else:
			impact_view.text += "\nAún no se ha observado el cambio; prueba el ejemplo guiado."
			practice_feedback.text = "Revisa el ejemplo del paso 2. " + ("En login, escribe admin' -- sin añadir una comilla al final." if campaign.mission().kind == "login" else "Comprueba que lo hayas copiado completo.")
			practice_feedback.visible = true
	elif int(state.stage) == 3 and result.get("attack", false):
		state["independent_done"] = true
		practice_feedback.text = "Prueba completada. Lee el resultado y pulsa Continuar para ver cómo proteger la aplicación."
		practice_feedback.visible = true
	_show_stage()
	_update_comparison()

func _result_summary(result: Dictionary) -> String:
	var rows: Array = result.get("rows", [])
	var parts := PackedStringArray()
	for row in rows:
		var values := PackedStringArray()
		for column in result.get("columns", []): values.append(str(row.get(column, "")))
		parts.append(" | ".join(values))
	if parts.is_empty(): return str(result.get("message", "Sin filas visibles"))
	return " ; ".join(parts)

func _update_comparison() -> void:
	var state := campaign.lesson_state()
	var normal := str(state.get("normal_summary", ""))
	var attack := str(state.get("attack_summary", ""))
	comparison_view.text = ""
	if not normal.is_empty(): comparison_view.text = "PRUEBA NORMAL: " + normal
	if not attack.is_empty(): comparison_view.text += "\nPRUEBA MANIPULADA: " + attack

func _render_result(result: Dictionary) -> void:
	var query: String = str(result.get("query", ""))
	var highlight: String = str(result.get("highlight", ""))
	query_view.text = _highlight_query(query, highlight)
	var lines := PackedStringArray()
	lines.append("ENTRADA PROCESADA")
	lines.append(str(result.get("input", "(entrada no disponible)")))
	lines.append("\nRESULTADO")
	var rows: Array = result.get("rows", [])
	var columns: Array = result.get("columns", [])
	if rows.is_empty(): lines.append("(sin filas visibles · el laboratorio puede ocultar datos)")
	else:
		lines.append(" | ".join(columns))
		for row in rows:
			var values := PackedStringArray()
			for column in columns: values.append(str(row.get(column, "")))
			lines.append(" | ".join(values))
	result_view.text = "\n".join(lines)
	impact_view.text = str(result.get("message", result.get("error", "")))
	if output_tween and output_tween.is_running(): output_tween.kill()
	result_view.visible_characters = 0
	if reduced_motion:
		result_view.visible_characters = -1
	else:
		output_tween = create_tween()
		output_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		output_tween.tween_property(result_view, "visible_characters", result_view.get_total_character_count(), 0.28)

func _highlight_query(query: String, fragment: String) -> String:
	var safe_query := _escape_bbcode(query)
	if fragment.is_empty(): return safe_query
	var safe_fragment := _escape_bbcode(fragment)
	if not safe_query.contains(safe_fragment): return safe_query
	var index := safe_query.find(safe_fragment)
	return safe_query.substr(0, index) + "[bgcolor=#4b2424][color=#FF7B72]" + safe_fragment + "[/color][/bgcolor]" + safe_query.substr(index + safe_fragment.length())

func _escape_bbcode(value: String) -> String:
	return value.replace("[", "[lb]")

func _invalidate_defense() -> void:
	if campaign.evidence.erase("defense"):
		verification_view.text = "La solución cambió. Ejecuta nuevamente las pruebas."

func _test_patch() -> void:
	if int(campaign.lesson_state().stage) != 5: return
	campaign.evidence.erase("defense")
	var result: Dictionary = Blocks.evaluate(str(campaign.mission().kind), selected_blocks, campaign.db)
	verification_view.text = str(result.message)
	tutor_message.text = "Byte: " + ("¡Excelente! La estructura y los datos permanecen separados. " if result.ok else "Aún falta algo. ") + str(result.message)
	if result.ok:
		campaign.patch_text = patch_edit.text
		campaign.mark("defense")
	performed.emit(campaign.evidence.has("defense"))
	_refresh_tutor()
	refresh()

func _save_report() -> void:
	var valid := campaign.save_report(report_edit.text)
	report_result.text = "Reporte adjunto: evidencia, causa y corrección registradas." if valid else "Completa Evidencia:, Causa: y Corrección: con al menos 100 caracteres y una evidencia reproducida."
	performed.emit(valid)
	refresh()

func refresh() -> void:
	if campaign == null or claim == null: return
	if int(campaign.lesson_state().stage) == 5:
		phase.text = "PRUEBAS SUPERADAS" if campaign.evidence.has("defense") else "VERIFICAR DEFENSA"
	var lines := PackedStringArray()
	var mission_goals: Array = campaign.mission().get("goals", [])
	var criteria: Array = campaign.goals()
	for i in range(criteria.size()): lines.append(("[OK]  " if campaign.evidence.has(criteria[i]) else "[  ]  ") + str(mission_goals[i]))
	checklist.text = "\n".join(lines)
	claim.disabled = not campaign.can_complete()
	current_objective.text = "OBJETIVO ACTUAL: " + _next_action(str(campaign.mission().kind), campaign.lesson_state())
	status_label.text = "EVIDENCIAS %d/%d · XP %d · ENTORNO AISLADO" % [campaign.evidence.size(), criteria.size(), campaign.xp]

func _hint() -> void:
	var count := int(campaign.hints.get(str(campaign.current), 0))
	var hints: Array = campaign.mission().hints
	var state := campaign.lesson_state()
	if int(state.stage) == 2:
		if not state.normal: hints = [_normal_example(str(campaign.mission().kind)), "Puedes pulsar el botón 'Probar entrada normal de ejemplo'.", "Después mira el resultado en el panel C."]
		elif not state.guided: hints = ["Copia el ejemplo guiado que aparece debajo de la explicación.", "Escríbelo en el formulario del panel A y pulsa el botón de prueba.", "Ejemplo para esta misión: " + _guided_example(str(campaign.mission().kind))]
		else: hints = ["Compara las dos pruebas en el panel C.", "Busca qué dato cambió y pulsa Continuar.", "La segunda entrada altera una parte de la consulta original."]
	elif int(state.stage) == 5:
		hints = ["Pulsa un bloque para añadirlo a tu solución.", _defense_explanation(str(campaign.mission().kind)), "Retira los bloques que concatenen entrada y ejecuta las pruebas."]
	if campaign.mission().kind == "login" and int(campaign.lesson_state().stage) == 3:
		hints = ["Recuerda qué puede ocurrir al introducir una comilla simple.", "Un comentario SQL puede dejar de lado el resto de la condición.", "Comienza con un usuario existente seguido de una comilla; después considera el comentario."]
	campaign.hints[str(campaign.current)] = mini(count + 1, 3)
	tutor_message.text = "Byte - pista %d/3: %s" % [mini(count + 1, 3), hints[mini(count, 2)]]
	hint_label.text = "Pista %d/3" % mini(count + 1, 3)
	campaign.save_lesson()

func _refresh_tutor() -> void:
	if campaign == null: return
	var count := int(campaign.hints.get(str(campaign.current), 0))
	hint_label.text = "Byte: observa la traza y cambia una sola cosa por intento." if count == 0 else "Byte: ya tienes %d pista(s); vuelve a comparar entrada y estructura." % count

func _reset() -> void:
	if not reset_pending or Time.get_ticks_msec() > reset_deadline:
		reset_pending = true
		reset_deadline = Time.get_ticks_msec() + 5000
		reset_button.text = "Confirmar reinicio"
		return
	campaign.reset_lab()
	campaign.lessons.erase(str(campaign.current))
	reset_pending = false
	reset_button.text = "Restaurar escenario"
	_setup_mission()

func close_lab() -> void:
	if not visible: return
	if reduced_motion:
		hide()
		closed.emit()
		return
	if lab_tween and lab_tween.is_running(): lab_tween.kill()
	lab_tween = create_tween()
	lab_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	lab_tween.tween_property(root_panel, "modulate:a", 0.0, 0.16)
	lab_tween.finished.connect(func(): hide(); root_panel.modulate.a = 1.0; closed.emit())

func _process(_delta: float) -> void:
	if reset_pending and Time.get_ticks_msec() > reset_deadline:
		reset_pending = false
		reset_button.text = "Restaurar escenario"

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE:
		close_lab()
		get_viewport().set_input_as_handled()
