extends CharacterBody2D
class_name Unit

signal died(unit: CharacterBody2D)

enum Team { ALLY, ENEMY }

const MAX_HP := 100.0
const MOVE_SPEED := 200.0
const SKILL_COOLDOWN := 3.0
const SKILL_RANGE := 500.0

var team: Team = Team.ALLY
var is_player := false
var hp := MAX_HP
var last_move_dir := Vector2.RIGHT
var skill_timer := 0.0
var input_vector := Vector2.ZERO
var pending_skill := false
var game: Node = null
var unit_color: Color = Color.WHITE

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

func _ready() -> void:
	add_to_group("units")
	nav_agent.max_speed = MOVE_SPEED

func setup(team_value: Team, player_controlled: bool, color: Color, game_ref: Node) -> void:
	team = team_value
	is_player = player_controlled
	game = game_ref
	unit_color = color
	queue_redraw()
	if is_player:
		$Camera2D.enabled = true
	else:
		$Camera2D.enabled = false

func _physics_process(delta: float) -> void:
	if hp <= 0.0:
		return

	skill_timer = max(skill_timer - delta, 0.0)

	if is_player:
		process_player(delta)
	else:
		process_ai(delta)

	if velocity.length() > 0.1:
		last_move_dir = velocity.normalized()

	move_and_slide()

func process_player(_delta: float) -> void:
	var move_dir = input_vector
	velocity = move_dir * MOVE_SPEED
	if pending_skill:
		pending_skill = false
		try_fire_skill()

func process_ai(_delta: float) -> void:
	if game == null:
		velocity = Vector2.ZERO
		return

	var target_pos = global_position
	if game.is_outside_safe_zone(global_position):
		target_pos = game.get_safe_center()
	else:
		var nearest = game.find_nearest_enemy(self)
		if nearest:
			target_pos = nearest.global_position

	nav_agent.target_position = target_pos
	var next_pos = nav_agent.get_next_path_position()
	var dir = (next_pos - global_position)
	if dir.length() > 4.0:
		dir = dir.normalized()
	else:
		dir = Vector2.ZERO

	velocity = dir * MOVE_SPEED

	var enemy = game.find_nearest_enemy(self)
	if enemy and global_position.distance_to(enemy.global_position) <= SKILL_RANGE:
		try_fire_skill()

func set_input_vector(vec: Vector2) -> void:
	input_vector = vec
	if input_vector.length() > 0.1:
		last_move_dir = input_vector.normalized()

func request_skill() -> void:
	pending_skill = true

func try_fire_skill() -> void:
	if skill_timer > 0.0:
		return
	var dir = get_aim_direction()
	if dir == Vector2.ZERO:
		return
	skill_timer = SKILL_COOLDOWN
	if game:
		game.spawn_projectile(self, dir)

func get_aim_direction() -> Vector2:
	if game:
		var enemy = game.find_nearest_enemy(self)
		if enemy:
			return (enemy.global_position - global_position).normalized()
	return last_move_dir

func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return
	hp = max(hp - amount, 0.0)
	if hp <= 0.0:
		die()

func die() -> void:
	emit_signal("died", self)
	queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 16.0, unit_color)
