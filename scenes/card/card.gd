class_name Card
extends Node2D


@onready var card_sprite:Sprite2D = %CardSprite

func _ready():
	CardManager.shuffle_deck()


func set_card(index: int) -> void:

	card_sprite.frame = index
	
