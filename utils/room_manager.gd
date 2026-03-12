

var players = 4

var current_cards = []

func _ready():
	pass

func start_game() -> void:
	deal_cards()

# 发牌
func deal_cards() -> void:
	current_cards = CardManager.shuffle_deck()
	
func shuffle_cards() ->void:
	current_cards = CardManager.shuffle_deck()
