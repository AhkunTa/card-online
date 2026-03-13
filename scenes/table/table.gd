extends Control

const CARD_SCENE := preload("res://scenes/card/card.tscn")

# 顺时针座位槽位，seat 0 = 当前用户（底部），顺时针递增
# 视觉顺时针（屏幕坐标）: 底 -> 左下 -> 左上 -> 上左 -> 上中 -> 上右 -> 右上 -> 右下
# 视觉布局:
#       [3]  [4]  [5]
#  [2]                [6]
#  [1]                [7]
#       [0 - 你]

enum Slot {
	BOTTOM    = 0,  # 当前用户，固定在底部
	LEFT_1    = 1,  # 左侧下
	LEFT_2    = 2,  # 左侧上
	TOP_LEFT  = 3,  # 上方左
	TOP_MID   = 4,  # 上方中
	TOP_RIGHT = 5,  # 上方右
	RIGHT_2   = 6,  # 右侧上
	RIGHT_1   = 7,  # 右侧下
}

# 各人数启用的槽位（顺时针顺序，含 BOTTOM）
const PLAYER_SLOT_MAP = {
	2: [Slot.BOTTOM, Slot.TOP_MID],
	3: [Slot.BOTTOM, Slot.LEFT_1, Slot.TOP_RIGHT],
	4: [Slot.BOTTOM, Slot.LEFT_1, Slot.TOP_MID, Slot.RIGHT_1],
	5: [Slot.BOTTOM, Slot.LEFT_1, Slot.TOP_LEFT, Slot.TOP_RIGHT, Slot.RIGHT_1],
	6: [Slot.BOTTOM, Slot.LEFT_1, Slot.TOP_LEFT, Slot.TOP_MID, Slot.TOP_RIGHT, Slot.RIGHT_1],
	7: [Slot.BOTTOM, Slot.LEFT_1, Slot.LEFT_2, Slot.TOP_LEFT, Slot.TOP_RIGHT, Slot.RIGHT_2, Slot.RIGHT_1],
	8: [Slot.BOTTOM, Slot.LEFT_1, Slot.LEFT_2, Slot.TOP_LEFT, Slot.TOP_MID, Slot.TOP_RIGHT, Slot.RIGHT_2, Slot.RIGHT_1],
}

# 槽位 -> 所属区域容器名
const SLOT_AREA = {
	Slot.BOTTOM:    "BottomArea",
	Slot.LEFT_1:    "LeftArea",
	Slot.LEFT_2:    "LeftArea",
	Slot.TOP_LEFT:  "TopArea",
	Slot.TOP_MID:   "TopArea",
	Slot.TOP_RIGHT: "TopArea",
	Slot.RIGHT_2:   "RightArea",
	Slot.RIGHT_1:   "RightArea",
}

@onready var top_area: HBoxContainer    = %TopArea
@onready var left_area: VBoxContainer   = %LeftArea
@onready var right_area: VBoxContainer  = %RightArea
@onready var bottom_player_area: HBoxContainer = %BottomPlayerArea
@onready var button_blind: Button = %ButtonBlind

# seat_index -> PanelContainer
var seat_panels: Dictionary = {}

# 总人数（含自己），范围 2~8
var player_count: int = 4

# 本地玩家是否已翻过牌（翻过一张后禁止暗牌）
var _local_has_flipped: bool = false

# 绑定 RoomManager，连接发牌信号
func bind_room(room: Node) -> void:
	room.card_dealt.connect(_on_card_dealt)
	room.card_revealed.connect(_on_card_revealed)

func _ready() -> void:
	get_viewport().physics_object_picking = true
	_local_has_flipped = false
	button_blind.disabled = false
	setup_table(player_count)
	var room := $RoomManager as RoomManager
	room.players = player_count
	bind_room(room)
	room.start_game()

# 牌的偏移量（每张牌相对前一张的偏移）
const CARD_OFFSET_SELF     := Vector2(100, 0)  # 自己的牌
const CARD_OFFSET_OPPONENT := Vector2(30, 0)   # 对手的牌，紧凑叠放

# 收到一张牌：移除一个占位 ColorRect，插入真实 Card 节点并设置偏移
# 收到一张牌：card_id 存入 Card 节点 meta，客户端不持有牌面数据
func _on_card_dealt(seat_index: int, card_id: String, is_local: bool) -> void:
	var card_row := get_card_row(seat_index)
	if card_row == null:
		return
	var card_index := card_row.get_child_count()
	var card: Card = CARD_SCENE.instantiate()
	card.set_meta("card_id", card_id)
	card_row.add_child(card)
	var offset := CARD_OFFSET_SELF if is_local else CARD_OFFSET_OPPONENT
	card.position = offset * card_index
	if is_local:
		card.set_back()
		card.clickable = true
		card.flipped.connect(_on_local_card_flipped)
		($RoomManager as RoomManager).request_reveal(card_id, 0)
	else:
		card.set_back()

# 收到翻牌结果：本地牌只存 frame（等玩家点击翻），对手牌直接显示背面
func _on_card_revealed(card_id: String, frame_index: int) -> void:
	for seat_index in seat_panels.keys():
		var card_row := get_card_row(seat_index)
		if card_row == null:
			continue
		for child in card_row.get_children():
			if child is Card and child.get_meta("card_id", "") == card_id:
				if seat_index == 0:
					# 本地牌：只存 frame，保持背面，等玩家点击
					child._frame_index = frame_index
				else:
					child.set_card(frame_index)
				return

func _on_button_pressed() -> void:
	($RoomManager as RoomManager).request_reveal_all()

# 本地玩家翻开一张牌后：禁用 ButtonBlind，但其余牌仍可点击
func _on_local_card_flipped(_card: Card) -> void:
	if _local_has_flipped:
		return
	_local_has_flipped = true
	button_blind.disabled = true

func setup_table(count: int) -> void:
	player_count = clamp(count, 2, 8)
	seat_panels.clear()
	_clear_areas()

	var active_slots: Array = PLAYER_SLOT_MAP.get(player_count, [])

	# seat_index 按顺时针顺序分配：active_slots[0] 是自己(seat 0)，依次递增
	for seat_index in range(active_slots.size()):
		var slot: Slot = active_slots[seat_index]
		var is_self := (seat_index == 0)
		var panel := _make_player_panel("玩家%d" % seat_index if not is_self else "你", is_self)
		panel.set_meta("seat_index", seat_index)
		seat_panels[seat_index] = panel
		_add_to_area(slot, panel)

# 返回 seat 对应的 Node2D 卡牌容器
func get_card_row(seat_index: int) -> Node2D:
	if not seat_panels.has(seat_index):
		return null
	var panel: PanelContainer = seat_panels[seat_index]
	# panel > VBox > card_row(Control) > card_container(Node2D)
	return panel.get_child(0).get_child(1).get_child(0) as Node2D

func _clear_areas() -> void:
	for child in top_area.get_children():    child.queue_free()
	for child in left_area.get_children():   child.queue_free()
	for child in right_area.get_children():  child.queue_free()
	for child in bottom_player_area.get_children(): child.queue_free()

func _add_to_area(slot: Slot, panel: PanelContainer) -> void:
	match SLOT_AREA[slot]:
		"TopArea":
			var insert_pos := _top_area_insert_pos(slot)
			top_area.add_child(panel)
			top_area.move_child(panel, insert_pos)
		"RightArea":
			# RIGHT_2 在上，RIGHT_1 在下
			right_area.add_child(panel)
			if slot == Slot.RIGHT_2:
				right_area.move_child(panel, 0)
		"LeftArea":
			# LEFT_2 在上，LEFT_1 在下
			left_area.add_child(panel)
			if slot == Slot.LEFT_2:
				left_area.move_child(panel, 0)
		"BottomArea":
			bottom_player_area.add_child(panel)

func _top_area_insert_pos(slot: Slot) -> int:
	# 上方从左到右: TOP_LEFT < TOP_MID < TOP_RIGHT
	const TOP_ORDER = [Slot.TOP_LEFT, Slot.TOP_MID, Slot.TOP_RIGHT]
	var pos := 0
	for existing in top_area.get_children():
		var existing_slot = _get_panel_slot(existing)
		if TOP_ORDER.find(existing_slot) < TOP_ORDER.find(slot):
			pos += 1
	return pos

func _get_panel_slot(panel: Node) -> Slot:
	# 通过 seat_index 反查槽位
	if not panel.has_meta("seat_index"):
		return Slot.BOTTOM
	var si: int = panel.get_meta("seat_index")
	var active_slots: Array = PLAYER_SLOT_MAP.get(player_count, [])
	if si < active_slots.size():
		return active_slots[si]
	return Slot.BOTTOM

func _make_player_panel(player_name: String, is_self: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_constant_override("margin_left", 20)
	panel.add_theme_constant_override("margin_right", 20)
	panel.add_theme_constant_override("margin_top", 20)
	panel.add_theme_constant_override("margin_bottom", 20)
	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var name_label := Label.new()
	name_label.text = player_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	var card_row := Control.new()
	card_row.custom_minimum_size = Vector2(200, 96) if is_self else Vector2(120, 56)
	card_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(card_row)

	# Node2D 容器放在 card_row 下，Card 加到这里，Area2D 信号不受 Control 拦截
	var card_container := Node2D.new()
	card_row.add_child(card_container)

	panel.custom_minimum_size = Vector2(300, 160) if is_self else Vector2(200, 110)
	return panel
