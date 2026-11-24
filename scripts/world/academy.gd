class_name QuestWorld
extends Node2D
const SIZE := Vector2i(30, 21)
const CAMPUS_SIZE := Vector2(1536, 928)
const INTERIOR_CHARACTER_SCALE := 1.25
const CAMPUS_CAFE := preload("res://assets/buildings/cafe.png")
const CAMPUS_LAB := preload("res://assets/buildings/server_center.png")
const CAMPUS_OBJECTS := preload("res://assets/props/outdoor_objects.png")
const TILE := 32
const NAMES := ["Casa · mi cuarto", "Universidad · campus norte", "CyberAcademy · aula Byte", "Laboratorio · Login SQLi", "Centro · UNION y ORDER BY", "Aurora Tech · prácticas", "SOC · Blind SQL Injection", "Arena final · NullSec"]
const NPC := ["Nova", "Nova", "Profesor Byte", "Profesor Byte", "Profesor Byte", "Director Kernel", "Profesor Byte", "Profesor Byte"]
const CHARACTER_ANIMATIONS := preload("res://assets/characters/animation_frames.png")
const NPC_SHEET := preload("res://assets/characters/npc_and_hacker_sheet.png")
const PROFESSOR_SHEET := preload("res://assets/characters/professor_walk_sheet.png")
const CAMPUS_TREES := preload("res://assets/environment/trees_and_flowers.png")
const CAMPUS_PATHS := preload("res://assets/environment/grass_and_paths.png")
const ACADEMY_DOOR := Vector2(480, 300)
const CLASSROOM_EXIT := Vector2(480, 615)
const BEDROOM_COMPUTER := Vector2(535, 280)
const BEDROOM_EXIT := Vector2(644, 390)
const BEDROOM_SOLIDS := [Rect2(305, 292, 78, 105), Rect2(495, 260, 92, 38), Rect2(602, 248, 45, 40), Rect2(304, 245, 45, 38)]
const BEDROOM_FLOOR := preload("res://assets/bedroom/floor.png")
const BEDROOM_WALL := preload("res://assets/bedroom/wall.png")
const BEDROOM_DESK := preload("res://assets/bedroom/desk.png")
const BEDROOM_BOOKS := preload("res://assets/bedroom/bookshelf.png")
const BEDROOM_CLOSET := preload("res://assets/bedroom/wardrobe.png")
const BEDROOM_CHAIR := preload("res://assets/bedroom/chair.png")
const BEDROOM_WINDOW := preload("res://assets/bedroom/window.png")
const BEDROOM_DOOR := preload("res://assets/bedroom/door.png")
const BEDROOM_RUG := preload("res://assets/bedroom/rug.png")
const BEDROOM_PLANT := preload("res://assets/bedroom/plant.png")
const BEDROOM_POSTER := preload("res://assets/bedroom/poster.png")
const CAMPUS_SOLIDS := [
    Rect2(155, 65, 650, 205), # facade footprint; the approach remains clear
    Rect2(60, 390, 65, 60), Rect2(165, 510, 65, 60),
    Rect2(805, 390, 65, 60), Rect2(730, 510, 65, 60),
    Rect2(1060, 95, 230, 150), Rect2(1190, 550, 270, 170),
    Rect2(995, 760, 65, 60), Rect2(1370, 365, 65, 60)
]
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
enum NPCState { IDLE, INTERACT }
var npc_state := NPCState.IDLE
var npc_looks_left := false
# Approximate solid footprints mapped to the classroom artwork scaled to 960x672.
# Rectangles are separated to preserve the central and side aisles.
const CLASSROOM_SOLIDS := [
    Rect2(310, 84, 365, 182), # display and wall-mounted frame
    Rect2(48, 245, 120, 181), # left bookcase
    Rect2(824, 381, 76, 246), # right cabinet and bookcase
    Rect2(520, 290, 82, 91), # teacher's desk
    Rect2(205, 410, 225, 103), # left front student desks
    Rect2(205, 530, 225, 104), # left rear student desks
    Rect2(550, 410, 225, 103), # right front student desks
    Rect2(550, 530, 225, 104), # right rear student desks
    Rect2(72, 135, 90, 100), # upper left plant
    Rect2(800, 135, 90, 100), # upper right plant
    Rect2(68, 515, 94, 122), # lower left plant
    Rect2(220, 230, 70, 75), # small left plant
    Rect2(760, 230, 70, 75) # small right plant
]

func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    setup(room)

func setup(index: int) -> void:
    room = index
    if is_instance_valid(hero) and is_instance_valid(hero.sprite):
        var visual_scale := INTERIOR_CHARACTER_SCALE if room >= 2 else 1.0
        hero.sprite.scale = Vector2.ONE * 0.68 * visual_scale
        hero.sprite.position = Vector2(0, -24 * visual_scale)
    npc_pos = Vector2(690, 420) if room == 1 else Vector2(13.5, 9.5) * TILE
    # The classroom console is the wooden desk in front of the board.
    terminal_pos = Vector2(560, 330) if room == 2 else Vector2(17.5, 7.5) * TILE
    npc_state = NPCState.IDLE
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
    if room == 0:
        var feet := Rect2(point + Vector2(-8, -4), Vector2(16, 8))
        if not Rect2(300, 250, 360, 220).encloses(feet): return false
        for solid in BEDROOM_SOLIDS:
            if feet.intersects(solid): return false
    if room == 1:
        var feet := Rect2(point + Vector2(-8, -4), Vector2(16, 8))
        if not Rect2(Vector2(32, 64), CAMPUS_SIZE - Vector2(64, 96)).encloses(feet): return false
        for solid in CAMPUS_SOLIDS:
            if feet.intersects(solid): return false
        return point.distance_to(npc_pos) >= 20
    if room == 2:
        var feet := Rect2(point + Vector2(-8, -4), Vector2(16, 8))
        for solid in CLASSROOM_SOLIDS:
            if feet.intersects(solid): return false
    for offset in [Vector2(-8, -4), Vector2(8, -4), Vector2(-8, 4), Vector2(8, 4)]:
        var tile := Vector2i((point + offset) / TILE)
        if tile.x < 0 or tile.y < 0 or tile.x >= SIZE.x or tile.y >= SIZE.y: return false
        if walls.has(tile): return false
        if room not in [0, 1, 2] and furniture.has(tile) and furniture[tile] != 13: return false
    if room != 0 and point.distance_to(npc_pos) < 20: return false
    return true

func interaction(point: Vector2) -> String:
    if room == 0:
        if point.distance_to(BEDROOM_EXIT) < 68: return "bedroom_exit"
        if point.y >= 298 and point.distance_to(BEDROOM_COMPUTER) < 70: return "bedroom_message"
        return ""
    if room == 1 and point.distance_to(ACADEMY_DOOR) < 65: return "academy_entry"
    if room == 2 and point.distance_to(CLASSROOM_EXIT) < 55: return "campus_exit"
    # Prefer the desk when the player is in front of it, even if Byte is nearby.
    if room == 2 and point.y >= 365 and point.distance_to(terminal_pos) < 100: return "terminal"
    if point.distance_to(npc_pos) < 62: return "npc"
    if room != 1 and point.distance_to(terminal_pos) < 65: return "terminal"
    if point.distance_to(Vector2(1, 11.5) * TILE) < 55: return "previous"
    if room == 1: return "chip" if chip_visible and point.distance_to(chip_pos) < 42 else ""
    if point.distance_to(Vector2(29, 11.5) * TILE) < 55: return "next"
    if chip_visible and point.distance_to(chip_pos) < 42: return "chip"
    if point.distance_to(Vector2(4.5, 16) * TILE) < 66: return "books"
    return ""

func begin_npc_interaction(player_position: Vector2) -> void:
    npc_state = NPCState.INTERACT
    npc_looks_left = player_position.x < npc_pos.x
    queue_redraw()

func end_npc_interaction() -> void:
    npc_state = NPCState.IDLE
    queue_redraw()

func _process(delta: float) -> void:
    if not reduced_motion: time += delta
    queue_redraw()

func _tile(id: int, point: Vector2) -> void:
    draw_texture_rect_region(atlas, Rect2(point, Vector2(32, 32)), Rect2(id * 32, 0, 32, 32))

func _draw() -> void:
    if room == 0:
        _draw_bedroom()
        return
    if room == 1:
        _draw_campus()
        return
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
    if room == 2:
        # Marker stays above the desk; it does not change its collision footprint.
        var pulse := 0.12 if reduced_motion else 0.1 + 0.04 * sin(time * 3.0)
        draw_circle(terminal_pos + Vector2(0, -15), 12, Color(0.22, 0.83, 0.33, pulse))
        draw_rect(Rect2(CLASSROOM_EXIT + Vector2(-30, 6), Vector2(60, 8)), Color("58a6ff"))
    if chip_visible: _tile(14, chip_pos - Vector2(16, 16 + sin(time * 3) * 3))
    for i in range(12):
        var p := Vector2(fmod(i * 83.0 + sin(time + i) * 8, 920) + 20, fmod(i * 47.0 - time * 7 + 5000, 570) + 65)
        draw_rect(Rect2(p, Vector2(2, 2)), Color(0.6, 0.9, 0.9, 0.18))

func _draw_bedroom() -> void:
    draw_rect(Rect2(0, 0, 960, 672), Color("151321"))
    for y in range(250, 470, 44):
        for x in range(300, 660, 45):
            draw_texture_rect(BEDROOM_FLOOR, Rect2(x, y, 45, 44), false)
    for x in range(300, 660, 60):
        draw_texture_rect(BEDROOM_WALL, Rect2(x, 185, 60, 65), false)
    draw_texture_rect(BEDROOM_WINDOW, Rect2(405, 192, 88, 60), false)
    draw_texture_rect(BEDROOM_POSTER, Rect2(365, 199, 26, 38), false)
    draw_texture_rect(BEDROOM_RUG, Rect2(408, 360, 120, 65), false)
    draw_texture_rect(BEDROOM_CLOSET, Rect2(304, 213, 45, 70), false)
    draw_texture_rect(BEDROOM_BOOKS, Rect2(602, 215, 45, 73), false)
    draw_texture_rect(BEDROOM_DESK, Rect2(495, 231, 92, 67), false)
    draw_texture_rect(BEDROOM_CHAIR, Rect2(525, 302, 30, 40), false)
    draw_texture_rect(BEDROOM_PLANT, Rect2(600, 397, 35, 50), false)
    draw_texture_rect(BEDROOM_DOOR, Rect2(626, 344, 35, 68), false)
    # The supplied atlases contain no bed sprite.
    draw_rect(Rect2(305, 292, 78, 105), Color("362c45"))
    draw_rect(Rect2(309, 297, 70, 94), Color("ded5c9"))
    draw_rect(Rect2(314, 301, 60, 22), Color("f3eee5"))
    draw_rect(Rect2(309, 329, 70, 62), Color("695787"))
    draw_rect(Rect2(309, 329, 70, 5), Color("aa96c3"))

func _draw_campus() -> void:
    # Paths and garden elements reuse the existing pixel art rather than indoor tiles.
    draw_rect(Rect2(Vector2.ZERO, CAMPUS_SIZE), Color("46864d"))
    for y in range(0, 928, 96):
        for x in range(0, 1536, 96):
            var tint := Color(0.35, 0.65, 0.34, 0.12 if (int(x / 96) + int(y / 96)) % 2 == 0 else 0.06)
            draw_rect(Rect2(x, y, 96, 96), tint)
    for y in range(275, 928, 96):
        var height := mini(96, 928 - y)
        draw_texture_rect_region(CAMPUS_PATHS, Rect2(432, y, 96, height), Rect2(203, 8, 100, height))
    for x in range(0, 1536, 96):
        if x < 432 or x > 528:
            draw_texture_rect_region(CAMPUS_PATHS, Rect2(x, 440, 96, 96), Rect2(203, 8, 100, 96))
    draw_texture_rect(ROOM_ART[1], Rect2(155, 20, 650, 267), false)
    draw_texture_rect(CAMPUS_CAFE, Rect2(1060, 70, 230, 195), false)
    draw_texture_rect(CAMPUS_LAB, Rect2(1190, 540, 270, 195), false)
    for point in [Vector2(1060, 360), Vector2(1060, 620), Vector2(790, 750)]:
        draw_texture_rect_region(CAMPUS_OBJECTS, Rect2(point, Vector2(74, 62)), Rect2(229, 5, 90, 88))
    for point in [Vector2(48, 335), Vector2(153, 455), Vector2(793, 335), Vector2(718, 455), Vector2(983, 705), Vector2(1358, 310)]:
        draw_texture_rect_region(CAMPUS_TREES, Rect2(point, Vector2(90, 110)), Rect2(0, 0, 115, 125))
    for point in [Vector2(285, 345), Vector2(590, 345), Vector2(285, 570), Vector2(590, 570)]:
        draw_texture_rect_region(CAMPUS_TREES, Rect2(point, Vector2(65, 40)), Rect2(744, 25, 82, 55))
    _draw_npc()
    var marker := ACADEMY_DOOR + Vector2(0, -10)
    draw_circle(marker, 15, Color(0.22, 0.83, 0.33, 0.3))
    draw_rect(Rect2(marker + Vector2(-9, -10), Vector2(18, 20)), Color("102b27"))
    draw_string(ThemeDB.fallback_font, marker + Vector2(-5, 5), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
    if chip_visible: _tile(14, chip_pos - Vector2(16, 16))

func _draw_npc() -> void:
    # These NPCs are stationary: never cycle walk frames without movement.
    var frame := 0
    var texture: Texture2D
    var region: Rect2
    if NPC[room] == "Profesor Byte":
        texture = PROFESSOR_SHEET
        var cell_height := PROFESSOR_SHEET.get_height() / 2.0
        region = Rect2(frame * (PROFESSOR_SHEET.get_width() / 4.0), cell_height if npc_looks_left else 0, PROFESSOR_SHEET.get_width() / 4.0, cell_height)
    elif room in [0, 1]:
        texture = CHARACTER_ANIMATIONS
        # The original atlas has unevenly spaced groups; Nova occupies this full frame.
        region = Rect2(480, 0, 48, 70) if room == 1 else Rect2((8 + frame) * (CHARACTER_ANIMATIONS.get_width() / 16.0), 0, CHARACTER_ANIMATIONS.get_width() / 16.0, CHARACTER_ANIMATIONS.get_height() / 4.0)
    else:
        texture = NPC_SHEET
        var column := 5 if room == 5 else 6
        region = Rect2(column * (NPC_SHEET.get_width() / 7.0), 0, NPC_SHEET.get_width() / 7.0, NPC_SHEET.get_height() / 2.0)
    var visual_scale := INTERIOR_CHARACTER_SCALE if room >= 2 else 1.0
    draw_texture_rect_region(texture, Rect2(npc_pos + Vector2(-21, -50) * visual_scale, Vector2(42, 56) * visual_scale), region)
