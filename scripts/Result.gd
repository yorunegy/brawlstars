extends Control

@onready var result_label: Label = $Panel/VBoxContainer/ResultLabel

func _ready() -> void:
	result_label.text = GameState.result_text

func _on_retry_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_title_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Title.tscn")
