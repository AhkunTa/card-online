class_name Card
extends Node2D

signal flipped(card: Card)
signal mouse_entered_card
signal mouse_exited_card

@onready var card_sprite: Sprite2D = %CardSprite

var _frame_index: int = -1
var is_face_up: bool = false
var clickable: bool = false

const BASE_SCALE   := Vector2(3.0, 3.0)
const LIFT_Y       := -12.0
const TILT_ROT_MAX := 6.0
const TILT_SCALE_X := 0.06

var _base_y: float = 0.0
var _is_hovering: bool = false
var _tween: Tween

func _ready() -> void:
	_base_y = card_sprite.position.y
	# 连接自己的信号到动画处理
	mouse_entered_card.connect(_on_hover_in)
	mouse_exited_card.connect(_on_hover_out)

func set_card(index: int) -> void:
	_frame_index = index
	card_sprite.frame = index
	is_face_up = true

func set_back() -> void:
	card_sprite.frame = 60
	is_face_up = false

func flip() -> void:
	if not clickable or is_face_up or _frame_index == -1:
		return
	set_card(_frame_index)
	emit_signal("flipped", self)

# ── 坐标检测（在 Control 场景里 Area2D 不可靠，用此方法）──────

func _get_card_rect() -> Rect2:
	var tex := card_sprite.texture as Texture2D
	if tex == null:
		return Rect2()
	var half_w: float = tex.get_width()  / 15.0 * 0.5 * BASE_SCALE.x
	var half_h: float = tex.get_height() / 5.0  * 0.5 * BASE_SCALE.y
	var center := card_sprite.global_position
	return Rect2(center.x - half_w, center.y - half_h, half_w * 2.0, half_h * 2.0)

func _is_mouse_over() -> bool:
	return _get_card_rect().has_point(get_global_mouse_position())

# ── _input 触发信号，外部逻辑全走信号 ────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var over := _is_mouse_over()
		if over and not _is_hovering:
			_is_hovering = true
			emit_signal("mouse_entered_card")
		elif not over and _is_hovering:
			_is_hovering = false
			emit_signal("mouse_exited_card")

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_mouse_over():
			flip()
			get_viewport().set_input_as_handled()

# ── 信号处理：动画 ────────────────────────────────────────────

func _on_hover_in() -> void:
	print("hover in ", self)
	_tween_to(_base_y + LIFT_Y)

func _on_hover_out() -> void:
	print("hover out ", self)
	if _tween:
		_tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.parallel().tween_property(card_sprite, "position:y", _base_y, 0.15)
	_tween.parallel().tween_property(card_sprite, "scale:x", BASE_SCALE.x, 0.15)
	_tween.parallel().tween_property(card_sprite, "rotation_degrees", 0.0, 0.15)

# ── 倾斜效果（每帧，仅 hover 时）────────────────────────────

func _process(_delta: float) -> void:
	if not _is_hovering:
		return
	var local_pos := card_sprite.to_local(get_global_mouse_position())
	var tex := card_sprite.texture as Texture2D
	var half_w: float = tex.get_width()  / 15.0 * 0.5
	var half_h: float = tex.get_height() / 5.0  * 0.5
	var nx: float = clamp(local_pos.x / half_w, -1.0, 1.0)
	var ny: float = clamp(local_pos.y / half_h, -1.0, 1.0)
	card_sprite.scale.x = BASE_SCALE.x * (1.0 - abs(nx) * TILT_SCALE_X)
	card_sprite.rotation_degrees = ny * TILT_ROT_MAX

func _tween_to(target_y: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(card_sprite, "position:y", target_y, 0.15)

# tscn 里的 Area2D 信号保留（编辑器连接用），实际逻辑走上面
func _on_card_area_mouse_entered() -> void:
	pass
func _on_card_area_mouse_exited() -> void:
	pass
func _on_card_area_input_event(_viewport: Node, _event: InputEvent, _shape_idx: int) -> void:
	pass
