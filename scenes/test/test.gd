extends Node2D

const TestScript = preload("res://tests/test_card_manager.gd")

func _ready() -> void:
	var runner := TestScript.new()
	add_child(runner)
