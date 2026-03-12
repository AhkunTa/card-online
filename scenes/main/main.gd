extends Node

const CARD_PRELOAD = preload("res://scenes/card/card.tscn")

@onready var bottom_player_area :HBoxContainer = %BottomPlayerArea

var get_3_cards: Array[String] = CardManager.shuffle_deck().slice(0,3)



func _ready():
	for card_string in get_3_cards:
		var card_index := card_string.split('-')[2]
		var card_instance = CARD_PRELOAD.instantiate()
		card_instance.set_card(int(card_index))
		card_instance.position = card_instance.position + Vector2(100 * get_3_cards.find(card_string), 0)
		add_child(card_instance)
