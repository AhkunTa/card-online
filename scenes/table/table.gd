extends Control

# 顺时针座位槽位，seat 0 = 当前用户（底部），顺时针递增
# 视觉布局:
#       [5]  [4]  [3]
#  [6]                [2]
#  [7]                [1]
#       [0 - 你]
#
# 顺时针: 0(底) -> 1(右下) -> 2(右上) -> 3(上右) -> 4(上中) -> 5(上左) -> 6(左上) -> 7(左下)

enum Slot {
	BOTTOM   = 0,  # 当前用户，固定在底部
	RIGHT_1  = 1,  # 右侧下
	RIGHT_2  = 2,  # 右侧上
	TOP_RIGHT = 3, # 上方右
	TOP_MID  = 4,  # 上方中
	TOP_LEFT = 5,  # 上方左
	LEFT_2   = 6,  # 左侧上
	LEFT_1   = 7,  # 左侧下
}

# 顺时针完整序列（seat_index 0~7 对应的槽位）
const CLOCKWISE_SLOTS: Array = [
	Slot.BOTTOM,
	Slot.RIGHT_1,
	Slot.RIGHT_2,
	Slot.TOP_RIGHT,
	Slot.TOP_MID,
	Slot.TOP_LEFT,
	Slot.LEFT_2,
	Slot.LEFT_1,
]

# 各人数启用的槽位（顺时针顺序，含 BOTTOM）
const PLAYER_SLOT_MAP = {
	2: [Slot.BOTTOM, Slot.TOP_MID],
	3: [Slot.BOTTOM, Slot.RIGHT_1, Slot.TOP_LEFT],
	4: [Slot.BOTTOM, Slot.RIGHT_1, Slot.TOP_MID, Slot.LEFT_1],
	5: [Slot.BOTTOM, Slot.RIGHT_1, Slot.TOP_RIGHT, Slot.TOP_LEFT, Slot.LEFT_1],
	6: [Slot.BOTTOM, Slot.RIGHT_1, Slot.TOP_RIGHT, Slot.TOP_MID, Slot.TOP_LEFT, Slot.LEFT_1],
	7: [Slot.BOTTOM, Slot.RIGHT_1, Slot.RIGHT_2, Slot.TOP_RIGHT, Slot.TOP_LEFT, Slot.LEFT_2, Slot.LEFT_1],
	8: [Slot.BOTTOM, Slot.RIGHT_1, Slot.RIGHT_2, Slot.TOP_RIGHT, Slot.TOP_MID, Slot.TOP_LEFT, Slot.LEFT_2, Slot.LEFT_1],
}

# 槽位 -> 所属区域容器名
const SLOT_AREA = {
	Slot.BOTTOM:    "BottomArea",
	Slot.RIGHT_1:   "RightArea",
	Slot.RIGHT_2:   "RightArea",
	Slot.TOP_RIGHT: "TopArea",
	Slot.TOP_MID:   "TopArea",
	Slot.TOP_LEFT:  "TopArea",
	Slot.LEFT_2:    "LeftArea",
	Slot.LEFT_1:    "LeftArea",
}

@onready var top_area: HBoxContainer    = %TopArea
@onready var left_area: VBoxContainer   = %LeftArea
@onready var right_area: VBoxContainer  = %RightArea
@onready var bottom_player_area: HBoxContainer = %BottomPlayerArea

# seat_index -> PanelContainer，供发牌逻辑使用
var seat_panels: Dictionary = {}

# 总人数（含自己），范围 2~8
var player_count: int = 4

func _ready() -> void:
	setup_table(player_count)

# 根据人数初始化牌桌，返回 seat_panels 供外部发牌使用
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

# 外部发牌接口：根据 seat_index 获取对应面板的卡牌行
func get_card_row(seat_index: int) -> HBoxContainer:
	if not seat_panels.has(seat_index):
		return null
	var panel: PanelContainer = seat_panels[seat_index]
	# 结构: PanelContainer -> VBoxContainer -> HBoxContainer(card_row)
	return panel.get_child(0).get_child(1) as HBoxContainer

func _clear_areas() -> void:
	for child in top_area.get_children():    child.queue_free()
	for child in left_area.get_children():   child.queue_free()
	for child in right_area.get_children():  child.queue_free()
	for child in bottom_player_area.get_children(): child.queue_free()

func _add_to_area(slot: Slot, panel: PanelContainer) -> void:
	match SLOT_AREA[slot]:
		"TopArea":
			# 上方区域：TOP_LEFT=左, TOP_MID=中, TOP_RIGHT=右，按槽位值排序插入
			var insert_pos := _top_area_insert_pos(slot)
			top_area.add_child(panel)
			top_area.move_child(panel, insert_pos)
		"RightArea":
			# 右侧：RIGHT_1 在下，RIGHT_2 在上 -> 先加的在下，后加的 move 到前面
			right_area.add_child(panel)
			if slot == Slot.RIGHT_2:
				right_area.move_child(panel, 0)
		"LeftArea":
			# 左侧：LEFT_2 在上，LEFT_1 在下 -> LEFT_2 先占位0，LEFT_1 追加
			left_area.add_child(panel)
			if slot == Slot.LEFT_2:
				left_area.move_child(panel, 0)
		"BottomArea":
			bottom_player_area.add_child(panel)

func _top_area_insert_pos(slot: Slot) -> int:
	# 上方从左到右: TOP_LEFT(5) < TOP_MID(4) < TOP_RIGHT(3)，按视觉位置排
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
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var name_label := Label.new()
	name_label.text = player_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	var card_row := HBoxContainer.new()
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(card_row)

	for i in range(3):
		var placeholder := ColorRect.new()
		placeholder.color = Color(0.2, 0.5, 0.2, 0.8)
		placeholder.custom_minimum_size = Vector2(72, 96) if is_self else Vector2(40, 56)
		card_row.add_child(placeholder)

	panel.custom_minimum_size = Vector2(300, 140) if is_self else Vector2(160, 90)
	return panel
