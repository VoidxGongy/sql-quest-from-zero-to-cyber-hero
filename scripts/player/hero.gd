class_name QuestHero
extends CharacterBody2D
signal stepped
const SPEED := 145.0
enum State { IDLE, WALK, WORK, CELEBRATE, ERROR, CERTIFICATE, INTERVIEW }
var state := State.IDLE
var direction := 0
var locked := false
var clock := 0.0
var step_clock := 0.0
var sprite: Sprite2D
var walk_test: Callable
var action_time := 0.0

func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite = Sprite2D.new()
    sprite.texture = preload("res://assets/characters/protagonist_walk_sheet.png")
    sprite.hframes = 4
    sprite.vframes = 3
    sprite.scale = Vector2(0.68, 0.68)
    sprite.position.y = -24
    add_child(sprite)

func act(value: State, duration: float = 1.5) -> void:
    state = value
    action_time = duration

func _physics_process(delta: float) -> void:
    clock += delta
    if action_time > 0:
        action_time -= delta
        if action_time <= 0: state = State.IDLE
    elif not locked:
        var movement := Vector2(
            float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
            float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
        # Four directions, with horizontal priority, like a classic top-down RPG.
        if movement.x != 0: movement.y = 0
        state = State.WALK if movement != Vector2.ZERO else State.IDLE
        if movement != Vector2.ZERO:
            direction = 2 if movement.x > 0 else (1 if movement.x < 0 else (3 if movement.y < 0 else 0))
            var target := position + movement * SPEED * delta
            if walk_test.is_valid() and walk_test.call(target): position = target
            step_clock += delta
            if step_clock > 0.32: step_clock = 0; stepped.emit()
    var row := 0 if direction == 0 else (2 if direction == 3 else 1)
    var moving := state == State.WALK
    var frame := int(clock * 8) % 4 if moving else 0
    sprite.frame = row * 4 + frame
    sprite.flip_h = direction == 1
    sprite.position.y = -24 + (sin(clock * 2) * 0.5 if state == State.IDLE else 0)
