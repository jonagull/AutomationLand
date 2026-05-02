class_name TopDownPlayerController2D
extends CharacterBody2D

@export_node_path("Sprite2D") var PLAYER_SPRITE
@onready var _sprite: Sprite2D = get_node(PLAYER_SPRITE) if PLAYER_SPRITE else $Sprite2D

@export_node_path("AnimationPlayer") var ANIMATION_PLAYER
@onready var _animation_player: AnimationPlayer = get_node(ANIMATION_PLAYER) if ANIMATION_PLAYER else $AnimationPlayer

@export var dash_timer: Timer
@export var dash_cooldown_timer: Timer

@export var ACTION_UP: String = "up"
@export var ACTION_DOWN: String = "down"
@export var ACTION_LEFT: String = "left"
@export var ACTION_RIGHT: String = "right"
@export var ACTION_SPRINT: String = "sprint"
@export var ACTION_DASH: String = "dash"

@export var JOYSTICK_MOVEMENT: bool = false

@export_range(0, 2000, 0.1) var ACCELERATION: float = 800
@export_range(0, 2000, 0.1) var FRICTION: float = 1200
@export_range(0, 2000, 0.1) var MAX_WALK_SPEED: float = 100
@export_range(0, 2000, 0.1) var MAX_SPRINT_SPEED: float = 200
@export_range(0, 2000, 0.1) var DASH_SPEED: float = 500
@export_range(0, 1000, 0.1) var GRAVITY: float = 0

enum STATES { IDLE, WALK, SPRINT, DASH }
var state: int = STATES.IDLE

@export var ENABLE_SPRINT: bool = false
@onready var can_sprint: bool = ENABLE_SPRINT
var sprinting: bool = false

@export var ENABLE_DASH: bool = false
@onready var can_dash: bool = ENABLE_DASH
var dashing: bool = false
var dash_on_cooldown: bool = false

func _physics_process(delta: float) -> void:
	physics_tick(delta)

func physics_tick(delta: float) -> void:
	var inputs := handle_inputs()
	handle_sprint(inputs.sprint_strength)
	handle_velocity(delta, inputs.input_direction, inputs.dash_pressed)
	manage_state()
	manage_animations()
	velocity.y += GRAVITY * delta
	move_and_slide()

func manage_state() -> void:
	if dashing:
		state = STATES.DASH
	elif sprinting and velocity != Vector2.ZERO:
		state = STATES.SPRINT
	elif velocity != Vector2.ZERO:
		state = STATES.WALK
	else:
		state = STATES.IDLE

func manage_animations() -> void:
	if velocity.x > 0:
		_sprite.flip_h = false
	elif velocity.x < 0:
		_sprite.flip_h = true
	match state:
		STATES.IDLE:
			_animation_player.play("Idle")
		STATES.WALK, STATES.SPRINT, STATES.DASH:
			_animation_player.play("Walk")

func handle_inputs() -> Dictionary:
	return {
		input_direction = get_input_direction(),
		sprint_strength = Input.get_action_strength(ACTION_SPRINT) if ENABLE_SPRINT else 0.0,
		dash_pressed = ENABLE_DASH and Input.is_action_just_pressed(ACTION_DASH),
	}

func get_input_direction() -> Vector2:
	var x_dir := Input.get_action_strength(ACTION_RIGHT) - Input.get_action_strength(ACTION_LEFT)
	var y_dir := Input.get_action_strength(ACTION_DOWN) - Input.get_action_strength(ACTION_UP)
	if JOYSTICK_MOVEMENT:
		return Vector2(x_dir, y_dir)
	return Vector2(sign(x_dir), sign(y_dir)).normalized()

func handle_velocity(delta: float, input_direction: Vector2, dash_pressed: bool) -> void:
	if dashing:
		return
	if dash_pressed and can_dash and not dash_on_cooldown and input_direction != Vector2.ZERO:
		_start_dash(input_direction)
		return
	if input_direction != Vector2.ZERO:
		var target_speed := MAX_SPRINT_SPEED if sprinting else MAX_WALK_SPEED
		velocity = velocity.move_toward(input_direction * target_speed, ACCELERATION * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)

func _start_dash(direction: Vector2) -> void:
	dashing = true
	dash_on_cooldown = true
	velocity = direction * DASH_SPEED
	dash_timer.start()
	dash_cooldown_timer.start()

func handle_sprint(sprint_strength: float) -> void:
	sprinting = sprint_strength > 0 and can_sprint

func _on_dash_timer_timeout() -> void:
	dashing = false
	dash_timer.stop()

func _on_dash_cooldown_timer_timeout() -> void:
	dash_on_cooldown = false
	dash_cooldown_timer.stop()
