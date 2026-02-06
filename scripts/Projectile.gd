extends Area2D

const SPEED := 600.0
const RANGE := 500.0
const DAMAGE := 25.0

var direction := Vector2.RIGHT
var team := 0
var traveled := 0.0

func _ready() -> void:
	connect("body_entered", Callable(self, "_on_body_entered"))

func _physics_process(delta: float) -> void:
	var step = SPEED * delta
	position += direction * step
	traveled += step
	if traveled >= RANGE:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D and body.has_method("take_damage"):
		if body.team == team:
			return
		body.take_damage(DAMAGE)
		queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 6.0, Color.YELLOW)
