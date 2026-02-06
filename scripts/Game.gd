extends Node2D

const MATCH_TIME := 60.0
const SAFE_RADIUS_START := 900.0
const SAFE_RADIUS_END := 200.0
const GAS_DAMAGE_PERCENT := 0.05
const MAP_HALF_SIZE := 1000.0
const UNIT_MAX_HP := 100.0

@onready var navigation_region: NavigationRegion2D = $NavigationRegion2D
@onready var obstacles_root: Node2D = $Obstacles
@onready var units_root: Node2D = $Units
@onready var projectiles_root: Node2D = $Projectiles
@onready var gas_visualizer: Node2D = $GasVisualizer
@onready var camera: Camera2D = $Camera2D
@onready var time_label: Label = $CanvasLayer/UI/TopBar/TimeLabel
@onready var count_label: Label = $CanvasLayer/UI/TopBar/CountLabel
@onready var joystick: Control = $CanvasLayer/UI/VirtualJoystick
@onready var skill_button: Button = $CanvasLayer/UI/SkillButton

var unit_scene := preload("res://scenes/Unit.tscn")
var projectile_scene := preload("res://scenes/Projectile.tscn")

var player: CharacterBody2D
var allies: Array = []
var enemies: Array = []
var time_left := MATCH_TIME
var safe_center := Vector2.ZERO
var safe_radius := SAFE_RADIUS_START
var match_over := false
var skill_requested := false

var obstacles := [
	{"pos": Vector2(-200, -100), "size": Vector2(200, 120)},
	{"pos": Vector2(300, 200), "size": Vector2(220, 120)},
	{"pos": Vector2(-350, 350), "size": Vector2(140, 180)}
]

func _ready() -> void:
	safe_center = Vector2.ZERO
	build_navigation()
	spawn_units()
	skill_button.pressed.connect(_on_skill_button_pressed)
	update_ui()

func _process(delta: float) -> void:
	if match_over:
		return
	update_time(delta)
	update_player_input()
	apply_gas_damage(delta)
	update_ui()
	check_match_end()

func update_time(delta: float) -> void:
	time_left = max(time_left - delta, 0.0)
	var t = 1.0 - (time_left / MATCH_TIME)
	safe_radius = lerp(SAFE_RADIUS_START, SAFE_RADIUS_END, t)
	gas_visualizer.safe_center = safe_center
	gas_visualizer.safe_radius = safe_radius
	gas_visualizer.queue_redraw()

func update_player_input() -> void:
	if not player or not is_instance_valid(player):
		return
	var move_input = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	var joy_vec = joystick.get_vector()
	if joy_vec.length() > 0.1:
		move_input = joy_vec
	move_input = move_input.limit_length(1.0)
	player.set_input_vector(move_input)

	if Input.is_action_just_pressed("skill") or skill_requested:
		skill_requested = false
		player.request_skill()

	camera.global_position = player.global_position

func apply_gas_damage(delta: float) -> void:
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit):
			continue
		if is_outside_safe_zone(unit.global_position):
			unit.take_damage(UNIT_MAX_HP * GAS_DAMAGE_PERCENT * delta)

func is_outside_safe_zone(pos: Vector2) -> bool:
	return pos.distance_to(safe_center) > safe_radius

func get_safe_center() -> Vector2:
	return safe_center

func find_nearest_enemy(requester: Node) -> Node:
	var nearest: Node = null
	var min_dist := INF
	for unit in get_tree().get_nodes_in_group("units"):
		if unit == requester or not is_instance_valid(unit):
			continue
		if unit.team == requester.team:
			continue
		var dist = requester.global_position.distance_to(unit.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = unit
	return nearest

func spawn_units() -> void:
	player = create_unit(Unit.Team.ALLY, true, Color(0.2, 0.7, 1.0))
	player.global_position = Vector2(-600, 0)
	allies.append(player)

	for i in range(2):
		var ally = create_unit(Unit.Team.ALLY, false, Color(0.2, 0.9, 0.4))
		ally.global_position = Vector2(-700, -150 + i * 300)
		allies.append(ally)

	for i in range(3):
		var enemy = create_unit(Unit.Team.ENEMY, false, Color(1.0, 0.3, 0.3))
		enemy.global_position = Vector2(600, -200 + i * 200)
		enemies.append(enemy)

func create_unit(team_value: int, player_controlled: bool, color: Color) -> CharacterBody2D:
	var unit = unit_scene.instantiate()
	unit.setup(team_value, player_controlled, color, self)
	unit.died.connect(_on_unit_died)
	units_root.add_child(unit)
	return unit

func spawn_projectile(owner: Node, direction: Vector2) -> void:
	var projectile = projectile_scene.instantiate()
	projectile.global_position = owner.global_position + direction.normalized() * 20.0
	projectile.direction = direction.normalized()
	projectile.team = owner.team
	projectiles_root.add_child(projectile)

func build_navigation() -> void:
	# Step 1: No obstacles. Then add obstacles as holes for navigation.
	var nav_poly = NavigationPolygon.new()
	var outer = PackedVector2Array([
		Vector2(-MAP_HALF_SIZE, -MAP_HALF_SIZE),
		Vector2(MAP_HALF_SIZE, -MAP_HALF_SIZE),
		Vector2(MAP_HALF_SIZE, MAP_HALF_SIZE),
		Vector2(-MAP_HALF_SIZE, MAP_HALF_SIZE)
	])
	nav_poly.add_outline(outer)

	for data in obstacles:
		var size: Vector2 = data["size"]
		var pos: Vector2 = data["pos"]
		var half = size * 0.5
		var hole = PackedVector2Array([
			pos + Vector2(-half.x, -half.y),
			pos + Vector2(half.x, -half.y),
			pos + Vector2(half.x, half.y),
			pos + Vector2(-half.x, half.y)
		])
		nav_poly.add_outline(hole)
		create_wall(pos, size)

	nav_poly.make_polygons_from_outlines()
	navigation_region.navigation_polygon = nav_poly

func create_wall(pos: Vector2, size: Vector2) -> void:
	var wall = StaticBody2D.new()
	wall.collision_layer = 2
	wall.collision_mask = 1
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	wall.add_child(shape)
	wall.position = pos
	obstacles_root.add_child(wall)

func update_ui() -> void:
	count_label.text = "ALLY: %d  ENEMY: %d" % [count_alive(Unit.Team.ALLY), count_alive(Unit.Team.ENEMY)]
	time_label.text = "TIME: %.1f" % time_left

func count_alive(team_value: int) -> int:
	var count := 0
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit):
			continue
		if unit.team == team_value:
			count += 1
	return count

func total_hp(team_value: int) -> float:
	var total := 0.0
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit):
			continue
		if unit.team == team_value:
			total += unit.hp
	return total

func check_match_end() -> void:
	var ally_count = count_alive(Unit.Team.ALLY)
	var enemy_count = count_alive(Unit.Team.ENEMY)
	if ally_count == 0 or enemy_count == 0:
		end_match(ally_count, enemy_count)
		return
	if time_left <= 0.0:
		end_match(ally_count, enemy_count)

func end_match(ally_count: int, enemy_count: int) -> void:
	match_over = true
	var result = "DRAW"
	if ally_count > enemy_count:
		result = "WIN"
	elif enemy_count > ally_count:
		result = "LOSE"
	else:
		var ally_hp = total_hp(Unit.Team.ALLY)
		var enemy_hp = total_hp(Unit.Team.ENEMY)
		if ally_hp > enemy_hp:
			result = "WIN"
		elif enemy_hp > ally_hp:
			result = "LOSE"
		else:
			result = "DRAW"

	GameState.set_result("RESULT: %s" % result)
	get_tree().change_scene_to_file("res://scenes/Result.tscn")

func _on_unit_died(unit: Node) -> void:
	if allies.has(unit):
		allies.erase(unit)
	if enemies.has(unit):
		enemies.erase(unit)

func _on_skill_button_pressed() -> void:
	skill_requested = true
