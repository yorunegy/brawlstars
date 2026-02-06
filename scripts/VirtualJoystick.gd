extends Control

signal vector_changed(vec: Vector2)

const DEADZONE := 0.2

var dragging := false
var pointer_id := -1
var radius := 80.0
var current_vector := Vector2.ZERO

@onready var base: ColorRect = $Base
@onready var knob: ColorRect = $Knob

func _ready() -> void:
	base.size = Vector2(radius * 2.0, radius * 2.0)
	base.position = Vector2.ZERO
	base.color = Color(0, 0, 0, 0.3)
	knob.size = Vector2(radius, radius)
	knob.position = base.position + Vector2(radius * 0.5, radius * 0.5)
	knob.color = Color(1, 1, 1, 0.6)
	set_process_unhandled_input(true)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _is_inside(event.position):
			dragging = true
			pointer_id = event.index
			_update_vector(event.position)
		elif not event.pressed and event.index == pointer_id:
			_reset()
	elif event is InputEventScreenDrag:
		if dragging and event.index == pointer_id:
			_update_vector(event.position)
	elif event is InputEventMouseButton:
		if event.pressed and _is_inside(event.position):
			dragging = true
			pointer_id = 0
			_update_vector(event.position)
		elif not event.pressed and pointer_id == 0:
			_reset()
	elif event is InputEventMouseMotion:
		if dragging and pointer_id == 0:
			_update_vector(event.position)

func _update_vector(pos: Vector2) -> void:
	var center = base.global_position + Vector2(radius, radius)
	var dir = pos - center
	if dir.length() > radius:
		dir = dir.normalized() * radius
	knob.global_position = center + dir - knob.size * 0.5
	current_vector = dir / radius
	if current_vector.length() < DEADZONE:
		current_vector = Vector2.ZERO
	emit_signal("vector_changed", current_vector)

func _reset() -> void:
	dragging = false
	pointer_id = -1
	current_vector = Vector2.ZERO
	knob.position = base.position + Vector2(radius * 0.5, radius * 0.5)
	emit_signal("vector_changed", current_vector)

func get_vector() -> Vector2:
	return current_vector

func _is_inside(pos: Vector2) -> bool:
	return Rect2(base.global_position, base.size).has_point(pos)
