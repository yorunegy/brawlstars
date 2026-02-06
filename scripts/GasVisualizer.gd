extends Node2D

var safe_radius := 900.0
var safe_center := Vector2.ZERO

func _draw() -> void:
	draw_circle(safe_center, safe_radius, Color(0, 0.7, 0.2, 0.1))
	draw_arc(safe_center, safe_radius, 0.0, TAU, 64, Color(0, 0.8, 0.3, 0.8), 3.0)
