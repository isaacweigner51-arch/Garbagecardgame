extends Control

const CardView = preload("res://scripts/card_view.gd")
const CARD_SIZE = Vector2(96, 134)
const CARD_GAP = 14.0
const MAX_PER_ROW = 5
const JOKER_COUNT = 2
const SAVE_PATH = "user://garbage_profile.json"
const MENU_MUSIC_PATH = "res://audio/music_menu.mp3"
const GAMEPLAY_MUSIC_PATH = "res://audio/music_gameplay.mp3"

var difficulty := "Normal"
var player_level := 10
var ai_level := 10
var round_number := 1
var menu_selected_difficulty := "Normal"
var deck = []
var discard = []
var player_slots = []
var ai_slots = []
var player_views = []
var ai_views = []
var player_active = null
var ai_active = null
var turn := "player"
var phase := "menu"
var discard_rank_counts := {}

var game_layer
var menu_layer
var modal_layer
var video_layer
var video_player
var video_pause_button
var road_label
var tutorial_mode := false
var tutorial_step := 0
var opponent_label
var player_label
var turn_label
var instruction_label
var round_label
var draw_view
var discard_view
var active_view
var draw_count_label
var discard_button
var menu_button
var sound_slide
var sound_flip
var sound_place
var sound_discard_land
var sound_click
var sound_road
var music_player
var music_fade_tween
var current_music_path := ""
var background_rect
var background_wash
var collection_status_label
var intro_layer
var intro_finished := false

var profile_data = {}
var menu_points_label
var menu_rank_label
var continue_button
var match_points_earned := 0
var match_xp_earned := 0
var match_cards_placed := 0
var match_rounds_won := 0
var match_rounds_lost := 0
var match_started_unix := 0
var match_recent_unlocks = []

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_profile()
	_build_background()
	_build_audio()
	_build_game_layer()
	_build_menu()
	_build_video_tutorial()
	_show_opening_intro()

func _show_opening_intro():
	phase = "intro"
	intro_finished = false
	game_layer.visible = false
	menu_layer.visible = false
	if video_layer != null:
		video_layer.visible = false

	_play_music(MENU_MUSIC_PATH)

	if intro_layer != null:
		intro_layer.queue_free()

	intro_layer = Control.new()
	intro_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	intro_layer.z_index = 1000
	add_child(intro_layer)

	var shade = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.018, 0.009, 0.005, 0.96)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_layer.add_child(shade)

	var glow = ColorRect.new()
	glow.position = Vector2(86, 214)
	glow.size = Vector2(548, 670)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow_shader = Shader.new()
	glow_shader.code = """
shader_type canvas_item;
void fragment() {
	vec2 p = UV - vec2(0.5);
	float d = length(vec2(p.x * 0.86, p.y));
	float g = 1.0 - smoothstep(0.04, 0.66, d);
	COLOR = vec4(0.87, 0.48, 0.14, g * 0.16);
}
"""
	var glow_mat = ShaderMaterial.new()
	glow_mat.shader = glow_shader
	glow.material = glow_mat
	intro_layer.add_child(glow)

	var card = Panel.new()
	card.name = "IntroCard"
	card.position = Vector2(270, 336)
	card.size = Vector2(180, 252)
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2(0.76, 0.76)
	card.modulate.a = 0.0
	card.add_theme_stylebox_override("panel", _intro_card_back_style())
	intro_layer.add_child(card)

	var back_inner = Panel.new()
	back_inner.name = "BackInner"
	back_inner.position = Vector2(13, 13)
	back_inner.size = Vector2(154, 226)
	back_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_inner.add_theme_stylebox_override("panel", _intro_card_inner_style())
	card.add_child(back_inner)

	var back_mark = _make_label(
		"RTA",
		Vector2(20, 72),
		Vector2(114, 62),
		30,
		Color("#e6c07a"),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	back_mark.name = "BackMark"
	back_inner.add_child(back_mark)

	var back_sub = _make_label(
		"ROAD TO ACE",
		Vector2(12, 132),
		Vector2(130, 28),
		10,
		Color("#b58a52"),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	back_sub.name = "BackSub"
	back_inner.add_child(back_sub)

	var ace_label = _make_label(
		"A",
		Vector2(0, 42),
		Vector2(180, 108),
		82,
		Color("#2a1510"),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	ace_label.name = "AceLabel"
	ace_label.visible = false
	card.add_child(ace_label)

	var suit_label = _make_label(
		"♠",
		Vector2(0, 132),
		Vector2(180, 62),
		42,
		Color("#2a1510"),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	suit_label.name = "SuitLabel"
	suit_label.visible = false
	card.add_child(suit_label)

	var title = _make_label(
		"GARBAGE",
		Vector2(40, 638),
		Vector2(640, 66),
		42,
		Color("#f5e7d5"),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	title.name = "IntroTitle"
	title.modulate.a = 0.0
	title.position.y += 18
	intro_layer.add_child(title)

	var subtitle = _make_label(
		"ROAD TO ACE",
		Vector2(40, 696),
		Vector2(640, 44),
		21,
		Color("#e0b464"),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	subtitle.name = "IntroSubtitle"
	subtitle.modulate.a = 0.0
	subtitle.position.y += 18
	intro_layer.add_child(subtitle)

	var tagline = _make_label(
		"CLIMB FROM 10 TO ACE",
		Vector2(40, 754),
		Vector2(640, 30),
		11,
		Color("#a9937e"),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	tagline.name = "IntroTagline"
	tagline.modulate.a = 0.0
	intro_layer.add_child(tagline)

	var skip_button = Button.new()
	skip_button.name = "IntroSkip"
	skip_button.text = "TAP / CLICK TO SKIP"
	skip_button.position = Vector2(0, 0)
	skip_button.size = Vector2(720, 1280)
	skip_button.flat = true
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.add_theme_font_size_override("font_size", 10)
	skip_button.add_theme_color_override("font_color", Color(1, 1, 1, 0))
	skip_button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 0))
	skip_button.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 0))
	skip_button.pressed.connect(_finish_opening_intro)
	intro_layer.add_child(skip_button)

	var skip_hint = _make_label(
		"TAP / CLICK TO SKIP",
		Vector2(40, 1168),
		Vector2(640, 28),
		10,
		Color(0.78, 0.69, 0.60, 0.66),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	skip_hint.name = "IntroSkipHint"
	skip_hint.modulate.a = 0.0
	skip_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_layer.add_child(skip_hint)

	_run_opening_intro_animation(card, title, subtitle, tagline, skip_hint)

func _run_opening_intro_animation(card, title, subtitle, tagline, skip_hint):
	var enter = create_tween().set_parallel(true)
	enter.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	enter.tween_property(card, "scale", Vector2.ONE, 0.42)
	enter.tween_property(card, "modulate:a", 1.0, 0.26)
	enter.tween_property(card, "position:y", 322.0, 0.42)
	await enter.finished
	if intro_finished:
		return

	await get_tree().create_timer(0.22).timeout
	if intro_finished:
		return

	var close = create_tween()
	close.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	close.tween_property(card, "scale:x", 0.035, 0.12)
	await close.finished
	if intro_finished:
		return

	_intro_reveal_ace(card)
	_play_sfx(sound_flip, 0.97, 1.02)
	_haptic(18)

	var open = create_tween()
	open.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	open.tween_property(card, "scale:x", 1.0, 0.17)
	await open.finished
	if intro_finished:
		return

	var reveal = create_tween().set_parallel(true)
	reveal.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reveal.tween_property(title, "modulate:a", 1.0, 0.28)
	reveal.tween_property(title, "position:y", 638.0, 0.34)
	reveal.tween_property(subtitle, "modulate:a", 1.0, 0.34).set_delay(0.08)
	reveal.tween_property(subtitle, "position:y", 696.0, 0.34).set_delay(0.08)
	reveal.tween_property(tagline, "modulate:a", 1.0, 0.34).set_delay(0.16)
	reveal.tween_property(skip_hint, "modulate:a", 1.0, 0.30).set_delay(0.38)
	await get_tree().create_timer(1.42).timeout
	if intro_finished:
		return

	_finish_opening_intro()

func _intro_reveal_ace(card):
	card.add_theme_stylebox_override("panel", _intro_card_face_style())
	var back_inner = card.get_node_or_null("BackInner")
	if back_inner != null:
		back_inner.visible = false
	var ace_label = card.get_node_or_null("AceLabel")
	if ace_label != null:
		ace_label.visible = true
	var suit_label = card.get_node_or_null("SuitLabel")
	if suit_label != null:
		suit_label.visible = true

func _finish_opening_intro():
	if intro_finished:
		return
	intro_finished = true
	_show_menu()
	if intro_layer == null or not is_instance_valid(intro_layer):
		return
	intro_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fade = create_tween()
	fade.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	fade.tween_property(intro_layer, "modulate:a", 0.0, 0.28)
	fade.tween_callback(Callable(self, "_free_intro_layer"))

func _free_intro_layer():
	if intro_layer != null and is_instance_valid(intro_layer):
		intro_layer.queue_free()
	intro_layer = null

func _intro_card_back_style():
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#3a170f")
	style.border_color = Color("#d0a15a")
	style.set_border_width_all(3)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.shadow_color = Color(0, 0, 0, 0.54)
	style.shadow_size = 18
	return style

func _intro_card_inner_style():
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#24100b")
	style.border_color = Color("#8d5e32")
	style.set_border_width_all(2)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	return style

func _intro_card_face_style():
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#f0e4cf")
	style.border_color = Color("#d6a85b")
	style.set_border_width_all(3)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.shadow_color = Color(0, 0, 0, 0.50)
	style.shadow_size = 18
	return style

func _build_background():
	background_rect = ColorRect.new()
	background_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_rect.material = _theme_material(_equipped_theme_id())
	add_child(background_rect)

	background_wash = ColorRect.new()
	background_wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background_wash)
	_apply_theme_wash(_equipped_theme_id())

func _theme_definitions():
	return [
		{
			"id": "walnut",
			"name": "CLASSIC WALNUT",
			"description": "Warm wood • the original Road to Ace table",
			"price": 0,
			"pattern": 0.0,
			"top": "#35170d",
			"bottom": "#120805",
			"accent": "#d08a46",
			"wash": "#190704",
			"wash_alpha": 0.08
		},
		{
			"id": "emerald",
			"name": "EMERALD FELT",
			"description": "Deep green felt • old-school card room",
			"price": 150,
			"pattern": 1.0,
			"top": "#0b4634",
			"bottom": "#031a14",
			"accent": "#d4b463",
			"wash": "#001a10",
			"wash_alpha": 0.08
		},
		{
			"id": "midnight",
			"name": "MIDNIGHT CLUB",
			"description": "Navy velvet • cool late-night table",
			"price": 300,
			"pattern": 2.0,
			"top": "#15233e",
			"bottom": "#060914",
			"accent": "#6e88d8",
			"wash": "#030713",
			"wash_alpha": 0.10
		},
		{
			"id": "desert",
			"name": "DESERT SUNSET",
			"description": "Burnt copper • Arizona-after-dark warmth",
			"price": 450,
			"pattern": 3.0,
			"top": "#7a3519",
			"bottom": "#281009",
			"accent": "#f0a050",
			"wash": "#351006",
			"wash_alpha": 0.07
		},
		{
			"id": "neon",
			"name": "NEON AFTER DARK",
			"description": "Black violet • subtle electric glow",
			"price": 650,
			"pattern": 2.0,
			"top": "#1e1034",
			"bottom": "#05030b",
			"accent": "#cb5bff",
			"wash": "#10001e",
			"wash_alpha": 0.09
		},
		{
			"id": "ace_room",
			"name": "THE ACE ROOM",
			"description": "Black & gold • earned by completing the Road",
			"price": -1,
			"achievement": "road_complete",
			"pattern": 4.0,
			"top": "#211b11",
			"bottom": "#070604",
			"accent": "#f0ca72",
			"wash": "#120d05",
			"wash_alpha": 0.06
		}
	]

func _theme_definition(theme_id):
	for item in _theme_definitions():
		if str(item.get("id", "")) == str(theme_id):
			return item
	return _theme_definitions()[0]

func _theme_shader():
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(0.20, 0.08, 0.04, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.05, 0.02, 0.01, 1.0);
uniform vec4 accent_color : source_color = vec4(0.80, 0.52, 0.24, 1.0);
uniform float pattern = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	float n = noise2d(uv * vec2(34.0, 52.0));
	vec3 col = mix(top_color.rgb, bottom_color.rgb, uv.y);

	if (pattern < 0.5) {
		float grain = sin((uv.y + n * 0.055) * 170.0 + sin(uv.x * 15.0) * 2.4);
		col += grain * 0.022;
		float long_grain = sin((uv.y + noise2d(uv * 8.0) * 0.08) * 38.0);
		col += long_grain * 0.018;
	} else if (pattern < 1.5) {
		col += (n - 0.5) * 0.055;
		float fibers = sin((uv.x + uv.y) * 420.0) * 0.006;
		col += fibers;
	} else if (pattern < 2.5) {
		float bands = 0.5 + 0.5 * sin((uv.x * 1.2 + uv.y) * 22.0);
		col = mix(col, accent_color.rgb, bands * 0.055);
		col += (n - 0.5) * 0.032;
	} else if (pattern < 3.5) {
		float glow = 1.0 - smoothstep(0.08, 0.76, distance(uv, vec2(0.5, 0.42)));
		col = mix(col, accent_color.rgb, glow * 0.14);
		float sweep = sin((uv.x * 0.7 + uv.y) * 24.0 + n * 2.0) * 0.012;
		col += sweep;
	} else {
		float vein = sin((uv.x * 1.35 + uv.y) * 34.0 + n * 4.2) * 0.5 + 0.5;
		float gold = smoothstep(0.91, 1.0, vein);
		col = mix(col, accent_color.rgb, gold * 0.17);
		col += (n - 0.5) * 0.018;
	}

	float vignette = 1.0 - smoothstep(0.26, 0.83, distance(uv, vec2(0.5)));
	col *= mix(0.68, 1.03, vignette);
	COLOR = vec4(col, 1.0);
}
"""
	return shader

func _theme_material(theme_id):
	var item = _theme_definition(theme_id)
	var mat = ShaderMaterial.new()
	mat.shader = _theme_shader()
	mat.set_shader_parameter("top_color", Color(str(item.get("top", "#35170d"))))
	mat.set_shader_parameter("bottom_color", Color(str(item.get("bottom", "#120805"))))
	mat.set_shader_parameter("accent_color", Color(str(item.get("accent", "#d08a46"))))
	mat.set_shader_parameter("pattern", float(item.get("pattern", 0.0)))
	return mat

func _equipped_theme_id():
	var theme_id = str(profile_data.get("equipped_theme", "walnut"))
	if not _theme_is_owned(theme_id):
		return "walnut"
	return theme_id

func _theme_is_owned(theme_id):
	if str(theme_id) == "walnut":
		return true
	var item = _theme_definition(theme_id)
	var requirement = str(item.get("achievement", ""))
	if requirement != "":
		var achievements = profile_data.get("achievements", {})
		if bool(achievements.get(requirement, false)):
			return true
	var owned = profile_data.get("owned_themes", {})
	return bool(owned.get(str(theme_id), false))

func _apply_theme_wash(theme_id):
	if background_wash == null:
		return
	var item = _theme_definition(theme_id)
	var wash = Color(str(item.get("wash", "#190704")))
	wash.a = float(item.get("wash_alpha", 0.08))
	background_wash.color = wash

func _apply_equipped_theme():
	if background_rect == null:
		return
	var theme_id = _equipped_theme_id()
	background_rect.material = _theme_material(theme_id)
	_apply_theme_wash(theme_id)
	background_rect.modulate.a = 0.45
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(background_rect, "modulate:a", 1.0, 0.28)

func _build_audio():
	# Physical card SFX stay dry and forward; music sits much lower underneath.
	sound_slide = _make_sfx_player("res://audio/card_slide.wav", -14.0, 12)
	sound_flip = _make_sfx_player("res://audio/card_flip.wav", -11.5, 6)
	sound_place = _make_sfx_player("res://audio/card_place.wav", -12.0, 8)
	sound_discard_land = _make_sfx_player("res://audio/card_place.wav", -16.5, 6)
	sound_click = _make_sfx_player("res://audio/ui_click.wav", -16.0, 4)
	sound_road = _make_sfx_player("res://audio/road_advance.wav", -13.0, 3)

	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -60.0
	add_child(music_player)

func _make_sfx_player(path, volume_db, polyphony := 4):
	var player = AudioStreamPlayer.new()
	player.stream = load(path)
	player.volume_db = volume_db
	player.set_meta("base_volume_db", volume_db)
	player.max_polyphony = polyphony
	add_child(player)
	return player

func _play_sfx(player, pitch_min := 1.0, pitch_max := 1.0):
	if not _sound_enabled():
		return
	if player == null or player.stream == null:
		return
	var base_db = float(player.get_meta("base_volume_db", player.volume_db))
	var level = max(_sfx_volume(), 0.001)
	player.volume_db = base_db + linear_to_db(level)
	player.pitch_scale = randf_range(pitch_min, pitch_max)
	player.play()

func _music_target_db():
	var level = _music_volume()
	if level <= 0.001:
		return -60.0
	return linear_to_db(level)

func _play_music(path):
	if music_player == null:
		return
	if not _music_enabled():
		_stop_music_smooth()
		return
	if not ResourceLoader.exists(path):
		# Music files are optional during development; gameplay still runs without them.
		return
	if current_music_path == path and music_player.playing:
		_refresh_music_volume()
		return
	if music_fade_tween != null and music_fade_tween.is_valid():
		music_fade_tween.kill()
	if music_player.playing:
		music_fade_tween = create_tween()
		music_fade_tween.tween_property(music_player, "volume_db", -60.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		music_fade_tween.tween_callback(Callable(self, "_swap_music_stream").bind(path))
	else:
		_swap_music_stream(path)

func _swap_music_stream(path):
	if not _music_enabled() or not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if stream == null:
		return
	if stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamOggVorbis:
		stream.loop = true
	current_music_path = path
	music_player.stream = stream
	music_player.volume_db = -60.0
	music_player.play()
	if music_fade_tween != null and music_fade_tween.is_valid():
		music_fade_tween.kill()
	music_fade_tween = create_tween()
	music_fade_tween.tween_property(music_player, "volume_db", _music_target_db(), 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _stop_music_smooth():
	if music_player == null or not music_player.playing:
		return
	if music_fade_tween != null and music_fade_tween.is_valid():
		music_fade_tween.kill()
	music_fade_tween = create_tween()
	music_fade_tween.tween_property(music_player, "volume_db", -60.0, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	music_fade_tween.tween_callback(Callable(self, "_finish_music_stop"))

func _finish_music_stop():
	if music_player != null:
		music_player.stop()

func _refresh_music_volume():
	if music_player == null:
		return
	if not _music_enabled():
		_stop_music_smooth()
		return
	if music_player.playing:
		if music_fade_tween != null and music_fade_tween.is_valid():
			music_fade_tween.kill()
		music_fade_tween = create_tween()
		music_fade_tween.tween_property(music_player, "volume_db", _music_target_db(), 0.16)

func _haptic(milliseconds):
	if not _haptics_enabled():
		return
	Input.vibrate_handheld(milliseconds)

func _build_game_layer():
	game_layer = Control.new()
	game_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(game_layer)

	# ============================================================
	# WARM TABLETOP SHOWDOWN — BATTLE SCREEN
	# ============================================================

	# Soft spotlight over the center play area.
	var center_glow = ColorRect.new()
	center_glow.position = Vector2(72, 340)
	center_glow.size = Vector2(576, 430)
	center_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var glow_shader = Shader.new()
	glow_shader.code = """
shader_type canvas_item;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float d = length(vec2(p.x * 0.82, p.y));
	float glow = 1.0 - smoothstep(0.05, 0.70, d);
	COLOR = vec4(0.73, 0.35, 0.10, glow * 0.13);
}
"""

	var glow_material = ShaderMaterial.new()
	glow_material.shader = glow_shader
	center_glow.material = glow_material
	game_layer.add_child(center_glow)

	# ------------------------------------------------------------
	# TOP HUD
	# ------------------------------------------------------------

	var round_pill = Panel.new()
	round_pill.position = Vector2(28, 20)
	round_pill.size = Vector2(126, 42)
	round_pill.add_theme_stylebox_override("panel", _showdown_pill_style())
	game_layer.add_child(round_pill)

	round_label = _make_label(
		"ROUND 1",
		Vector2.ZERO,
		Vector2(126, 42),
		13,
		Color("#efc56e"),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	round_pill.add_child(round_label)

	var cpu_left_line = _showdown_line(Vector2(174, 41), Vector2(84, 1), 0.62)
	game_layer.add_child(cpu_left_line)

	var cpu_left_dot = _showdown_dot(Vector2(264, 39))
	game_layer.add_child(cpu_left_dot)

	opponent_label = _make_label(
		"CPU • 10 CARDS",
		Vector2(274, 20),
		Vector2(246, 42),
		20,
		Color("#f7ead9"),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	opponent_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.42))
	opponent_label.add_theme_constant_override("shadow_offset_y", 2)
	game_layer.add_child(opponent_label)

	var cpu_right_dot = _showdown_dot(Vector2(525, 39))
	game_layer.add_child(cpu_right_dot)

	var cpu_right_line = _showdown_line(Vector2(533, 41), Vector2(42, 1), 0.62)
	game_layer.add_child(cpu_right_line)

	menu_button = _make_button(
		"MENU",
		Rect2(590, 20, 102, 42),
		_on_menu_pressed,
		12
	)
	menu_button.add_theme_stylebox_override("normal", _showdown_menu_style(Color("#703824")))
	menu_button.add_theme_stylebox_override("hover", _showdown_menu_style(Color("#8b4930")))
	menu_button.add_theme_stylebox_override("pressed", _showdown_menu_style(Color("#51291c")))
	game_layer.add_child(menu_button)

	# Thin shadow line beneath the opponent's hand.
	var cpu_floor = ColorRect.new()
	cpu_floor.position = Vector2(88, 378)
	cpu_floor.size = Vector2(544, 2)
	cpu_floor.color = Color(0.03, 0.01, 0.005, 0.26)
	cpu_floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_layer.add_child(cpu_floor)

	# ------------------------------------------------------------
	# TURN MESSAGE
	# ------------------------------------------------------------

	turn_label = _make_label(
		"YOUR TURN",
		Vector2(100, 390),
		Vector2(520, 40),
		25,
		Color("#f3d58e"),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	turn_label.add_theme_color_override("font_shadow_color", Color(0.35, 0.15, 0.04, 0.72))
	turn_label.add_theme_constant_override("shadow_offset_y", 2)
	game_layer.add_child(turn_label)

	var turn_line = ColorRect.new()
	turn_line.position = Vector2(208, 433)
	turn_line.size = Vector2(304, 2)
	turn_line.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var line_shader = Shader.new()
	line_shader.code = """
shader_type canvas_item;

void fragment() {
	float x = abs(UV.x - 0.5) * 2.0;
	float alpha = 1.0 - smoothstep(0.0, 1.0, x);
	COLOR = vec4(0.96, 0.68, 0.29, alpha * 0.82);
}
"""

	var line_material = ShaderMaterial.new()
	line_material.shader = line_shader
	turn_line.material = line_material
	game_layer.add_child(turn_line)

	instruction_label = _make_label(
		"Draw a card or take the top discard.",
		Vector2(80, 438),
		Vector2(560, 58),
		14,
		Color("#ead9c4"),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	game_layer.add_child(instruction_label)

	# ------------------------------------------------------------
	# DRAW / DISCARD TABLE STATIONS
	# ------------------------------------------------------------

	var draw_mark = Panel.new()
	draw_mark.position = Vector2(188, 505)
	draw_mark.size = Vector2(160, 174)
	draw_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw_mark.add_theme_stylebox_override("panel", _showdown_table_mark_style())
	game_layer.add_child(draw_mark)

	var discard_mark = Panel.new()
	discard_mark.position = Vector2(372, 505)
	discard_mark.size = Vector2(160, 174)
	discard_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	discard_mark.add_theme_stylebox_override("panel", _showdown_table_mark_style())
	game_layer.add_child(discard_mark)

	var center_arc = ColorRect.new()
	center_arc.position = Vector2(346, 588)
	center_arc.size = Vector2(28, 1)
	center_arc.color = Color(0.80, 0.55, 0.28, 0.23)
	center_arc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_layer.add_child(center_arc)

	# Draw pile stack.
	var stack_back_1 = _create_card_view(-201, Vector2(212, 529))
	stack_back_1.face_down = true
	stack_back_1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack_back_1.modulate = Color(0.56, 0.56, 0.56, 0.48)
	game_layer.add_child(stack_back_1)

	var stack_back_2 = _create_card_view(-202, Vector2(216, 525))
	stack_back_2.face_down = true
	stack_back_2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack_back_2.modulate = Color(0.78, 0.78, 0.78, 0.72)
	game_layer.add_child(stack_back_2)

	draw_view = _create_card_view(-100, Vector2(220, 521))
	draw_view.face_down = true
	draw_view.set_interactive(false)
	game_layer.add_child(draw_view)
	draw_view.slot_pressed.connect(_on_pile_pressed)

	# Discard pile / active card location.
	discard_view = _create_card_view(-101, Vector2(404, 521))
	discard_view.set_placeholder("DISCARD")
	discard_view.slot_pressed.connect(_on_pile_pressed)
	game_layer.add_child(discard_view)

	active_view = _create_card_view(-102, Vector2(404, 521))
	active_view.visible = false
	active_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	active_view.z_index = 20
	game_layer.add_child(active_view)

	var draw_title = _make_label(
		"DRAW",
		Vector2(198, 661),
		Vector2(140, 24),
		12,
		Color("#f3e1c9"),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	game_layer.add_child(draw_title)

	draw_count_label = _make_label(
		"",
		Vector2(198, 682),
		Vector2(140, 20),
		10,
		Color("#bca080"),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	game_layer.add_child(draw_count_label)

	var discard_title = _make_label(
		"DISCARD",
		Vector2(382, 661),
		Vector2(140, 24),
		12,
		Color("#f3e1c9"),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	game_layer.add_child(discard_title)

	# Dead-card action only appears when needed.
	discard_button = _make_button(
		"DISCARD CARD",
		Rect2(255, 709, 210, 44),
		_on_discard_pressed,
		13
	)
	discard_button.visible = false
	discard_button.add_theme_stylebox_override("normal", _showdown_menu_style(Color("#713621")))
	discard_button.add_theme_stylebox_override("hover", _showdown_menu_style(Color("#91482b")))
	discard_button.add_theme_stylebox_override("pressed", _showdown_menu_style(Color("#542719")))
	game_layer.add_child(discard_button)

	# ------------------------------------------------------------
	# PLAYER HEADING
	# ------------------------------------------------------------

	var you_left_line = _showdown_line(Vector2(106, 790), Vector2(132, 1), 0.58)
	game_layer.add_child(you_left_line)

	var you_left_dot = _showdown_dot(Vector2(240, 788))
	game_layer.add_child(you_left_dot)

	player_label = _make_label(
		"YOU • 10 CARDS",
		Vector2(246, 769),
		Vector2(228, 42),
		20,
		Color("#f7ead9"),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	player_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.42))
	player_label.add_theme_constant_override("shadow_offset_y", 2)
	game_layer.add_child(player_label)

	var you_right_dot = _showdown_dot(Vector2(476, 788))
	game_layer.add_child(you_right_dot)

	var you_right_line = _showdown_line(Vector2(484, 790), Vector2(130, 1), 0.58)
	game_layer.add_child(you_right_line)

	# ------------------------------------------------------------
	# ROAD TO ACE PANEL
	# ------------------------------------------------------------

	var road_panel = Panel.new()
	road_panel.name = "RoadPanel"
	road_panel.position = Vector2(34, 1110)
	road_panel.size = Vector2(652, 126)
	road_panel.add_theme_stylebox_override("panel", _showdown_road_style())
	game_layer.add_child(road_panel)

	var road_title_left = _showdown_line(Vector2(40, 26), Vector2(176, 1), 0.52)
	road_panel.add_child(road_title_left)

	var road_title = _make_label(
		"ROAD TO ACE",
		Vector2(224, 10),
		Vector2(204, 32),
		13,
		Color("#e7b85d"),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	road_panel.add_child(road_title)

	var road_title_right = _showdown_line(Vector2(436, 26), Vector2(176, 1), 0.52)
	road_panel.add_child(road_title_right)

	road_label = _make_label(
		"",
		Vector2.ZERO,
		Vector2.ZERO,
		1,
		Color.TRANSPARENT,
		HORIZONTAL_ALIGNMENT_LEFT
	)
	road_label.visible = false
	road_panel.add_child(road_label)

	var road_dynamic = Control.new()
	road_dynamic.name = "RoadDynamic"
	road_dynamic.position = Vector2.ZERO
	road_dynamic.size = road_panel.size
	road_dynamic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	road_panel.add_child(road_dynamic)

	_update_road_progress()


func _showdown_line(pos, line_size, alpha := 0.60):
	var line = ColorRect.new()
	line.position = pos
	line.size = line_size
	line.color = Color(0.68, 0.45, 0.22, alpha)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _showdown_dot(pos):
	var dot = Panel.new()
	dot.position = pos
	dot.size = Vector2(5, 5)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	style.bg_color = Color("#d4a353")
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	dot.add_theme_stylebox_override("panel", style)

	return dot


func _showdown_pill_style():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.052, 0.026, 0.88)
	style.border_color = Color("#a97a3d")
	style.set_border_width_all(2)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.shadow_color = Color(0, 0, 0, 0.30)
	style.shadow_size = 7
	return style


func _showdown_menu_style(bg_color):
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = Color("#b57b45")
	style.set_border_width_all(2)
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
	style.shadow_color = Color(0, 0, 0, 0.32)
	style.shadow_size = 7
	return style


func _showdown_table_mark_style():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.045, 0.020, 0.10)
	style.border_color = Color(0.78, 0.53, 0.27, 0.28)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 72
	style.corner_radius_top_right = 72
	style.corner_radius_bottom_left = 72
	style.corner_radius_bottom_right = 72
	return style


func _showdown_road_style():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.050, 0.023, 0.016, 0.95)
	style.border_color = Color("#9c6e3b")
	style.set_border_width_all(2)
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_left = 22
	style.corner_radius_bottom_right = 22
	style.shadow_color = Color(0, 0, 0, 0.50)
	style.shadow_size = 14
	return style


func _build_road_tracker_row(parent, row_name, y, level, is_player):
	var row_label = _make_label(
		row_name,
		Vector2(24, y - 14),
		Vector2(56, 28),
		11,
		Color("#e3c89e"),
		HORIZONTAL_ALIGNMENT_LEFT
	)
	parent.add_child(row_label)

	var stages = [10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
	var start_x = 92.0
	var spacing = 52.0
	var diameter = 28.0

	for i in range(stages.size()):
		var stage = stages[i]

		if i < stages.size() - 1:
			var connector = ColorRect.new()
			connector.position = Vector2(
				start_x + i * spacing + diameter,
				y - 1
			)
			connector.size = Vector2(spacing - diameter, 2)
			connector.mouse_filter = Control.MOUSE_FILTER_IGNORE

			if stage > level:
				connector.color = Color(0.86, 0.61, 0.27, 0.72)
			else:
				connector.color = Color(0.39, 0.31, 0.26, 0.58)

			parent.add_child(connector)

		var marker = Panel.new()
		marker.position = Vector2(
			start_x + i * spacing,
			y - diameter * 0.5
		)
		marker.size = Vector2(diameter, diameter)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var marker_style = StyleBoxFlat.new()

		if stage == level:
			if is_player:
				marker_style.bg_color = Color(0.84, 0.57, 0.20, 1.0)
			else:
				marker_style.bg_color = Color(0.63, 0.45, 0.24, 1.0)

			marker_style.border_color = Color("#f0c66c")
			marker_style.shadow_color = Color(0.92, 0.62, 0.20, 0.42)
			marker_style.shadow_size = 7

		elif stage > level:
			marker_style.bg_color = Color(0.38, 0.26, 0.15, 0.96)
			marker_style.border_color = Color("#bd8843")

		else:
			marker_style.bg_color = Color(0.095, 0.068, 0.057, 0.96)
			marker_style.border_color = Color("#59483d")

		marker_style.set_border_width_all(2)
		marker_style.corner_radius_top_left = 14
		marker_style.corner_radius_top_right = 14
		marker_style.corner_radius_bottom_left = 14
		marker_style.corner_radius_bottom_right = 14
		marker.add_theme_stylebox_override("panel", marker_style)
		parent.add_child(marker)

		var stage_text = "A" if stage == 1 else str(stage)
		var marker_label = _make_label(
			stage_text,
			Vector2.ZERO,
			Vector2(diameter, diameter),
			10,
			Color("#f7e8cf"),
			HORIZONTAL_ALIGNMENT_CENTER
		)
		marker.add_child(marker_label)

func _build_menu():
	menu_layer = Control.new()
	menu_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(menu_layer)

	var veil = ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.05, 0.018, 0.008, 0.28)
	menu_layer.add_child(veil)

	var profile_panel = Panel.new()
	profile_panel.position = Vector2(22, 18)
	profile_panel.size = Vector2(232, 52)
	profile_panel.add_theme_stylebox_override("panel", _panel_style(Color("#24140e"), Color("#8d673f"), 14, 0.88))
	menu_layer.add_child(profile_panel)

	menu_rank_label = _make_label("LEVEL 1 • TABLE ROOKIE", Vector2(12, 4), Vector2(208, 22), 11, Color("#d9b978"), HORIZONTAL_ALIGNMENT_LEFT)
	profile_panel.add_child(menu_rank_label)
	menu_points_label = _make_label("0 POINTS", Vector2(12, 24), Vector2(208, 22), 12, Color("#f6ead6"), HORIZONTAL_ALIGNMENT_LEFT)
	profile_panel.add_child(menu_points_label)

	var profile_button = _make_button("PROFILE", Rect2(394, 20, 94, 42), Callable(self, "_show_profile"), 11)
	menu_layer.add_child(profile_button)
	var style_button = _make_button("STYLE", Rect2(496, 20, 94, 42), Callable(self, "_show_style_collection"), 11)
	menu_layer.add_child(style_button)
	var settings_button = _make_button("SETTINGS", Rect2(598, 20, 100, 42), Callable(self, "_show_settings"), 10)
	menu_layer.add_child(settings_button)

	var title = _make_label(
		"GARBAGE",
		Vector2(60, 78),
		Vector2(600, 76),
		62,
		Color("#f7eadc"),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	menu_layer.add_child(title)

	var subtitle = _make_label(
		"ROAD TO ACE",
		Vector2(60, 146),
		Vector2(600, 36),
		20,
		Color("#e0b45b"),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	menu_layer.add_child(subtitle)

	var tagline = _make_label(
		"Win rounds. Drop a card. Reach the final Ace.",
		Vector2(70, 190),
		Vector2(580, 38),
		16,
		Color("#d7c5b3"),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	menu_layer.add_child(tagline)

	title.modulate.a = 0.0
	title.position.y -= 22

	subtitle.modulate.a = 0.0
	subtitle.position.y -= 16

	tagline.modulate.a = 0.0

	var title_tween = create_tween()
	title_tween.set_parallel(true)
	title_tween.set_trans(Tween.TRANS_QUAD)
	title_tween.set_ease(Tween.EASE_OUT)
	title_tween.tween_property(title, "modulate:a", 1.0, 0.35)
	title_tween.tween_property(title, "position:y", 78.0, 0.35)
	title_tween.tween_property(subtitle, "modulate:a", 1.0, 0.42).set_delay(0.10)
	title_tween.tween_property(subtitle, "position:y", 146.0, 0.42).set_delay(0.10)
	title_tween.tween_property(tagline, "modulate:a", 1.0, 0.40).set_delay(0.22)

	var card_center = Vector2(318, 300)

	var card_positions = [
		Vector2(228, 312),
		Vector2(268, 292),
		Vector2(318, 282),
		Vector2(368, 292),
		Vector2(408, 312)
	]

	var card_rotations = [
		deg_to_rad(-24.0),
		deg_to_rad(-12.0),
		deg_to_rad(0.0),
		deg_to_rad(12.0),
		deg_to_rad(24.0)
	]

	for i in range(5):
		var card = Panel.new()
		card.position = card_center
		card.size = Vector2(96, 138)
		card.pivot_offset = card.size * 0.5
		card.rotation = 0.0
		card.modulate.a = 0.0

		card.add_theme_stylebox_override(
			"panel",
			_panel_style(
				Color("#741d1f"),
				Color("#ddb98a"),
				12,
				1.0
			)
		)

		menu_layer.add_child(card)

		var inner = Panel.new()
		inner.position = Vector2(9, 9)
		inner.size = Vector2(78, 120)

		inner.add_theme_stylebox_override(
			"panel",
			_panel_style(
				Color("#581317"),
				Color("#bd8d67"),
				8,
				1.0
			)
		)

		card.add_child(inner)

		var diamond = _make_label(
			"♦",
			Vector2(0, 35),
			Vector2(78, 50),
			34,
			Color("#d7aa7e"),
			HORIZONTAL_ALIGNMENT_CENTER
		)
		inner.add_child(diamond)

		var card_tween = create_tween()
		card_tween.set_parallel(true)
		card_tween.set_trans(Tween.TRANS_BACK)
		card_tween.set_ease(Tween.EASE_OUT)

		card_tween.tween_property(
			card,
			"position",
			card_positions[i],
			0.48
		).set_delay(0.18 + (i * 0.06))

		card_tween.tween_property(
			card,
			"rotation",
			card_rotations[i],
			0.48
		).set_delay(0.18 + (i * 0.06))

		card_tween.tween_property(
			card,
			"modulate:a",
			1.0,
			0.30
		).set_delay(0.18 + (i * 0.06))

	var choose_label = _make_label(
		"CHOOSE YOUR TABLE",
		Vector2(40, 474),
		Vector2(640, 28),
		14,
		Color("#b89a7d"),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	menu_layer.add_child(choose_label)

	var easy_button = _make_button(
		"EASY",
		Rect2(72, 518, 176, 86),
		Callable(self, "_select_menu_difficulty").bind("Easy"),
		17
	)
	easy_button.name = "EasyButton"
	menu_layer.add_child(easy_button)

	var normal_button = _make_button(
		"NORMAL",
		Rect2(272, 518, 176, 86),
		Callable(self, "_select_menu_difficulty").bind("Normal"),
		17
	)
	normal_button.name = "NormalButton"
	menu_layer.add_child(normal_button)

	var hard_button = _make_button(
		"HARD",
		Rect2(472, 518, 176, 86),
		Callable(self, "_select_menu_difficulty").bind("Hard"),
		17
	)
	hard_button.name = "HardButton"
	menu_layer.add_child(hard_button)

	var easy_sub = _make_label(
		"RELAXED • BASE POINTS",
		Vector2(72, 576),
		Vector2(176, 22),
		9,
		Color("#c1aa96"),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	easy_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(easy_sub)

	var normal_sub = _make_label(
		"CLASSIC • MORE POINTS",
		Vector2(272, 576),
		Vector2(176, 22),
		9,
		Color("#c1aa96"),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	normal_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(normal_sub)

	var hard_sub = _make_label(
		"SHARP • MOST POINTS",
		Vector2(472, 576),
		Vector2(176, 22),
		9,
		Color("#c1aa96"),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	hard_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(hard_sub)

	var play_button = _make_button(
		"PLAY NORMAL",
		Rect2(120, 632, 480, 72),
		Callable(self, "_play_selected_difficulty"),
		19
	)
	play_button.name = "PlayButton"

	play_button.add_theme_stylebox_override(
		"normal",
		_panel_style(
			Color("#8f432b"),
			Color("#dfaa6b"),
			16,
			1.0
		)
	)

	play_button.add_theme_stylebox_override(
		"hover",
		_panel_style(
			Color("#a95635"),
			Color("#f0c17e"),
			16,
			1.0
		)
	)

	menu_layer.add_child(play_button)

	continue_button = _make_button(
		"CONTINUE ROAD",
		Rect2(120, 714, 480, 50),
		Callable(self, "_continue_saved_match"),
		14
	)
	continue_button.name = "ContinueButton"
	continue_button.visible = false
	menu_layer.add_child(continue_button)

	var how_to_label = _make_label(
		"HOW TO PLAY",
		Vector2(40, 794),
		Vector2(640, 28),
		14,
		Color("#b89a7d"),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	menu_layer.add_child(how_to_label)

	var learn_button = _make_button(
		"♠  LEARN BY PLAYING",
		Rect2(86, 838, 258, 66),
		Callable(self, "_start_interactive_tutorial"),
		15
	)
	menu_layer.add_child(learn_button)

	var watch_button = _make_button(
		"▶  WATCH TUTORIAL",
		Rect2(376, 838, 258, 66),
		Callable(self, "_show_video_tutorial"),
		15
	)
	menu_layer.add_child(watch_button)

	var road_title = _make_label(
		"THE ROAD TO ACE",
		Vector2(40, 966),
		Vector2(640, 28),
		14,
		Color("#b89a7d"),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	menu_layer.add_child(road_title)

	var road_values = [
		"10",
		"9",
		"8",
		"7",
		"6",
		"5",
		"4",
		"3",
		"2",
		"A"
	]

	var start_x = 56.0
	var marker_width = 48.0
	var marker_gap = 14.0

	for i in range(road_values.size()):
		var marker = Panel.new()

		marker.position = Vector2(
			start_x + (i * (marker_width + marker_gap)),
			1020
		)

		marker.size = Vector2(marker_width, 62)
		marker.pivot_offset = marker.size * 0.5
		marker.scale = Vector2(0.72, 0.72)
		marker.modulate.a = 0.0

		marker.add_theme_stylebox_override(
			"panel",
			_panel_style(
				Color("#2c1912"),
				Color("#a37a50"),
				9,
				0.94
			)
		)

		menu_layer.add_child(marker)

		var marker_label = _make_label(
			road_values[i],
			Vector2(0, 11),
			Vector2(marker_width, 40),
			17,
			Color("#e5c47c"),
			HORIZONTAL_ALIGNMENT_CENTER
		)

		marker.add_child(marker_label)

		var marker_tween = create_tween()
		marker_tween.set_parallel(true)
		marker_tween.set_trans(Tween.TRANS_BACK)
		marker_tween.set_ease(Tween.EASE_OUT)

		marker_tween.tween_property(
			marker,
			"scale",
			Vector2.ONE,
			0.30
		).set_delay(0.55 + (i * 0.055))

		marker_tween.tween_property(
			marker,
			"modulate:a",
			1.0,
			0.24
		).set_delay(0.55 + (i * 0.055))

	var road_copy = _make_label(
		"Every round you win shrinks your layout by one card.",
		Vector2(60, 1108),
		Vector2(600, 44),
		14,
		Color("#c5b19d"),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	road_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_layer.add_child(road_copy)

	var footer = _make_label(
		"REVEAL THE FINAL ACE TO WIN THE MATCH",
		Vector2(60, 1158),
		Vector2(600, 34),
		12,
		Color("#d8ad62"),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	menu_layer.add_child(footer)

	var animated_controls = [
		choose_label,
		easy_button,
		normal_button,
		hard_button,
		play_button,
		continue_button,
		how_to_label,
		learn_button,
		watch_button,
		road_title
	]

	for i in range(animated_controls.size()):
		var control = animated_controls[i]

		var final_y = control.position.y

		control.position.y += 18
		control.modulate.a = 0.0

		var tween = create_tween()
		tween.set_parallel(true)
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)

		tween.tween_property(
			control,
			"position:y",
			final_y,
			0.35
		).set_delay(0.34 + (i * 0.045))

		tween.tween_property(
			control,
			"modulate:a",
			1.0,
			0.30
		).set_delay(0.34 + (i * 0.045))

	menu_selected_difficulty = "Normal"
	_refresh_menu_profile()
	_select_menu_difficulty("Normal")
	
func _default_profile():
	return {
		"version": 2,
		"points": 0,
		"xp": 0,
		"level": 1,
		"matches_played": 0,
		"matches_won": 0,
		"matches_lost": 0,
		"rounds_won": 0,
		"rounds_lost": 0,
		"current_win_streak": 0,
		"best_win_streak": 0,
		"hard_wins": 0,
		"cards_placed": 0,
		"jokers_played": 0,
		"best_road": 10,
		"achievements": {},
		"owned_themes": {
			"walnut": true
		},
		"equipped_theme": "walnut",
		"settings": {
			"sound": true,
			"music": true,
			"sfx_volume": 0.90,
			"music_volume": 0.12,
			"haptics": true
		},
		"active_run": {
			"valid": false
		}
	}

func _load_profile():
	profile_data = _default_profile()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for key in parsed.keys():
		if key in ["settings", "achievements", "active_run", "owned_themes"] and typeof(parsed[key]) == TYPE_DICTIONARY:
			for sub_key in parsed[key].keys():
				profile_data[key][sub_key] = parsed[key][sub_key]
		else:
			profile_data[key] = parsed[key]

func _save_profile():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(profile_data))

func _sound_enabled():
	var settings = profile_data.get("settings", {})
	return bool(settings.get("sound", true))

func _music_enabled():
	var settings = profile_data.get("settings", {})
	return bool(settings.get("music", true))

func _sfx_volume():
	var settings = profile_data.get("settings", {})
	return clampf(float(settings.get("sfx_volume", 0.90)), 0.0, 1.0)

func _music_volume():
	var settings = profile_data.get("settings", {})
	return clampf(float(settings.get("music_volume", 0.12)), 0.0, 1.0)

func _haptics_enabled():
	var settings = profile_data.get("settings", {})
	return bool(settings.get("haptics", true))

func _xp_needed(level):
	return 100 + max(0, level - 1) * 40

func _profile_rank():
	var level = int(profile_data.get("level", 1))
	if level >= 15:
		return "ROAD MASTER"
	if level >= 10:
		return "ACE HUNTER"
	if level >= 6:
		return "ROAD RUNNER"
	if level >= 3:
		return "TABLE REGULAR"
	return "TABLE ROOKIE"

func _refresh_menu_profile():
	if menu_layer == null:
		return
	if menu_points_label != null:
		menu_points_label.text = "%d POINTS" % int(profile_data.get("points", 0))
	if menu_rank_label != null:
		menu_rank_label.text = "LEVEL %d • %s" % [int(profile_data.get("level", 1)), _profile_rank()]
	if continue_button != null:
		var run = profile_data.get("active_run", {})
		var valid = bool(run.get("valid", false))
		continue_button.visible = valid
		if valid:
			continue_button.text = "CONTINUE ROAD  •  %s  •  YOU %s / CPU %s" % [
				str(run.get("difficulty", "Normal")).to_upper(),
				_stage_name(int(run.get("player_level", 10))),
				_stage_name(int(run.get("ai_level", 10)))
			]

func _save_active_run(round_override := -1):
	if tutorial_mode:
		return
	var saved_round = round_number if round_override < 0 else round_override
	profile_data["active_run"] = {
		"valid": true,
		"difficulty": difficulty,
		"player_level": player_level,
		"ai_level": ai_level,
		"round_number": saved_round,
		"match_points_earned": match_points_earned,
		"match_xp_earned": match_xp_earned,
		"match_cards_placed": match_cards_placed,
		"match_rounds_won": match_rounds_won,
		"match_rounds_lost": match_rounds_lost,
		"match_started_unix": match_started_unix,
		"match_recent_unlocks": match_recent_unlocks
	}
	_save_profile()

func _clear_active_run():
	profile_data["active_run"] = {"valid": false}
	_save_profile()

func _continue_saved_match():
	var run = profile_data.get("active_run", {})
	if not bool(run.get("valid", false)):
		return
	_play_music(GAMEPLAY_MUSIC_PATH)
	_play_sfx(sound_click, 0.985, 1.015)
	tutorial_mode = false
	tutorial_step = 0
	difficulty = str(run.get("difficulty", "Normal"))
	player_level = clampi(int(run.get("player_level", 10)), 1, 10)
	ai_level = clampi(int(run.get("ai_level", 10)), 1, 10)
	round_number = max(1, int(run.get("round_number", 1)))
	match_points_earned = int(run.get("match_points_earned", 0))
	match_xp_earned = int(run.get("match_xp_earned", 0))
	match_cards_placed = int(run.get("match_cards_placed", 0))
	match_rounds_won = int(run.get("match_rounds_won", 0))
	match_rounds_lost = int(run.get("match_rounds_lost", 0))
	match_started_unix = int(run.get("match_started_unix", int(Time.get_unix_time_from_system())))
	match_recent_unlocks = run.get("match_recent_unlocks", []).duplicate()
	menu_layer.visible = false
	game_layer.visible = true
	_start_round()

func _apply_rewards(points, xp):
	profile_data["points"] = int(profile_data.get("points", 0)) + points
	match_points_earned += points
	match_xp_earned += xp
	var level_up = false
	var current_xp = int(profile_data.get("xp", 0)) + xp
	var level = int(profile_data.get("level", 1))
	while current_xp >= _xp_needed(level):
		current_xp -= _xp_needed(level)
		level += 1
		level_up = true
	profile_data["xp"] = current_xp
	profile_data["level"] = level
	return level_up

func _record_round_result(winner):
	var points = 0
	var xp = 0
	if winner == "player":
		match_rounds_won += 1
		profile_data["rounds_won"] = int(profile_data.get("rounds_won", 0)) + 1
		if difficulty == "Easy":
			points = 10
			xp = 18
		elif difficulty == "Hard":
			points = 25
			xp = 35
		else:
			points = 15
			xp = 25
	else:
		match_rounds_lost += 1
		profile_data["rounds_lost"] = int(profile_data.get("rounds_lost", 0)) + 1
		if difficulty == "Easy":
			xp = 4
		elif difficulty == "Hard":
			xp = 8
		else:
			xp = 6
	var level_up = _apply_rewards(points, xp)
	return {
		"points": points,
		"xp": xp,
		"level_up": level_up,
		"achievements": []
	}

func _complete_match(winner, final_round_reward):
	profile_data["matches_played"] = int(profile_data.get("matches_played", 0)) + 1
	var bonus_points = 0
	var bonus_xp = 0
	if winner == "player":
		profile_data["matches_won"] = int(profile_data.get("matches_won", 0)) + 1
		profile_data["current_win_streak"] = int(profile_data.get("current_win_streak", 0)) + 1
		profile_data["best_win_streak"] = max(int(profile_data.get("best_win_streak", 0)), int(profile_data["current_win_streak"]))
		profile_data["best_road"] = 1
		if difficulty == "Hard":
			profile_data["hard_wins"] = int(profile_data.get("hard_wins", 0)) + 1
		if difficulty == "Easy":
			bonus_points = 40
			bonus_xp = 50
		elif difficulty == "Hard":
			bonus_points = 90
			bonus_xp = 110
		else:
			bonus_points = 60
			bonus_xp = 75
	else:
		profile_data["matches_lost"] = int(profile_data.get("matches_lost", 0)) + 1
		profile_data["current_win_streak"] = 0
		bonus_xp = 15
	_apply_rewards(bonus_points, bonus_xp)
	var unlocks = _check_achievements()
	if not unlocks.is_empty():
		final_round_reward["achievements"] = unlocks
		for unlock_title in unlocks:
			if not match_recent_unlocks.has(unlock_title):
				match_recent_unlocks.append(unlock_title)
	_clear_active_run()
	_save_profile()
	_show_match_over(winner)

func _achievement_definitions():
	return [
		{"id": "first_round", "title": "FIRST STEP", "description": "Win your first round.", "reward": 25},
		{"id": "road_complete", "title": "ROAD COMPLETE", "description": "Complete the Road to Ace once.", "reward": 75},
		{"id": "streak_three", "title": "HOT STREAK", "description": "Win 3 matches in a row.", "reward": 100},
		{"id": "hard_win", "title": "SHARP TABLE", "description": "Win a match on Hard.", "reward": 125},
		{"id": "century", "title": "CENTURY CLUB", "description": "Place 100 cards.", "reward": 100},
		{"id": "ten_wins", "title": "ACE CHASER", "description": "Win 10 matches.", "reward": 200}
	]

func _achievement_condition(id):
	match id:
		"first_round":
			return int(profile_data.get("rounds_won", 0)) >= 1
		"road_complete":
			return int(profile_data.get("matches_won", 0)) >= 1
		"streak_three":
			return int(profile_data.get("current_win_streak", 0)) >= 3
		"hard_win":
			return int(profile_data.get("hard_wins", 0)) >= 1
		"century":
			return int(profile_data.get("cards_placed", 0)) >= 100
		"ten_wins":
			return int(profile_data.get("matches_won", 0)) >= 10
	return false

func _check_achievements():
	var unlocked_titles = []
	var achievements = profile_data.get("achievements", {})
	for item in _achievement_definitions():
		var id = str(item["id"])
		if bool(achievements.get(id, false)):
			continue
		if _achievement_condition(id):
			achievements[id] = true
			var reward = int(item["reward"])
			profile_data["points"] = int(profile_data.get("points", 0)) + reward
			match_points_earned += reward
			unlocked_titles.append(str(item["title"]))
	profile_data["achievements"] = achievements
	return unlocked_titles

func _achievement_reward_total(unlocked_titles):
	var total = 0
	for title in unlocked_titles:
		for item in _achievement_definitions():
			if str(item["title"]) == str(title):
				total += int(item["reward"])
	return total

func _join_text(items, separator):
	var result = ""
	for i in range(items.size()):
		if i > 0:
			result += separator
		result += str(items[i])
	return result

func _format_match_time():
	if match_started_unix <= 0:
		return "0:00"
	var elapsed = max(0, int(Time.get_unix_time_from_system()) - match_started_unix)
	var minutes = int(elapsed / 60)
	var seconds = elapsed % 60
	return "%d:%02d" % [minutes, seconds]

func _show_profile():
	_play_sfx(sound_click, 0.985, 1.015)
	if modal_layer != null:
		modal_layer.queue_free()
	modal_layer = Control.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal_layer)
	var shade = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.01, 0.005, 0.78)
	modal_layer.add_child(shade)
	var panel = Panel.new()
	panel.position = Vector2(64, 190)
	panel.size = Vector2(592, 880)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#1d100b"), Color("#a2774f"), 24, 0.98))
	modal_layer.add_child(panel)
	panel.add_child(_make_label("PLAYER PROFILE", Vector2(30, 28), Vector2(532, 48), 30, Color("#f4e7d7"), HORIZONTAL_ALIGNMENT_CENTER))
	panel.add_child(_make_label("LEVEL %d • %s" % [int(profile_data.get("level", 1)), _profile_rank()], Vector2(30, 76), Vector2(532, 30), 14, Color("#d8ad62"), HORIZONTAL_ALIGNMENT_CENTER))
	var xp_text = "%d / %d XP TO NEXT LEVEL" % [int(profile_data.get("xp", 0)), _xp_needed(int(profile_data.get("level", 1)))]
	panel.add_child(_make_label(xp_text, Vector2(30, 110), Vector2(532, 24), 11, Color("#bfa98f"), HORIZONTAL_ALIGNMENT_CENTER))
	panel.add_child(_make_label("%d POINTS" % int(profile_data.get("points", 0)), Vector2(30, 142), Vector2(532, 36), 19, Color("#efc56e"), HORIZONTAL_ALIGNMENT_CENTER))

	var stats = "MATCHES   %d played   •   %d won   •   %d lost\nROUNDS      %d won   •   %d lost\nSTREAK      %d current   •   %d best\nCARDS       %d placed   •   %d Jokers\nBEST ROAD   %s" % [
		int(profile_data.get("matches_played", 0)),
		int(profile_data.get("matches_won", 0)),
		int(profile_data.get("matches_lost", 0)),
		int(profile_data.get("rounds_won", 0)),
		int(profile_data.get("rounds_lost", 0)),
		int(profile_data.get("current_win_streak", 0)),
		int(profile_data.get("best_win_streak", 0)),
		int(profile_data.get("cards_placed", 0)),
		int(profile_data.get("jokers_played", 0)),
		_stage_name(int(profile_data.get("best_road", 10)))
	]
	var stats_label = _make_label(stats, Vector2(52, 194), Vector2(488, 190), 14, Color("#e7d7c6"), HORIZONTAL_ALIGNMENT_LEFT)
	stats_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	panel.add_child(stats_label)

	panel.add_child(_make_label("ACHIEVEMENTS", Vector2(30, 398), Vector2(532, 30), 14, Color("#d8ad62"), HORIZONTAL_ALIGNMENT_CENTER))
	var y = 442.0
	var achievements = profile_data.get("achievements", {})
	for item in _achievement_definitions():
		var unlocked = bool(achievements.get(str(item["id"]), false))
		var state = "DONE" if unlocked else "LOCKED"
		var line = "%s   %s  —  %s   (+%d)" % [state, str(item["title"]), str(item["description"]), int(item["reward"])]
		panel.add_child(_make_label(line, Vector2(42, y), Vector2(508, 34), 11, Color("#f0dfca") if unlocked else Color("#8f7b6a"), HORIZONTAL_ALIGNMENT_LEFT))
		y += 50.0

	panel.add_child(_make_button("CLOSE", Rect2(166, 804, 260, 54), Callable(self, "_close_profile_or_settings"), 15))

func _show_style_collection():
	_play_sfx(sound_click, 0.985, 1.015)
	if modal_layer != null:
		modal_layer.queue_free()

	modal_layer = Control.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal_layer)

	var shade = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.008, 0.004, 0.80)
	modal_layer.add_child(shade)

	var panel = Panel.new()
	panel.position = Vector2(48, 108)
	panel.size = Vector2(624, 1062)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#1b100c"), Color("#a2774f"), 24, 0.985))
	modal_layer.add_child(panel)

	panel.add_child(_make_label("STYLE COLLECTION", Vector2(30, 24), Vector2(564, 46), 28, Color("#f4e7d7"), HORIZONTAL_ALIGNMENT_CENTER))
	panel.add_child(_make_label("Unlock styles with points earned by playing.\nCOSMETIC ONLY • NO GAMEPLAY ADVANTAGES", Vector2(48, 64), Vector2(528, 54), 12, Color("#bfa98f"), HORIZONTAL_ALIGNMENT_CENTER))

	var points_label = _make_label("%d POINTS AVAILABLE" % int(profile_data.get("points", 0)), Vector2(48, 108), Vector2(528, 30), 14, Color("#efc56e"), HORIZONTAL_ALIGNMENT_CENTER)
	panel.add_child(points_label)

	collection_status_label = _make_label("Equipped: %s" % str(_theme_definition(_equipped_theme_id()).get("name", "CLASSIC WALNUT")), Vector2(48, 138), Vector2(528, 28), 11, Color("#d8c7b4"), HORIZONTAL_ALIGNMENT_CENTER)
	panel.add_child(collection_status_label)

	var defs = _theme_definitions()
	var card_w = 258.0
	var card_h = 232.0
	var left_x = 34.0
	var right_x = 332.0
	var start_y = 182.0
	var gap_y = 248.0

	for i in range(defs.size()):
		var item = defs[i]
		var theme_id = str(item.get("id", "walnut"))
		var x = left_x if i % 2 == 0 else right_x
		var y = start_y + int(i / 2) * gap_y

		var theme_button = Button.new()
		theme_button.position = Vector2(x, y)
		theme_button.size = Vector2(card_w, card_h)
		theme_button.text = ""
		theme_button.focus_mode = Control.FOCUS_NONE
		theme_button.pressed.connect(Callable(self, "_on_theme_pressed").bind(theme_id))
		

		var equipped = _equipped_theme_id() == theme_id
		var owned = _theme_is_owned(theme_id)
		var border = Color("#efc56e") if equipped else (Color("#9e7650") if owned else Color("#59483d"))
		var bg = Color("#2a1710") if owned else Color("#18110d")
		theme_button.add_theme_stylebox_override("normal", _panel_style(bg, border, 16, 0.98))
		theme_button.add_theme_stylebox_override("hover", _panel_style(Color("#352016"), Color("#e0b45b"), 16, 1.0))
		theme_button.add_theme_stylebox_override("pressed", _panel_style(Color("#160d09"), Color("#f0c66c"), 16, 1.0))
		panel.add_child(theme_button)

		var preview = ColorRect.new()
		preview.position = Vector2(10, 10)
		preview.size = Vector2(card_w - 20, 112)
		preview.material = _theme_material(theme_id)
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		theme_button.add_child(preview)

		var preview_frame = Panel.new()
		preview_frame.position = Vector2(10, 10)
		preview_frame.size = Vector2(card_w - 20, 112)
		preview_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview_frame.add_theme_stylebox_override("panel", _panel_style(Color(0, 0, 0, 0), Color(str(item.get("accent", "#d08a46"))), 10, 0.0))
		theme_button.add_child(preview_frame)

		var name_label = _make_label(str(item.get("name", "")), Vector2(12, 128), Vector2(card_w - 24, 28), 13, Color("#f5e5d2"), HORIZONTAL_ALIGNMENT_CENTER)
		theme_button.add_child(name_label)

		var description_label = _make_label(str(item.get("description", "")), Vector2(14, 155), Vector2(card_w - 28, 34), 10, Color("#aa9683"), HORIZONTAL_ALIGNMENT_CENTER)
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description_label.size = Vector2(card_w - 28, 34)
		theme_button.add_child(description_label)

		var status = ""
		var status_color = Color("#9c8878")
		if equipped:
			status = "EQUIPPED"
			status_color = Color("#efc56e")
		elif owned:
			status = "OWNED • TAP TO EQUIP"
			status_color = Color("#d9b978")
		else:
			var requirement = str(item.get("achievement", ""))
			if requirement != "":
				status = "COMPLETE ROAD TO ACE"
				status_color = Color("#a58e78")
			else:
				status = "UNLOCK • %d POINTS" % int(item.get("price", 0))
				status_color = Color("#d59b58")

			var status_label = _make_label(
				status,
				Vector2(12, 188),
				Vector2(card_w - 24, 42),
				10,
				status_color,
				HORIZONTAL_ALIGNMENT_CENTER
			)
			status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			theme_button.add_child(status_label)
			
			
	panel.add_child(_make_button("CLOSE", Rect2(182, 956, 260, 58), Callable(self, "_close_profile_or_settings"), 15))

func _on_theme_pressed(theme_id):
	var item = _theme_definition(theme_id)
	if _theme_is_owned(theme_id):
		profile_data["equipped_theme"] = str(theme_id)
		_save_profile()
		_apply_equipped_theme()
		_haptic(24)
		_show_style_collection()
		return

	var requirement = str(item.get("achievement", ""))
	if requirement != "":
		if collection_status_label != null:
			collection_status_label.text = "Complete the Road to Ace to unlock %s." % str(item.get("name", "this table"))
		return

	var price = int(item.get("price", 0))
	var points = int(profile_data.get("points", 0))
	if points < price:
		if collection_status_label != null:
			collection_status_label.text = "You need %d more points for %s." % [price - points, str(item.get("name", "this table"))]
		_haptic(10)
		return

	profile_data["points"] = points - price
	var owned = profile_data.get("owned_themes", {})
	owned[str(theme_id)] = true
	profile_data["owned_themes"] = owned
	profile_data["equipped_theme"] = str(theme_id)
	_save_profile()
	_refresh_menu_profile()
	_apply_equipped_theme()
	_haptic(42)
	_show_style_collection()

func _show_settings():
	_play_sfx(sound_click, 0.985, 1.015)
	if modal_layer != null:
		modal_layer.queue_free()
	modal_layer = Control.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal_layer)

	var shade = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.01, 0.005, 0.78)
	modal_layer.add_child(shade)

	var panel = Panel.new()
	panel.name = "Panel"
	panel.position = Vector2(88, 238)
	panel.size = Vector2(544, 782)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#1d100b"), Color("#a2774f"), 24, 0.98))
	modal_layer.add_child(panel)

	panel.add_child(_make_label("AUDIO & FEEL", Vector2(30, 30), Vector2(484, 50), 30, Color("#f4e7d7"), HORIZONTAL_ALIGNMENT_CENTER))
	panel.add_child(_make_label("Keep the table tactile without letting the soundtrack take over.", Vector2(46, 76), Vector2(452, 46), 12, Color("#bfa98f"), HORIZONTAL_ALIGNMENT_CENTER))

	var music_text = "MUSIC: ON" if _music_enabled() else "MUSIC: OFF"
	var music_button = _make_button(music_text, Rect2(92, 132, 360, 56), Callable(self, "_toggle_music_setting"), 15)
	music_button.name = "MusicSettingButton"
	panel.add_child(music_button)

	var music_label = _make_label("MUSIC VOLUME  •  %d%%" % int(round(_music_volume() * 100.0)), Vector2(92, 198), Vector2(360, 28), 12, Color("#d8ad62"), HORIZONTAL_ALIGNMENT_LEFT)
	music_label.name = "MusicVolumeLabel"
	panel.add_child(music_label)

	var music_slider = HSlider.new()
	music_slider.name = "MusicVolumeSlider"
	music_slider.position = Vector2(92, 230)
	music_slider.size = Vector2(360, 36)
	music_slider.min_value = 0.0
	music_slider.max_value = 100.0
	music_slider.step = 1.0
	music_slider.value = _music_volume() * 100.0
	music_slider.value_changed.connect(_on_music_volume_changed)
	panel.add_child(music_slider)

	var sound_text = "SFX: ON" if _sound_enabled() else "SFX: OFF"
	var sound_button = _make_button(sound_text, Rect2(92, 290, 360, 56), Callable(self, "_toggle_sound_setting"), 15)
	sound_button.name = "SoundSettingButton"
	panel.add_child(sound_button)

	var sfx_label = _make_label("SFX VOLUME  •  %d%%" % int(round(_sfx_volume() * 100.0)), Vector2(92, 356), Vector2(360, 28), 12, Color("#d8ad62"), HORIZONTAL_ALIGNMENT_LEFT)
	sfx_label.name = "SfxVolumeLabel"
	panel.add_child(sfx_label)

	var sfx_slider = HSlider.new()
	sfx_slider.name = "SfxVolumeSlider"
	sfx_slider.position = Vector2(92, 388)
	sfx_slider.size = Vector2(360, 36)
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 100.0
	sfx_slider.step = 1.0
	sfx_slider.value = _sfx_volume() * 100.0
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	panel.add_child(sfx_slider)

	var haptic_text = "HAPTICS: ON" if _haptics_enabled() else "HAPTICS: OFF"
	var haptic_button = _make_button(haptic_text, Rect2(92, 452, 360, 56), Callable(self, "_toggle_haptic_setting"), 15)
	haptic_button.name = "HapticSettingButton"
	panel.add_child(haptic_button)

	var note = _make_label("Music and sound effects are controlled separately. Your choices are saved locally on this device.", Vector2(64, 540), Vector2(416, 80), 13, Color("#bfa98f"), HORIZONTAL_ALIGNMENT_CENTER)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(note)

	panel.add_child(_make_button("CLOSE", Rect2(92, 664, 360, 58), Callable(self, "_close_profile_or_settings"), 15))

func _toggle_music_setting():
	var settings = profile_data.get("settings", {})
	settings["music"] = not bool(settings.get("music", true))
	profile_data["settings"] = settings
	_save_profile()
	var button = _find_descendant_by_name(modal_layer, "MusicSettingButton")
	if button != null:
		button.text = "MUSIC: ON" if _music_enabled() else "MUSIC: OFF"
	if _music_enabled():
		if phase == "menu":
			_play_music(MENU_MUSIC_PATH)
		elif phase == "video_tutorial":
			_stop_music_smooth()
		else:
			_play_music(GAMEPLAY_MUSIC_PATH)
	else:
		_stop_music_smooth()

func _toggle_sound_setting():
	var settings = profile_data.get("settings", {})
	settings["sound"] = not bool(settings.get("sound", true))
	profile_data["settings"] = settings
	_save_profile()
	var button = _find_descendant_by_name(modal_layer, "SoundSettingButton")
	if button != null:
		button.text = "SFX: ON" if _sound_enabled() else "SFX: OFF"
	if _sound_enabled():
		_play_sfx(sound_click, 1.0, 1.0)

func _on_music_volume_changed(value):
	var settings = profile_data.get("settings", {})
	settings["music_volume"] = clampf(float(value) / 100.0, 0.0, 1.0)
	profile_data["settings"] = settings
	_save_profile()
	var label = _find_descendant_by_name(modal_layer, "MusicVolumeLabel")
	if label != null:
		label.text = "MUSIC VOLUME  •  %d%%" % int(round(value))
	_refresh_music_volume()

func _on_sfx_volume_changed(value):
	var settings = profile_data.get("settings", {})
	settings["sfx_volume"] = clampf(float(value) / 100.0, 0.0, 1.0)
	profile_data["settings"] = settings
	_save_profile()
	var label = _find_descendant_by_name(modal_layer, "SfxVolumeLabel")
	if label != null:
		label.text = "SFX VOLUME  •  %d%%" % int(round(value))

func _toggle_haptic_setting():
	var settings = profile_data.get("settings", {})
	settings["haptics"] = not bool(settings.get("haptics", true))
	profile_data["settings"] = settings
	_save_profile()
	var button = _find_descendant_by_name(modal_layer, "HapticSettingButton")
	if button != null:
		button.text = "HAPTICS: ON" if _haptics_enabled() else "HAPTICS: OFF"
	_haptic(18)

func _find_descendant_by_name(root, target_name):
	if root == null:
		return null
	for child in root.get_children():
		if child.name == target_name:
			return child
		var found = _find_descendant_by_name(child, target_name)
		if found != null:
			return found
	return null

func _close_profile_or_settings():
	_play_sfx(sound_click, 0.985, 1.015)
	_close_modal()
	_refresh_menu_profile()

func _select_menu_difficulty(selected):
	menu_selected_difficulty = selected

	if menu_layer == null:
		return

	var difficulty_buttons = {
		"Easy": menu_layer.get_node_or_null("EasyButton"),
		"Normal": menu_layer.get_node_or_null("NormalButton"),
		"Hard": menu_layer.get_node_or_null("HardButton")
	}

	for level in difficulty_buttons:
		var button = difficulty_buttons[level]

		if button == null:
			continue

		if level == selected:
			button.add_theme_stylebox_override(
				"normal",
				_panel_style(
					Color("#87422c"),
					Color("#e3b461"),
					14,
					1.0
				)
			)

			button.add_theme_stylebox_override(
				"hover",
				_panel_style(
					Color("#995038"),
					Color("#f1cb85"),
					14,
					1.0
				)
			)

			var selected_tween = create_tween()
			selected_tween.set_trans(Tween.TRANS_BACK)
			selected_tween.set_ease(Tween.EASE_OUT)
			selected_tween.tween_property(
				button,
				"scale",
				Vector2(1.045, 1.045),
				0.16
			)

		else:
			button.add_theme_stylebox_override(
				"normal",
				_panel_style(
					Color("#43251b"),
					Color("#895f43"),
					14,
					0.92
				)
			)

			button.add_theme_stylebox_override(
				"hover",
				_panel_style(
					Color("#5b3021"),
					Color("#a8734e"),
					14,
					0.96
				)
			)

			var reset_tween = create_tween()
			reset_tween.set_trans(Tween.TRANS_QUAD)
			reset_tween.set_ease(Tween.EASE_OUT)
			reset_tween.tween_property(
				button,
				"scale",
				Vector2.ONE,
				0.12
			)

	var play_button = menu_layer.get_node_or_null("PlayButton")

	if play_button != null:
		play_button.text = "PLAY " + selected.to_upper()

		var play_tween = create_tween()
		play_tween.set_trans(Tween.TRANS_BACK)
		play_tween.set_ease(Tween.EASE_OUT)

		play_tween.tween_property(
			play_button,
			"scale",
			Vector2(1.025, 1.025),
			0.10
		)

		play_tween.tween_property(
			play_button,
			"scale",
			Vector2.ONE,
			0.12
		)


func _play_selected_difficulty():
	_start_new_match(menu_selected_difficulty)

func _show_menu():
	phase = "menu"
	_apply_equipped_theme()
	_play_music(MENU_MUSIC_PATH)
	tutorial_mode = false
	game_layer.visible = false
	menu_layer.visible = true
	_refresh_menu_profile()
	if video_layer != null:
		video_layer.visible = false
	if video_player != null:
		video_player.stop()
	if modal_layer != null:
		modal_layer.queue_free()
		modal_layer = null

func _on_menu_pressed():
	_play_sfx(sound_click, 0.985, 1.015)
	if phase != "menu" and not tutorial_mode:
		_save_active_run()
	_show_menu()

func _start_new_match(selected_difficulty):
	_play_music(GAMEPLAY_MUSIC_PATH)
	tutorial_mode = false
	tutorial_step = 0
	if video_layer != null:
		video_layer.visible = false
	difficulty = selected_difficulty
	player_level = 10
	ai_level = 10
	round_number = 1
	match_points_earned = 0
	match_xp_earned = 0
	match_cards_placed = 0
	match_rounds_won = 0
	match_rounds_lost = 0
	match_started_unix = int(Time.get_unix_time_from_system())
	match_recent_unlocks.clear()
	menu_layer.visible = false
	game_layer.visible = true
	_play_sfx(sound_click, 0.985, 1.015)
	_start_round()

func _start_round():
	phase = "dealing"
	_save_active_run()
	player_active = null
	ai_active = null
	discard_rank_counts.clear()
	discard.clear()
	deck = _make_deck()
	deck.shuffle()

	_clear_slot_views()
	player_slots = _deal_slots(player_level)
	ai_slots = _deal_slots(ai_level)
	_build_slot_views()

	round_label.text = "ROUND %d" % round_number
	player_label.text = "YOU • %s" % _stage_name(player_level)
	opponent_label.text = "CPU • %s" % _stage_name(ai_level)
	_update_road_progress()
	discard_view.set_placeholder("DISCARD")
	_hide_active_card()
	draw_view.face_down = true
	draw_view.card = null
	draw_view.queue_redraw()
	discard_button.visible = false
	_refresh_piles()

	await _animate_initial_deal()

	turn = "player" if round_number % 2 == 1 else "ai"
	phase = "playing"
	if turn == "player":
		_begin_player_turn()
	else:
		_begin_ai_turn()

func _make_deck():
	var cards = []
	for suit in ["H", "D", "C", "S"]:
		for rank in range(1, 14):
			cards.append({"rank": rank, "suit": suit, "joker": false})
	for i in range(JOKER_COUNT):
		cards.append({"rank": 0, "suit": "J", "joker": true})
	return cards

func _deal_slots(count):
	var slots = []
	for i in range(count):
		slots.append({
			"hidden": _draw_raw(),
			"revealed": false,
			"face_card": null,
			"assigned_rank": 0
		})
	return slots

func _draw_raw():
	if deck.is_empty():
		_recycle_discard()
	if deck.is_empty():
		return {"rank": 13, "suit": "S", "joker": false}
	return deck.pop_back()

func _recycle_discard():
	if discard.size() <= 1:
		return
	var top = discard.pop_back()
	deck = discard.duplicate(true)
	deck.shuffle()
	discard.clear()
	discard.append(top)

func _clear_slot_views():
	for v in player_views:
		if is_instance_valid(v):
			v.queue_free()
	for v in ai_views:
		if is_instance_valid(v):
			v.queue_free()
	player_views.clear()
	ai_views.clear()

func _build_slot_views():
	var p_positions = _slot_positions(player_level, 820.0, 968.0)
	for i in range(player_level):
		var view = _create_card_view(i, p_positions[i])
		view.configure(i, player_slots[i].get("hidden"), true)
		view.slot_pressed.connect(_on_player_slot_pressed)
		game_layer.add_child(view)
		player_views.append(view)

	var a_positions = _slot_positions(ai_level, 88.0, 236.0)
	for i in range(ai_level):
		var view = _create_card_view(i, a_positions[i])
		view.configure(i, ai_slots[i].get("hidden"), true)
		view.set_interactive(false)
		game_layer.add_child(view)
		ai_views.append(view)

func _slot_positions(count, first_y, second_y):
	var positions = []
	if count <= MAX_PER_ROW:
		var y = (first_y + second_y) * 0.5
		var total = count * CARD_SIZE.x + max(0, count - 1) * CARD_GAP
		var start_x = (720.0 - total) * 0.5
		for i in range(count):
			positions.append(Vector2(start_x + i * (CARD_SIZE.x + CARD_GAP), y))
		return positions

	var first_count = min(MAX_PER_ROW, count)
	var second_count = count - first_count
	var total1 = first_count * CARD_SIZE.x + (first_count - 1) * CARD_GAP
	var start1 = (720.0 - total1) * 0.5
	for i in range(first_count):
		positions.append(Vector2(start1 + i * (CARD_SIZE.x + CARD_GAP), first_y))
	if second_count > 0:
		var total2 = second_count * CARD_SIZE.x + (second_count - 1) * CARD_GAP
		var start2 = (720.0 - total2) * 0.5
		for i in range(second_count):
			positions.append(Vector2(start2 + i * (CARD_SIZE.x + CARD_GAP), second_y))
	return positions

func _create_card_view(index, pos):
	var view = CardView.new()
	view.position = pos
	view.size = CARD_SIZE
	view.slot_index = index
	return view

func _begin_player_turn():
	if phase != "playing":
		return
	turn = "player"
	player_active = null
	_hide_active_card()
	turn_label.text = "TUTORIAL" if tutorial_mode else "YOUR TURN"
	turn_label.modulate = Color.WHITE
	discard_button.visible = false
	_disable_player_slots()
	draw_view.set_interactive(true, true)
	if tutorial_mode:
		discard_view.set_interactive(false)
		instruction_label.text = _tutorial_idle_prompt()
		_refresh_piles()
		return
	instruction_label.text = "Choose one: draw from the deck or take the top discard."
	var can_take_discard = not discard.is_empty() and not _legal_targets(discard.back(), player_slots).is_empty()
	discard_view.set_interactive(can_take_discard, can_take_discard)
	_refresh_piles()

func _on_pile_pressed(index):
	if phase != "playing" or turn != "player" or player_active != null:
		return
	if index == -100:
		_player_draw_stock()
	elif index == -101:
		_player_take_discard()

func _player_draw_stock():
	draw_view.set_interactive(false)
	discard_view.set_interactive(false)
	if tutorial_mode:
		player_active = _tutorial_draw_card()
		if player_active == null:
			_begin_player_turn()
			return
	else:
		player_active = _draw_raw()
	_play_sfx(sound_slide, 0.96, 1.04)
	_haptic(18)
	await _animate_active_from(draw_view.global_position, player_active, true)
	_present_player_active()

func _player_take_discard():
	if discard.is_empty():
		return
	draw_view.set_interactive(false)
	discard_view.set_interactive(false)
	player_active = discard.pop_back()
	_play_sfx(sound_slide, 0.97, 1.035)
	await _animate_active_from(discard_view.global_position, player_active, false)
	_present_player_active()

func _present_player_active():
	if tutorial_mode:
		_present_tutorial_active()
		return
	_show_active_card(player_active)
	_refresh_piles()
	var targets = _legal_targets(player_active, player_slots)
	_disable_player_slots()
	if targets.is_empty():
		instruction_label.text = _dead_card_message(player_active)
		discard_button.visible = true
		return
	discard_button.visible = false
	if player_active.get("joker", false):
		instruction_label.text = "Joker: choose any face-down position. It will LOCK there for this round."
	else:
		instruction_label.text = "Play the %s into its matching position." % _rank_label(int(player_active.get("rank", 0)))
	for idx in targets:
		player_views[idx].set_interactive(true, true)

func _on_player_slot_pressed(index):
	if phase != "playing" or turn != "player" or player_active == null:
		return
	if tutorial_mode and not _tutorial_target_allowed(index):
		return
	var targets = _legal_targets(player_active, player_slots)
	if not targets.has(index):
		return

	_disable_player_slots()
	discard_button.visible = false
	var played_card = player_active
	var displaced = player_slots[index].get("hidden")

	await _animate_active_to_slot(player_views[index])

	player_slots[index]["revealed"] = true
	player_slots[index]["face_card"] = played_card
	player_slots[index]["assigned_rank"] = index + 1 if played_card.get("joker", false) else 0
	player_views[index].configure(index, played_card, false, player_slots[index].get("assigned_rank", 0))
	player_views[index].scale = Vector2(0.92, 0.92)
	player_views[index].modulate = Color(1.12, 1.06, 0.92, 1.0)
	var land = create_tween().set_parallel(true)
	land.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	land.tween_property(player_views[index], "scale", Vector2.ONE, 0.18)
	land.tween_property(player_views[index], "modulate", Color.WHITE, 0.22)
	_play_sfx(sound_place, 0.95, 1.05)
	_haptic(22)
	if not tutorial_mode:
		match_cards_placed += 1
		profile_data["cards_placed"] = int(profile_data.get("cards_placed", 0)) + 1
		if played_card.get("joker", false):
			profile_data["jokers_played"] = int(profile_data.get("jokers_played", 0)) + 1

	player_active = displaced
	if tutorial_mode:
		_advance_tutorial_after_play(index)

	if _all_revealed(player_slots):
		_hide_active_card()
		await _animate_round_sweep(player_views)
		if tutorial_mode:
			_show_tutorial_complete()
		else:
			_finish_round("player")
		return

	await _animate_displaced_from_slot(player_views[index], player_active)
	_present_player_active()

func _on_discard_pressed():
	if phase != "playing" or turn != "player" or player_active == null:
		return
	_play_sfx(sound_click, 0.985, 1.015)
	var card_to_discard = player_active
	await _animate_active_to_discard()
	_discard_card(card_to_discard)
	player_active = null
	_hide_active_card()
	discard_button.visible = false
	_disable_player_slots()
	_refresh_piles()
	await get_tree().create_timer(0.18).timeout
	if tutorial_mode:
		if tutorial_step == 3:
			tutorial_step = 4
			_begin_player_turn()
		elif tutorial_step == 6:
			tutorial_step = 7
			_begin_player_turn()
		elif tutorial_step == 8:
			tutorial_step = 9
			_show_tutorial_complete()
		else:
			_begin_player_turn()
		return
	_begin_ai_turn()

func _begin_ai_turn():
	if phase != "playing":
		return

	turn = "ai"
	_disable_player_slots()
	draw_view.set_interactive(false)
	discard_view.set_interactive(false)
	discard_button.visible = false
	turn_label.text = "CPU TURN"
	instruction_label.text = "Opponent is thinking…"

	await get_tree().create_timer(0.42).timeout

	var use_discard = false
	if not discard.is_empty() and not _legal_targets(discard.back(), ai_slots).is_empty():
		if difficulty == "Easy":
			# Easy intentionally overlooks most useful discards.
			use_discard = randf() < 0.18
		elif difficulty == "Normal":
			use_discard = randf() < 0.70
		else:
			use_discard = true

	if use_discard:
		ai_active = discard.pop_back()
		_play_sfx(sound_slide, 0.97, 1.035)
		await _animate_active_from(discard_view.global_position, ai_active, false)
	else:
		ai_active = _draw_raw()
		_play_sfx(sound_slide, 0.96, 1.04)
		await _animate_active_from(draw_view.global_position, ai_active, true)
	_refresh_piles()
	await get_tree().create_timer(0.32).timeout
	await _resolve_ai_chain()

func _resolve_ai_chain():
	var chain_steps := 0

	while ai_active != null and phase == "playing":
		var targets = _legal_targets(ai_active, ai_slots)

		if targets.is_empty():
			await _ai_discard_active()
			return

		# Difficulty changes decision quality, not the deck. Easy can miss a
		# playable card and is increasingly likely to stop a lucky chain.
		var play_chance := 1.0
		if difficulty == "Easy":
			play_chance = 0.76 if chain_steps == 0 else 0.60
		elif difficulty == "Normal":
			play_chance = 0.96 if chain_steps == 0 else 0.90

		if randf() > play_chance:
			instruction_label.text = "CPU misses an opportunity and discards."
			await get_tree().create_timer(0.18).timeout
			await _ai_discard_active()
			return

		var target = targets[0]
		if ai_active.get("joker", false):
			target = _choose_ai_joker_target(targets)

		instruction_label.text = "CPU plays %s." % ("a Joker" if ai_active.get("joker", false) else _rank_label(int(ai_active.get("rank", 0))))
		var played_card = ai_active
		var displaced = ai_slots[target].get("hidden")

		await _animate_active_to_slot(ai_views[target])

		ai_slots[target]["revealed"] = true
		ai_slots[target]["face_card"] = played_card
		ai_slots[target]["assigned_rank"] = target + 1 if played_card.get("joker", false) else 0
		ai_views[target].configure(target, played_card, false, ai_slots[target].get("assigned_rank", 0))
		ai_views[target].scale = Vector2(0.92, 0.92)
		var land = create_tween()
		land.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		land.tween_property(ai_views[target], "scale", Vector2.ONE, 0.18)
		_play_sfx(sound_place, 0.95, 1.05)

		ai_active = displaced
		chain_steps += 1

		if _all_revealed(ai_slots):
			_hide_active_card()
			await _animate_round_sweep(ai_views)
			_finish_round("ai")
			return

		await _animate_displaced_from_slot(ai_views[target], ai_active)
		await get_tree().create_timer(0.24).timeout

func _ai_discard_active():
	instruction_label.text = "CPU discards."
	var dead_card = ai_active
	await _animate_active_to_discard()
	_discard_card(dead_card)
	ai_active = null
	_hide_active_card()
	_refresh_piles()
	await get_tree().create_timer(0.28).timeout
	_begin_player_turn()

func _choose_ai_joker_target(targets):
	if targets.is_empty():
		return 0
	if difficulty != "Hard":
		return targets[randi() % targets.size()]
	var best = targets[0]
	var best_count = -1
	for idx in targets:
		var rank = idx + 1
		var seen = int(discard_rank_counts.get(rank, 0))
		if seen > best_count:
			best_count = seen
			best = idx
	return best

func _legal_targets(card, slots):
	var targets = []
	if card == null:
		return targets
	if card.get("joker", false):
		for i in range(slots.size()):
			if not slots[i].get("revealed", false):
				targets.append(i)
		return targets
	var rank = int(card.get("rank", 0))
	if rank < 1 or rank > 10:
		return targets
	if rank > slots.size():
		return targets
	var idx = rank - 1
	if not slots[idx].get("revealed", false):
		targets.append(idx)
	return targets

func _discard_card(card):
	discard.append(card)
	if card != null and not card.get("joker", false):
		var rank = int(card.get("rank", 0))
		discard_rank_counts[rank] = int(discard_rank_counts.get(rank, 0)) + 1
	_refresh_piles()

func _dead_card_message(card):
	if card.get("joker", false):
		return "No open positions remain for the Joker."
	var rank = int(card.get("rank", 0))
	if rank >= 11:
		return "%s is a dead card. Discard it." % _rank_label(rank)
	if rank > player_slots.size():
		return "%s is outside your current layout. Discard it." % _rank_label(rank)
	return "%s is already filled — that card is dead. Discard it." % _rank_label(rank)

func _disable_player_slots():
	for view in player_views:
		view.set_interactive(false, false)

func _all_revealed(slots):
	for slot in slots:
		if not slot.get("revealed", false):
			return false
	return true

func _finish_round(winner):
	if phase != "playing":
		return

	phase = "round_over"
	draw_view.set_interactive(false)
	discard_view.set_interactive(false)
	_disable_player_slots()
	discard_button.visible = false
	_haptic(65)

	var reward = _record_round_result(winner)
	var previous_level = player_level if winner == "player" else ai_level
	var match_winner = ""

	if winner == "player":
		if player_level == 1:
			match_winner = "player"
		else:
			player_level -= 1
			profile_data["best_road"] = min(int(profile_data.get("best_road", 10)), player_level)
	else:
		if ai_level == 1:
			match_winner = "ai"
		else:
			ai_level -= 1

	if match_winner != "":
		_complete_match(match_winner, reward)
		return

	var extra_unlocks = _check_achievements()
	if not extra_unlocks.is_empty():
		reward["achievements"] = extra_unlocks
		reward["points"] = int(reward.get("points", 0)) + _achievement_reward_total(extra_unlocks)
		for unlock_title in extra_unlocks:
			if not match_recent_unlocks.has(unlock_title):
				match_recent_unlocks.append(unlock_title)

	_update_road_progress()
	_save_profile()
	_save_active_run(round_number + 1)
	var new_level = player_level if winner == "player" else ai_level
	_run_round_transition(winner, previous_level, new_level, reward)

func _run_round_transition(winner, previous_level, new_level, reward):
	# This is deliberately automatic: result -> collect -> next round -> deal.
	var transition = Control.new()
	transition.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transition.mouse_filter = Control.MOUSE_FILTER_STOP
	transition.z_index = 300
	add_child(transition)

	var shade = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.025, 0.010, 0.004, 0.0)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition.add_child(shade)

	var result_panel = Panel.new()
	result_panel.position = Vector2(92, 402)
	result_panel.size = Vector2(536, 292)
	result_panel.modulate = Color(1, 1, 1, 0)
	result_panel.scale = Vector2(0.90, 0.90)
	result_panel.pivot_offset = result_panel.size * 0.5
	result_panel.add_theme_stylebox_override(
		"panel",
		_panel_style(Color("#1b0d08"), Color("#d0a054"), 24, 0.96)
	)
	transition.add_child(result_panel)

	var heading = "ROUND WON" if winner == "player" else "CPU TAKES THE ROUND"
	var subheading = "YOU ADVANCE" if winner == "player" else "CPU ADVANCES"

	result_panel.add_child(_make_label(
		heading,
		Vector2(24, 28),
		Vector2(488, 46),
		30,
		Color("#f6e8d4"),
		HORIZONTAL_ALIGNMENT_CENTER
	))

	result_panel.add_child(_make_label(
		subheading,
		Vector2(24, 82),
		Vector2(488, 26),
		13,
		Color("#d8ad62"),
		HORIZONTAL_ALIGNMENT_CENTER
	))

	var progress_text = "%s   →   %s" % [_stage_name(previous_level), _stage_name(new_level)]
	result_panel.add_child(_make_label(
		progress_text,
		Vector2(24, 116),
		Vector2(488, 58),
		28,
		Color("#fff0d0"),
		HORIZONTAL_ALIGNMENT_CENTER
	))

	var reward_text = "+%d POINTS   •   +%d XP" % [int(reward.get("points", 0)), int(reward.get("xp", 0))]
	result_panel.add_child(_make_label(
		reward_text,
		Vector2(24, 174),
		Vector2(488, 30),
		14,
		Color("#efc56e"),
		HORIZONTAL_ALIGNMENT_CENTER
	))

	var unlock_text = ""
	var unlocked = reward.get("achievements", [])
	if unlocked.size() > 0:
		unlock_text = "ACHIEVEMENT • %s" % str(unlocked[0])
	elif bool(reward.get("level_up", false)):
		unlock_text = "LEVEL UP • LEVEL %d • %s" % [int(profile_data.get("level", 1)), _profile_rank()]

	if unlock_text != "":
		result_panel.add_child(_make_label(
			unlock_text,
			Vector2(24, 208),
			Vector2(488, 24),
			11,
			Color("#f7ead6"),
			HORIZONTAL_ALIGNMENT_CENTER
		))

	result_panel.add_child(_make_label(
		"ROAD TO ACE",
		Vector2(24, 248),
		Vector2(488, 22),
		11,
		Color("#9f7a52"),
		HORIZONTAL_ALIGNMENT_CENTER
	))

	var intro = create_tween().set_parallel(true)
	intro.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro.tween_property(shade, "color", Color(0.025, 0.010, 0.004, 0.58), 0.24)
	intro.tween_property(result_panel, "modulate", Color.WHITE, 0.24)
	intro.tween_property(result_panel, "scale", Vector2.ONE, 0.30)
	await intro.finished
	_play_sfx(sound_road, 0.99, 1.015)

	await get_tree().create_timer(1.15).timeout

	# Pull every hand card back toward the draw pile while the result recedes.
	var collect_target = draw_view.global_position + CARD_SIZE * 0.5
	var all_views = []
	all_views.append_array(ai_views)
	all_views.append_array(player_views)
	_play_sfx(sound_slide, 0.90, 0.95)

	for i in range(all_views.size()):
		var view = all_views[i]
		if not is_instance_valid(view):
			continue
		view.z_index = 250 + i
		var target = collect_target - view.size * 0.5
		var collect = create_tween().set_parallel(true)
		collect.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		collect.tween_property(view, "global_position", target, 0.28 + i * 0.012)
		collect.tween_property(view, "scale", Vector2(0.72, 0.72), 0.28 + i * 0.012)
		collect.tween_property(view, "rotation", deg_to_rad(randf_range(-5.0, 5.0)), 0.28 + i * 0.012)
		collect.tween_property(view, "modulate", Color(1, 1, 1, 0), 0.28 + i * 0.012)

	var panel_out = create_tween().set_parallel(true)
	panel_out.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	panel_out.tween_property(result_panel, "modulate", Color(1, 1, 1, 0), 0.24)
	panel_out.tween_property(result_panel, "scale", Vector2(0.94, 0.94), 0.24)
	await get_tree().create_timer(0.48).timeout

	# Change the same overlay into a clean next-round title.
	for child in result_panel.get_children():
		child.queue_free()
	result_panel.position = Vector2(110, 470)
	result_panel.size = Vector2(500, 150)
	result_panel.pivot_offset = result_panel.size * 0.5
	result_panel.scale = Vector2(0.92, 0.92)
	result_panel.modulate = Color(1, 1, 1, 0)

	result_panel.add_child(_make_label(
		"ROUND %d" % (round_number + 1),
		Vector2(20, 26),
		Vector2(460, 50),
		34,
		Color("#f7e7c8"),
		HORIZONTAL_ALIGNMENT_CENTER
	))
	result_panel.add_child(_make_label(
		"GET READY",
		Vector2(20, 84),
		Vector2(460, 28),
		13,
		Color("#d8ad62"),
		HORIZONTAL_ALIGNMENT_CENTER
	))

	var next_in = create_tween().set_parallel(true)
	next_in.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	next_in.tween_property(result_panel, "modulate", Color.WHITE, 0.20)
	next_in.tween_property(result_panel, "scale", Vector2.ONE, 0.24)
	await next_in.finished
	await get_tree().create_timer(0.58).timeout

	var next_out = create_tween().set_parallel(true)
	next_out.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	next_out.tween_property(result_panel, "modulate", Color(1, 1, 1, 0), 0.18)
	next_out.tween_property(shade, "color", Color(0.025, 0.010, 0.004, 0.0), 0.24)
	await next_out.finished

	round_number += 1
	transition.queue_free()
	_start_round()

func _show_match_over(winner):
	phase = "match_over"
	var heading = "ROAD TO ACE COMPLETE" if winner == "player" else "CPU COMPLETES THE ROAD"
	var result_line = "You revealed the final Ace and completed the entire Road to Ace." if winner == "player" else "The CPU revealed its final Ace first."
	var record = "%d - %d" % [match_rounds_won, match_rounds_lost]
	var unlock_summary = ""
	if not match_recent_unlocks.is_empty():
		unlock_summary = "\n\nNEW ACHIEVEMENT: %s" % _join_text(match_recent_unlocks, ", ")
	var body = "%s\n\nMATCH SUMMARY\nRounds: %s\nCards placed: %d\nTime: %s\n\nREWARDS THIS MATCH\n+%d points  •  +%d XP\n\nProfile: Level %d • %s%s" % [
		result_line,
		record,
		match_cards_placed,
		_format_match_time(),
		match_points_earned,
		match_xp_earned,
		int(profile_data.get("level", 1)),
		_profile_rank(),
		unlock_summary
	]
	_show_modal(heading, body, "PLAY AGAIN", Callable(self, "_restart_match"), true)

func _next_round():
	round_number += 1
	_close_modal()
	_start_round()

func _restart_match():
	_close_modal()
	_start_new_match(difficulty)

func _modal_to_menu():
	_close_modal()
	_show_menu()

func _show_modal(heading, body, primary_text, primary_callback, show_menu_option := false):
	if modal_layer != null:
		modal_layer.queue_free()

	modal_layer = Control.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal_layer)

	var shade = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.01, 0.005, 0.72)
	modal_layer.add_child(shade)

	var panel = Panel.new()
	panel.position = Vector2(88, 320)
	panel.size = Vector2(544, 590 if show_menu_option else 510)
	panel.add_theme_stylebox_override(
		"panel",
		_panel_style(
			Color("#241610"),
			Color("#a2774f"),
			22,
			0.98
		)
	)
	modal_layer.add_child(panel)

	panel.add_child(
		_make_label(
			heading,
			Vector2(30, 44),
			Vector2(484, 54),
			32,
			Color("#f4e7d7"),
			HORIZONTAL_ALIGNMENT_CENTER
		)
	)

	var body_label = _make_label(
		body,
		Vector2(46, 118),
		Vector2(452, 220),
		16,
		Color("#cbb9a7"),
		HORIZONTAL_ALIGNMENT_CENTER
	)

	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(body_label)

	panel.add_child(
		_make_button(
			primary_text,
			Rect2(92, 360, 360, 60),
			primary_callback,
			17
		)
	)

	if show_menu_option:
		panel.add_child(
			_make_button(
				"MAIN MENU",
				Rect2(92, 442, 360, 56),
				Callable(self, "_modal_to_menu"),
				15
			)
		)

func _close_modal():
	if modal_layer != null:
		modal_layer.queue_free()
		modal_layer = null

func _build_video_tutorial():
	video_layer = Control.new()
	video_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(video_layer)
	video_layer.visible = false

	var shade = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.035, 0.018, 0.012, 0.90)
	video_layer.add_child(shade)

	var panel = Panel.new()
	panel.position = Vector2(42, 42)
	panel.size = Vector2(636, 1196)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#18100c"), Color("#8b6547"), 24, 0.97))
	video_layer.add_child(panel)

	panel.add_child(_make_label("WATCH TUTORIAL", Vector2(28, 30), Vector2(580, 48), 30, Color("#f4e7d7"), HORIZONTAL_ALIGNMENT_CENTER))
	panel.add_child(_make_label("Learn from the real tabletop game that inspired this version.", Vector2(60, 78), Vector2(516, 52), 14, Color("#bca793"), HORIZONTAL_ALIGNMENT_CENTER))

	video_player = VideoStreamPlayer.new()
	video_player.position = Vector2(138, 142)
	video_player.size = Vector2(360, 640)
	video_player.expand = true
	video_player.stream = load("res://tutorial/tutorial.ogv")
	panel.add_child(video_player)

	video_pause_button = _make_button("PAUSE", Rect2(70, 820, 150, 54), Callable(self, "_toggle_video_pause"), 15)
	panel.add_child(video_pause_button)
	panel.add_child(_make_button("RESTART", Rect2(243, 820, 150, 54), Callable(self, "_restart_video"), 15))
	panel.add_child(_make_button("BACK", Rect2(416, 820, 150, 54), Callable(self, "_back_from_video"), 15))

	var note = _make_label("Key rule: once a Joker is played into a position, it stays locked there for that round. If the matching natural card appears later, that card is dead.", Vector2(62, 916), Vector2(512, 110), 15, Color("#cbb9a7"), HORIZONTAL_ALIGNMENT_CENTER)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(note)
	panel.add_child(_make_label("Prefer hands-on learning? Choose LEARN BY PLAYING from the main menu.", Vector2(62, 1040), Vector2(512, 64), 14, Color("#d8ad62"), HORIZONTAL_ALIGNMENT_CENTER))

func _show_video_tutorial():
	_play_sfx(sound_click, 0.985, 1.015)
	_stop_music_smooth()
	phase = "video_tutorial"
	tutorial_mode = false
	menu_layer.visible = false
	game_layer.visible = false
	video_layer.visible = true
	video_pause_button.text = "PAUSE"
	video_player.stop()
	video_player.play()

func _toggle_video_pause():
	_play_sfx(sound_click, 0.985, 1.015)
	if not video_player.is_playing():
		video_player.play()
		video_pause_button.text = "PAUSE"
		return
	video_player.paused = not video_player.paused
	video_pause_button.text = "PLAY" if video_player.paused else "PAUSE"

func _restart_video():
	_play_sfx(sound_click, 0.985, 1.015)
	video_player.stop()
	video_player.play()
	video_pause_button.text = "PAUSE"

func _back_from_video():
	_play_sfx(sound_click, 0.985, 1.015)
	video_player.stop()
	_show_menu()

func _start_interactive_tutorial():
	_play_sfx(sound_click, 0.985, 1.015)
	_play_music(GAMEPLAY_MUSIC_PATH)
	tutorial_mode = true
	tutorial_step = 0
	difficulty = "Tutorial"
	player_level = 10
	ai_level = 10
	round_number = 1
	menu_layer.visible = false
	if video_layer != null:
		video_layer.visible = false
	game_layer.visible = true
	phase = "dealing"
	discard.clear()
	discard_rank_counts.clear()
	deck.clear()
	player_active = null
	ai_active = null
	_clear_slot_views()
	player_slots = _tutorial_player_slots()
	ai_slots = _tutorial_cpu_slots()
	_build_slot_views()
	for i in range(player_views.size()):
		player_views[i].set_position_hint("A" if i == 0 else str(i + 1))
	round_label.text = "HOW TO PLAY"
	player_label.text = "YOU • PRACTICE ROUND"
	opponent_label.text = "PRACTICE TABLE"
	_update_road_progress()
	discard_view.set_placeholder("DISCARD")
	_hide_active_card()
	draw_view.face_down = true
	draw_view.card = null
	draw_view.queue_redraw()
	discard_button.visible = false
	draw_count_label.text = "practice deck"
	turn = "player"
	phase = "playing"
	_begin_player_turn()

func _tutorial_player_slots():
	var slots = []
	var hidden_cards = [
		_tutorial_card(12, "H"), _tutorial_card(2, "S"), _tutorial_card(3, "D"), _tutorial_card(8, "C"), _tutorial_card(5, "H"),
		_tutorial_card(6, "S"), _tutorial_card(7, "D"), _tutorial_card(13, "C"), _tutorial_card(9, "H"), _tutorial_card(10, "S")
	]
	for card in hidden_cards:
		slots.append({"hidden": card, "revealed": false, "face_card": null, "assigned_rank": 0})
	return slots

func _tutorial_cpu_slots():
	var slots = []
	for i in range(10):
		slots.append({"hidden": _tutorial_card((i % 10) + 1, "S"), "revealed": false, "face_card": null, "assigned_rank": 0})
	return slots

func _tutorial_card(rank, suit := "S", joker := false):
	return {"rank": rank, "suit": suit, "joker": joker}

func _tutorial_idle_prompt():
	match tutorial_step:
		0:
			return "Welcome. Tap DRAW. We’ll walk through a complete chain one move at a time."
		4:
			return "Good. Tap DRAW again — now we’ll learn the Joker rule."
		7:
			return "One last example. Tap DRAW to see what happens when a Joker already owns that position."
		_:
			return "Tap DRAW to continue the tutorial."

func _tutorial_draw_card():
	match tutorial_step:
		0:
			tutorial_step = 1
			return _tutorial_card(4, "H")
		4:
			tutorial_step = 5
			return _tutorial_card(0, "J", true)
		7:
			tutorial_step = 8
			return _tutorial_card(1, "D")
		_:
			return null

func _present_tutorial_active():
	_show_active_card(player_active)
	_disable_player_slots()
	discard_button.visible = false
	draw_view.set_interactive(false)
	discard_view.set_interactive(false)
	match tutorial_step:
		1:
			instruction_label.text = "You drew a 4. Tap the position marked 4. The card underneath will become your next card."
			player_views[3].set_interactive(true, true)
		2:
			instruction_label.text = "The hidden card was an 8. Keep the chain going — tap position 8."
			player_views[7].set_interactive(true, true)
		3:
			instruction_label.text = "You uncovered a King. Jacks, Queens, and Kings are dead cards. Tap DISCARD CARD to end this chain."
			discard_button.visible = true
		5:
			instruction_label.text = "Joker! It can fill any open position. For this lesson, play it as Ace. Once placed, it is LOCKED there."
			player_views[0].set_interactive(true, true)
		6:
			instruction_label.text = "The Joker is now permanently your Ace for this round. You uncovered a Queen, so discard the dead face card."
			discard_button.visible = true
		8:
			instruction_label.text = "You drew the real Ace — but the Joker already owns Ace. The Ace is now dead. Discard it."
			discard_button.visible = true
		_:
			instruction_label.text = "Follow the highlighted position."

func _tutorial_target_allowed(index):
	if tutorial_step == 1:
		return index == 3
	if tutorial_step == 2:
		return index == 7
	if tutorial_step == 5:
		return index == 0
	return false

func _advance_tutorial_after_play(index):
	if tutorial_step == 1 and index == 3:
		tutorial_step = 2
	elif tutorial_step == 2 and index == 7:
		tutorial_step = 3
	elif tutorial_step == 5 and index == 0:
		tutorial_step = 6

func _show_tutorial_complete():
	phase = "tutorial_complete"
	draw_view.set_interactive(false)
	discard_view.set_interactive(false)
	_disable_player_slots()
	discard_button.visible = false

	var body = "That’s the core loop:\n\nDraw a card, place matching ranks,\ncontinue the chain, and discard dead cards.\n\nWin a round to shrink your layout.\nGo from 10 cards all the way down\nto one final Ace."

	_show_modal(
		"YOU’RE READY",
		body,
		"PLAY NORMAL",
		Callable(self, "_finish_tutorial_to_game"),
		true
	)

func _finish_tutorial_to_game():
	_close_modal()
	tutorial_mode = false
	_start_new_match("Normal")

func _update_road_progress():
	if road_label != null:
		road_label.text = "YOU  %s\nCPU  %s" % [_road_line(player_level), _road_line(ai_level)]

	if game_layer == null:
		return

	var road_panel = game_layer.get_node_or_null("RoadPanel")
	if road_panel == null:
		return

	var road_dynamic = road_panel.get_node_or_null("RoadDynamic")
	if road_dynamic == null:
		return

	for child in road_dynamic.get_children():
		road_dynamic.remove_child(child)
		child.queue_free()

	_build_road_tracker_row(
		road_dynamic,
		"YOU",
		58,
		player_level,
		true
	)

	_build_road_tracker_row(
		road_dynamic,
		"CPU",
		94,
		ai_level,
		false
	)

func _road_line(level):
	var line = ""
	for stage in range(10, 0, -1):
		var name = "A" if stage == 1 else str(stage)
		var token = name
		if stage > level:
			token = "✓" + name
		elif stage == level:
			token = "[" + name + "]"
		if line != "":
			line += "  "
		line += token
	return line

func _road_status_text():
	return "YOU  %s\nCPU  %s" % [_road_line(player_level), _road_line(ai_level)]

func _active_home_position() -> Vector2:
	return Vector2(400, 519)

func _animate_initial_deal():
	var all_views = []
	for view in ai_views:
		all_views.append(view)
	for view in player_views:
		all_views.append(view)

	var homes = []
	for view in all_views:
		homes.append(view.position)
		view.position = draw_view.position + Vector2(8, 4)
		view.scale = Vector2(0.72, 0.72)
		view.rotation = deg_to_rad(randf_range(-5.0, 5.0))
		view.modulate.a = 0.0

	for i in range(all_views.size()):
		var view = all_views[i]
		view.modulate.a = 1.0
		var tween = create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(view, "position", homes[i], 0.20)
		tween.tween_property(view, "scale", Vector2.ONE, 0.20)
		tween.tween_property(view, "rotation", 0.0, 0.20)
		_play_sfx(sound_slide, 0.94, 1.06)
		await get_tree().create_timer(0.045).timeout

	await get_tree().create_timer(0.16).timeout

func _animate_active_from(source_global: Vector2, card, flip_from_back := true):
	active_view.visible = true
	discard_view.visible = false
	active_view.z_index = 80
	active_view.global_position = source_global
	active_view.scale = Vector2(0.92, 0.92)
	active_view.rotation = deg_to_rad(-2.5)
	active_view.modulate = Color.WHITE

	if flip_from_back:
		active_view.configure(-102, card, true)
	else:
		active_view.configure(-102, card, false)

	var lift_target = _active_home_position() + Vector2(0, -18)
	var travel = create_tween().set_parallel(true)
	travel.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	travel.tween_property(active_view, "position", lift_target, 0.26)
	travel.tween_property(active_view, "scale", Vector2(1.08, 1.08), 0.26)
	travel.tween_property(active_view, "rotation", 0.0, 0.26)
	await travel.finished

	if flip_from_back:
		var close = create_tween()
		close.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		close.tween_property(active_view, "scale:x", 0.03, 0.10)
		await close.finished
		active_view.configure(-102, card, false)
		_play_sfx(sound_flip, 0.96, 1.04)
		var open = create_tween()
		open.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		open.tween_property(active_view, "scale:x", 1.08, 0.14)
		await open.finished

	var settle = create_tween()
	settle.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	settle.tween_property(active_view, "position", _active_home_position(), 0.12)
	await settle.finished
	active_view.z_index = 20

func _animate_active_to_slot(target_view):
	if not active_view.visible:
		return
	active_view.z_index = 90
	var target = target_view.global_position
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(active_view, "global_position", target, 0.24)
	tween.tween_property(active_view, "scale", Vector2(0.96, 0.96), 0.24)
	tween.tween_property(active_view, "rotation", deg_to_rad(1.5), 0.12)
	await tween.finished
	active_view.visible = false
	active_view.rotation = 0.0
	active_view.scale = Vector2.ONE
	active_view.z_index = 20

func _animate_displaced_from_slot(source_view, card):
	active_view.configure(-102, card, true)
	active_view.visible = true
	discard_view.visible = false
	active_view.z_index = 90
	active_view.global_position = source_view.global_position
	active_view.scale = Vector2(0.92, 0.92)
	active_view.rotation = deg_to_rad(2.0)

	var lift = create_tween().set_parallel(true)
	lift.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lift.tween_property(active_view, "position", _active_home_position() + Vector2(0, -18), 0.25)
	lift.tween_property(active_view, "scale", Vector2(1.08, 1.08), 0.25)
	lift.tween_property(active_view, "rotation", 0.0, 0.25)
	await lift.finished

	var close = create_tween()
	close.tween_property(active_view, "scale:x", 0.03, 0.09)
	await close.finished
	active_view.configure(-102, card, false)
	_play_sfx(sound_flip, 0.96, 1.04)
	var open = create_tween()
	open.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	open.tween_property(active_view, "scale:x", 1.08, 0.13)
	await open.finished

	var settle = create_tween()
	settle.tween_property(active_view, "position", _active_home_position(), 0.11)
	await settle.finished
	active_view.z_index = 20

func _animate_active_to_discard():
	if not active_view.visible:
		return
	active_view.z_index = 90
	var target = discard_view.global_position + Vector2(randf_range(-3.0, 3.0), randf_range(-2.0, 2.0))
	_play_sfx(sound_slide, 0.92, 0.98)
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(active_view, "global_position", target, 0.22)
	tween.tween_property(active_view, "rotation", deg_to_rad(randf_range(-5.0, 5.0)), 0.22)
	tween.tween_property(active_view, "scale", Vector2(0.96, 0.96), 0.22)
	await tween.finished
	_play_sfx(sound_discard_land, 0.84, 0.91)
	active_view.z_index = 20

func _animate_round_sweep(views):
	for view in views:
		if not is_instance_valid(view):
			continue
		var tween = create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(view, "scale", Vector2(1.06, 1.06), 0.10)
		tween.tween_property(view, "modulate", Color(1.16, 1.08, 0.86, 1.0), 0.10)
		await tween.finished
		var back = create_tween().set_parallel(true)
		back.tween_property(view, "scale", Vector2.ONE, 0.12)
		back.tween_property(view, "modulate", Color.WHITE, 0.12)
		await get_tree().create_timer(0.025).timeout
	await get_tree().create_timer(0.12).timeout

func _show_active_card(card):
	active_view.configure(-102, card, false)
	active_view.visible = true
	active_view.scale = Vector2.ONE
	active_view.rotation = 0.0
	active_view.modulate = Color.WHITE
	discard_view.visible = false

func _hide_active_card():
	if active_view == null:
		return
	active_view.visible = false
	if discard_view != null:
		discard_view.visible = true

func _refresh_piles():
	discard_view.visible = not active_view.visible
	if tutorial_mode:
		draw_count_label.text = "practice deck"
		draw_view.face_down = true
		draw_view.placeholder_text = ""
		draw_view.queue_redraw()
		if discard.is_empty():
			discard_view.set_placeholder("DISCARD")
		else:
			discard_view.configure(-101, discard.back(), false)
		discard_view.queue_redraw()
		return
	draw_count_label.text = "%d cards" % deck.size()
	draw_view.face_down = not deck.is_empty()
	if deck.is_empty():
		draw_view.set_placeholder("EMPTY")
	else:
		draw_view.face_down = true
		draw_view.placeholder_text = ""
		draw_view.queue_redraw()

	if discard.is_empty():
		discard_view.set_placeholder("DISCARD")
	else:
		discard_view.configure(-101, discard.back(), false)
	discard_view.queue_redraw()

func _stage_name(count):
	if count == 1:
		return "ACE"
	return "%d CARDS" % count

func _rank_label(rank):
	if rank == 1: return "Ace"
	if rank == 11: return "Jack"
	if rank == 12: return "Queen"
	if rank == 13: return "King"
	return str(rank)

func _make_label(text_value, pos, size_value, font_size, color, alignment):
	var label = Label.new()
	label.text = text_value
	label.position = pos
	label.size = size_value
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _make_button(text_value, rect, callback, font_size := 16):
	var button = Button.new()
	button.text = text_value
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color("#f4e8d8"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _button_style(Color("#6f3825"), Color("#9a6849")))
	button.add_theme_stylebox_override("hover", _button_style(Color("#84452e"), Color("#c08b60")))
	button.add_theme_stylebox_override("pressed", _button_style(Color("#4f281c"), Color("#d5a16f")))
	button.pressed.connect(callback)
	return button

func _button_style(bg, border):
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = Color(0, 0, 0, 0.24)
	style.shadow_size = 5
	return style

func _panel_style(bg, border, radius, alpha):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(bg.r, bg.g, bg.b, alpha)
	style.border_color = border
	style.set_border_width_all(2)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 14
	return style
