class_name RoomManager
extends Node

# 每人发牌数
const CARDS_PER_PLAYER := 3
# 发牌间隔（秒）
const DEAL_INTERVAL := .5

# 当前玩家 seat_index（0 = 自己）
var local_seat: int = 0
var players: int = 4
var current_cards: Array[String] = []

# 发牌队列：每项 { seat_index, card_string }
var _deal_queue: Array = []
var _deal_timer: Timer

# 信号：通知外部某座位收到一张牌
signal card_dealt(seat_index: int, card_string: String, is_local: bool)
signal deal_finished()

func _ready() -> void:
	_deal_timer = Timer.new()
	_deal_timer.wait_time = DEAL_INTERVAL
	_deal_timer.one_shot = false
	_deal_timer.timeout.connect(_on_deal_tick)
	add_child(_deal_timer)

func start_game() -> void:
	current_cards = CardManager.shuffle_deck()
	_build_deal_queue()
	_deal_timer.start()

# 重置并重新开始
func restart_game() -> void:
	_deal_timer.stop()
	_deal_queue.clear()
	start_game()

# 按顺时针、每轮一张的顺序构建发牌队列
# 顺序：第1轮 seat0,1,2...N -> 第2轮 -> 第3轮
func _build_deal_queue() -> void:
	_deal_queue.clear()
	var card_index := 0
	for deal_round in range(CARDS_PER_PLAYER):
		for seat in range(players):
			_deal_queue.append({
				"seat_index": seat,
				"card_string": current_cards[card_index],
			})
			card_index += 1

func _on_deal_tick() -> void:
	if _deal_queue.is_empty():
		_deal_timer.stop()
		emit_signal("deal_finished")
		return

	var item: Dictionary = _deal_queue.pop_front()
	var seat: int = item["seat_index"]
	var card_str: String = item["card_string"]
	var is_local := (seat == local_seat)
	emit_signal("card_dealt", seat, card_str, is_local)
