class_name CardManager


enum CARD_TYPE {
	Heart = 1,
	Diamond = 2,
	Spade = 3,
	Club = 4
}

# 牌型等级（炸金花，从大到小）
enum HAND_RANK {
	HIGH_CARD = 0, # 散牌
	PAIR = 1, # 对子
	STRAIGHT = 2, # 顺子
	FLUSH = 3, # 同花
	STRAIGHT_FLUSH = 4, # 同花顺
	SPECIAL_235 = 5, # 特殊：2-3-5，只能杀豹子
	LEOPARD = 6, # 豹子（三条）
}

# 点数 -> 数值（A 在炸金花中最大）
const POINT_VALUE: Dictionary = {
	'2': 2, '3': 3, '4': 4, '5': 5, '6': 6, '7': 7,
	'8': 8, '9': 9, '10': 10, 'J': 11, 'Q': 12, 'K': 13, 'A': 14,
}

# 卡牌位置
const CARDS: Dictionary = {
	CARD_TYPE.Heart: {
		'A': 0, '2': 1, '3': 2, '4': 3, '5': 4, '6': 5, '7': 6,
		'8': 7, '9': 8, '10': 9, 'J': 10, 'Q': 11, 'K': 12,
	},
	CARD_TYPE.Diamond: {
		'A': 15, '2': 16, '3': 17, '4': 18, '5': 19, '6': 20, '7': 21,
		'8': 22, '9': 23, '10': 24, 'J': 25, 'Q': 26, 'K': 27,
	},
	CARD_TYPE.Spade: {
		'A': 30, '2': 31, '3': 32, '4': 33, '5': 34, '6': 35, '7': 36,
		'8': 37, '9': 38, '10': 39, 'J': 40, 'Q': 41, 'K': 42,
	},
	CARD_TYPE.Club: {
		'A': 45, '2': 46, '3': 47, '4': 48, '5': 49, '6': 50, '7': 51,
		'8': 52, '9': 53, '10': 54, 'J': 55, 'Q': 56, 'K': 57,
	}
}

const mini_card: Dictionary = {
	CARD_TYPE.Heart: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
	CARD_TYPE.Diamond: [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27],
	CARD_TYPE.Spade: [30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42],
	CARD_TYPE.Club: [45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57],
}

func _ready():
	shuffle_deck()

# 洗牌：返回打乱顺序的 52 张牌，格式 "suit-point-frame"
static func shuffle_deck() -> Array[String]:
	var deck: Array[String] = []
	for suit in CARD_TYPE.values():
		for point in CARDS[suit].keys():
			deck.append("%s-%s-%s" % [suit, point, CARDS[suit][point]])
	deck.shuffle()
	return deck

# 解析单张牌字符串 -> { suit: int, point: String, value: int }
static func parse_card(card_str: String) -> Dictionary:
	var parts := card_str.split("-")
	return {
		"suit": int(parts[0]),
		"point": parts[1],
		"value": POINT_VALUE.get(parts[1], 0),
	}

# 计算三张牌的牌型，返回 { rank: HAND_RANK, values: Array[int] }
# values 用于同牌型时比大小，按重要性降序排列
static func evaluate_hand(cards: Array[String]) -> Dictionary:
	assert(cards.size() == 3, "炸金花需要3张牌")
	var parsed := cards.map(func(c): return parse_card(c))
	var suits: Array[int] = []
	for c in parsed:
		suits.append(c["suit"])
	var values: Array[int] = []
	for c in parsed:
		values.append(c["value"])
	values.sort()
	values.reverse() # 降序

  # 同花
	var is_flush := (suits[0] == suits[1]) and (suits[1] == suits[2])
	# 豹子
	var is_leopard := (values[0] == values[1]) and (values[1] == values[2])
	# 对子
	var is_pair := (values[0] == values[1]) or (values[1] == values[2])
	# 顺子
	var is_straight := _is_straight(values)
	# 235 特殊牌型：点数恰好是 5、3、2（不要求同花）
	var is_235 := (values[0] == 5) and (values[1] == 3) and (values[2] == 2) and !is_flush

	var rank: HAND_RANK
	if is_235:
		rank = HAND_RANK.SPECIAL_235
	elif is_leopard:
		rank = HAND_RANK.LEOPARD
	elif is_flush and is_straight:
		rank = HAND_RANK.STRAIGHT_FLUSH
	elif is_flush:
		rank = HAND_RANK.FLUSH
	elif is_straight:
		rank = HAND_RANK.STRAIGHT
	elif is_pair:
		rank = HAND_RANK.PAIR
		# 对子排前面，方便比较
		if values[1] == values[2]:
			values = [values[1], values[2], values[0]]
	else:
		rank = HAND_RANK.HIGH_CARD

	return {"rank": rank, "values": values}

# 判断是否为顺子（含 A-2-3 特殊顺子）
static func _is_straight(sorted_desc: Array[int]) -> bool:
	# 普通顺子
	if sorted_desc[0] - sorted_desc[1] == 1 and sorted_desc[1] - sorted_desc[2] == 1:
		return true
	# A-2-3 特殊顺子（A=14, 3=3, 2=2）
	if sorted_desc[0] == 14 and sorted_desc[1] == 3 and sorted_desc[2] == 2:
		return true
	return false

# 比较两手牌，返回正数表示 hand_a 赢，负数表示 hand_b 赢，0 表示平局
# hand_a / hand_b: Array[String]，每个元素为 card_str
static func compare_hands(hand_a: Array[String], hand_b: Array[String]) -> int:
	var eval_a := evaluate_hand(hand_a)
	var eval_b := evaluate_hand(hand_b)
	return _compare_eval(eval_a, eval_b)



static func _compare_eval(a: Dictionary, b: Dictionary) -> int:
	var ra: HAND_RANK = a["rank"]
	var rb: HAND_RANK = b["rank"]

	# 235 vs 235：永远平局
	if ra == HAND_RANK.SPECIAL_235 and rb == HAND_RANK.SPECIAL_235:
		return 0

	# 235 特殊规则：只赢豹子，输给其他所有牌型
	if ra == HAND_RANK.SPECIAL_235:
		return 1 if rb == HAND_RANK.LEOPARD else -1
	if rb == HAND_RANK.SPECIAL_235:
		return -1 if ra == HAND_RANK.LEOPARD else 1

	# 普通比较
	if ra != rb:
		return ra - rb
	var va: Array = a["values"]
	var vb: Array = b["values"]
	for i in range(va.size()):
		if va[i] != vb[i]:
			return va[i] - vb[i]
	return 0
