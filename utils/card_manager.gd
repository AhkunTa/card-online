class_name CardManager


enum CARD_TYPE {
	Heart = 1,
	Diamond = 2,
	Spade = 3,
	Club = 4
}



# 卡牌位置
const CARDS: Dictionary = {
	# A - k
	CARD_TYPE.Heart: {
		'A': 0,
		'2': 1,
		'3': 2,
		'4': 3,
		'5': 4,
		'6': 5,
		'7': 6,
		'8': 7,
		'9': 8,
		'10': 9,
		'J': 10,
		'Q': 11,
		'K': 12,
	},
	CARD_TYPE.Diamond: {
		'A': 15,
		'2': 16,
		'3': 17,
		'4': 18,
		'5': 19,
		'6': 20,
		'7': 21,
		'8': 22,
		'9': 23,
		'10': 24,
		'J': 25,
		'Q': 26,
		'K': 27,
	},
	CARD_TYPE.Spade: {
		'A': 30,
		'2': 31,
		'3': 32,
		'4': 33,
		'5': 34,
		'6': 35,
		'7': 36,
		'8': 37,
		'9': 38,
		'10': 39,
		'J': 40,
		'Q': 41,
		'K': 42,
	},
	CARD_TYPE.Club: {
		'A': 45,
		'2': 46,
		'3': 47,
		'4': 48,
		'5': 49,
		'6': 50,
		'7': 51,
		'8': 52,
		'9': 53,
		'10': 54,
		'J': 55,
		'Q': 56,
		'K': 57,
	}
}

func _ready():
	shuffle_deck()

const mini_card: Dictionary = {
	CARD_TYPE.Heart: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
	CARD_TYPE.Diamond: [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27],
	CARD_TYPE.Spade: [30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42],
	CARD_TYPE.Club: [45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57],
}

# 洗牌：返回打乱顺序的 52 张牌，格式如 "heart-A"、"spade-10"
static func shuffle_deck() -> Array[String]:
	var deck: Array[String] = []
	for suit in CARD_TYPE.values():
		for point in CARDS[suit].keys():
			var card_str = "%s-%s-%s" % [suit, point, CARDS[suit][point]]
			deck.append(card_str)
	deck.shuffle()
	print("Shuffled deck: ", deck)
	return deck
