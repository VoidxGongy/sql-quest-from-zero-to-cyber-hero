class_name QuestWorld
extends Node2D
const SIZE := Vector2i(30, 21)
const TILE := 32
const NAMES := ["Casa · el comienzo", "Universidad · campus norte", "CyberAcademy · aula Byte", "Laboratorio · Login SQLi", "Centro · UNION y ORDER BY", "Aurora Tech · prácticas", "SOC · Blind SQL Injection", "Arena final · NullSec"]
const NPC := ["Nova", "Nova", "Profesor Byte", "Profesor Byte", "Profesor Byte", "Director Kernel", "Profesor Byte", "Profesor Byte"]
const CHARACTER_ANIMATIONS := preload("res://assets/characters/animation_frames.png")
const NPC_SHEET := preload("res://assets/characters/npc_and_hacker_sheet.png")
const PROFESSOR_SHEET := preload("res://assets/characters/professor_walk_sheet.png")
const ROOM_ART := [
    preload("res://assets/levels/academy_front.png"),
    preload("res://assets/levels/academy_front.png"),
    preload("res://assets/levels/classroom.png"),
    preload("res://assets/levels/computer_lab.png"),
    preload("res://assets/levels/sql_injection_lab.png"),
    preload("res://assets/levels/server_room.png"),
    preload("res://assets/levels/security_office.png"),
    preload("res://assets/levels/server_vault.png")
]
const ROOM_ART_AS_BACKGROUND := [false, false, true, true, true, true, true, true]
var room := 2
var time := 0.0
var furniture: Dictionary = {}
var walls: Dictionary = {}
var atlas := preload("res://assets/tilesets/academy.svg")
var npc_pos := Vector2(13.5, 9.5) * TILE
var terminal_pos := Vector2(17.5, 7.5) * TILE
var chip_pos := Vector2(23.5, 14.5) * TILE
var chip_visible := true
var unlocked := 2
var hero: QuestHero
var reduced_motion := false

func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    setup(room)

func setup(index: int) -> void:
    room = index
    walls.clear()
    furniture.clear()
    for x in range(SIZE.x):
        for y in range(SIZE.y):
            if x == 0 or x == SIZE.x - 1 or y < 2 or y == SIZE.y - 1:
                walls[Vector2i(x, y)] = true
    # The two exits share a clear corridor throughout all eight locations.
    walls.erase(Vector2i(0, 11)); walls.erase(Vector2i(29, 11))
    for x in [3, 8, 21, 26]: furniture[Vector2i(x, 3)] = 8
    for x in [5, 6, 23, 24]: furniture[Vector2i(x, 2)] = 15
    for x in [4, 5, 6, 21, 22, 23]:
        furniture[Vector2i(x, 6)] = 6 if x % 2 == 0 else 5
        furniture[Vector2i(x, 8)] = 10
    for x in [3, 4, 5]: furniture[Vector2i(x, 16)] = 12
    for x in [24, 25, 26]: furniture[Vector2i(x, 16)] = 7
    furniture[Vector2i(17, 7)] = 6
    furniture[Vector2i(17, 9)] = 10
    if room == 0:
        for x in [4, 5, 6, 21, 22, 23]:
            furniture.erase(Vector2i(x, 6))
            furniture.erase(Vector2i(x, 8))
        furniture[Vector2i(7, 15)] = 11
        furniture[Vector2i(8, 15)] = 11
        for x in range(5, 9): furniture[Vector2i(x, 5)] = 12
        for x in range(21, 25): furniture[Vector2i(x, 6)] = 5
        furniture[Vector2i(21, 7)] = 10
        furniture[Vector2i(24, 7)] = 10
    if room == 1:
        for x in [5, 10, 19, 24]:
            furniture[Vector2i(x, 14)] = 8
            for y in [15, 16]: furniture[Vector2i(x, y)] = 12
    if room == 2:
        for x in [7, 10, 19, 22]:
            furniture[Vector2i(x, 14)] = 5
            furniture[Vector2i(x, 15)] = 10
    if room in [3, 4, 6]:
        for x in range(9, 22, 2): furniture[Vector2i(x, 16)] = 7
    if room == 3:
        for y in [5, 6, 7, 8, 13, 14, 15]:
            furniture[Vector2i(8, y)] = 7
            furniture[Vector2i(24, y)] = 7
    if room == 4:
        for x in [6, 22]:
            for y in [13, 14]: furniture[Vector2i(x, y)] = 6
        for x in [10, 19]: furniture[Vector2i(x, 4)] = 8
    if room == 5:
        for x in [7, 11, 19, 23]:
            furniture[Vector2i(x, 14)] = 6
            furniture[Vector2i(x, 15)] = 10
            furniture[Vector2i(x + 1, 14)] = 5
    if room == 6:
        for x in range(8, 23): furniture[Vector2i(x, 4)] = 6 if x % 2 == 0 else 7
    if room == 7:
        for x in range(12, 16): furniture[Vector2i(x, 6)] = 5
        for x in [12, 15]: furniture[Vector2i(x, 7)] = 10
        for x in [6, 9, 20, 23]: furniture[Vector2i(x, 14)] = 8
    queue_redraw()

func walkable(point: Vector2) -> bool:
    for offset in [Vector2(-8, -4), Vector2(8, -4), Vector2(-8, 4), Vector2(8, 4)]:
        var tile := Vector2i((point + offset) / TILE)
        if tile.x < 0 or tile.y < 0 or tile.x >= SIZE.x or tile.y >= SIZE.y: return false
        if walls.has(tile): return false
        if furniture.has(tile) and furniture[tile] != 13: return false
    if point.distance_to(npc_pos) < 20: return false
    return true

func interaction(point: Vector2) -> String:
    if point.distance_to(npc_pos) < 62: return "npc"
    if point.distance_to(terminal_pos) < 65: return "terminal"
    if point.distance_to(Vector2(1, 11.5) * TILE) < 55: return "previous"
    if point.distance_to(Vector2(29, 11.5) * TILE) < 55: return "next"
    if chip_visible and point.distance_to(chip_pos) < 42: return "chip"
    if point.distance_to(Vector2(4.5, 16) * TILE) < 66: return "books"
    return ""

func _process(delta: float) -> void:
    if not reduced_motion: time += delta
    queue_redraw()

func _tile(id: int, point: Vector2) -> void:
    draw_texture_rect_region(atlas, Rect2(point, Vector2(32, 32)), Rect2(id * 32, 0, 32, 32))

func _draw() -> void:
    for y in range(SIZE.y):
        for x in range(SIZE.x):
            var cell := Vector2i(x, y)
            _tile(4 if walls.has(cell) else (2 if room in [0, 1] else (3 if room in [4, 7] else (x + y) % 2)), Vector2(cell) * TILE)
    if ROOM_ART_AS_BACKGROUND[room]:
        # Scenario art is visual only; walkability still comes from the hand-built grid.
        draw_texture_rect(ROOM_ART[room], Rect2(0, 0, SIZE.x * TILE, SIZE.y * TILE), false)
    else:
        for x in range(10, 20):
            for y in range(10, 14): _tile(13, Vector2(x, y) * TILE)
        var art_bounds := Rect2(382, 98, 196, 124)
        var art_size := Vector2(ROOM_ART[room].get_size())
        var art_scale := minf(art_bounds.size.x / art_size.x, art_bounds.size.y / art_size.y)
        var art_size_scaled := art_size * art_scale
        var art_rect := Rect2(art_bounds.get_center() - art_size_scaled / 2, art_size_scaled)
        draw_rect(art_bounds.grow(4), Color("101c30"))
        draw_texture_rect(ROOM_ART[room], art_rect, false)
        draw_rect(art_bounds.grow(4), Color("819dc3"), false, 2)
    if not ROOM_ART_AS_BACKGROUND[room]:
        for cell in furniture: _tile(furniture[cell], Vector2(cell) * TILE)
    draw_rect(Rect2(290, 66, 380, 29), Color("101c30"))
    draw_string(ThemeDB.fallback_font, Vector2(306, 86), NAMES[room], HORIZONTAL_ALIGNMENT_LEFT, 350, 17, Color("b8dbd1"))
    draw_string(ThemeDB.fallback_font, Vector2(35, 336), "SALIDA", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("94e1b0"))
    draw_string(ThemeDB.fallback_font, Vector2(845, 336), "ACCESO", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("94e1b0"))
    for x in [0, 29]:
        var near := hero != null and hero.position.distance_to(Vector2(x, 11.5) * TILE) < 70
        if near and (x == 0 or room < unlocked):
            _tile(0, Vector2(x, 11) * TILE)
            draw_rect(Rect2(Vector2(x * TILE + 1, 11 * TILE), Vector2(3, TILE)), Color("74dfb1"))
        else: _tile(9, Vector2(x, 11) * TILE)
    # Screen pixels blink; lamps cast a broad, low-opacity pool on the floor.
    for cell in furniture:
        if furniture[cell] in [6, 7]:
            var base := Vector2(cell) * TILE
            draw_rect(Rect2(base + Vector2(9, 10), Vector2(3, 2)), Color("b7ffca") if int(time * 2 + cell.x) % 2 else Color("3b8e91"))
            for i in range(3): draw_circle(base + Vector2(16, 30), 20.0 + i * 10, Color(0.2, 0.8, 0.7, 0.018))
    _draw_npc()
    draw_string(ThemeDB.fallback_font, npc_pos + Vector2(-45, -62), NPC[room], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("d9e8ee"))
    draw_string(ThemeDB.fallback_font, terminal_pos + Vector2(-28, -9), "SQL / E", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("9ae1b0"))
    if chip_visible: _tile(14, chip_pos - Vector2(16, 16 + sin(time * 3) * 3))
    for i in range(12):
        var p := Vector2(fmod(i * 83.0 + sin(time + i) * 8, 920) + 20, fmod(i * 47.0 - time * 7 + 5000, 570) + 65)
        draw_rect(Rect2(p, Vector2(2, 2)), Color(0.6, 0.9, 0.9, 0.18))

func _draw_npc() -> void:
    var frame := int(time * 4) % 4 if not reduced_motion else 0
    var texture: Texture2D
    var region: Rect2
    if room in [2, 3]:
        texture = PROFESSOR_SHEET
        region = Rect2(frame * (PROFESSOR_SHEET.get_width() / 4.0), 0, PROFESSOR_SHEET.get_width() / 4.0, 98)
    elif room in [0, 1]:
        texture = CHARACTER_ANIMATIONS
        region = Rect2((8 + frame) * (CHARACTER_ANIMATIONS.get_width() / 16.0), 0, CHARACTER_ANIMATIONS.get_width() / 16.0, CHARACTER_ANIMATIONS.get_height() / 4.0)
    elif room in [4, 6]:
        texture = CHARACTER_ANIMATIONS
        region = Rect2((12 + frame) * (CHARACTER_ANIMATIONS.get_width() / 16.0), 0, CHARACTER_ANIMATIONS.get_width() / 16.0, CHARACTER_ANIMATIONS.get_height() / 4.0)
    else:
        texture = NPC_SHEET
        var column := 5 if room == 5 else 6
        region = Rect2(column * (NPC_SHEET.get_width() / 7.0), 0, NPC_SHEET.get_width() / 7.0, NPC_SHEET.get_height() / 2.0)
    draw_texture_rect_region(texture, Rect2(npc_pos + Vector2(-21, -50), Vector2(42, 56)), region)
