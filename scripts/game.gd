extends Node2D
## Scene coordinator: world, UI and persistent campaign communicate through signals.
const Campaign = preload("res://scripts/missions/campaign.gd")
const Save = preload("res://scripts/save_system/save_store.gd")
const World = preload("res://scripts/world/academy.gd")
const Hero = preload("res://scripts/player/hero.gd")
const Audio = preload("res://scripts/audio/quest_audio.gd")
const Lab = preload("res://scripts/ui/quest_lab.gd")
const UI = preload("res://scripts/ui/ui_kit.gd")
var campaign = Campaign.new()
var save_store = Save.new()
var world: QuestWorld
var hero: QuestHero
var audio: QuestAudio
var lab: QuestLab
var camera: Camera2D
var ui: Control
var hud: VBoxContainer
var hud_title: Label
var hud_mission: Label
var xp_bar: ProgressBar
var prompt: Label
var notice: Label
var menu: PanelContainer
var menu_box: VBoxContainer
var overlay: PanelContainer
var overlay_box: VBoxContainer
var dialogue_label: Label
var dialogue_speaker: Label
var dialogue_portrait: TextureRect
var dialogue_portrait_frames: Array[Texture2D] = []
var dialogue_demo: Label
var dialogue_lines: Array = []
var dialogue_index := 0
var dialogue_clock := 0.0
var dialogue_portrait_clock := 0.0
var dialogue_active := false
var transition: ColorRect
var transition_busy := false
var started := false
var notebook := ""
var notified := 0.0
var time := 0.0
var save_clock := 0.0
var room := 2
var music_volume := 0.55
var effects_volume := 0.65
var reduce_motion := false
var new_game_confirm := false

func _ready() -> void:
    RenderingServer.set_default_clear_color(Color("091522"))
    var preferences := ConfigFile.new()
    if preferences.load("user://settings.cfg") == OK:
        music_volume = clampf(float(preferences.get_value("audio", "music", 0.55)), 0, 1)
        effects_volume = clampf(float(preferences.get_value("audio", "effects", 0.65)), 0, 1)
        reduce_motion = bool(preferences.get_value("display", "reduce_motion", false))
    world = World.new()
    add_child(world)
    hero = Hero.new()
    hero.position = Vector2(14.5, 12.5) * 32
    hero.walk_test = world.walkable
    world.add_child(hero)
    world.hero = hero
    camera = Camera2D.new()
    camera.position = Vector2(480, 336)
    camera.position_smoothing_enabled = true
    camera.position_smoothing_speed = 5
    camera.zoom = Vector2(1.3, 1.3)
    add_child(camera)
    camera.make_current()
    audio = Audio.new()
    add_child(audio)
    audio.set_volumes(music_volume, effects_volume)
    audio.change_track(0)
    hero.stepped.connect(func(): audio.sfx("step"))
    var canvas := CanvasLayer.new()
    add_child(canvas)
    ui = Control.new()
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.theme = UI.theme()
    ui.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    canvas.add_child(ui)
    _build_hud()
    lab = Lab.new()
    lab.campaign = campaign
    ui.add_child(lab)
    lab.closed.connect(func(): hero.act(Hero.State.IDLE, 0); _save())
    lab.performed.connect(func(success):
        audio.sfx("key" if success else "error")
        hero.act(Hero.State.WORK if success else Hero.State.ERROR, 0.5)
        _save())
    lab.reward_requested.connect(func(): campaign.complete())
    overlay = PanelContainer.new()
    overlay.set_anchors_preset(Control.PRESET_CENTER)
    overlay.offset_left = -405
    overlay.offset_top = -245
    overlay.offset_right = 405
    overlay.offset_bottom = 245
    ui.add_child(overlay)
    overlay.hide()
    menu = PanelContainer.new()
    menu.set_anchors_preset(Control.PRESET_FULL_RECT)
    menu.add_theme_stylebox_override("panel", UI.style(Color(0.025, 0.055, 0.10, 0.92), Color("253a50")))
    ui.add_child(menu)
    transition = ColorRect.new()
    transition.color = Color("07111f")
    transition.modulate.a = 0
    transition.mouse_filter = Control.MOUSE_FILTER_IGNORE
    transition.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.add_child(transition)
    campaign.changed.connect(_refresh)
    campaign.mission_completed.connect(_completed)
    _main_menu()
    _refresh()
    get_tree().auto_accept_quit = false

func _build_hud() -> void:
    hud = VBoxContainer.new()
    hud.position = Vector2(24, 16)
    hud.size = Vector2(1104, 110)
    hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(hud)
    var panel := PanelContainer.new()
    hud.add_child(panel)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 16)
    panel.add_child(row)
    var labels := VBoxContainer.new()
    labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(labels)
    hud_title = UI.label(labels, "CYBERACADEMY", 20, UI.GREEN)
    hud_mission = UI.label(labels, "", 14)
    for label in [hud_title, hud_mission]:
        label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        label.clip_text = true
    UI.button(row, "Diario · J", func(): _notebook("Diario"))
    UI.button(row, "Mapa · Tab", func(): _notebook("Mapa"))
    UI.button(row, "Perfil · P", func(): _notebook("Perfil"))
    UI.button(row, "Pausa · Esc", _pause)
    xp_bar = ProgressBar.new()
    xp_bar.custom_minimum_size.y = 6
    xp_bar.show_percentage = false
    xp_bar.max_value = 250
    hud.add_child(xp_bar)
    prompt = UI.label(ui, "", 17, UI.GREEN)
    prompt.position = Vector2(120, 595)
    prompt.size = Vector2(912, 30)
    prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    notice = UI.label(ui, "", 16)
    notice.position = Vector2(40, 632)
    notice.size = Vector2(1072, 55)
    notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _main_menu() -> void:
    _clear_menu()
    var columns := HBoxContainer.new()
    columns.add_theme_constant_override("separation", 65)
    menu.add_child(columns)
    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 65)
    margin.add_theme_constant_override("margin_top", 100)
    margin.add_theme_constant_override("margin_bottom", 70)
    columns.add_child(margin)
    menu_box = VBoxContainer.new()
    menu_box.custom_minimum_size.x = 470
    menu_box.add_theme_constant_override("separation", 14)
    margin.add_child(menu_box)
    UI.label(menu_box, "SQL\nQUEST", 76, UI.GREEN)
    UI.label(menu_box, "FROM ZERO TO CYBER HERO", 20)
    UI.paragraph(menu_box, "Tu primer SELECT. Tu primera investigación.\nEl trabajo que siempre imaginaste.", 18)
    var spacer := Control.new()
    spacer.custom_minimum_size.y = 12
    menu_box.add_child(spacer)
    var saved := save_store.read()
    var continue_button := UI.button(menu_box, "Continuar aventura", _continue)
    continue_button.disabled = saved.is_empty()
    var new_button := UI.button(menu_box, "Nueva aventura", _request_new)
    UI.button(menu_box, "Audio y accesibilidad", _settings)
    UI.button(menu_box, "Salir", _quit)
    new_button.grab_focus() if saved.is_empty() else continue_button.grab_focus()
    var right := VBoxContainer.new()
    right.custom_minimum_size.x = 400
    right.alignment = BoxContainer.ALIGNMENT_CENTER
    columns.add_child(right)
    var art := TextureRect.new()
    var region := AtlasTexture.new()
    region.atlas = preload("res://assets/characters/protagonist_walk_sheet.png")
    region.region = Rect2(0, 0, 287.0 / 4.0, 280.0 / 3.0)
    art.texture = region
    art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    art.custom_minimum_size = Vector2(220, 260)
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    right.add_child(art)
    UI.label(right, "Una aventura de aprender haciendo", 21, UI.GREEN)
    UI.paragraph(right, "Explora 8 espacios. Escribe consultas.\nInvestiga sistemas ficticios. Repara el código.\nDemuestra lo que sabes en tu entrevista final.", 17)
    UI.paragraph(right, "WASD / flechas · caminar\nE · interactuar   J · diario   Tab · mapa\nP · perfil   I · inventario   K · conocimientos", 15)
    menu.show()
    hud.hide()
    prompt.hide()

func _clear_menu() -> void:
    for child in menu.get_children(): menu.remove_child(child); child.queue_free()

func _request_new() -> void:
    if not save_store.read().is_empty() and not new_game_confirm:
        new_game_confirm = true
        _clear_menu()
        menu_box = VBoxContainer.new()
        menu.add_child(menu_box)
        menu_box.alignment = BoxContainer.ALIGNMENT_CENTER
        UI.label(menu_box, "Empezar una nueva aventura", 32)
        UI.paragraph(menu_box, "Se reemplazará la partida actual. La copia anterior quedará como respaldo hasta el siguiente guardado.")
        UI.button(menu_box, "Confirmar nueva partida", _new_game)
        UI.button(menu_box, "Conservar mi partida", func(): new_game_confirm = false; _main_menu())
        return
    _new_game()

func _new_game() -> void:
    new_game_confirm = false
    campaign.restore(Campaign.new().serialize())
    lab.shown_mission = -1
    room = 2
    hero.position = Vector2(14.5, 12.5) * 32
    _start()
    _dialogue([
        "Profesor Byte: ¡Bienvenida a CyberAcademy! Hoy aprenderás a leer datos sin cambiar nada.",
        "Profesor Byte: SELECT elige las columnas; FROM indica la tabla. La demostración muestra estudiantes ficticios.",
        "Profesor Byte: WHERE filtra filas. Si la condición coincide, verás menos resultados.",
        "Nova: Ahora prueba algo parecido en la terminal iluminada. En Esquema puedes consultar las tablas.",
        "Profesor Byte: Tu objetivo es encontrar únicamente mi registro de Nova. Puedes pedir pistas y volver a intentarlo."
    ], "SELECT nombre FROM estudiantes;\n→ Leo · Nova · Ada · Iris\n\nSELECT nombre FROM estudiantes WHERE carrera = 'Sistemas';\n→ 3 filas · solo estudiantes de Sistemas")
    _save()

func _continue() -> void:
    var data := save_store.read()
    if data.is_empty(): _notify(save_store.last_error); return
    campaign.restore(data.campaign)
    room = clampi(int(data.get("room", 2)), 0, _unlocked())
    var p = data.get("position", [464, 400])
    hero.position = Vector2(float(p[0]), float(p[1])) if p is Array and p.size() == 2 else Vector2(464, 400)
    _start()
    if not world.walkable(hero.position): hero.position = Vector2(14.5, 12.5) * 32
    _notify("Partida recuperada. Tu próxima evidencia te espera.")

func _start() -> void:
    started = true
    menu.hide()
    hud.show()
    prompt.show()
    overlay.hide()
    world.setup(room)
    world.unlocked = _unlocked()
    world.chip_visible = room not in campaign.collected
    audio.set_volumes(music_volume, effects_volume)
    audio.change_track(room)
    _refresh()

func _unlocked() -> int:
    if campaign.current >= 7: return 7
    if campaign.current >= 4: return 6
    if campaign.current >= 2: return 4
    if campaign.current >= 1: return 3
    return 2

func _refresh() -> void:
    if hud_title == null: return
    hud_title.text = world.NAMES[room] + "    ·    " + campaign.rank_name()
    hud_mission.text = ("Misión %d/%d · " % [campaign.current + 1, campaign.missions.size()] + campaign.mission().title) if campaign.current < campaign.missions.size() else "Certificado y contratado · explora y consulta tu expediente"
    hud_mission.text += "     |     %d XP · nivel %d" % [campaign.xp, 1 + campaign.xp / 250]
    xp_bar.value = campaign.xp % 250
    world.unlocked = _unlocked()
    if lab and lab.visible: lab.refresh()

func _process(delta: float) -> void:
    time += delta
    save_clock += delta
    hero.locked = not started or menu.visible or overlay.visible or lab.visible or transition_busy
    camera.position = Vector2(480, 320) + (hero.position - Vector2(480, 336)) * 0.25
    world.reduced_motion = reduce_motion
    if dialogue_active and dialogue_label != null:
        dialogue_clock += delta * 42
        dialogue_label.visible_characters = int(dialogue_clock) if not reduce_motion else -1
        if not dialogue_portrait_frames.is_empty():
            dialogue_portrait_clock += delta
            dialogue_portrait.texture = dialogue_portrait_frames[int(dialogue_portrait_clock * 3) % dialogue_portrait_frames.size()]
    if notified > 0:
        notified -= delta
        if notified <= 0: notice.text = ""
    if started and not hero.locked:
        var near := world.interaction(hero.position)
        match near:
            "npc": prompt.text = "E · Conversar con " + world.NPC[room]
            "terminal": prompt.text = "E · Abrir laboratorio SQL"
            "previous": prompt.text = "E · " + (world.NAMES[room - 1] if room > 0 else "Aquí comienza tu historia")
            "next": prompt.text = "E · " + (world.NAMES[room + 1] if room < world.unlocked else "Acceso pendiente · avanza en tu misión")
            "chip": prompt.text = "E · Recoger chip de conocimiento (+25 XP)"
            "books": prompt.text = "E · Consultar biblioteca"
            _: prompt.text = "WASD / flechas · caminar     E · interactuar     J · objetivo     Tab · mapa"
    elif prompt: prompt.text = ""
    if save_clock > 25 and started:
        save_clock = 0
        _save()
    queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo: return
    if lab.visible: return
    if dialogue_active and event.keycode in [KEY_E, KEY_SPACE, KEY_ENTER]: _advance_dialogue(); return
    if event.keycode == KEY_ESCAPE:
        if overlay.visible: _close_overlay()
        elif menu.visible and started: menu.hide(); hud.show()
        elif started: _pause()
        return
    if menu.visible or overlay.visible or transition_busy or not started: return
    match event.keycode:
        KEY_E: _interact()
        KEY_J: _notebook("Diario")
        KEY_TAB: _notebook("Mapa"); get_viewport().set_input_as_handled()
        KEY_P: _notebook("Perfil")
        KEY_I: _notebook("Inventario")
        KEY_K: _notebook("Conocimientos")

func _interact() -> void:
    match world.interaction(hero.position):
        "npc":
            hero.act(Hero.State.INTERVIEW if room == 7 else Hero.State.IDLE, 1)
            if campaign.current < campaign.missions.size():
                _dialogue([world.NPC[room] + ": " + campaign.mission().lesson,
                    "Tu objetivo: " + campaign.mission().objective,
                    "Nova: Cada terminal es un entorno autorizado. El diario marca tu destino; no pierdes experiencia por equivocarte."],
                    "SELECT nombre FROM estudiantes;\n→ Lee primero los datos.\n\nWHERE condicion;\n→ Reduce las filas que coinciden." if room == 2 and campaign.current == 0 else "")
            else: _dialogue(["Alex: Bienvenido al equipo de seguridad. Tu expediente demuestra que sabes investigar, reparar y comprobar."])
        "terminal":
            if campaign.current < campaign.missions.size() and room != int(campaign.mission().room):
                _notify("Tu práctica está en " + world.NAMES[int(campaign.mission().room)] + ". Consulta el mapa.")
            else: hero.act(Hero.State.WORK, 10000); lab.open_lab()
        "previous":
            if room > 0: _travel(room - 1, true)
        "next":
            if room < world.unlocked: _travel(room + 1, false)
            else: _notify("Este acceso se desbloquea al entregar la misión actual.")
        "chip":
            if campaign.collect(room):
                world.chip_visible = false
                audio.sfx("reward")
                _notify("Chip recuperado · +25 XP. Consulta su nota en Inventario.")
                _save()
        "books": _notebook("Conocimientos")

func _travel(destination: int, from_right: bool = false) -> void:
    if transition_busy or destination < 0 or destination > _unlocked(): return
    transition_busy = true
    _close_overlay()
    audio.sfx("door")
    var tween := create_tween()
    tween.tween_property(transition, "modulate:a", 1.0, 0.01 if reduce_motion else 0.18)
    await tween.finished
    room = destination
    world.setup(room)
    world.chip_visible = room not in campaign.collected
    hero.position = Vector2(27.5 if from_right else 2.5, 11.5) * 32
    audio.change_track(room)
    _refresh()
    var fade := create_tween()
    fade.tween_property(transition, "modulate:a", 0.0, 0.01 if reduce_motion else 0.24)
    await fade.finished
    transition_busy = false
    _save()

func _panel(title: String) -> VBoxContainer:
    for child in overlay.get_children(): overlay.remove_child(child); child.queue_free()
    overlay.remove_theme_stylebox_override("panel")
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    overlay.add_child(scroll)
    overlay_box = VBoxContainer.new()
    overlay_box.add_theme_constant_override("separation", 14)
    overlay_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(overlay_box)
    UI.label(overlay_box, title, 27, UI.GREEN)
    overlay.show()
    return overlay_box

func _dialogue(lines: Array, demo: String = "") -> void:
    dialogue_lines = lines
    dialogue_index = 0
    dialogue_active = true
    var box := _panel("Conversación · CyberAcademy")
    overlay.add_theme_stylebox_override("panel", UI.texture_style(preload("res://assets/ui/dialogue_frame.png"), 22))
    var content := HBoxContainer.new()
    content.add_theme_constant_override("separation", 18)
    box.add_child(content)
    var portrait_panel := PanelContainer.new()
    portrait_panel.custom_minimum_size = Vector2(174, 218)
    portrait_panel.add_theme_stylebox_override("panel", UI.style(Color("0b1727"), Color("45627b")))
    content.add_child(portrait_panel)
    var portrait_column := VBoxContainer.new()
    portrait_column.alignment = BoxContainer.ALIGNMENT_CENTER
    portrait_panel.add_child(portrait_column)
    dialogue_portrait = TextureRect.new()
    dialogue_portrait.custom_minimum_size = Vector2(150, 178)
    dialogue_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    dialogue_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    dialogue_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    portrait_column.add_child(dialogue_portrait)
    var speech := VBoxContainer.new()
    speech.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    speech.add_theme_constant_override("separation", 10)
    content.add_child(speech)
    var speaker_row := HBoxContainer.new()
    speaker_row.add_theme_constant_override("separation", 8)
    speech.add_child(speaker_row)
    var speaker_icon := TextureRect.new()
    var icon := AtlasTexture.new()
    icon.atlas = preload("res://assets/ui/interaction_and_effect_icons.png")
    icon.region = Rect2(40, 54, 42, 42)
    speaker_icon.texture = icon
    speaker_icon.custom_minimum_size = Vector2(30, 30)
    speaker_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    speaker_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    speaker_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    speaker_row.add_child(speaker_icon)
    dialogue_speaker = UI.label(speaker_row, "", 19, UI.GREEN)
    dialogue_label = UI.paragraph(speech, "", 20)
    dialogue_label.custom_minimum_size.y = 110
    dialogue_demo = UI.paragraph(speech, demo, 14)
    dialogue_demo.add_theme_font_override("font", preload("res://assets/fonts/DejaVuSansMono.ttf"))
    dialogue_demo.custom_minimum_size.y = 82
    dialogue_demo.visible = not demo.is_empty()
    UI.button(box, "Continuar · E / Espacio", _advance_dialogue).grab_focus()
    UI.button(box, "Volver a explorar", _close_overlay)
    _show_line()

func _show_line() -> void:
    var line := str(dialogue_lines[dialogue_index])
    var separator := line.find(":")
    var speaker: String = world.NPC[room]
    if separator >= 0:
        speaker = line.substr(0, separator).strip_edges()
        line = line.substr(separator + 1).strip_edges()
    dialogue_speaker.text = speaker
    dialogue_label.text = line
    _set_dialogue_portrait(speaker, line)
    dialogue_label.visible_characters = 0
    dialogue_clock = 0
    audio.sfx("key")

func _set_dialogue_portrait(speaker: String, _line: String) -> void:
    dialogue_portrait_frames.clear()
    dialogue_portrait_clock = 0
    if speaker == "Profesor Byte":
        dialogue_portrait_frames.append(preload("res://assets/portraits/professor_byte.png"))
    elif speaker == "Nova":
        dialogue_portrait_frames.append(preload("res://assets/portraits/nova.png"))
    elif speaker == "Zero":
        dialogue_portrait_frames.append(preload("res://assets/portraits/zero.png"))
    elif speaker == "Director Kernel" or speaker == "Alex":
        var sheet := preload("res://assets/characters/npc_and_hacker_sheet.png")
        var crop := AtlasTexture.new()
        crop.atlas = sheet
        var column := 5 if speaker == "Director Kernel" else 6
        crop.region = Rect2(column * (sheet.get_width() / 7.0), 0, sheet.get_width() / 7.0, sheet.get_height() / 2.0)
        dialogue_portrait_frames.append(crop)
    else:
        dialogue_portrait_frames.append(preload("res://assets/portraits/hero.png"))
    dialogue_portrait.texture = dialogue_portrait_frames[0]

func _advance_dialogue() -> void:
    if dialogue_label.visible_characters >= 0 and dialogue_label.visible_characters < dialogue_label.text.length():
        dialogue_clock = dialogue_label.text.length()
        dialogue_label.visible_characters = -1
        return
    dialogue_index += 1
    if dialogue_index >= dialogue_lines.size(): _close_overlay()
    else: _show_line()

func _close_overlay() -> void:
    overlay.hide()
    dialogue_active = false
    dialogue_portrait_frames.clear()

func _notebook(page: String) -> void:
    if not started or lab.visible or menu.visible: return
    dialogue_active = false
    notebook = page
    var box := _panel(page)
    match page:
        "Diario":
            if campaign.current >= campaign.missions.size():
                UI.paragraph(box, "Campaña completada · práctica libre desbloqueada", 22)
                UI.paragraph(box, "Todas las terminales permiten experimentar. Tu perfil conserva las certificaciones y los informes.")
            else:
                UI.paragraph(box, "Misión activa: " + campaign.mission().title, 22)
                UI.paragraph(box, campaign.mission().objective)
                UI.paragraph(box, "Destino: " + world.NAMES[int(campaign.mission().room)], 18)
            for i in range(campaign.missions.size()):
                UI.paragraph(box, ("[COMPLETA] " if i in campaign.completed else ("[ACTIVA] " if i == campaign.current else "[PENDIENTE] ")) + campaign.missions[i].title, 15)
        "Mapa":
            UI.paragraph(box, "Campus conectado · las puertas laterales unen espacios consecutivos. Selecciona un destino desbloqueado para viajar.")
            for i in range(world.NAMES.size()):
                var label: String = ("[AQUÍ] " if i == room else "") + world.NAMES[i]
                if campaign.current < campaign.missions.size() and i == int(campaign.mission().room): label += " · OBJETIVO"
                var button := UI.button(box, label, _travel.bind(i))
                button.disabled = i > _unlocked() or i == room
        "Perfil":
            UI.paragraph(box, campaign.rank_name(), 25)
            UI.paragraph(box, "%d XP · nivel %d · %d/%d misiones" % [campaign.xp, 1 + campaign.xp / 250, campaign.completed.size(), campaign.missions.size()])
            for i in campaign.completed:
                UI.paragraph(box, campaign.missions[int(i)].badge + " · " + campaign.missions[int(i)].rank)
            if campaign.completed.is_empty(): UI.paragraph(box, "Tu expediente comienza con una consulta. Byte te espera.")
            for key in campaign.reports:
                UI.paragraph(box, "Informe · " + campaign.missions[int(key)].title, 18)
                UI.paragraph(box, campaign.reports[key], 14)
        "Inventario":
            UI.paragraph(box, "Credencial CyberAcademy · acceso a laboratorios autorizados\nPortátil de prácticas · SQL local y datos restaurables\nDiario de investigación · tus pruebas e informes")
            for i in campaign.collected: UI.paragraph(box, "Chip de " + world.NAMES[int(i)] + " · " + _chip_note(int(i)))
            for i in campaign.completed: UI.paragraph(box, "Insignia: " + campaign.missions[int(i)].badge)
        "Conocimientos":
            UI.paragraph(box, "Biblioteca de campo", 22)
            UI.paragraph(box, "SELECT columnas FROM tabla WHERE condición;\nTexto entre comillas simples. AND tiene prioridad sobre OR.\nEn el laboratorio, Esquema contiene la referencia completa.")
            for i in range(mini(campaign.current + 1, campaign.missions.size())):
                UI.paragraph(box, campaign.missions[i].title, 19)
                UI.paragraph(box, campaign.missions[i].lesson)
    UI.button(box, "Cerrar · Esc", _close_overlay)

func _chip_note(index: int) -> String:
    return ["Haz una copia antes de experimentar.", "Una fila representa un registro.", "Un resultado vacío también es evidencia.", "Los parámetros separan datos y estructura.", "UNION exige igual número de columnas.", "Un informe debe poder reproducirse.", "Un canal lateral revela diferencias, no filas.", "Una corrección necesita pruebas legítimas y adversarias."][index]

func _completed(index: int, earned: int) -> void:
    lab.hide()
    hero.act(Hero.State.CERTIFICATE if index == campaign.missions.size() - 1 else Hero.State.CELEBRATE, 3)
    audio.sfx("reward")
    _refresh()
    _save()
    var box := _panel("¡Contrato conseguido!" if index == campaign.missions.size() - 1 else "Certificación obtenida")
    var stage := Control.new()
    stage.custom_minimum_size.y = 98
    box.add_child(stage)
    var graduate := AnimatedSprite2D.new()
    var frames := SpriteFrames.new()
    frames.set_animation_speed("default", 5)
    for frame in range(4):
        var portrait := AtlasTexture.new()
        portrait.atlas = preload("res://assets/characters/protagonist_walk_sheet.png")
        portrait.region = Rect2(frame * (287.0 / 4.0), (2 if index == campaign.missions.size() - 1 else 0) * (280.0 / 3.0), 287.0 / 4.0, 280.0 / 3.0)
        frames.add_frame("default", portrait)
    graduate.sprite_frames = frames
    graduate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    graduate.scale = Vector2.ONE
    graduate.position = Vector2(60, 48)
    stage.add_child(graduate)
    var effect := TextureRect.new()
    var effect_crop := AtlasTexture.new()
    effect_crop.atlas = preload("res://assets/effects/cyber_effects.png")
    effect_crop.region = Rect2(1470, 0, 65, 65)
    effect.texture = effect_crop
    effect.position = Vector2(375, 4)
    effect.custom_minimum_size = Vector2(56, 56)
    effect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    effect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    effect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    stage.add_child(effect)
    if not reduce_motion: graduate.play()
    var certificate := UI.label(stage, "CYBERACADEMY\nCertificado de competencia práctica", 22, UI.GREEN)
    certificate.position = Vector2(130, 20)
    UI.paragraph(box, campaign.missions[index].badge, 30)
    UI.paragraph(box, "+%d XP · %s" % [earned, campaign.rank_name()], 22)
    if index == campaign.missions.size() - 1:
        audio.change_track(8)
        UI.paragraph(box, "Alex: Has demostrado investigación, mitigación y pruebas. Bienvenido al equipo de seguridad de Aurora Tech.\n\nDirector Kernel: Tu certificado Cyber Hero queda registrado en tu perfil. Tu aventura profesional acaba de empezar.", 19)
        UI.button(box, "Explorar y consultar mi expediente", _close_overlay)
    else:
        UI.paragraph(box, "Siguiente misión: " + campaign.mission().title + "\nDestino: " + world.NAMES[int(campaign.mission().room)], 19)
        UI.button(box, "Viajar a la siguiente misión", _travel.bind(int(campaign.mission().room)))
        UI.button(box, "Seguir explorando", _close_overlay)
    _notify("Misión entregada · " + campaign.missions[index].badge + " · +%d XP" % earned)

func _pause() -> void:
    if lab.visible or not started: return
    _clear_menu()
    menu_box = VBoxContainer.new()
    menu_box.alignment = BoxContainer.ALIGNMENT_CENTER
    menu_box.add_theme_constant_override("separation", 12)
    menu.add_child(menu_box)
    UI.label(menu_box, "Pausa · SQL Quest", 36, UI.GREEN)
    UI.button(menu_box, "Volver a la aventura", func(): menu.hide(); hud.show())
    UI.button(menu_box, "Guardar partida", func(): _save(); _notify("Partida guardada." if save_store.last_error == "" else save_store.last_error))
    UI.button(menu_box, "Audio y accesibilidad", _settings)
    UI.button(menu_box, "Menú principal", func(): _save(); started = false; overlay.hide(); dialogue_active = false; _main_menu())
    UI.button(menu_box, "Guardar y salir", _quit)
    menu.show()

func _settings() -> void:
    _clear_menu()
    menu_box = VBoxContainer.new()
    menu_box.alignment = BoxContainer.ALIGNMENT_CENTER
    menu_box.add_theme_constant_override("separation", 15)
    menu.add_child(menu_box)
    UI.label(menu_box, "Audio y accesibilidad", 36, UI.GREEN)
    for kind in ["Música", "Efectos"]:
        var level := UI.label(menu_box, kind, 20)
        var slider := HSlider.new()
        slider.min_value = 0
        slider.max_value = 1
        slider.step = 0.05
        slider.value = music_volume if kind == "Música" else effects_volume
        menu_box.add_child(slider)
        level.text = kind + " · %d%%" % int(slider.value * 100)
        slider.value_changed.connect(func(value):
            if kind == "Música": music_volume = value
            else: effects_volume = value
            level.text = kind + " · %d%%" % int(value * 100)
            audio.set_volumes(music_volume, effects_volume)
            if kind == "Efectos": audio.sfx("key"))
    var motion := CheckButton.new()
    motion.text = "Reducir movimiento y mostrar diálogos inmediatamente"
    motion.button_pressed = reduce_motion
    motion.toggled.connect(func(value): reduce_motion = value)
    menu_box.add_child(motion)
    UI.button(menu_box, "Aplicar y volver", func():
        var preferences := ConfigFile.new()
        preferences.set_value("audio", "music", music_volume)
        preferences.set_value("audio", "effects", effects_volume)
        preferences.set_value("display", "reduce_motion", reduce_motion)
        if preferences.save("user://settings.cfg") != OK: _notify("No se pudieron guardar las preferencias.")
        if started: _save(); _pause()
        else: _main_menu())
    menu.show()

func _save() -> void:
    if not started: return
    if not save_store.write({"campaign": campaign.serialize(), "room": room, "position": [hero.position.x, hero.position.y], "music": music_volume, "effects": effects_volume, "reduce_motion": reduce_motion}):
        _notify(save_store.last_error)

func _notify(message: String) -> void:
    notice.text = message
    notified = 7

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST: _quit()

func _quit() -> void:
    _save()
    get_tree().quit()

func _draw() -> void:
    if campaign.current >= campaign.missions.size() or hero != null and hero.state == Hero.State.CELEBRATE:
        for i in range(30):
            var point := Vector2(180 + fmod(i * 71.0, 620), 90 + fmod(time * 50 + i * 37, 460))
            draw_rect(Rect2(point, Vector2(4, 7)), Color("94e1b0") if i % 2 else Color("b7a2ed"))
