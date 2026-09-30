extends Control

signal slot_pressed(slot_index)
signal drag_started(slot_index)
signal drag_moved(slot_index, pointer_position)
signal drag_released(slot_index, pointer_position)

var slot_index := -1
var face_down := true
var card = null
var assigned_rank := 0
var interactive := false
var highlighted := false
var dimmed := false
var placeholder_text := ""
var position_hint := ""

var draggable := false
var dragging := false
var drag_offset := Vector2.ZERO
var drag_home := Vector2.ZERO

var hovered := false
var _scale_tween: Tween = null

var back_texture = preload("res://assets/cards/backs/card_back.svg")

static var texture_cache := {}

const IVORY = Color("#fbf6ea")
const GOLD = Color("#e0b45b")
const FRAME_COLOR = Color("#c8ad79")

const CARD_ASPECT := 5.0 / 7.0
const HOVER_SCALE := 1.025
const DRAG_SCALE := 1.075

var art: TextureRect
var position_badge: Label
var joker_badge: Label


func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	pivot_offset = size * 0.5

	_create_art_layer()
	_create_badges()

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	_update_card_layout()
	_sync_visuals()

	queue_redraw()


func _create_art_layer():
	art = TextureRect.new()

	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	var shader = Shader.new()

	shader.code = """
shader_type canvas_item;

uniform float radius = 0.045;
uniform float aspect = 0.7142857;
uniform float border_width = 0.007;
uniform vec4 border_color : source_color = vec4(0.78, 0.67, 0.47, 1.0);

void fragment() {
	vec2 centered = abs(UV - vec2(0.5));

	vec2 q = vec2(
		centered.x * aspect,
		centered.y
	);

	vec2 bounds = vec2(
		0.5 * aspect - radius,
		0.5 - radius
	);

	vec2 corner = q - bounds;

	float distance_field =
		length(max(corner, vec2(0.0))) +
		min(max(corner.x, corner.y), 0.0) -
		radius;

	if (distance_field > 0.0) {
		discard;
	}

	vec4 tex = texture(TEXTURE, UV);

	if (distance_field > -border_width) {
		float edge = smoothstep(
			-border_width,
			0.0,
			distance_field
		);

		tex = mix(
			tex,
			border_color,
			edge
		);
	}

	COLOR = tex;
}
"""

	var material = ShaderMaterial.new()
	material.shader = shader

	art.material = material

	add_child(art)


func _create_badges():
	position_badge = Label.new()
	position_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	position_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	position_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	position_badge.add_theme_font_size_override("font_size", 14)
	position_badge.add_theme_color_override("font_color", GOLD)

	var position_style = StyleBoxFlat.new()
	position_style.bg_color = Color(0.08, 0.04, 0.025, 0.88)
	position_style.border_color = Color("#d8ad62")
	position_style.set_border_width_all(1)
	position_style.corner_radius_top_left = 7
	position_style.corner_radius_top_right = 7
	position_style.corner_radius_bottom_left = 7
	position_style.corner_radius_bottom_right = 7

	position_badge.add_theme_stylebox_override(
		"normal",
		position_style
	)

	position_badge.visible = false

	add_child(position_badge)


	joker_badge = Label.new()
	joker_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joker_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	joker_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	joker_badge.add_theme_font_size_override("font_size", 9)
	joker_badge.add_theme_color_override("font_color", GOLD)

	var joker_style = StyleBoxFlat.new()
	joker_style.bg_color = Color(0.08, 0.04, 0.025, 0.92)
	joker_style.border_color = GOLD
	joker_style.set_border_width_all(1)
	joker_style.corner_radius_top_left = 6
	joker_style.corner_radius_top_right = 6
	joker_style.corner_radius_bottom_left = 6
	joker_style.corner_radius_bottom_right = 6

	joker_badge.add_theme_stylebox_override(
		"normal",
		joker_style
	)

	joker_badge.visible = false

	add_child(joker_badge)


func configure(index, data, is_face_down, joker_value := 0):
	slot_index = index
	card = data
	face_down = is_face_down
	assigned_rank = joker_value

	_sync_visuals()
	queue_redraw()


func set_interactive(value, glow := false):
	interactive = value
	highlighted = glow

	if value or draggable:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		mouse_default_cursor_shape = Control.CURSOR_ARROW

	queue_redraw()


func set_draggable(value):
	draggable = value

	if value:
		drag_home = position
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_DRAG
	else:
		dragging = false
		z_index = 0

		mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND
			if interactive
			else Control.CURSOR_ARROW
		)

		_tween_scale(
			Vector2.ONE,
			0.08
		)


func set_drag_home(new_home):
	drag_home = new_home


func snap_home():
	dragging = false
	z_index = 0

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(
		self,
		"position",
		drag_home,
		0.18
	)

	_tween_scale(
		Vector2.ONE,
		0.10
	)


func set_placeholder(text):
	placeholder_text = text
	card = null
	face_down = false

	_sync_visuals()
	queue_redraw()


func set_position_hint(text):
	position_hint = text

	_sync_badges()
	queue_redraw()


func pulse():
	_tween_scale(
		Vector2.ONE,
		0.01
	)

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(
		self,
		"scale",
		Vector2(1.055, 1.055),
		0.09
	)

	tween.tween_property(
		self,
		"scale",
		Vector2.ONE,
		0.14
	)


func _gui_input(event):
	if draggable:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					_start_drag(event.position)
				else:
					_finish_drag(
						get_global_mouse_position()
					)

				accept_event()
				return

		if event is InputEventMouseMotion and dragging:
			_move_drag(
				get_global_mouse_position()
			)

			accept_event()
			return

		if event is InputEventScreenTouch:
			if event.pressed:
				_start_drag(event.position)
			else:
				_finish_drag(event.position)

			accept_event()
			return

		if event is InputEventScreenDrag and dragging:
			_move_drag(event.position)

			accept_event()
			return

	if not interactive:
		return

	if event is InputEventMouseButton:
		if (
			event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed
		):
			slot_pressed.emit(slot_index)
			accept_event()

	elif event is InputEventScreenTouch:
		if event.pressed:
			slot_pressed.emit(slot_index)
			accept_event()


func _start_drag(pointer_position):
	if not draggable:
		return

	dragging = true
	drag_home = position

	var global_pointer = pointer_position

	if (
		pointer_position.x <= size.x
		and pointer_position.y <= size.y
	):
		global_pointer = (
			global_position +
			pointer_position
		)

	drag_offset = (
		global_pointer -
		global_position
	)

	z_index = 100

	_tween_scale(
		Vector2.ONE * DRAG_SCALE,
		0.08,
		Tween.TRANS_BACK
	)

	drag_started.emit(slot_index)

	queue_redraw()


func _move_drag(pointer_position):
	if not dragging:
		return

	global_position = (
		pointer_position -
		drag_offset
	)

	drag_moved.emit(
		slot_index,
		pointer_position
	)


func _finish_drag(pointer_position):
	if not dragging:
		return

	dragging = false
	z_index = 0

	_tween_scale(
		Vector2.ONE,
		0.08
	)

	drag_released.emit(
		slot_index,
		pointer_position
	)

	queue_redraw()


func _on_mouse_entered():
	hovered = true

	if dragging:
		return

	if interactive or draggable:
		_tween_scale(
			Vector2.ONE * HOVER_SCALE,
			0.08
		)


func _on_mouse_exited():
	hovered = false

	if dragging:
		return

	_tween_scale(
		Vector2.ONE,
		0.08
	)


func _tween_scale(
	target_scale: Vector2,
	duration: float,
	transition := Tween.TRANS_QUAD
):
	if (
		_scale_tween != null
		and _scale_tween.is_valid()
	):
		_scale_tween.kill()

	_scale_tween = create_tween()

	_scale_tween.set_trans(
		transition
	)

	_scale_tween.set_ease(
		Tween.EASE_OUT
	)

	_scale_tween.tween_property(
		self,
		"scale",
		target_scale,
		duration
	)


func _notification(what):
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size * 0.5

		if art != null:
			_update_card_layout()

		queue_redraw()


func _update_card_layout():
	var rect = _get_card_rect()

	art.position = rect.position
	art.size = rect.size

	if art.material is ShaderMaterial:
		art.material.set_shader_parameter(
			"aspect",
			rect.size.x / rect.size.y
		)

	if position_badge != null:
		position_badge.position = Vector2(
			rect.position.x +
			rect.size.x * 0.5 -
			18,
			rect.position.y + 7
		)

		position_badge.size = Vector2(
			36,
			27
		)

	if joker_badge != null:
		var badge_width = min(
			rect.size.x - 10.0,
			74.0
		)

		joker_badge.position = Vector2(
			rect.position.x +
			(rect.size.x - badge_width) * 0.5,
			rect.position.y +
			rect.size.y -
			25
		)

		joker_badge.size = Vector2(
			badge_width,
			20
		)


func _sync_visuals():
	if art == null:
		return

	if face_down:
		art.texture = back_texture
		art.visible = true
		art.stretch_mode = TextureRect.STRETCH_SCALE

	elif card != null:
		art.texture = _get_card_texture()
		art.visible = art.texture != null

		if _is_number_card():
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		else:
			art.stretch_mode = TextureRect.STRETCH_SCALE

	else:
		art.texture = null
		art.visible = false

	if dimmed:
		art.modulate = Color(
			0.62,
			0.62,
			0.62,
			1.0
		)
	else:
		art.modulate = Color.WHITE

	_sync_badges()
	
func _is_number_card() -> bool:
	if card == null:
		return false

	if card.get("joker", false):
		return false

	var rank = int(
		card.get("rank", 0)
	)

	return rank >= 2 and rank <= 10


func _sync_badges():
	if position_badge != null:
		position_badge.text = position_hint

		position_badge.visible = (
			face_down
			and position_hint != ""
		)

	if joker_badge != null:
		if (
			card != null
			and card.get("joker", false)
			and assigned_rank > 0
			and not face_down
		):
			joker_badge.text = (
				"WILD → %s"
				% rank_label(assigned_rank)
			)

			joker_badge.visible = true

		else:
			joker_badge.visible = false


func _draw():
	var rect = _get_card_rect()

	var shadow_offset = Vector2(
		4,
		6
	)

	var shadow_alpha = 0.28

	if dragging:
		shadow_offset = Vector2(
			7,
			10
		)

		shadow_alpha = 0.42

	var shadow = StyleBoxFlat.new()

	shadow.bg_color = Color(
		0,
		0,
		0,
		shadow_alpha
	)

	shadow.corner_radius_top_left = 9
	shadow.corner_radius_top_right = 9
	shadow.corner_radius_bottom_left = 9
	shadow.corner_radius_bottom_right = 9

	draw_style_box(
		shadow,
		Rect2(
			rect.position +
			shadow_offset,
			rect.size
		)
	)

	if card == null and not face_down:
		_draw_placeholder(
			rect
		)

	if highlighted:
		var glow = StyleBoxFlat.new()

		glow.bg_color = Color(
			0,
			0,
			0,
			0
		)

		glow.border_color = GOLD
		glow.set_border_width_all(3)

		glow.corner_radius_top_left = 11
		glow.corner_radius_top_right = 11
		glow.corner_radius_bottom_left = 11
		glow.corner_radius_bottom_right = 11

		draw_style_box(
			glow,
			Rect2(
				rect.position -
				Vector2(4, 4),
				rect.size +
				Vector2(8, 8)
			)
		)


func _get_card_rect() -> Rect2:
	var available = Vector2(
		max(size.x, 1.0),
		max(size.y, 1.0)
	)

	var width = available.x
	var height = width / CARD_ASPECT

	if height > available.y:
		height = available.y
		width = height * CARD_ASPECT

	width = round(width)
	height = round(height)

	var card_size = Vector2(
		width,
		height
	)

	var card_position = (
		(available - card_size) *
		0.5
	).round()

	return Rect2(
		card_position,
		card_size
	)


func _get_card_texture():
	if card == null:
		return null

	var path := ""

	if card.get("joker", false):
		var joker_color = str(
			card.get(
				"color",
				card.get(
					"joker_color",
					"red"
				)
			)
		).to_lower()

		if joker_color == "black":
			path = (
				"res://assets/cards/faces/"
				+ "joker_black.png"
			)
		else:
			path = (
				"res://assets/cards/faces/"
				+ "joker_red.png"
			)

	else:
		var rank = int(
			card.get(
				"rank",
				0
			)
		)

		var suit = str(
			card.get(
				"suit",
				"S"
			)
		).to_upper()

		path = (
			"res://assets/cards/faces/%s%s.png"
			% [
				rank_label(rank),
				suit
			]
		)

	if texture_cache.has(path):
		return texture_cache[path]

	if not ResourceLoader.exists(path):
		push_warning(
			"Missing card texture: " +
			path
		)

		return null

	var texture = load(path)

	texture_cache[path] = texture

	return texture


func _draw_placeholder(rect):
	var face = StyleBoxFlat.new()

	face.bg_color = Color(
		0.10,
		0.055,
		0.035,
		0.72
	)

	face.border_color = FRAME_COLOR
	face.set_border_width_all(2)

	face.corner_radius_top_left = 9
	face.corner_radius_top_right = 9
	face.corner_radius_bottom_left = 9
	face.corner_radius_bottom_right = 9

	draw_style_box(
		face,
		rect
	)

	if placeholder_text == "":
		return

	var font = ThemeDB.fallback_font
	var fs = 13

	var text_width = font.get_string_size(
		placeholder_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		fs
	).x

	draw_string(
		font,
		Vector2(
			rect.position.x +
			(rect.size.x - text_width) *
			0.5,
			rect.position.y +
			rect.size.y *
			0.54
		),
		placeholder_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		fs,
		Color("#d9c5af")
	)


func rank_label(rank):
	if rank == 1:
		return "A"

	if rank == 11:
		return "J"

	if rank == 12:
		return "Q"

	if rank == 13:
		return "K"

	return str(rank)
