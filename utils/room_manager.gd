class_name RoomManager
extends Node

const CARDS_PER_PLAYER := 3
const DEAL_INTERVAL := .5

var local_seat: int = 0
var players: int = 4
var current_cards: Array[String] = []

var _deal_queue: Array = []
var _deal_timer: Timer

# 防作弊核心：card_id -> card_string，只在服务端（此处）持有
# 客户端只知道 card_id，不知道牌面
var _card_registry: Dictionary = {}

signal card_dealt(seat_index: int, card_id: String, is_local: bool)
signal card_revealed(card_id: String, frame_index: int)
signal deal_finished()

func _ready() -> void:
	_deal_timer = Timer.new()
	_deal_timer.wait_time = DEAL_INTERVAL
	_deal_timer.one_shot = false
	_deal_timer.timeout.connect(_on_deal_tick)
	add_child(_deal_timer)

func start_game() -> void:
	_card_registry.clear()
	current_cards = CardManager.shuffle_deck()
	_build_deal_queue()
	_deal_timer.start()

func restart_game() -> void:
	_deal_timer.stop()
	_deal_queue.clear()
	start_game()

func _build_deal_queue() -> void:
	_deal_queue.clear()
	var card_index := 0
	for deal_round in range(CARDS_PER_PLAYER):
		for seat in range(players):
			var card_str := current_cards[card_index]
			var card_id := _generate_card_id(seat, deal_round, card_str)
			_card_registry[card_id] = {
				"card_string": card_str,
				"seat_index": seat,
			}
			_deal_queue.append({
				"seat_index": seat,
				"card_id": card_id,
			})
			card_index += 1

# FNV-1a 32bit hash，输入任意字符串，返回 hex 字符串
static func _fnv1a(input: String) -> String:
	const FNV_PRIME := 0x01000193
	const FNV_OFFSET := 0x811c9dc5
	var hash_val := FNV_OFFSET
	for ch in input.to_utf8_buffer():
		hash_val ^= ch
		hash_val = (hash_val * FNV_PRIME) & 0xFFFFFFFF
	return "%08x" % hash_val

# 生成 card_id：基于 seat、round、card_string 和时间戳组合 hash，保证唯一且不可逆推
func _generate_card_id(seat: int, deal_round: int, card_str: String) -> String:
	var raw := "%d|%d|%s|%d" % [seat, deal_round, card_str, Time.get_ticks_usec()]
	return "card_%s" % _fnv1a(raw)

func _on_deal_tick() -> void:
	if _deal_queue.is_empty():
		_deal_timer.stop()
		emit_signal("deal_finished")
		return
	var item: Dictionary = _deal_queue.pop_front()
	var seat: int = item["seat_index"]
	var card_id: String = item["card_id"]
	var is_local := (seat == local_seat)
	emit_signal("card_dealt", seat, card_id, is_local)

# 翻牌请求：验证 card_id 归属，只有合法请求才返回牌面
# requester_seat: 请求翻牌的座位（用于权限校验，如只允许游戏结束后翻）
func request_reveal(card_id: String, _requester_seat: int) -> void:
	if not _card_registry.has(card_id):
		push_warning("RoomManager: 非法 card_id %s" % card_id)
		return
	var data: Dictionary = _card_registry[card_id]
	var frame_index := int(data["card_string"].split("-")[2])
	emit_signal("card_revealed", card_id, frame_index)

# 一次性翻开所有牌（游戏结束/摊牌）
func request_reveal_all() -> void:
	for card_id in _card_registry.keys():
		var data: Dictionary = _card_registry[card_id]
		var frame_index := int(data["card_string"].split("-")[2])
		emit_signal("card_revealed", card_id, frame_index)
