class_name QuestHero
extends CharacterBody2D
## Top-down protagonist with explicit direction-to-animation mapping.
## The source sheet has three rows: down, side-facing-left, up. Horizontal
## movement reuses the verified side row and mirrors it only for the right side.

signal stepped

const SPEED := 145.0
const SHEET := preload("res://assets/characters/protagonist_walk_sheet.png")
const FRAME_COUNT := 4
const FRAME_ROWS := 3

enum State { IDLE, WALK, WORK, CELEBRATE, ERROR, CERTIFICATE, INTERVIEW }
enum Facing { DOWN, LEFT, RIGHT, UP }

var state := State.IDLE
var facing := Facing.DOWN
var direction := Facing.DOWN # Compatibility with existing save/debug callers.
var locked := false
var clock := 0.0
var step_clock := 0.0
var sprite: AnimatedSprite2D
var walk_test: Callable
var action_time := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite = AnimatedSprite2D.new()
	sprite.name = "HeroSprite"
	sprite.sprite_frames = _build_frames()
	sprite.animation = "idle_down"
	sprite.frame = 0
	sprite.centered = true
	sprite.position = Vector2(0, -24)
	sprite.scale = Vector2(0.68, 0.68)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	_apply_animation()

func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var cell_size := Vector2(SHEET.get_width() / float(FRAME_COUNT), SHEET.get_height() / float(FRAME_ROWS))
	for animation_name in ["idle_down", "idle_left", "idle_right", "idle_up", "walk_down", "walk_left", "walk_right", "walk_up"]:
		frames.add_animation(animation_name)
		frames.set_animation_loop(animation_name, animation_name.begins_with("walk_"))
		frames.set_animation_speed(animation_name, 8.0)

	# Verified sheet order: row 0 = down, row 1 = side facing left,
	# row 2 = up. Right-facing frames reuse the side row and mirror at playback.
	_add_row(frames, "idle_down", 0, [0])
	_add_row(frames, "walk_down", 0, [0, 1, 2, 3])
	_add_row(frames, "idle_left", 1, [0])
	_add_row(frames, "walk_left", 1, [0, 1, 2, 3])
	_add_row(frames, "idle_right", 1, [0])
	_add_row(frames, "walk_right", 1, [0, 1, 2, 3])
	_add_row(frames, "idle_up", 2, [0])
	_add_row(frames, "walk_up", 2, [0, 1, 2, 3])
	return frames

func _add_row(frames: SpriteFrames, animation_name: String, row: int, columns: Array) -> void:
	var cell_size := Vector2(SHEET.get_width() / float(FRAME_COUNT), SHEET.get_height() / float(FRAME_ROWS))
	for column in columns:
		var atlas := AtlasTexture.new()
		atlas.atlas = SHEET
		atlas.region = Rect2(Vector2(column, row) * cell_size, cell_size)
		frames.add_frame(animation_name, atlas)

func act(value: State, duration: float = 1.5) -> void:
	state = value
	action_time = duration
	_apply_animation()

func _physics_process(delta: float) -> void:
	clock += delta
	if action_time > 0.0:
		action_time -= delta
		if action_time <= 0.0:
			state = State.IDLE
			_apply_animation()
	elif not locked:
		var horizontal := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
		var vertical := float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
		var movement := Vector2(horizontal, vertical)
		# Keep movement and orientation deterministic when two keys are held.
		if not is_zero_approx(horizontal): movement.y = 0.0
		if movement != Vector2.ZERO:
			movement = movement.normalized()
			_set_facing(movement)
			state = State.WALK
			var target := position + movement * SPEED * delta
			if walk_test.is_valid() and walk_test.call(target): position = target
			step_clock += delta
			if step_clock > 0.32:
				step_clock = 0.0
				stepped.emit()
		else:
			state = State.IDLE
		step_clock = 0.0
		_apply_animation()

func _set_facing(movement: Vector2) -> void:
	if absf(movement.x) > 0.0:
		facing = Facing.RIGHT if movement.x > 0.0 else Facing.LEFT
	else:
		facing = Facing.DOWN if movement.y > 0.0 else Facing.UP
	direction = facing

func _apply_animation() -> void:
	if sprite == null: return
	var prefix := "walk_" if state == State.WALK else "idle_"
	var suffix: String = ["down", "left", "right", "up"][facing]
	var animation_name: String = prefix + suffix
	# The sheet's side row faces left; flip only when facing right.
	sprite.flip_h = facing == Facing.RIGHT
	if sprite.animation != animation_name:
		sprite.play(animation_name)
	else:
		sprite.play()
	if state != State.WALK:
		sprite.frame = 0
