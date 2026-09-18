extends Control


const BG := Color("111111")
const CARD := Color("5C1F1F")
const GOLD := Color("D4AF37")
const TEXT := Color("f5f1e8")
const MUTED := Color("aaa69d")
const SHOP_API_URL := "https://thespotlounge.com/wp-json/wc/store/v1/products?per_page=100"
const EVENTS_URL := "https://thespotlounge.com/wp-json/wp/v2/event?per_page=100&_embed=1"
const MEMBERSHIP_API_URL := "https://thespotlounge.com/wp-json/wp/v2/search?search=Monthly&subtype=product&per_page=100"
const MEETINGS_API_URL := "https://thespotlounge.com/wp-json/wp/v2/pages?slug=meetings"


var shop_request: HTTPRequest
var shop_products: Array = []
var content: VBoxContainer
var title_label: Label
var nav: HBoxContainer
var nav_button_group := ButtonGroup.new()
var overscroll_offset := 0.0
var main_scroll: ScrollContainer
var events_request: HTTPRequest
var events_data: Array = []
var event_schedule_cache: Dictionary = {}
var membership_request: HTTPRequest
var meetings_request: HTTPRequest
var meetings_html: String = ""
var meetings_data: Array = []
var selected_meeting_day: String = "Sunday"
var bg: TextureRect

func _ready() -> void:
	shop_request = HTTPRequest.new()
	add_child(shop_request)
	shop_request.request_completed.connect(_on_shop_request_completed)
	
	events_request = HTTPRequest.new()
	add_child(events_request)
	events_request.request_completed.connect(_on_events_request_completed)
	
	membership_request = HTTPRequest.new()
	add_child(membership_request)
	membership_request.request_completed.connect(_on_membership_request_completed)
	
	meetings_request = HTTPRequest.new()
	add_child(meetings_request)
	meetings_request.request_completed.connect(_on_meetings_request_completed)
	
	_load_cached_live_data()
	_build_shell()
	show_home()
	_show_opening_screen()
	meetings_request.request(MEETINGS_API_URL)

	if not events_data.is_empty():
		events_request.request(EVENTS_URL)

func _show_opening_screen() -> void:
	var splash := Control.new()
	splash.name = "OpeningSplash"
	splash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	splash.mouse_filter = Control.MOUSE_FILTER_STOP
	splash.z_index = 1000
	add_child(splash)

	var black_background := ColorRect.new()
	black_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black_background.color = Color.BLACK
	black_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	splash.add_child(black_background)

	var photo := TextureRect.new()
	photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	photo.texture = load("res://assets/spot_opening.png")
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo.modulate.a = 0.0
	splash.add_child(photo)

	# One restrained shade keeps the photo visible while improving contrast.
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.26)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.modulate.a = 0.0
	splash.add_child(shade)

	# Logo and tagline occupy only the upper third.
	var logo_holder := VBoxContainer.new()
	logo_holder.set_anchors_preset(Control.PRESET_TOP_WIDE)
	logo_holder.anchor_top = 0.06
	logo_holder.anchor_bottom = 0.39
	logo_holder.offset_left = 18.0
	logo_holder.offset_right = -18.0
	logo_holder.alignment = BoxContainer.ALIGNMENT_CENTER
	logo_holder.add_theme_constant_override("separation", -2)
	logo_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo_holder.modulate.a = 0.0
	splash.add_child(logo_holder)

	var logo := TextureRect.new()
	logo.texture = load("res://assets/Spotlogo.png")
	logo.custom_minimum_size = Vector2(330.0, 210.0)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo_holder.add_child(logo)

	# Lighter tagline treatment: no large heavy box.
	var tagline_panel := PanelContainer.new()
	tagline_panel.custom_minimum_size = Vector2(306.0, 40.0)
	tagline_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tagline_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tagline_style := StyleBoxFlat.new()
	tagline_style.bg_color = Color(0.08, 0.01, 0.02, 0.62)
	tagline_style.border_color = Color(0.96, 0.77, 0.25, 0.78)
	tagline_style.border_width_bottom = 1
	tagline_style.set_corner_radius_all(9)
	tagline_style.content_margin_left = 10
	tagline_style.content_margin_right = 10
	tagline_style.content_margin_top = 6
	tagline_style.content_margin_bottom = 6
	tagline_panel.add_theme_stylebox_override("panel", tagline_style)
	logo_holder.add_child(tagline_panel)

	var tagline_label := Label.new()
	tagline_label.text = "SOBER LOUNGE  •  SOBER STATE OF MIND"
	tagline_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tagline_label.add_theme_font_size_override("font_size", 14)
	tagline_label.add_theme_color_override("font_color", Color("#F5C542"))
	tagline_label.add_theme_color_override("font_outline_color", Color("#3A080E"))
	tagline_label.add_theme_constant_override("outline_size", 2)
	tagline_panel.add_child(tagline_label)

	# The entrance button now has its own space near the bottom.
	var button_holder := CenterContainer.new()
	button_holder.set_anchors_preset(Control.PRESET_TOP_WIDE)
	button_holder.anchor_top = 0.78
	button_holder.anchor_bottom = 0.90
	button_holder.offset_left = 20.0
	button_holder.offset_right = -20.0
	button_holder.modulate.a = 0.0
	splash.add_child(button_holder)

	var enter_button := Button.new()
	enter_button.text = "COME ON IN   ›"
	enter_button.custom_minimum_size = Vector2(270.0, 68.0)
	enter_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	enter_button.add_theme_font_size_override("font_size", 23)
	enter_button.add_theme_color_override(
		"font_color",
		Color("#FFF0B5")
	)
	enter_button.add_theme_color_override(
		"font_hover_color",
		Color.WHITE
	)
	enter_button.add_theme_color_override(
		"font_pressed_color",
		Color.WHITE
	)
	enter_button.add_theme_color_override(
		"font_outline_color",
		Color("#8B1010")
	)
	enter_button.add_theme_constant_override("outline_size", 3)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color("#26050B")
	normal_style.border_color = Color("#FFE36E")
	normal_style.set_border_width_all(3)
	normal_style.set_corner_radius_all(14)
	normal_style.shadow_color = Color(0.90, 0.02, 0.12, 0.72)
	normal_style.shadow_size = 14
	normal_style.shadow_offset = Vector2.ZERO
	enter_button.add_theme_stylebox_override(
		"normal",
		normal_style
	)

	var hover_style := normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color("#7A0B1D")
	hover_style.border_color = Color("#FFF0B5")
	hover_style.shadow_color = Color(1.0, 0.05, 0.15, 0.90)
	hover_style.shadow_size = 18
	enter_button.add_theme_stylebox_override(
		"hover",
		hover_style
	)
	enter_button.add_theme_stylebox_override(
		"focus",
		hover_style
	)

	var pressed_style := normal_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color("#E30620")
	pressed_style.border_color = Color.WHITE
	pressed_style.shadow_size = 5
	enter_button.add_theme_stylebox_override(
		"pressed",
		pressed_style
	)

	button_holder.add_child(enter_button)
	await get_tree().process_frame

	photo.pivot_offset = photo.size / 2.0
	logo_holder.pivot_offset = logo_holder.size / 2.0
	button_holder.pivot_offset = button_holder.size / 2.0

	photo.scale = Vector2(1.08, 1.08)
	logo_holder.scale = Vector2(0.84, 0.84)
	button_holder.scale = Vector2(0.92, 0.92)
	logo_holder.modulate = Color(1.18, 0.88, 0.70, 0.0)

	var opening := create_tween()
	opening.set_parallel(true)
	opening.set_trans(Tween.TRANS_QUAD)
	opening.set_ease(Tween.EASE_OUT)
	opening.tween_property(photo, "modulate:a", 1.0, 0.9)
	opening.tween_property(shade, "modulate:a", 1.0, 0.9)
	opening.tween_property(photo, "scale", Vector2.ONE, 4.0)

	await get_tree().create_timer(0.40).timeout

	var logo_entrance := create_tween()
	logo_entrance.set_parallel(true)
	logo_entrance.set_trans(Tween.TRANS_BACK)
	logo_entrance.set_ease(Tween.EASE_OUT)
	logo_entrance.tween_property(
		logo_holder,
		"modulate",
		Color.WHITE,
		0.68
	)
	logo_entrance.tween_property(
		logo_holder,
		"scale",
		Vector2.ONE,
		0.68
	)
	logo_entrance.tween_property(
		logo_holder,
		"position:y",
		logo_holder.position.y,
		0.68
	).from(logo_holder.position.y + 24.0)

	await get_tree().create_timer(0.24).timeout

	var button_entrance := create_tween()
	button_entrance.set_parallel(true)
	button_entrance.set_trans(Tween.TRANS_BACK)
	button_entrance.set_ease(Tween.EASE_OUT)
	button_entrance.tween_property(
		button_holder,
		"modulate:a",
		1.0,
		0.55
	)
	button_entrance.tween_property(
		button_holder,
		"scale",
		Vector2.ONE,
		0.55
	)
	button_entrance.tween_property(
		button_holder,
		"position:y",
		button_holder.position.y,
		0.55
	).from(button_holder.position.y + 28.0)

	await button_entrance.finished

	var button_pulse := create_tween()
	button_pulse.set_loops()
	button_pulse.set_trans(Tween.TRANS_SINE)
	button_pulse.set_ease(Tween.EASE_IN_OUT)
	button_pulse.tween_property(
		normal_style,
		"shadow_size",
		19,
		0.85
	)
	button_pulse.tween_property(
		normal_style,
		"shadow_size",
		11,
		0.85
	)

	await enter_button.pressed
	button_pulse.kill()
	enter_button.disabled = true
	Input.vibrate_handheld(60)
	var entrance_sound := AudioStreamPlayer.new()
	entrance_sound.stream = load(
		"res://assets/audio/come_on_in.mp3"
	)
	entrance_sound.volume_db = -8.0
	add_child(entrance_sound)
	entrance_sound.finished.connect(
		entrance_sound.queue_free
	)
	entrance_sound.play()
	var flash := ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color("#F5C542")
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.modulate.a = 0.0
	flash.z_index = 100
	splash.add_child(flash)

	enter_button.pivot_offset = enter_button.size / 2.0
	logo_holder.pivot_offset = logo_holder.size / 2.0
	button_holder.pivot_offset = button_holder.size / 2.0

	var press_tween := create_tween()
	press_tween.set_trans(Tween.TRANS_BACK)
	press_tween.set_ease(Tween.EASE_IN)
	press_tween.tween_property(enter_button, "scale", Vector2(0.88, 0.88), 0.10)
	press_tween.tween_property(enter_button, "scale", Vector2(1.08, 1.08), 0.16)
	await press_tween.finished

	enter_button.text = "WELCOME HOME"

		# Two lounge-style doors cover the splash, then open onto Home.
	var left_door := PanelContainer.new()
	left_door.anchor_left = 0.0
	left_door.anchor_top = 0.0
	left_door.anchor_right = 0.5
	left_door.anchor_bottom = 1.0
	left_door.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_door.modulate.a = 0.0
	left_door.z_index = 200

	var left_door_style := StyleBoxFlat.new()
	left_door_style.bg_color = Color("#26050B")
	left_door_style.border_color = Color("#FFE36E")
	left_door_style.border_width_right = 3
	left_door_style.shadow_color = Color(0, 0, 0, 0.85)
	left_door_style.shadow_size = 12
	left_door_style.shadow_offset = Vector2(5, 0)
	left_door.add_theme_stylebox_override(
		"panel",
		left_door_style
	)
	splash.add_child(left_door)

	var right_door := PanelContainer.new()
	right_door.anchor_left = 0.5
	right_door.anchor_top = 0.0
	right_door.anchor_right = 1.0
	right_door.anchor_bottom = 1.0
	right_door.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_door.modulate.a = 0.0
	right_door.z_index = 200

	var right_door_style := StyleBoxFlat.new()
	right_door_style.bg_color = Color("#26050B")
	right_door_style.border_color = Color("#FFE36E")
	right_door_style.border_width_left = 3
	right_door_style.shadow_color = Color(0, 0, 0, 0.85)
	right_door_style.shadow_size = 12
	right_door_style.shadow_offset = Vector2(-5, 0)
	right_door.add_theme_stylebox_override(
		"panel",
		right_door_style
	)
	splash.add_child(right_door)

	var welcome_overlay := Label.new()
	welcome_overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	welcome_overlay.text = "WELCOME HOME"
	welcome_overlay.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	welcome_overlay.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	welcome_overlay.add_theme_font_size_override(
		"font_size",
		46
	)
	welcome_overlay.add_theme_color_override(
		"font_color",
		Color("#FFF0B5")
	)
	welcome_overlay.add_theme_color_override(
		"font_outline_color",
		Color("#B60920")
	)
	welcome_overlay.add_theme_constant_override(
		"outline_size",
		8
	)
	welcome_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	welcome_overlay.modulate.a = 0.0
	welcome_overlay.z_index = 201

	if ResourceLoader.exists(
		"res://assets/fonts/Yellowtail/Yellowtail-Regular.ttf"
	):
		welcome_overlay.add_theme_font_override(
			"font",
			load(
				"res://assets/fonts/Yellowtail/Yellowtail-Regular.ttf"
			)
		)

	splash.add_child(welcome_overlay)

	await get_tree().process_frame

	# Brief branded pulse as the doors appear.
	var cover_tween := create_tween()
	cover_tween.set_parallel(true)
	cover_tween.set_trans(Tween.TRANS_QUAD)
	cover_tween.set_ease(Tween.EASE_OUT)
	cover_tween.tween_property(
		logo_holder,
		"scale",
		Vector2(1.08, 1.08),
		0.32
	)
	cover_tween.tween_property(
		photo,
		"modulate:a",
		0.0,
		0.32
	)
	cover_tween.tween_property(
		shade,
		"modulate:a",
		0.0,
		0.32
	)
	cover_tween.tween_property(
		logo_holder,
		"modulate:a",
		0.0,
		0.32
	)
	cover_tween.tween_property(
		button_holder,
		"modulate:a",
		0.0,
		0.32
	)
	cover_tween.tween_property(
		black_background,
		"modulate:a",
		0.0,
		0.32
	)
	cover_tween.tween_property(
		left_door,
		"modulate:a",
		1.0,
		0.18
	)
	cover_tween.tween_property(
		right_door,
		"modulate:a",
		1.0,
		0.32
	)
	cover_tween.tween_property(
		welcome_overlay,
		"modulate:a",
		1.0,
		0.40
	)

	await cover_tween.finished
	await get_tree().create_timer(0.22).timeout

	var screen_width := splash.size.x

	var door_tween := create_tween()
	door_tween.set_parallel(true)
	door_tween.set_trans(Tween.TRANS_CUBIC)
	door_tween.set_ease(Tween.EASE_IN_OUT)
	door_tween.tween_property(
		left_door,
		"position:x",
		left_door.position.x - screen_width * 0.55,
		1.15
	)
	door_tween.tween_property(
		right_door,
		"position:x",
		right_door.position.x + screen_width * 0.55,
		1.15
	)
	door_tween.tween_property(
		welcome_overlay,
		"modulate:a",
		0.0,
		0.65
	).set_delay(0.32)

	await door_tween.finished
	splash.queue_free()

	
func _load_cached_live_data() -> void:
	if FileAccess.file_exists("user://meetings_cache.json"):
		var _file = FileAccess.open("user://meetings_cache.json", FileAccess.READ)
		var _data = JSON.parse_string(_file.get_as_text())
		if _data is Array:
			meetings_data = _data
		
	if FileAccess.file_exists("user://shop_cache.json"):
		var _file = FileAccess.open("user://shop_cache.json", FileAccess.READ)
		var _data = JSON.parse_string(_file.get_as_text())
		if _data is Array:
			shop_products = _data

	if FileAccess.file_exists("user://events_cache.json"):
		var _file = FileAccess.open("user://events_cache.json", FileAccess.READ)
		var _data = JSON.parse_string(_file.get_as_text())
		if _data is Array:
			events_data = _data
	
func _apply_safe_area(
	safe_root: MarginContainer,
	bottom_safe_fill: Panel
) -> void:
	if OS.get_name() != "iOS" and OS.get_name() != "Android":
		bottom_safe_fill.visible = false
		return

	var safe_rect: Rect2i = DisplayServer.get_display_safe_area()
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	var viewport_size: Vector2 = get_viewport_rect().size

	if screen_size.x <= 0 or screen_size.y <= 0:
		return

	var scale_x: float = viewport_size.x / float(screen_size.x)
	var scale_y: float = viewport_size.y / float(screen_size.y)

	var left_margin: int = int(round(safe_rect.position.x * scale_x))
	var top_margin: int = int(round(safe_rect.position.y * scale_y))
	var right_pixels: int = (
		screen_size.x
		- safe_rect.position.x
		- safe_rect.size.x
	)
	var bottom_pixels: int = (
		screen_size.y
		- safe_rect.position.y
		- safe_rect.size.y
	)
	var right_margin: int = int(
		round(max(0, right_pixels) * scale_x)
	)
	var bottom_margin: int = int(
		round(max(0, bottom_pixels) * scale_y)
	)

	safe_root.add_theme_constant_override(
		"margin_left",
		left_margin
	)
	safe_root.add_theme_constant_override(
		"margin_top",
		top_margin
	)
	safe_root.add_theme_constant_override(
		"margin_right",
		right_margin
	)
	safe_root.add_theme_constant_override(
		"margin_bottom",
		bottom_margin
	)

	bottom_safe_fill.visible = (
		OS.get_name() == "iOS"
		and bottom_margin > 0
	)
	bottom_safe_fill.offset_top = -float(bottom_margin)
	
func _build_shell() -> void:
	var bg_image = load("res://assets/freedom.jpeg")

	bg = TextureRect.new()
	bg.texture = bg_image
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var background_tint := ColorRect.new()
	background_tint.color = Color(0.02, 0.01, 0.015, 0.32)
	background_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_tint.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	add_child(background_tint)

	# Fill the iPhone bottom safe area with the navigation color.
	var bottom_safe_fill := Panel.new()
	bottom_safe_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_safe_fill.anchor_left = 0.0
	bottom_safe_fill.anchor_top = 1.0
	bottom_safe_fill.anchor_right = 1.0
	bottom_safe_fill.anchor_bottom = 1.0
	bottom_safe_fill.offset_left = 0.0
	bottom_safe_fill.offset_top = 0.0
	bottom_safe_fill.offset_right = 0.0
	bottom_safe_fill.offset_bottom = 0.0
	bottom_safe_fill.visible = false

	var bottom_fill_style := StyleBoxFlat.new()
	bottom_fill_style.bg_color = Color.from_rgba8(
		74, 22, 27, 255
	)
	bottom_fill_style.border_color = Color.from_rgba8(
		212, 175, 55, 255
	)
	bottom_fill_style.border_width_left = 2
	bottom_fill_style.border_width_right = 2
	bottom_fill_style.border_width_bottom = 2
	bottom_fill_style.corner_radius_bottom_left = 18
	bottom_fill_style.corner_radius_bottom_right = 18

	bottom_safe_fill.add_theme_stylebox_override(
		"panel",
		bottom_fill_style
	)
	add_child(bottom_safe_fill)

	var safe_root := MarginContainer.new()
	safe_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(safe_root)

	var root := VBoxContainer.new()
	root.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 0)
	safe_root.add_child(root)

	get_viewport().size_changed.connect(
		func():
			_apply_safe_area(safe_root, bottom_safe_fill)
	)

	call_deferred(
		"_apply_safe_area",
		safe_root,
		bottom_safe_fill
	)

	var header := VBoxContainer.new()
	header.custom_minimum_size.y = 14
	header.add_theme_constant_override("separation", 2)
	root.add_child(header)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", TEXT)
	title_label.add_theme_color_override(
		"font_outline_color",
		Color("#000000")
	)
	title_label.add_theme_constant_override("outline_size", 12)
	title_label.custom_minimum_size.y = 20
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title_label)

	var scroll := ScrollContainer.new()
	main_scroll = scroll
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.scroll_deadzone = 12
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)

	nav = HBoxContainer.new()
	nav.custom_minimum_size.y = 84
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 6)
	root.add_child(nav)

	_nav_button("Home", show_home)
	_nav_button("Meetings", show_meetings)
	_nav_button("Events", show_events)
	_nav_button("Shop", show_shop)
	_nav_button("More", show_more)

func _nav_button(label: String, action: Callable) -> void:
	var b := Button.new()

	b.toggle_mode = true
	b.button_group = nav_button_group
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 76)
	b.text = ""

	# ---------- INACTIVE BUTTON STYLE ----------
	var nav_style := StyleBoxFlat.new()
	nav_style.bg_color = Color.from_rgba8(74, 22, 27, 255)
	nav_style.border_color = Color.from_rgba8(212, 175, 55, 255)
	nav_style.set_border_width_all(2)

	nav_style.corner_radius_top_left = 14
	nav_style.corner_radius_top_right = 14
	nav_style.corner_radius_bottom_left = 14
	nav_style.corner_radius_bottom_right = 14

	nav_style.shadow_color = Color(0, 0, 0, 0.55)
	nav_style.shadow_size = 6

	b.add_theme_stylebox_override("normal", nav_style)
	b.add_theme_stylebox_override("hover", nav_style)


	# ---------- ACTIVE BUTTON STYLE ----------
	var active_style := StyleBoxFlat.new()
	active_style.bg_color = Color.from_rgba8(182, 22, 39, 255)
	active_style.border_color = Color.from_rgba8(255, 210, 63, 255)
	active_style.set_border_width_all(3)

	active_style.corner_radius_top_left = 16
	active_style.corner_radius_top_right = 16
	active_style.corner_radius_bottom_left = 16
	active_style.corner_radius_bottom_right = 16

	active_style.shadow_color = Color(0, 0, 0, 0.75)
	active_style.shadow_size = 10

	b.add_theme_stylebox_override("pressed", active_style)
	b.add_theme_stylebox_override("hover_pressed", active_style)


	# ---------- ICON + LABEL ----------
	var icon_stack := VBoxContainer.new()
	b.add_child(icon_stack)

	icon_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	icon_stack.add_theme_constant_override("separation", 2)
	icon_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE


	var icon := NavIcon.new()
	icon.setup(label.to_lower())
	icon_stack.add_child(icon)

	icon.custom_minimum_size = Vector2(34, 34)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE


	var nav_label := Label.new()
	nav_label.text = label
	nav_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_label.add_theme_font_size_override("font_size", 12)
	nav_label.add_theme_color_override(
		"font_color",
		Color.from_rgba8(212, 175, 55, 255)
	)
	nav_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	icon_stack.add_child(nav_label)


	# ---------- HOME STARTS SELECTED ----------
	if label == "Home":
		b.button_pressed = true

		icon.icon_color = Color.from_rgba8(255, 224, 102, 255)
		icon.queue_redraw()

		nav_label.add_theme_color_override(
			"font_color",
			Color.WHITE
		)


	# ---------- CHANGE ICON COLORS WHEN TAB IS SELECTED ----------
	b.pressed.connect(func():
		for child in nav.get_children():
			if child is Button:
				var child_stack := child.get_child(0) as VBoxContainer
				var child_icon := child_stack.get_child(0) as NavIcon
				var child_label := child_stack.get_child(1) as Label

				child_icon.icon_color = Color.from_rgba8(
					212, 175, 55, 255
				)
				child_icon.queue_redraw()

				child_label.add_theme_color_override(
					"font_color",
					Color.from_rgba8(212, 175, 55, 255)
				)

		var selected_stack := b.get_child(0) as VBoxContainer
		var selected_icon := selected_stack.get_child(0) as NavIcon
		var selected_label := selected_stack.get_child(1) as Label

		selected_icon.icon_color = Color.from_rgba8(
			255, 224, 102, 255
		)
		selected_icon.queue_redraw()

		selected_label.add_theme_color_override(
			"font_color",
			Color.WHITE
		)

		action.call()
	)


	nav.add_child(b)

func _clear(page_title: String) -> void:
	title_label.visible = true
	title_label.text = page_title
	var title_style = StyleBoxFlat.new()
	title_style.bg_color = Color("#B83A4B")
	title_style.border_color = Color("#D4AF37")
	title_style.set_border_width_all(3)
	title_style.corner_radius_top_left = 14
	title_style.corner_radius_top_right = 14
	title_style.corner_radius_bottom_left = 14
	title_style.corner_radius_bottom_right = 14
	title_style.content_margin_top = 8
	title_style.content_margin_bottom = 8

	title_label.add_theme_stylebox_override("normal", title_style)
	title_label.add_theme_color_override("font_color", Color("#F3D36A"))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.custom_minimum_size = Vector2(0, 50)
	bg.modulate = Color.WHITE
	for c in content.get_children(): c.queue_free()
	content.add_spacer(false)

func _add_page_header(
	page_title: String,
	subtitle_text: String,
	icon_name: String,
	badge_text: String
) -> void:
	var header_panel := PanelContainer.new()
	header_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_panel.custom_minimum_size.y = 104
	header_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var header_style := StyleBoxFlat.new()
	header_style.bg_color = Color("#5B0715")
	header_style.border_color = Color("#FFE36E")
	header_style.set_border_width_all(2)
	header_style.border_width_left = 6
	header_style.set_corner_radius_all(15)
	header_style.shadow_color = Color(0, 0, 0, 0.72)
	header_style.shadow_size = 10
	header_style.shadow_offset = Vector2(0, 4)
	header_style.content_margin_left = 14
	header_style.content_margin_right = 12
	header_style.content_margin_top = 13
	header_style.content_margin_bottom = 13
	header_panel.add_theme_stylebox_override("panel", header_style)
	content.add_child(header_panel)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_panel.add_child(header_row)

	var icon_badge := PanelContainer.new()
	icon_badge.custom_minimum_size = Vector2(58, 58)
	icon_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color("#A9152D")
	icon_style.border_color = Color("#FFE36E")
	icon_style.set_border_width_all(2)
	icon_style.set_corner_radius_all(29)
	icon_badge.add_theme_stylebox_override("panel", icon_style)
	header_row.add_child(icon_badge)

	var header_icon := NavIcon.new()
	header_icon.setup(icon_name)
	header_icon.icon_color = Color("#FFE36E")
	header_icon.custom_minimum_size = Vector2(40, 40)
	header_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	header_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_badge.add_child(header_icon)

	var heading_stack := VBoxContainer.new()
	heading_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	heading_stack.add_theme_constant_override("separation", 2)
	heading_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_child(heading_stack)

	var heading := Label.new()
	heading.text = page_title
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.custom_minimum_size.x = 0
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", Color("#FFF0B5"))
	heading.add_theme_color_override(
		"font_outline_color",
		Color("#3A080E")
	)
	heading.add_theme_constant_override("outline_size", 3)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading_stack.add_child(heading)

	var subtitle := Label.new()
	subtitle.text = subtitle_text
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.custom_minimum_size.x = 0
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override(
		"font_color",
		Color("#F5E9E1")
	)
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading_stack.add_child(subtitle)

	var header_badge := PanelContainer.new()
	header_badge.custom_minimum_size = Vector2(68, 48)
	header_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color("#E30620")
	badge_style.border_color = Color("#FFE36E")
	badge_style.set_border_width_all(2)
	badge_style.set_corner_radius_all(10)
	header_badge.add_theme_stylebox_override("panel", badge_style)
	header_row.add_child(header_badge)

	var badge_label := Label.new()
	badge_label.text = badge_text
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.add_theme_font_size_override("font_size", 10)
	badge_label.add_theme_color_override(
		"font_color",
		Color("#FFF0B5")
	)
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_badge.add_child(badge_label)

func _animate_section(panel: Control) -> void:
	await get_tree().process_frame

	if not is_instance_valid(panel) or not panel.is_inside_tree():
		return

	panel.pivot_offset = panel.size / 2.0

	var tween := panel.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.22)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.22)

func _show_map_choice() -> void:
	var apple_maps_url := (
		"https://maps.apple.com/?daddr="
		+ "4220+W+Northern+Ave,+Suite+111,+Phoenix,+AZ"
	)

	var google_maps_url := (
		"https://www.google.com/maps/dir/?api=1&destination="
		+ "4220+W+Northern+Ave,+Suite+111,+Phoenix,+AZ"
	)

	# Android continues directly to Google Maps.
	if OS.has_feature("android"):
		OS.shell_open(google_maps_url)
		return

	var map_dialog := ConfirmationDialog.new()
	map_dialog.title = ""
	map_dialog.dialog_text = (
		"CHOOSE YOUR MAP\n"
		+ "How would you like to get directions to The Spot?"
	)
	map_dialog.ok_button_text = "APPLE MAPS"
	map_dialog.cancel_button_text = "CANCEL"
	map_dialog.exclusive = true
	map_dialog.borderless = true
	map_dialog.unresizable = true

	var google_button: Button = map_dialog.add_button(
		"GOOGLE MAPS",
		false,
		"google_maps"
	)

	add_child(map_dialog)

	var dialog_style := StyleBoxFlat.new()
	dialog_style.bg_color = Color("#35060E")
	dialog_style.border_color = Color("#FFE36E")
	dialog_style.set_border_width_all(3)
	dialog_style.set_corner_radius_all(18)
	dialog_style.shadow_color = Color(0, 0, 0, 0.80)
	dialog_style.shadow_size = 16
	dialog_style.shadow_offset = Vector2(0, 5)
	dialog_style.content_margin_left = 18
	dialog_style.content_margin_right = 18
	dialog_style.content_margin_top = 18
	dialog_style.content_margin_bottom = 16
	map_dialog.add_theme_stylebox_override(
		"panel",
		dialog_style
	)

	var map_message := map_dialog.get_label()
	map_message.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	map_message.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	map_message.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	map_message.add_theme_font_size_override(
		"font_size",
		17
	)
	map_message.add_theme_color_override(
		"font_color",
		Color("#FFF0B5")
	)
	map_message.add_theme_color_override(
		"font_outline_color",
		Color("#5B0715")
	)
	map_message.add_theme_constant_override(
		"outline_size",
		3
	)

	var apple_button := map_dialog.get_ok_button()
	var cancel_button := map_dialog.get_cancel_button()

	var choice_normal := StyleBoxFlat.new()
	choice_normal.bg_color = Color("#E30620")
	choice_normal.border_color = Color("#FFE36E")
	choice_normal.set_border_width_all(2)
	choice_normal.set_corner_radius_all(10)
	choice_normal.content_margin_left = 10
	choice_normal.content_margin_right = 10
	choice_normal.content_margin_top = 10
	choice_normal.content_margin_bottom = 10

	var choice_hover := (
		choice_normal.duplicate() as StyleBoxFlat
	)
	choice_hover.bg_color = Color("#FF1733")
	choice_hover.border_color = Color("#FFF0B5")

	var choice_pressed := (
		choice_normal.duplicate() as StyleBoxFlat
	)
	choice_pressed.bg_color = Color("#8A0B1D")

	var map_choice_buttons: Array[Button] = [
		apple_button,
		google_button
	]

	for choice_button in map_choice_buttons:
		choice_button.add_theme_font_size_override(
			"font_size",
			13
		)
		choice_button.add_theme_color_override(
			"font_color",
			Color("#FFF0B5")
		)
		choice_button.add_theme_color_override(
			"font_hover_color",
			Color.WHITE
		)
		choice_button.add_theme_stylebox_override(
			"normal",
			choice_normal
		)
		choice_button.add_theme_stylebox_override(
			"hover",
			choice_hover
		)
		choice_button.add_theme_stylebox_override(
			"focus",
			choice_hover
		)
		choice_button.add_theme_stylebox_override(
			"pressed",
			choice_pressed
		)

	var cancel_style := (
		choice_normal.duplicate() as StyleBoxFlat
	)
	cancel_style.bg_color = Color("#210409")
	cancel_style.border_color = Color("#B5273D")

	cancel_button.add_theme_font_size_override(
		"font_size",
		13
	)
	cancel_button.add_theme_color_override(
		"font_color",
		Color("#E8D4CE")
	)
	cancel_button.add_theme_stylebox_override(
		"normal",
		cancel_style
	)
	cancel_button.add_theme_stylebox_override(
		"hover",
		choice_hover
	)
	cancel_button.add_theme_stylebox_override(
		"focus",
		choice_hover
	)

	map_dialog.confirmed.connect(
		func() -> void:
			OS.shell_open(apple_maps_url)
			map_dialog.queue_free()
	)

	map_dialog.custom_action.connect(
		func(action: StringName) -> void:
			if action == &"google_maps":
				OS.shell_open(google_maps_url)

			map_dialog.queue_free()
	)

	map_dialog.canceled.connect(
		map_dialog.queue_free
	)

	map_dialog.popup_centered(
		Vector2i(340, 280)
	)


func _section(text: String, body: String, button_text := "", url := "") -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.98, 0.98)

	var style := StyleBoxFlat.new()
	style.bg_color = Color("#641A24")
	style.border_color = Color("#D4AF37")
	style.set_border_width_all(1)
	style.border_width_left = 4
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 3)
	style.content_margin_left = 20
	style.content_margin_right = 18
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)
	content.add_child(panel)
	_animate_section(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var h := Label.new()
	h.text = text
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.custom_minimum_size.x = 0
	h.add_theme_font_size_override("font_size", 21)
	h.add_theme_color_override("font_color", Color("#FFE06A"))
	h.add_theme_color_override("font_outline_color", Color("#3A080E"))
	h.add_theme_constant_override("outline_size", 4)
	box.add_child(h)

	var accent_line := ColorRect.new()
	accent_line.color = Color("#D4AF37")
	accent_line.custom_minimum_size = Vector2(0, 2)
	accent_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(accent_line)

	var p := Label.new()
	p.text = body
	p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size.x = 0
	p.add_theme_font_size_override("font_size", 16)
	p.add_theme_color_override("font_color", Color("#F5E9E1"))
	p.add_theme_constant_override("line_spacing", 4)
	box.add_child(p)

	if button_text != "":
		var b := Button.new()
		b.text = button_text
		b.custom_minimum_size = Vector2(0, 52)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 16)
		b.add_theme_color_override("font_color", Color("#FFE06A"))
		b.add_theme_color_override("font_hover_color", Color("#FFFFFF"))
		b.add_theme_color_override("font_pressed_color", Color("#FFFFFF"))
		b.add_theme_color_override("font_outline_color", Color("#3A080E"))
		b.add_theme_constant_override("outline_size", 3)
		box.add_child(b)

		var button_style := StyleBoxFlat.new()
		button_style.bg_color = Color("#A9152D")
		button_style.border_color = Color("#D4AF37")
		button_style.set_border_width_all(2)
		button_style.corner_radius_top_left = 10
		button_style.corner_radius_top_right = 10
		button_style.corner_radius_bottom_left = 10
		button_style.corner_radius_bottom_right = 10
		button_style.shadow_color = Color(0, 0, 0, 0.4)
		button_style.shadow_size = 5
		button_style.shadow_offset = Vector2(0, 2)

		var button_hover_style := button_style.duplicate() as StyleBoxFlat
		button_hover_style.bg_color = Color("#D21F3B")
		button_hover_style.border_color = Color("#FFF09A")

		var button_pressed_style := button_style.duplicate() as StyleBoxFlat
		button_pressed_style.bg_color = Color("#741522")
		button_pressed_style.shadow_size = 2

		b.add_theme_stylebox_override("normal", button_style)
		b.add_theme_stylebox_override("hover", button_hover_style)
		b.add_theme_stylebox_override("pressed", button_pressed_style)
		b.add_theme_stylebox_override("focus", button_hover_style)

		if url == "app://shop":
			b.pressed.connect(show_shop)
		elif url == "app://vip":
			b.pressed.connect(show_vip)
		elif url != "":
			b.pressed.connect(func(): OS.shell_open(url))

func show_home() -> void:
	_clear("")
	title_label.visible = false
	_add_page_header(
		"WELCOME HOME",
		"Welcome back to your community.",
		"home",
		"THE\nSPOT"
	)

	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.custom_minimum_size.y = 56
	title_label.add_theme_font_size_override("font_size", 27)
	title_label.add_theme_color_override("font_color", Color("#FFE06A"))
	title_label.add_theme_color_override("font_outline_color", Color("#3A080E"))
	title_label.add_theme_constant_override("outline_size", 6)

	var title_style := StyleBoxFlat.new()
	title_style.bg_color = Color("#C91932")
	title_style.border_color = Color("#FFE06A")
	title_style.set_border_width_all(3)
	title_style.corner_radius_top_left = 15
	title_style.corner_radius_top_right = 15
	title_style.corner_radius_bottom_left = 15
	title_style.corner_radius_bottom_right = 15
	title_style.shadow_color = Color(0, 0, 0, 0.7)
	title_style.shadow_size = 10
	title_style.shadow_offset = Vector2(0, 3)
	title_style.content_margin_left = 12
	title_style.content_margin_right = 12
	title_style.content_margin_top = 6
	title_style.content_margin_bottom = 6
	title_label.add_theme_stylebox_override("normal", title_style)

	var hero_panel := PanelContainer.new()
	hero_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_panel.modulate.a = 0.0
	hero_panel.scale = Vector2(0.98, 0.98)

	var hero_style := StyleBoxFlat.new()
	hero_style.bg_color = Color(0.035, 0.025, 0.025, 0.88)
	hero_style.border_color = Color("#D4AF37")
	hero_style.set_border_width_all(2)
	hero_style.corner_radius_top_left = 16
	hero_style.corner_radius_top_right = 16
	hero_style.corner_radius_bottom_left = 16
	hero_style.corner_radius_bottom_right = 16
	hero_style.shadow_color = Color(0, 0, 0, 0.6)
	hero_style.shadow_size = 10
	hero_style.shadow_offset = Vector2(0, 3)
	hero_style.content_margin_left = 12
	hero_style.content_margin_right = 12
	hero_style.content_margin_top = 10
	hero_style.content_margin_bottom = 12
	hero_panel.add_theme_stylebox_override("panel", hero_style)
	content.add_child(hero_panel)
	_animate_section(hero_panel)

	var hero_box := VBoxContainer.new()
	hero_box.add_theme_constant_override("separation", 6)
	hero_panel.add_child(hero_box)

	var sub := Label.new()
	sub.text = "SOBER LOUNGE • SOBER STATE OF MIND"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color("#FFE06A"))
	sub.add_theme_color_override("font_outline_color", Color("#6E1823"))
	sub.add_theme_constant_override("outline_size", 5)
	hero_box.add_child(sub)

	var hero_line := ColorRect.new()
	hero_line.color = Color("#D4AF37")
	hero_line.custom_minimum_size = Vector2(0, 2)
	hero_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_box.add_child(hero_line)

	var logo := TextureRect.new()
	logo.texture = load("res://assets/Spotlogo.png")
	logo.custom_minimum_size = Vector2(0, 160)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero_box.add_child(logo)
	call_deferred("_animate_home_logo", logo)

	_section(
		"MORE THAN A MEETING",
		"A place to connect, laugh, grow, and experience life in recovery.\n\nMeetings • Fellowship • Events • Games • Community"
	)

	var more_feature := content.get_child(
		content.get_child_count() - 1
	) as PanelContainer

	var more_feature_style := StyleBoxFlat.new()
	more_feature_style.bg_color = Color("#4A0612")
	more_feature_style.border_color = Color("#FFE36E")
	more_feature_style.set_border_width_all(2)
	more_feature_style.border_width_left = 7
	more_feature_style.set_corner_radius_all(16)
	more_feature_style.shadow_color = Color(0, 0, 0, 0.75)
	more_feature_style.shadow_size = 12
	more_feature_style.shadow_offset = Vector2(0, 4)
	more_feature_style.content_margin_left = 18
	more_feature_style.content_margin_right = 16
	more_feature_style.content_margin_top = 15
	more_feature_style.content_margin_bottom = 16
	more_feature.add_theme_stylebox_override(
		"panel",
		more_feature_style
	)

	var more_feature_box := more_feature.get_child(0) as VBoxContainer
	var more_feature_title := more_feature_box.get_child(0) as Label
	var more_feature_line := more_feature_box.get_child(1) as ColorRect
	var more_feature_body := more_feature_box.get_child(2) as Label

	var feature_eyebrow := Label.new()
	feature_eyebrow.text = "THE SPOT DIFFERENCE"
	feature_eyebrow.add_theme_font_size_override("font_size", 11)
	feature_eyebrow.add_theme_color_override(
		"font_color",
		Color("#E94B5F")
	)
	more_feature_box.add_child(feature_eyebrow)
	more_feature_box.move_child(feature_eyebrow, 0)

	more_feature_title.add_theme_font_size_override("font_size", 25)
	more_feature_title.add_theme_color_override(
		"font_color",
		Color("#FFF0B5")
	)
	more_feature_title.add_theme_constant_override("outline_size", 4)

	more_feature_line.color = Color("#E30620")
	more_feature_line.custom_minimum_size.y = 3

	more_feature_body.add_theme_font_size_override("font_size", 16)
	more_feature_body.add_theme_color_override(
		"font_color",
		Color("#FFF7F0")
	)
	more_feature_body.add_theme_constant_override("line_spacing", 5)

	var date: Dictionary = Time.get_date_dict_from_system()
	var weekday: int = int(date.get("weekday", 0))
	var day_names: Array[String] = [
		"Sunday",
		"Monday",
		"Tuesday",
		"Wednesday",
		"Thursday",
		"Friday",
		"Saturday"
	]
	var today: String = day_names[weekday]

	var today_panel := PanelContainer.new()
	today_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	today_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	today_panel.modulate.a = 0.0
	today_panel.scale = Vector2(0.98, 0.98)

	var today_style := StyleBoxFlat.new()
	today_style.bg_color = Color("#7A1F2A")
	today_style.border_color = Color("#FFE06A")
	today_style.set_border_width_all(3)
	today_style.corner_radius_top_left = 16
	today_style.corner_radius_top_right = 16
	today_style.corner_radius_bottom_left = 16
	today_style.corner_radius_bottom_right = 16
	today_style.shadow_color = Color(0, 0, 0, 0.65)
	today_style.shadow_size = 10
	today_style.shadow_offset = Vector2(0, 3)
	today_style.content_margin_left = 14
	today_style.content_margin_right = 14
	today_style.content_margin_top = 16
	today_style.content_margin_bottom = 16
	today_panel.add_theme_stylebox_override("panel", today_style)
	content.add_child(today_panel)
	_animate_section(today_panel)

	var today_box := VBoxContainer.new()
	today_box.add_theme_constant_override("separation", 10)
	today_panel.add_child(today_box)

	var today_title := Label.new()
	today_title.text = "Today at The Spot — " + today
	today_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	today_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	today_title.add_theme_font_size_override("font_size", 20)
	today_title.add_theme_color_override("font_color", Color("#FFE06A"))
	today_title.add_theme_color_override("font_outline_color", Color("#3A080E"))
	today_title.add_theme_constant_override("outline_size", 4)
	today_box.add_child(today_title)

	var today_line := ColorRect.new()
	today_line.color = Color("#D4AF37")
	today_line.custom_minimum_size = Vector2(0, 2)
	today_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	today_box.add_child(today_line)

	if meetings_data.is_empty():
		var loading_label := Label.new()
		loading_label.text = "Loading today's meetings..."
		loading_label.add_theme_font_size_override("font_size", 16)
		loading_label.add_theme_color_override("font_color", Color("#F5E9E1"))
		today_box.add_child(loading_label)
	else:
		var meetings_found := 0

		for meeting in meetings_data:
			if str(meeting.get("day", "")) != today:
				continue

			meetings_found += 1

			var meeting_time: String = str(meeting.get("time", ""))
			var meeting_name: String = str(meeting.get("meeting", ""))
			var meeting_room: String = str(meeting.get("room", ""))

			meeting_name = meeting_name.replace("&amp;", "&")
			meeting_name = meeting_name.replace("&#8216;", "'")
			meeting_name = meeting_name.replace("&#8217;", "'")
			meeting_name = meeting_name.replace("&#8211;", "-")

			meeting_room = meeting_room.replace("&amp;", "&")
			meeting_room = meeting_room.replace("&#8216;", "'")
			meeting_room = meeting_room.replace("&#8217;", "'")
			meeting_room = meeting_room.replace("&#8211;", "-")

			var name_parts: PackedStringArray = meeting_name.split("|", false)
			var display_name: String = meeting_name.strip_edges()
			var detail_text := ""

			if name_parts.size() > 0:
				display_name = name_parts[0].strip_edges()

			for detail_index in range(1, name_parts.size()):
				var detail_piece: String = name_parts[detail_index].strip_edges()

				if detail_piece == "":
					continue

				if detail_text != "":
					detail_text += " • "

				detail_text += detail_piece

			if meeting_room != "":
				if detail_text != "":
					detail_text += " • "

				detail_text += meeting_room

			var meeting_row := PanelContainer.new()
			meeting_row.mouse_filter = Control.MOUSE_FILTER_PASS
			meeting_row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			meeting_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var row_style := StyleBoxFlat.new()
			row_style.bg_color = Color(0.20, 0.035, 0.055, 0.82)
			row_style.border_color = Color("#D4AF37")
			row_style.set_border_width_all(1)
			row_style.border_width_left = 4
			row_style.corner_radius_top_left = 10
			row_style.corner_radius_top_right = 10
			row_style.corner_radius_bottom_left = 10
			row_style.corner_radius_bottom_right = 10
			row_style.content_margin_left = 12
			row_style.content_margin_right = 12
			row_style.content_margin_top = 10
			row_style.content_margin_bottom = 10
			meeting_row.add_theme_stylebox_override("panel", row_style)
			today_box.add_child(meeting_row)

			meeting_row.mouse_entered.connect(
				_set_home_meeting_row_hovered.bind(meeting_row, true)
			)
			meeting_row.mouse_exited.connect(
				_set_home_meeting_row_hovered.bind(meeting_row, false)
			)
			meeting_row.gui_input.connect(
				_on_home_meeting_row_input.bind(meeting_row)
			)

			var row_box := VBoxContainer.new()
			row_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row_box.add_theme_constant_override("separation", 3)
			meeting_row.add_child(row_box)

			var time_label := Label.new()
			time_label.text = meeting_time
			time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			time_label.add_theme_font_size_override("font_size", 16)
			time_label.add_theme_color_override("font_color", Color("#FFE06A"))
			time_label.add_theme_color_override(
				"font_outline_color",
				Color("#3A080E")
			)
			time_label.add_theme_constant_override("outline_size", 3)
			row_box.add_child(time_label)

			var meeting_label := Label.new()
			meeting_label.text = display_name
			meeting_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			meeting_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			meeting_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			meeting_label.custom_minimum_size.x = 0
			meeting_label.add_theme_font_size_override("font_size", 17)
			meeting_label.add_theme_color_override(
				"font_color",
				Color("#FFF7F0")
			)
			row_box.add_child(meeting_label)

			if detail_text != "":
				var detail_label := Label.new()
				detail_label.text = detail_text
				detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
				detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				detail_label.custom_minimum_size.x = 0
				detail_label.add_theme_font_size_override("font_size", 13)
				detail_label.add_theme_color_override(
					"font_color",
					Color("#D9C9C1")
				)
				row_box.add_child(detail_label)

		if meetings_found == 0:
			var empty_label := Label.new()
			empty_label.text = "No meetings scheduled today."
			empty_label.add_theme_font_size_override("font_size", 16)
			empty_label.add_theme_color_override(
				"font_color",
				Color("#F5E9E1")
			)
			today_box.add_child(empty_label)

	var schedule_button := Button.new()
	schedule_button.text = "VIEW TODAY'S FULL SCHEDULE"
	schedule_button.custom_minimum_size = Vector2(0, 50)
	schedule_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	schedule_button.add_theme_font_size_override("font_size", 15)
	schedule_button.add_theme_color_override(
		"font_color",
		Color("#FFE06A")
	)
	schedule_button.add_theme_color_override(
		"font_hover_color",
		Color.WHITE
	)
	schedule_button.add_theme_color_override(
		"font_pressed_color",
		Color.WHITE
	)
	schedule_button.add_theme_color_override(
		"font_outline_color",
		Color("#3A080E")
	)
	schedule_button.add_theme_constant_override("outline_size", 3)

	var schedule_style := StyleBoxFlat.new()
	schedule_style.bg_color = Color("#A9152D")
	schedule_style.border_color = Color("#FFE06A")
	schedule_style.set_border_width_all(2)
	schedule_style.corner_radius_top_left = 10
	schedule_style.corner_radius_top_right = 10
	schedule_style.corner_radius_bottom_left = 10
	schedule_style.corner_radius_bottom_right = 10
	schedule_style.shadow_color = Color(0, 0, 0, 0.45)
	schedule_style.shadow_size = 5
	schedule_style.shadow_offset = Vector2(0, 2)

	var schedule_hover := schedule_style.duplicate() as StyleBoxFlat
	schedule_hover.bg_color = Color("#D21F3B")
	schedule_hover.border_color = Color("#FFF09A")

	var schedule_pressed := schedule_style.duplicate() as StyleBoxFlat
	schedule_pressed.bg_color = Color("#741522")
	schedule_pressed.shadow_size = 2

	schedule_button.add_theme_stylebox_override("normal", schedule_style)
	schedule_button.add_theme_stylebox_override("hover", schedule_hover)
	schedule_button.add_theme_stylebox_override("pressed", schedule_pressed)
	schedule_button.add_theme_stylebox_override("focus", schedule_hover)
	schedule_button.pressed.connect(_open_today_meetings.bind(today))
	today_box.add_child(schedule_button)

	# Replace only the original Today card with the approved darker design.
	content.remove_child(today_panel)
	today_panel.queue_free()
	_build_today_at_spot_card(today)

	var recovery_thoughts: Array[String] = [
		"Just for today, focus on the next right thing.",
		"Recovery grows stronger every time you choose connection over isolation.",
		"You don't have to have everything figured out today. Just keep moving forward, stay connected, and don't pick up.",
		"Progress doesn't have to be perfect to be real.",
		"Your worst day sober is still a day you gave yourself another chance.",
		"Stay close to the people who remind you why you started.",
		"One honest conversation can change the direction of your whole day.",
		"Recovery isn't about becoming someone else. It's about becoming who you were meant to be.",
		"Keep showing up. Some days that is the victory.",
		"You never have to do recovery alone.",
		"Protect your peace, but don't isolate yourself from your people.",
		"The life you're building is worth protecting today.",
		"Small choices made consistently become a completely different life.",
		"Ask for help before you convince yourself you don't need it."
	]

	var thought_key: int = (
		int(date.get("year", 0)) * 372
		+ int(date.get("month", 0)) * 31
		+ int(date.get("day", 0))
	)

	var thought_index: int = posmod(
		thought_key,
		recovery_thoughts.size()
	)

	_section(
		"RECOVERY THOUGHT",
		recovery_thoughts[thought_index]
	)

	var recovery_feature := content.get_child(
		content.get_child_count() - 1
	) as PanelContainer

	var recovery_style := StyleBoxFlat.new()
	recovery_style.bg_color = Color("#651126")
	recovery_style.border_color = Color("#FFE36E")
	recovery_style.set_border_width_all(2)
	recovery_style.border_width_left = 7
	recovery_style.set_corner_radius_all(16)
	recovery_style.shadow_color = Color(0, 0, 0, 0.72)
	recovery_style.shadow_size = 11
	recovery_style.shadow_offset = Vector2(0, 4)
	recovery_style.content_margin_left = 18
	recovery_style.content_margin_right = 16
	recovery_style.content_margin_top = 15
	recovery_style.content_margin_bottom = 17
	recovery_feature.add_theme_stylebox_override(
		"panel",
		recovery_style
	)

	var recovery_box := recovery_feature.get_child(0) as VBoxContainer
	var recovery_title := recovery_box.get_child(0) as Label
	var recovery_line := recovery_box.get_child(1) as ColorRect
	var recovery_body := recovery_box.get_child(2) as Label

	var recovery_eyebrow := Label.new()
	recovery_eyebrow.text = "JUST FOR TODAY"
	recovery_eyebrow.add_theme_font_size_override("font_size", 11)
	recovery_eyebrow.add_theme_color_override(
		"font_color",
		Color("#E94B5F")
	)
	recovery_box.add_child(recovery_eyebrow)
	recovery_box.move_child(recovery_eyebrow, 0)

	recovery_title.add_theme_font_size_override("font_size", 25)
	recovery_title.add_theme_color_override(
		"font_color",
		Color("#FFF0B5")
	)
	recovery_title.add_theme_constant_override("outline_size", 4)

	recovery_line.color = Color("#FFE36E")
	recovery_line.custom_minimum_size.y = 2

	recovery_body.add_theme_font_size_override("font_size", 18)
	recovery_body.add_theme_color_override(
		"font_color",
		Color("#FFF7F0")
	)
	recovery_body.add_theme_constant_override("line_spacing", 6)

	_section(
		"VISIT THE SPOT",
		"4220 W Northern Ave, Suite 111\nPhoenix, Arizona",
		"GET DIRECTIONS",
		"https://www.google.com/maps/search/?api=1&query=4220+W+Northern+Ave+Suite+111+Phoenix+AZ"
	)

	var visit_feature := content.get_child(
		content.get_child_count() - 1
	) as PanelContainer
	var directions_section_box := (
		visit_feature.get_child(0) as VBoxContainer
	)

	var map_choice_button: Button = null

	for directions_child in directions_section_box.get_children():
		if directions_child is Button:
			map_choice_button = directions_child as Button
			break

	if map_choice_button != null:
		for direction_connection in (
			map_choice_button.pressed.get_connections()
		):
			var connected_callable: Callable = (
				direction_connection["callable"]
			)

			map_choice_button.pressed.disconnect(
				connected_callable
			)

		map_choice_button.pressed.connect(
			_show_map_choice
		)


	var visit_style := StyleBoxFlat.new()
	visit_style.bg_color = Color("#3F0710")
	visit_style.border_color = Color("#FFE36E")
	visit_style.set_border_width_all(2)
	visit_style.border_width_left = 7
	visit_style.set_corner_radius_all(16)
	visit_style.shadow_color = Color(0, 0, 0, 0.72)
	visit_style.shadow_size = 11
	visit_style.shadow_offset = Vector2(0, 4)
	visit_style.content_margin_left = 18
	visit_style.content_margin_right = 16
	visit_style.content_margin_top = 15
	visit_style.content_margin_bottom = 17
	visit_feature.add_theme_stylebox_override(
		"panel",
		visit_style
	)

	var visit_box := visit_feature.get_child(0) as VBoxContainer
	var visit_title := visit_box.get_child(0) as Label
	var visit_line := visit_box.get_child(1) as ColorRect
	var visit_body := visit_box.get_child(2) as Label
	var visit_button := visit_box.get_child(3) as Button

	var visit_eyebrow := Label.new()
	visit_eyebrow.text = "COME SEE US"
	visit_eyebrow.add_theme_font_size_override("font_size", 11)
	visit_eyebrow.add_theme_color_override(
		"font_color",
		Color("#E94B5F")
	)
	visit_box.add_child(visit_eyebrow)
	visit_box.move_child(visit_eyebrow, 0)

	visit_title.add_theme_font_size_override("font_size", 25)
	visit_title.add_theme_color_override(
		"font_color",
		Color("#FFF0B5")
	)
	visit_title.add_theme_constant_override("outline_size", 4)

	visit_line.color = Color("#E30620")
	visit_line.custom_minimum_size.y = 3

	visit_body.add_theme_font_size_override("font_size", 17)
	visit_body.add_theme_color_override(
		"font_color",
		Color("#FFF7F0")
	)
	visit_body.add_theme_constant_override("line_spacing", 5)

	visit_button.custom_minimum_size.y = 56
	visit_button.add_theme_font_size_override("font_size", 17)
	visit_button.add_theme_color_override(
		"font_color",
		Color("#FFF0B5")
	)

	var visit_button_style := StyleBoxFlat.new()
	visit_button_style.bg_color = Color("#E30620")
	visit_button_style.border_color = Color("#FFE36E")
	visit_button_style.set_border_width_all(2)
	visit_button_style.set_corner_radius_all(12)
	visit_button_style.shadow_color = Color(0, 0, 0, 0.50)
	visit_button_style.shadow_size = 6
	visit_button_style.shadow_offset = Vector2(0, 3)
	visit_button.add_theme_stylebox_override(
		"normal",
		visit_button_style
	)

	var visit_hover := visit_button_style.duplicate() as StyleBoxFlat
	visit_hover.bg_color = Color("#FF1733")
	visit_button.add_theme_stylebox_override("hover", visit_hover)
	visit_button.add_theme_stylebox_override("focus", visit_hover)

	var visit_pressed := visit_button_style.duplicate() as StyleBoxFlat
	visit_pressed.bg_color = Color("#9E071A")
	visit_button.add_theme_stylebox_override(
		"pressed",
		visit_pressed
	)

	var bottom_space := Control.new()
	bottom_space.custom_minimum_size.y = 24
	content.add_child(bottom_space)


func _build_today_at_spot_card(today: String) -> void:
	var today_card := PanelContainer.new()
	today_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	today_card.modulate.a = 0.0
	today_card.scale = Vector2(0.98, 0.98)

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("#5B0715")
	card_style.border_color = Color("#FFE36E")
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(12)
	card_style.shadow_color = Color(0, 0, 0, 0.68)
	card_style.shadow_size = 8
	card_style.shadow_offset = Vector2(0, 3)
	card_style.content_margin_left = 14
	card_style.content_margin_right = 14
	card_style.content_margin_top = 13
	card_style.content_margin_bottom = 13
	today_card.add_theme_stylebox_override("panel", card_style)
	content.add_child(today_card)
	_animate_section(today_card)

	var card_box := VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 9)
	today_card.add_child(card_box)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	card_box.add_child(header_row)

	var card_title := Label.new()
	card_title.text = "TODAY AT THE SPOT"
	card_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_title.add_theme_font_size_override("font_size", 20)
	card_title.add_theme_color_override("font_color", Color("#FFE9A0"))
	card_title.add_theme_color_override("font_outline_color", Color("#3A080E"))
	card_title.add_theme_constant_override("outline_size", 3)
	header_row.add_child(card_title)

	var update_text := Label.new()
	update_text.text = "Updated moments ago"
	update_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	update_text.add_theme_font_size_override("font_size", 12)
	update_text.add_theme_color_override("font_color", Color("#D9C9C1"))
	header_row.add_child(update_text)

	var header_divider := ColorRect.new()
	header_divider.color = Color("#FFE36E")
	header_divider.custom_minimum_size = Vector2(0, 2)
	header_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_box.add_child(header_divider)

	if meetings_data.is_empty():
		var loading_text := Label.new()
		loading_text.text = "Loading today's meetings..."
		loading_text.add_theme_font_size_override("font_size", 16)
		loading_text.add_theme_color_override("font_color", Color("#FFF7F0"))
		card_box.add_child(loading_text)
	else:
		var meetings_found := 0

		for meeting in meetings_data:
			if str(meeting.get("day", "")) != today:
				continue

			meetings_found += 1
			var meeting_time := str(meeting.get("time", ""))
			var raw_name := str(meeting.get("meeting", ""))
			var room_name := str(meeting.get("room", ""))
			raw_name = raw_name.replace("&amp;", "&").replace("&#8216;", "'")
			raw_name = raw_name.replace("&#8217;", "'").replace("&#8211;", "-")
			room_name = room_name.replace("&amp;", "&").replace("&#8216;", "'")
			room_name = room_name.replace("&#8217;", "'").replace("&#8211;", "-")

			var name_parts: PackedStringArray = raw_name.split("|", false)
			var display_name := raw_name.strip_edges()
			var detail_parts := PackedStringArray()

			if name_parts.size() > 0:
				display_name = name_parts[0].strip_edges()

			for detail_index in range(1, name_parts.size()):
				var detail_piece := name_parts[detail_index].strip_edges()
				if detail_piece != "":
					detail_parts.append(detail_piece)

			if room_name != "":
				detail_parts.append(room_name)

			var meeting_row := PanelContainer.new()
			meeting_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			meeting_row.mouse_filter = Control.MOUSE_FILTER_PASS
			meeting_row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

			var row_style := StyleBoxFlat.new()
			row_style.bg_color = Color(0.18, 0.01, 0.03, 0.30)
			row_style.border_color = Color("#D4AF37")
			row_style.border_width_bottom = 1
			row_style.content_margin_left = 2
			row_style.content_margin_right = 2
			row_style.content_margin_top = 8
			row_style.content_margin_bottom = 10
			meeting_row.add_theme_stylebox_override("panel", row_style)
			card_box.add_child(meeting_row)

			meeting_row.mouse_entered.connect(
				_set_home_meeting_row_hovered.bind(meeting_row, true)
			)
			meeting_row.mouse_exited.connect(
				_set_home_meeting_row_hovered.bind(meeting_row, false)
			)
			meeting_row.gui_input.connect(
				_on_home_meeting_row_input.bind(meeting_row)
			)

			var row_content := HBoxContainer.new()
			row_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row_content.add_theme_constant_override("separation", 14)
			meeting_row.add_child(row_content)

			var time_badge := PanelContainer.new()
			time_badge.custom_minimum_size = Vector2(72, 60)

			var badge_style := StyleBoxFlat.new()
			badge_style.bg_color = Color("#FFD768")
			badge_style.border_color = Color("#FFE9A0")
			badge_style.set_border_width_all(2)
			badge_style.set_corner_radius_all(10)
			badge_style.shadow_color = Color(0, 0, 0, 0.50)
			badge_style.shadow_size = 5
			badge_style.shadow_offset = Vector2(0, 2)
			time_badge.add_theme_stylebox_override("panel", badge_style)
			row_content.add_child(time_badge)

			var formatted_time := meeting_time.replace(" ", "")
			formatted_time = formatted_time.replace("AM", "\nAM")
			formatted_time = formatted_time.replace("PM", "\nPM")

			var badge_text := Label.new()
			badge_text.text = formatted_time
			badge_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			badge_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			badge_text.add_theme_font_size_override("font_size", 17)
			badge_text.add_theme_color_override("font_color", Color("#3A080E"))
			time_badge.add_child(badge_text)

			var meeting_info := VBoxContainer.new()
			meeting_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			meeting_info.alignment = BoxContainer.ALIGNMENT_CENTER
			meeting_info.add_theme_constant_override("separation", 4)
			row_content.add_child(meeting_info)

			var name_text := Label.new()
			name_text.text = display_name.to_upper()
			name_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			name_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_text.custom_minimum_size.x = 0
			name_text.add_theme_font_size_override("font_size", 20)
			name_text.add_theme_color_override("font_color", Color("#FFF7F0"))
			meeting_info.add_child(name_text)

			if not detail_parts.is_empty():
				var meeting_detail_text := Label.new()
				meeting_detail_text.text = " • ".join(detail_parts)
				meeting_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				meeting_detail_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				meeting_detail_text.custom_minimum_size.x = 0
				meeting_detail_text.add_theme_font_size_override("font_size", 15)
				meeting_detail_text.add_theme_color_override("font_color", Color("#FFE9A0"))
				meeting_info.add_child(meeting_detail_text)

		if meetings_found == 0:
			var empty_text := Label.new()
			empty_text.text = "No meetings scheduled today."
			empty_text.add_theme_font_size_override("font_size", 16)
			empty_text.add_theme_color_override("font_color", Color("#FFF7F0"))
			card_box.add_child(empty_text)

	var schedule_button := Button.new()
	schedule_button.text = "VIEW TODAY'S FULL SCHEDULE"
	schedule_button.custom_minimum_size = Vector2(0, 56)
	schedule_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	schedule_button.add_theme_font_size_override("font_size", 16)
	schedule_button.add_theme_color_override("font_color", Color("#FFF7F0"))
	schedule_button.add_theme_color_override("font_hover_color", Color.WHITE)
	schedule_button.add_theme_color_override("font_pressed_color", Color.WHITE)

	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Color("#E30620")
	button_style.border_color = Color("#FFE36E")
	button_style.set_border_width_all(2)
	button_style.set_corner_radius_all(11)
	button_style.shadow_color = Color(0, 0, 0, 0.45)
	button_style.shadow_size = 5
	button_style.shadow_offset = Vector2(0, 2)
	schedule_button.add_theme_stylebox_override("normal", button_style)

	var hover_style := button_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color("#FF1733")
	schedule_button.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := button_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color("#9E071A")
	schedule_button.add_theme_stylebox_override("pressed", pressed_style)
	schedule_button.pressed.connect(_open_today_meetings.bind(today))
	card_box.add_child(schedule_button)


func _animate_home_logo(logo: TextureRect) -> void:
	if not is_instance_valid(logo):
		return

	logo.pivot_offset = logo.size / 2.0
	logo.modulate.a = 0.0
	logo.scale = Vector2(0.94, 0.94)

	var tween := logo.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(logo, "modulate:a", 1.0, 0.45)
	tween.tween_property(logo, "scale", Vector2.ONE, 0.45)


func _set_home_meeting_row_hovered(
	row: PanelContainer,
	hovered: bool
) -> void:
	if not is_instance_valid(row):
		return

	row.pivot_offset = row.size / 2.0

	var target_color := Color("#FFF3E6") if hovered else Color.WHITE
	var target_scale := Vector2(1.01, 1.01) if hovered else Vector2.ONE
	var tween := row.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(row, "modulate", target_color, 0.12)
	tween.tween_property(row, "scale", target_scale, 0.12)


func _on_home_meeting_row_input(
	event: InputEvent,
	row: PanelContainer
) -> void:
	if not is_instance_valid(row):
		return

	var pressed := false
	var released := false

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			pressed = event.pressed
			released = not event.pressed
	elif event is InputEventScreenTouch:
		pressed = event.pressed
		released = not event.pressed

	if not pressed and not released:
		return

	row.pivot_offset = row.size / 2.0

	var tween := row.create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)

	if pressed:
		tween.tween_property(row, "scale", Vector2(0.985, 0.985), 0.08)
	else:
		tween.tween_property(row, "scale", Vector2.ONE, 0.12)


func _open_today_meetings(day_name: String) -> void:
	selected_meeting_day = day_name

	if nav.get_child_count() > 1:
		var meetings_button := nav.get_child(1) as Button

		if meetings_button != null:
			meetings_button.button_pressed = true
			meetings_button.pressed.emit()
			return

	show_meetings()

func show_meetings() -> void:
	_clear("")
	title_label.visible = false
	main_scroll.scroll_vertical = 0


	var days: Array[String] = [
		"Sunday",
		"Monday",
		"Tuesday",
		"Wednesday",
		"Thursday",
		"Friday",
		"Saturday"
	]

	var page_margin := MarginContainer.new()
	page_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_margin.add_theme_constant_override("margin_left", 10)
	page_margin.add_theme_constant_override("margin_right", 10)
	page_margin.add_theme_constant_override("margin_top", 10)
	page_margin.add_theme_constant_override("margin_bottom", 18)
	content.add_child(page_margin)

	var page_box := VBoxContainer.new()
	page_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_box.add_theme_constant_override("separation", 12)
	page_margin.add_child(page_box)

	# Branded Meetings header.
	var header_panel := PanelContainer.new()
	header_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_panel.custom_minimum_size.y = 104

	var header_style := StyleBoxFlat.new()
	header_style.bg_color = Color("#5B0715")
	header_style.border_color = Color("#FFE36E")
	header_style.set_border_width_all(2)
	header_style.border_width_left = 6
	header_style.set_corner_radius_all(15)
	header_style.shadow_color = Color(0, 0, 0, 0.72)
	header_style.shadow_size = 10
	header_style.shadow_offset = Vector2(0, 4)
	header_style.content_margin_left = 14
	header_style.content_margin_right = 12
	header_style.content_margin_top = 13
	header_style.content_margin_bottom = 13
	header_panel.add_theme_stylebox_override("panel", header_style)
	page_box.add_child(header_panel)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	header_panel.add_child(header_row)

	var icon_badge := PanelContainer.new()
	icon_badge.custom_minimum_size = Vector2(58, 58)
	var icon_badge_style := StyleBoxFlat.new()
	icon_badge_style.bg_color = Color("#A9152D")
	icon_badge_style.border_color = Color("#FFE36E")
	icon_badge_style.set_border_width_all(2)
	icon_badge_style.set_corner_radius_all(29)
	icon_badge.add_theme_stylebox_override("panel", icon_badge_style)
	header_row.add_child(icon_badge)

	var meeting_icon := NavIcon.new()
	meeting_icon.setup("meetings")
	meeting_icon.icon_color = Color("#FFE36E")
	meeting_icon.custom_minimum_size = Vector2(40, 40)
	meeting_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	meeting_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meeting_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_badge.add_child(meeting_icon)

	var heading_stack := VBoxContainer.new()
	heading_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	heading_stack.add_theme_constant_override("separation", 2)
	header_row.add_child(heading_stack)

	var heading := Label.new()
	heading.text = "MEETINGS"
	heading.add_theme_font_size_override("font_size", 27)
	heading.add_theme_color_override("font_color", Color("#FFF0B5"))
	heading.add_theme_color_override("font_outline_color", Color("#3A080E"))
	heading.add_theme_constant_override("outline_size", 3)
	heading_stack.add_child(heading)

	var subtitle := Label.new()
	subtitle.text = "Find your people. Keep showing up."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.custom_minimum_size.x = 0
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color("#F5E9E1"))
	heading_stack.add_child(subtitle)

	var live_badge := PanelContainer.new()
	live_badge.custom_minimum_size = Vector2(68, 48)
	var live_style := StyleBoxFlat.new()
	live_style.bg_color = Color("#E30620")
	live_style.border_color = Color("#FFE36E")
	live_style.set_border_width_all(2)
	live_style.set_corner_radius_all(10)
	live_badge.add_theme_stylebox_override("panel", live_style)
	header_row.add_child(live_badge)

	var live_text := Label.new()
	live_text.text = "LIVE\nSCHEDULE"
	live_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	live_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	live_text.add_theme_font_size_override("font_size", 10)
	live_text.add_theme_color_override("font_color", Color("#FFF0B5"))
	live_badge.add_child(live_text)

	# Keep the day dropdown, with styling that matches the cards.
	var day_dropdown := OptionButton.new()
	day_dropdown.custom_minimum_size = Vector2(0, 56)
	day_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	day_dropdown.alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_dropdown.add_theme_font_size_override("font_size", 18)
	day_dropdown.add_theme_color_override("font_color", Color("#FFE9A0"))

	var dropdown_style := StyleBoxFlat.new()
	dropdown_style.bg_color = Color("#710E20")
	dropdown_style.border_color = Color("#FFE36E")
	dropdown_style.set_border_width_all(2)
	dropdown_style.set_corner_radius_all(12)
	dropdown_style.shadow_color = Color(0, 0, 0, 0.50)
	dropdown_style.shadow_size = 6
	dropdown_style.shadow_offset = Vector2(0, 2)
	day_dropdown.add_theme_stylebox_override("normal", dropdown_style)

	var dropdown_hover := dropdown_style.duplicate() as StyleBoxFlat
	dropdown_hover.bg_color = Color("#92142A")
	day_dropdown.add_theme_stylebox_override("hover", dropdown_hover)
	day_dropdown.add_theme_stylebox_override("pressed", dropdown_hover)

	for day_name in days:
		day_dropdown.add_item(day_name)
			# Style the dropdown's opened menu.
	var day_popup := day_dropdown.get_popup()

	var popup_panel_style := StyleBoxFlat.new()
	popup_panel_style.bg_color = Color("#5B0715")
	popup_panel_style.border_color = Color("#FFE36E")
	popup_panel_style.set_border_width_all(2)
	popup_panel_style.set_corner_radius_all(10)
	popup_panel_style.content_margin_left = 8
	popup_panel_style.content_margin_right = 8
	popup_panel_style.content_margin_top = 8
	popup_panel_style.content_margin_bottom = 8
	day_popup.add_theme_stylebox_override(
		"panel",
		popup_panel_style
	)

	var popup_hover_style := StyleBoxFlat.new()
	popup_hover_style.bg_color = Color("#E30620")
	popup_hover_style.set_corner_radius_all(8)
	day_popup.add_theme_stylebox_override(
		"hover",
		popup_hover_style
	)

	day_popup.add_theme_font_size_override("font_size", 18)
	day_popup.add_theme_color_override(
		"font_color",
		Color("#FFF0B5")
	)
	day_popup.add_theme_color_override(
		"font_hover_color",
		Color.WHITE
	)
	day_popup.add_theme_color_override(
		"font_separator_color",
		Color("#FFE36E")
	)
	day_popup.add_theme_constant_override("v_separation", 10)

	var selected_index := days.find(selected_meeting_day)
	if selected_index >= 0:
		day_dropdown.select(selected_index)

	day_dropdown.item_selected.connect(
		func(index: int):
			selected_meeting_day = days[index]
			show_meetings()
	)
	page_box.add_child(day_dropdown)

	if meetings_data.is_empty():
		if meetings_request.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
			meetings_request.request(MEETINGS_API_URL)

		var loading_panel := PanelContainer.new()
		loading_panel.custom_minimum_size.y = 90
		loading_panel.add_theme_stylebox_override("panel", dropdown_style)
		page_box.add_child(loading_panel)

		var loading_label := Label.new()
		loading_label.text = "Loading meetings..."
		loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		loading_label.add_theme_font_size_override("font_size", 17)
		loading_label.add_theme_color_override("font_color", Color("#FFF7F0"))
		loading_panel.add_child(loading_label)
		return

	var meetings_found := 0

	for meeting in meetings_data:
		var meeting_day := str(meeting.get("day", ""))
		if meeting_day != selected_meeting_day:
			continue

		meetings_found += 1
		var meeting_time := str(meeting.get("time", ""))
		var raw_name := str(meeting.get("meeting", ""))
		var meeting_room := str(meeting.get("room", ""))

		raw_name = raw_name.replace("&amp;", "&").replace("&#8216;", "'")
		raw_name = raw_name.replace("&#8217;", "'").replace("&#8211;", "-")
		meeting_room = meeting_room.replace("&amp;", "&").replace("&#8216;", "'")
		meeting_room = meeting_room.replace("&#8217;", "'").replace("&#8211;", "-")

		var name_parts: PackedStringArray = raw_name.split("|", false)
		var display_name := raw_name.strip_edges()
		var detail_parts := PackedStringArray()

		if name_parts.size() > 0:
			display_name = name_parts[0].strip_edges()

		for detail_index in range(1, name_parts.size()):
			var detail_piece := name_parts[detail_index].strip_edges()
			if detail_piece != "":
				detail_parts.append(detail_piece)

		if meeting_room != "":
			detail_parts.append(meeting_room)

		var meeting_panel := PanelContainer.new()
		meeting_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		meeting_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		meeting_panel.custom_minimum_size.y = 94
		meeting_panel.modulate.a = 0.0
		meeting_panel.scale = Vector2(0.98, 0.98)

		var meeting_style := StyleBoxFlat.new()
		meeting_style.bg_color = Color("#5B0715")
		meeting_style.border_color = Color("#FFE36E")
		meeting_style.set_border_width_all(2)
		meeting_style.set_corner_radius_all(12)
		meeting_style.shadow_color = Color(0, 0, 0, 0.62)
		meeting_style.shadow_size = 7
		meeting_style.shadow_offset = Vector2(0, 3)
		meeting_style.content_margin_left = 12
		meeting_style.content_margin_right = 12
		meeting_style.content_margin_top = 11
		meeting_style.content_margin_bottom = 11
		meeting_panel.add_theme_stylebox_override("panel", meeting_style)
		page_box.add_child(meeting_panel)
		_animate_section(meeting_panel)

		var meeting_row := HBoxContainer.new()
		meeting_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		meeting_row.add_theme_constant_override("separation", 14)
		meeting_panel.add_child(meeting_row)

		var time_badge := PanelContainer.new()
		time_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		time_badge.custom_minimum_size = Vector2(72, 68)
		var time_style := StyleBoxFlat.new()
		time_style.bg_color = Color("#FFD768")
		time_style.border_color = Color("#FFE9A0")
		time_style.set_border_width_all(2)
		time_style.set_corner_radius_all(10)
		time_style.shadow_color = Color(0, 0, 0, 0.50)
		time_style.shadow_size = 5
		time_style.shadow_offset = Vector2(0, 2)
		time_badge.add_theme_stylebox_override("panel", time_style)
		meeting_row.add_child(time_badge)

		var formatted_time := meeting_time.replace(" ", "")
		formatted_time = formatted_time.replace("AM", "\nAM")
		formatted_time = formatted_time.replace("PM", "\nPM")

		var time_label := Label.new()
		time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		time_label.text = formatted_time
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		time_label.add_theme_font_size_override("font_size", 18)
		time_label.add_theme_color_override("font_color", Color("#3A080E"))
		time_badge.add_child(time_label)

		var meeting_info := VBoxContainer.new()
		meeting_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		meeting_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		meeting_info.alignment = BoxContainer.ALIGNMENT_CENTER
		meeting_info.add_theme_constant_override("separation", 5)
		meeting_row.add_child(meeting_info)

		var name_label := Label.new()
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.text = display_name.to_upper()
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.custom_minimum_size.x = 0
		name_label.add_theme_font_size_override("font_size", 20)
		name_label.add_theme_color_override("font_color", Color("#FFF7F0"))
		meeting_info.add_child(name_label)

		if not detail_parts.is_empty():
			var detail_label := Label.new()
			detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			detail_label.text = " • ".join(detail_parts)
			detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			detail_label.custom_minimum_size.x = 0
			detail_label.add_theme_font_size_override("font_size", 14)
			detail_label.add_theme_color_override("font_color", Color("#FFE9A0"))
			meeting_info.add_child(detail_label)

	if meetings_found == 0:
		var empty_panel := PanelContainer.new()
		empty_panel.custom_minimum_size.y = 94
		empty_panel.add_theme_stylebox_override("panel", dropdown_style)
		page_box.add_child(empty_panel)

		var empty_label := Label.new()
		empty_label.text = "No meetings scheduled for " + selected_meeting_day + "."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.add_theme_font_size_override("font_size", 17)
		empty_label.add_theme_color_override("font_color", Color("#FFF7F0"))
		empty_panel.add_child(empty_label)

	var updated_label := Label.new()
	updated_label.text = "Updated moments ago"
	updated_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	updated_label.custom_minimum_size.y = 42
	updated_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	updated_label.add_theme_font_size_override("font_size", 13)
	updated_label.add_theme_color_override("font_color", Color("#BFAFB0"))
	page_box.add_child(updated_label)

func _load_event_schedule(
	event_url: String,
	target: Label
) -> void:
	if event_url == "" or not is_instance_valid(target):
		return

	if event_schedule_cache.has(event_url):
		target.text = str(event_schedule_cache[event_url])
		return

	var schedule_request := HTTPRequest.new()
	add_child(schedule_request)

	schedule_request.request_completed.connect(
		_on_event_schedule_request_completed.bind(
			schedule_request,
			target,
			event_url
		)
	)

	var request_error := schedule_request.request(event_url)

	if request_error != OK:
		schedule_request.queue_free()
		target.text = "FOR EVENT TIME, CONTACT THE SPOT"


func _on_event_schedule_request_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	schedule_request: HTTPRequest,
	target: Label,
	event_url: String
) -> void:
	var display_schedule := "FOR EVENT TIME, CONTACT THE SPOT"

	if response_code >= 200 and response_code < 300:
		var page_html := body.get_string_from_utf8()
		var schedule_regex := RegEx.new()

		schedule_regex.compile(
			"([A-Z][a-z]+ [0-9]{1,2}, [0-9]{4} [0-9]{1,2}:[0-9]{2} (am|pm))"
		)

		var schedule_match := schedule_regex.search(page_html)

		if schedule_match != null:
			display_schedule = schedule_match.get_string(1).to_upper()

	event_schedule_cache[event_url] = display_schedule

	if is_instance_valid(target):
		target.text = display_schedule

	if is_instance_valid(schedule_request):
		schedule_request.queue_free()




func show_events() -> void:
	_clear("")
	title_label.visible = false
	_add_page_header(
		"EVENTS",
		"Good people. Good times. Real connection.",
		"events",
		"WHAT'S\nNEXT"
	)

	if events_data.is_empty():
		if events_request.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
			events_request.request(EVENTS_URL)
		return

	var display_events: Array = events_data.duplicate(true)
	var has_big_book_showdown := false

	for existing_event in display_events:
		var existing_title := str(
			existing_event.get("title", {}).get("rendered", "")
		)

		if existing_title.to_lower().contains("big book showdown"):
			has_big_book_showdown = true
			break

	if not has_big_book_showdown:
		display_events.push_front({
			"title": {
				"rendered": "The Big Book Showdown"
			},
			"link": "https://www.facebook.com/thespotsoberlounge/",
			"local_image": "res://assets/events/big_book_showdown.jpeg",
			"summary": "September 26 • Big Book Trivia • Spades • Dominoes • Chess\nTeams of four • $20 entry per team • Fundraiser"
		})

	for event_item in display_events:
		var _event_title: String = str(event_item.get("title", {}).get("rendered", "Untitled Event"))
		var _event_link: String = str(event_item.get("link", ""))
		var _event_local_image: String = str(
			event_item.get("local_image", "")
		)
		var _event_summary: String = str(
			event_item.get(
				"summary",
				"See dates, times, and full event details on The Spot website."
			)
		)
		var _event_image_url: String = ""
		var embedded_data = event_item.get("_embedded", {})

		if embedded_data is Dictionary:
			var featured_media = embedded_data.get(
				"wp:featuredmedia",
				[]
			)

			if featured_media is Array and not featured_media.is_empty():
				var media_item = featured_media[0]

				if media_item is Dictionary:
					var media_details = media_item.get(
						"media_details",
						{}
					)
					var media_sizes = media_details.get("sizes", {})
					var phone_size = media_sizes.get(
						"et-pb-image--responsive--phone",
						{}
					)

					_event_image_url = str(
						phone_size.get(
							"source_url",
							media_item.get("source_url", "")
						)
					)
		_event_title = _event_title.replace("&#8216;", "'").replace("&#8217;", "'").replace("&#8211;", "-").replace("&#8230;", "...").replace("&amp;", "&")
		_section(
			_event_title,
			_event_summary,
			"VIEW EVENT",
			_event_link
		)

		var event_card := content.get_child(
			content.get_child_count() - 1
		) as PanelContainer

		var event_style := StyleBoxFlat.new()
		event_style.bg_color = Color("#4A0612")
		event_style.border_color = Color("#FFE36E")
		event_style.set_border_width_all(2)
		event_style.border_width_left = 7
		event_style.set_corner_radius_all(16)
		event_style.shadow_color = Color(0, 0, 0, 0.72)
		event_style.shadow_size = 11
		event_style.shadow_offset = Vector2(0, 4)
		event_style.content_margin_left = 18
		event_style.content_margin_right = 16
		event_style.content_margin_top = 15
		event_style.content_margin_bottom = 17
		event_card.add_theme_stylebox_override(
			"panel",
			event_style
		)

		var event_box := event_card.get_child(0) as VBoxContainer
		var event_title := event_box.get_child(0) as Label
		var event_line := event_box.get_child(1) as ColorRect
		var event_body := event_box.get_child(2) as Label
		var event_button := event_box.get_child(3) as Button

		var event_eyebrow := Label.new()
		event_eyebrow.text = "UPCOMING AT THE SPOT"
		event_eyebrow.add_theme_font_size_override("font_size", 11)
		event_eyebrow.add_theme_color_override(
			"font_color",
			Color("#E94B5F")
		)
		event_box.add_child(event_eyebrow)
		event_box.move_child(event_eyebrow, 0)
		if _event_local_image != "" or _event_image_url != "":
			var flyer_frame := PanelContainer.new()
			flyer_frame.custom_minimum_size.y = 430
			flyer_frame.size_flags_horizontal = (
				Control.SIZE_EXPAND_FILL
			)
			flyer_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			flyer_frame.clip_contents = true

			var flyer_frame_style := StyleBoxFlat.new()
			flyer_frame_style.bg_color = Color("#160207")
			flyer_frame_style.border_color = Color("#B5273D")
			flyer_frame_style.set_border_width_all(1)
			flyer_frame_style.set_corner_radius_all(12)
			flyer_frame_style.content_margin_left = 6
			flyer_frame_style.content_margin_right = 6
			flyer_frame_style.content_margin_top = 6
			flyer_frame_style.content_margin_bottom = 6
			flyer_frame.add_theme_stylebox_override(
				"panel",
				flyer_frame_style
			)

			event_box.add_child(flyer_frame)
			event_box.move_child(flyer_frame, 1)

			var event_flyer := TextureRect.new()
			event_flyer.custom_minimum_size = Vector2(0, 418)
			event_flyer.size_flags_horizontal = (
				Control.SIZE_EXPAND_FILL
			)
			event_flyer.expand_mode = (
				TextureRect.EXPAND_IGNORE_SIZE
			)
			event_flyer.stretch_mode = (
				TextureRect.STRETCH_KEEP_ASPECT_COVERED
			)
			event_flyer.texture_filter = (
				CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			)
			event_flyer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			flyer_frame.add_child(event_flyer)

			if _event_local_image != "":
				event_flyer.texture = load(_event_local_image)
			else:
				_load_product_image(
					_event_image_url,
					event_flyer
				)
		# Website events receive a clear date-and-time strip.
		# The manually added Big Book card remains untouched.
		if _event_local_image == "":
			var schedule_panel := PanelContainer.new()
			schedule_panel.size_flags_horizontal = (
				Control.SIZE_EXPAND_FILL
			)
			schedule_panel.mouse_filter = (
				Control.MOUSE_FILTER_IGNORE
			)

			var schedule_style := StyleBoxFlat.new()
			schedule_style.bg_color = Color("#240409")
			schedule_style.border_color = Color("#FFE36E")
			schedule_style.set_border_width_all(2)
			schedule_style.set_corner_radius_all(10)
			schedule_style.content_margin_left = 10
			schedule_style.content_margin_right = 10
			schedule_style.content_margin_top = 8
			schedule_style.content_margin_bottom = 8
			schedule_panel.add_theme_stylebox_override(
				"panel",
				schedule_style
			)

			event_box.add_child(schedule_panel)

			var schedule_label := Label.new()
			schedule_label.text = "LOADING EVENT DATE..."
			schedule_label.horizontal_alignment = (
				HORIZONTAL_ALIGNMENT_CENTER
			)
			schedule_label.autowrap_mode = (
				TextServer.AUTOWRAP_WORD_SMART
			)
			schedule_label.add_theme_font_size_override(
				"font_size",
				14
			)
			schedule_label.add_theme_color_override(
				"font_color",
				Color("#FFE36E")
			)
			schedule_label.mouse_filter = (
				Control.MOUSE_FILTER_IGNORE
			)
			schedule_panel.add_child(schedule_label)

			if _event_image_url != "":
				event_box.move_child(schedule_panel, 2)
			else:
				event_box.move_child(schedule_panel, 1)

			_load_event_schedule(
				_event_link,
				schedule_label
			)
		event_title.add_theme_font_size_override("font_size", 23)
		event_title.add_theme_color_override(
			"font_color",
			Color("#FFF0B5")
		)
		event_title.add_theme_constant_override("outline_size", 4)

		event_line.color = Color("#E30620")
		event_line.custom_minimum_size.y = 3

		event_body.add_theme_font_size_override("font_size", 15)
		event_body.add_theme_color_override(
			"font_color",
			Color("#FFF7F0")
		)
		event_body.add_theme_constant_override("line_spacing", 5)

		event_button.custom_minimum_size.y = 54
		event_button.add_theme_font_size_override("font_size", 16)
		event_button.add_theme_color_override(
			"font_color",
			Color("#FFF0B5")
		)

		var event_button_style := StyleBoxFlat.new()
		event_button_style.bg_color = Color("#E30620")
		event_button_style.border_color = Color("#FFE36E")
		event_button_style.set_border_width_all(2)
		event_button_style.set_corner_radius_all(12)
		event_button_style.shadow_color = Color(0, 0, 0, 0.50)
		event_button_style.shadow_size = 6
		event_button_style.shadow_offset = Vector2(0, 3)
		event_button.add_theme_stylebox_override(
			"normal",
			event_button_style
		)

		var event_hover := event_button_style.duplicate() as StyleBoxFlat
		event_hover.bg_color = Color("#FF1733")
		event_button.add_theme_stylebox_override("hover", event_hover)
		event_button.add_theme_stylebox_override("focus", event_hover)

		var event_pressed := event_button_style.duplicate() as StyleBoxFlat
		event_pressed.bg_color = Color("#9E071A")
		event_button.add_theme_stylebox_override(
			"pressed",
			event_pressed
		)
		
func show_vip() -> void:
	_clear("VIP MEMBERSHIP")
	title_label.visible = false

	_add_page_header(
		"VIP MEMBERSHIP",
		"Support the community and enjoy more of The Spot.",
		"shop",
		"VIP"
	)

	# Main VIP feature card.
	var vip_panel := PanelContainer.new()
	vip_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vip_style := StyleBoxFlat.new()
	vip_style.bg_color = Color("#650818")
	vip_style.border_color = Color("#FFE36E")
	vip_style.set_border_width_all(2)
	vip_style.border_width_left = 6
	vip_style.set_corner_radius_all(16)
	vip_style.shadow_color = Color(0, 0, 0, 0.70)
	vip_style.shadow_size = 10
	vip_style.shadow_offset = Vector2(0, 4)
	vip_style.content_margin_left = 18
	vip_style.content_margin_right = 18
	vip_style.content_margin_top = 18
	vip_style.content_margin_bottom = 18
	vip_panel.add_theme_stylebox_override("panel", vip_style)
	content.add_child(vip_panel)

	var vip_stack := VBoxContainer.new()
	vip_stack.add_theme_constant_override("separation", 10)
	vip_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vip_panel.add_child(vip_stack)

	var vip_mark := Label.new()
	vip_mark.text = "★  THE SPOT VIP  ★"
	vip_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vip_mark.add_theme_font_size_override("font_size", 16)
	vip_mark.add_theme_color_override("font_color", Color("#FFE36E"))
	vip_mark.add_theme_color_override(
		"font_outline_color",
		Color("#3A080E")
	)
	vip_mark.add_theme_constant_override("outline_size", 3)
	vip_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vip_stack.add_child(vip_mark)

	var vip_title := Label.new()
	vip_title.text = "MORE THAN A MEMBERSHIP"
	vip_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vip_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vip_title.add_theme_font_size_override("font_size", 25)
	vip_title.add_theme_color_override("font_color", Color("#FFF0B5"))
	vip_title.add_theme_color_override(
		"font_outline_color",
		Color("#3A080E")
	)
	vip_title.add_theme_constant_override("outline_size", 3)
	vip_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vip_stack.add_child(vip_title)

	var vip_description := Label.new()
	vip_description.text = "Become part of the community that keeps The Spot growing. VIP membership gives you special perks while supporting a welcoming place for connection, fellowship, and recovery."
	vip_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vip_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vip_description.add_theme_font_size_override("font_size", 15)
	vip_description.add_theme_color_override(
		"font_color",
		Color("#F5E9E1")
	)
	vip_description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vip_stack.add_child(vip_description)

	# Benefits card.
	var benefits_panel := PanelContainer.new()
	benefits_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	benefits_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var benefits_style := StyleBoxFlat.new()
	benefits_style.bg_color = Color("#21050A")
	benefits_style.border_color = Color("#B5273D")
	benefits_style.set_border_width_all(2)
	benefits_style.set_corner_radius_all(16)
	benefits_style.shadow_color = Color(0, 0, 0, 0.65)
	benefits_style.shadow_size = 8
	benefits_style.shadow_offset = Vector2(0, 3)
	benefits_style.content_margin_left = 16
	benefits_style.content_margin_right = 16
	benefits_style.content_margin_top = 16
	benefits_style.content_margin_bottom = 16
	benefits_panel.add_theme_stylebox_override(
		"panel",
		benefits_style
	)
	content.add_child(benefits_panel)

	var benefits_stack := VBoxContainer.new()
	benefits_stack.add_theme_constant_override("separation", 12)
	benefits_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	benefits_panel.add_child(benefits_stack)

	var benefits_heading := Label.new()
	benefits_heading.text = "VIP BENEFITS"
	benefits_heading.add_theme_font_size_override("font_size", 21)
	benefits_heading.add_theme_color_override(
		"font_color",
		Color("#FFE36E")
	)
	benefits_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	benefits_stack.add_child(benefits_heading)

	var divider := HSeparator.new()
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.add_theme_color_override(
		"separator",
		Color("#FFE36E")
	)
	benefits_stack.add_child(divider)

	var benefits := [
		[
			"★",
			"EVENT ACCESS",
			"Enjoy free admission to eligible events at The Spot."
		],
		[
			"◆",
			"MEMBER PERKS",
			"Receive special benefits created for VIP members."
		],
		[
			"♥",
			"SUPPORT THE COMMUNITY",
			"Help The Spot remain a home for fellowship and recovery."
		],
		[
			"✓",
			"FLEXIBLE OPTIONS",
			"Choose the monthly or annual membership that fits you."
		]
	]

	for benefit in benefits:
		var benefit_row := HBoxContainer.new()
		benefit_row.add_theme_constant_override("separation", 12)
		benefit_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		benefits_stack.add_child(benefit_row)

		var benefit_badge := PanelContainer.new()
		benefit_badge.custom_minimum_size = Vector2(46, 46)
		benefit_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = Color("#A9152D")
		badge_style.border_color = Color("#FFE36E")
		badge_style.set_border_width_all(2)
		badge_style.set_corner_radius_all(23)
		benefit_badge.add_theme_stylebox_override(
			"panel",
			badge_style
		)
		benefit_row.add_child(benefit_badge)

		var benefit_icon := Label.new()
		benefit_icon.text = str(benefit[0])
		benefit_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		benefit_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		benefit_icon.add_theme_font_size_override("font_size", 20)
		benefit_icon.add_theme_color_override(
			"font_color",
			Color("#FFE36E")
		)
		benefit_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		benefit_badge.add_child(benefit_icon)

		var benefit_text := VBoxContainer.new()
		benefit_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		benefit_text.add_theme_constant_override("separation", 2)
		benefit_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		benefit_row.add_child(benefit_text)

		var benefit_title := Label.new()
		benefit_title.text = str(benefit[1])
		benefit_title.add_theme_font_size_override("font_size", 16)
		benefit_title.add_theme_color_override(
			"font_color",
			Color("#FFF0B5")
		)
		benefit_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		benefit_text.add_child(benefit_title)

		var benefit_description := Label.new()
		benefit_description.text = str(benefit[2])
		benefit_description.autowrap_mode = (
			TextServer.AUTOWRAP_WORD_SMART
		)
		benefit_description.add_theme_font_size_override(
			"font_size",
			13
		)
		benefit_description.add_theme_color_override(
			"font_color",
			Color("#E8D4CE")
		)
		benefit_description.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)
		benefit_text.add_child(benefit_description)

	# Membership call-to-action.
	var membership_button := Button.new()
	membership_button.text = "VIEW MEMBERSHIP OPTIONS   ›"
	membership_button.custom_minimum_size.y = 64
	membership_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	membership_button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
	)
	membership_button.add_theme_font_size_override("font_size", 17)
	membership_button.add_theme_color_override(
		"font_color",
		Color("#FFF0B5")
	)
	membership_button.add_theme_color_override(
		"font_hover_color",
		Color.WHITE
	)
	membership_button.add_theme_color_override(
		"font_pressed_color",
		Color.WHITE
	)

	var membership_normal := StyleBoxFlat.new()
	membership_normal.bg_color = Color("#E30620")
	membership_normal.border_color = Color("#FFE36E")
	membership_normal.set_border_width_all(2)
	membership_normal.set_corner_radius_all(14)
	membership_normal.shadow_color = Color(0.90, 0.02, 0.12, 0.60)
	membership_normal.shadow_size = 9
	membership_normal.shadow_offset = Vector2(0, 3)
	membership_button.add_theme_stylebox_override(
		"normal",
		membership_normal
	)

	var membership_hover := (
		membership_normal.duplicate() as StyleBoxFlat
	)
	membership_hover.bg_color = Color("#FF1630")
	membership_hover.border_color = Color("#FFF0B5")
	membership_hover.shadow_size = 13
	membership_button.add_theme_stylebox_override(
		"hover",
		membership_hover
	)
	membership_button.add_theme_stylebox_override(
		"focus",
		membership_hover
	)

	var membership_pressed := (
		membership_normal.duplicate() as StyleBoxFlat
	)
	membership_pressed.bg_color = Color("#8A0B1D")
	membership_pressed.shadow_size = 3
	membership_button.add_theme_stylebox_override(
		"pressed",
		membership_pressed
	)

	membership_button.pressed.connect(
		_open_more_link.bind("https://thespotlounge.com/shop/")
	)
	content.add_child(membership_button)

	var bottom_space := Control.new()
	bottom_space.custom_minimum_size.y = 90
	bottom_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(bottom_space)




func show_more() -> void:
	_clear("More")
	title_label.visible = false
	main_scroll.scroll_vertical = 0
	_add_page_header(
		"MORE",
		"Explore everything The Spot offers.",
		"more",
		"EXPLORE"
	)

	# Branded introduction card.
	_section(
		"MORE THAN A MEETING",
		"A place for fellowship, connection, events, entertainment, and life in recovery."
	)

	var intro_card := content.get_child(
		content.get_child_count() - 1
	) as PanelContainer

	var intro_style := StyleBoxFlat.new()
	intro_style.bg_color = Color("#4A0612")
	intro_style.border_color = Color("#FFE36E")
	intro_style.set_border_width_all(2)
	intro_style.border_width_left = 7
	intro_style.set_corner_radius_all(16)
	intro_style.shadow_color = Color(0, 0, 0, 0.72)
	intro_style.shadow_size = 11
	intro_style.shadow_offset = Vector2(0, 4)
	intro_style.content_margin_left = 18
	intro_style.content_margin_right = 16
	intro_style.content_margin_top = 15
	intro_style.content_margin_bottom = 17
	intro_card.add_theme_stylebox_override("panel", intro_style)

	var intro_box := intro_card.get_child(0) as VBoxContainer
	var intro_title := intro_box.get_child(0) as Label
	var intro_line := intro_box.get_child(1) as ColorRect
	var intro_body := intro_box.get_child(2) as Label

	var intro_eyebrow := Label.new()
	intro_eyebrow.text = "WELCOME TO THE SPOT"
	intro_eyebrow.add_theme_font_size_override("font_size", 11)
	intro_eyebrow.add_theme_color_override("font_color", Color("#E94B5F"))
	intro_box.add_child(intro_eyebrow)
	intro_box.move_child(intro_eyebrow, 0)

	intro_title.add_theme_font_size_override("font_size", 24)
	intro_title.add_theme_color_override("font_color", Color("#FFF0B5"))
	intro_line.color = Color("#E30620")
	intro_line.custom_minimum_size.y = 3
	intro_body.add_theme_font_size_override("font_size", 16)
	intro_body.add_theme_color_override("font_color", Color("#FFF7F0"))
	intro_body.add_theme_constant_override("line_spacing", 5)

	# Explore menu container.
	var menu_panel := PanelContainer.new()
	menu_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_panel.modulate.a = 0.0
	menu_panel.scale = Vector2(0.98, 0.98)

	var menu_style := StyleBoxFlat.new()
	menu_style.bg_color = Color("#31060D")
	menu_style.border_color = Color("#8C6A2F")
	menu_style.set_border_width_all(1)
	menu_style.set_corner_radius_all(16)
	menu_style.shadow_color = Color(0, 0, 0, 0.60)
	menu_style.shadow_size = 9
	menu_style.shadow_offset = Vector2(0, 3)
	menu_style.content_margin_left = 12
	menu_style.content_margin_right = 12
	menu_style.content_margin_top = 15
	menu_style.content_margin_bottom = 15
	menu_panel.add_theme_stylebox_override("panel", menu_style)
	content.add_child(menu_panel)
	_animate_section(menu_panel)

	var menu_box := VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 10)
	menu_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_panel.add_child(menu_box)

	var menu_eyebrow := Label.new()
	menu_eyebrow.text = "QUICK LINKS"
	menu_eyebrow.add_theme_font_size_override("font_size", 11)
	menu_eyebrow.add_theme_color_override("font_color", Color("#E94B5F"))
	menu_eyebrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_box.add_child(menu_eyebrow)

	var menu_title := Label.new()
	menu_title.text = "EXPLORE THE SPOT"
	menu_title.add_theme_font_size_override("font_size", 23)
	menu_title.add_theme_color_override("font_color", Color("#FFF0B5"))
	menu_title.add_theme_color_override("font_outline_color", Color("#3A080E"))
	menu_title.add_theme_constant_override("outline_size", 3)
	menu_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_box.add_child(menu_title)

	var menu_line := ColorRect.new()
	menu_line.color = Color("#FFE36E")
	menu_line.custom_minimum_size = Vector2(0, 2)
	menu_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_box.add_child(menu_line)

	menu_box.add_child(
		_more_action_button(
			"★",
			"ABOUT THE FOUNDERS",
			"Meet the people behind The Spot.",
			show_founders,
			true
		)
	)

	menu_box.add_child(
		_more_action_button(
			"V",
			"VIP MEMBERSHIP",
			"Member perks, event access, and more.",
			show_vip
		)
	)

	menu_box.add_child(
		_more_action_button(
			"▶",
			"ON THE SPOT PODCAST",
			"Watch conversations from the community.",
			_open_more_link.bind(
				"https://www.youtube.com/@thespotsoberlounge1079"
			)
		)
	)

	menu_box.add_child(
		_more_action_button(
			"⌂",
			"VISIT OUR WEBSITE",
			"Explore the complete Spot website.",
			_open_more_link.bind("https://thespotlounge.com/")
		)
	)

	menu_box.add_child(
		_more_action_button(
			"@",
			"CONTACT & SUPPORT",
			"Email or call The Spot team.",
			_open_more_link.bind("mailto:thespotphoenix@gmail.com")
		)
	)

	menu_box.add_child(
		_more_action_button(
			"i",
			"PRIVACY POLICY",
			"Review privacy and app information.",
			_open_more_link.bind(
				"https://isaacweigner51-arch.github.io/the-spot-sober-lounge-app/docs/index.html"
			)
		)
	)

	var contact_panel := PanelContainer.new()
	contact_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var contact_style := StyleBoxFlat.new()
	contact_style.bg_color = Color("#4A101A")
	contact_style.border_color = Color("#8C6A2F")
	contact_style.set_border_width_all(1)
	contact_style.set_corner_radius_all(12)
	contact_style.content_margin_left = 12
	contact_style.content_margin_right = 12
	contact_style.content_margin_top = 10
	contact_style.content_margin_bottom = 10
	contact_panel.add_theme_stylebox_override("panel", contact_style)
	menu_box.add_child(contact_panel)

	var contact_info := Label.new()
	contact_info.text = "thespotphoenix@gmail.com  •  480-249-0492"
	contact_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contact_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contact_info.add_theme_font_size_override("font_size", 13)
	contact_info.add_theme_color_override("font_color", Color("#D9C9C1"))
	contact_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contact_panel.add_child(contact_info)

	var version_label := Label.new()
	version_label.text = "THE SPOT SOBER LOUNGE • VERSION 1.0"
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	version_label.add_theme_font_size_override("font_size", 11)
	version_label.add_theme_color_override(
		"font_color",
		Color(0.83, 0.69, 0.22, 0.72)
	)
	version_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_box.add_child(version_label)

	var bottom_space := Control.new()
	bottom_space.custom_minimum_size.y = 90
	bottom_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(bottom_space)


func _more_action_button(
	icon_text: String,
	button_title: String,
	description: String,
	action: Callable,
	featured := false
) -> Button:
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = Vector2(0, 82)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.clip_contents = true

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color("#A9152D") if featured else Color("#4A161B")
	normal_style.border_color = Color("#FFE36E") if featured else Color("#8C6A2F")
	normal_style.set_border_width_all(2 if featured else 1)
	normal_style.set_corner_radius_all(12)
	normal_style.shadow_color = Color(0, 0, 0, 0.45)
	normal_style.shadow_size = 6
	normal_style.shadow_offset = Vector2(0, 2)

	var hover_style := normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color("#D21F3B") if featured else Color("#721E27")
	hover_style.border_color = Color("#FFF09A")

	var pressed_style := normal_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color("#8F1023")
	pressed_style.shadow_size = 2

	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("focus", hover_style)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -12
	row.offset_top = 8
	row.offset_bottom = -8
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)

	var icon_badge := PanelContainer.new()
	icon_badge.custom_minimum_size = Vector2(48, 48)
	icon_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color("#E30620") if featured else Color("#6A1420")
	icon_style.border_color = Color("#FFE36E")
	icon_style.set_border_width_all(2)
	icon_style.set_corner_radius_all(24)
	icon_badge.add_theme_stylebox_override("panel", icon_style)
	row.add_child(icon_badge)

	var icon_label := Label.new()
	icon_label.text = icon_text
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 20)
	icon_label.add_theme_color_override("font_color", Color("#FFF0B5"))
	icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_badge.add_child(icon_label)

	var text_stack := VBoxContainer.new()
	text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	text_stack.add_theme_constant_override("separation", 2)
	text_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_stack)

	var title_label_text := Label.new()
	title_label_text.text = button_title
	title_label_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label_text.custom_minimum_size.x = 0
	title_label_text.add_theme_font_size_override("font_size", 15)
	title_label_text.add_theme_color_override("font_color", Color("#FFE9A0"))
	title_label_text.add_theme_color_override("font_outline_color", Color("#3A080E"))
	title_label_text.add_theme_constant_override("outline_size", 2)
	title_label_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_stack.add_child(title_label_text)

	var description_label := Label.new()
	description_label.text = description
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.custom_minimum_size.x = 0
	description_label.add_theme_font_size_override("font_size", 12)
	description_label.add_theme_color_override("font_color", Color("#D9C9C1"))
	description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_stack.add_child(description_label)

	var chevron := Label.new()
	chevron.text = "›"
	chevron.custom_minimum_size.x = 20
	chevron.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chevron.add_theme_font_size_override("font_size", 28)
	chevron.add_theme_color_override("font_color", Color("#FFE36E"))
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(chevron)

	button.button_down.connect(_animate_more_button.bind(button, true))
	button.button_up.connect(_animate_more_button.bind(button, false))
	button.pressed.connect(action)

	return button


func _animate_more_button(
	button: Button,
	pressed: bool
) -> void:
	if not is_instance_valid(button):
		return

	button.pivot_offset = button.size / 2.0

	var target_scale := (
		Vector2(0.985, 0.985)
		if pressed
		else Vector2.ONE
	)

	var tween := button.create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(
		button,
		"scale",
		target_scale,
		0.09 if pressed else 0.13
	)


func _open_more_link(url: String) -> void:
	OS.shell_open(url)

func show_founders() -> void:
	_clear("ABOUT THE FOUNDERS")
	title_label.visible = false
	main_scroll.scroll_vertical = 0

	_add_page_header(
		"ABOUT THE FOUNDERS",
		"The people and purpose behind The Spot.",
		"meetings",
		"OUR\nSTORY"
	)

	# Framed founders photograph.
	var founders_frame := PanelContainer.new()
	founders_frame.custom_minimum_size.y = 410
	founders_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	founders_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	founders_frame.modulate.a = 0.0
	founders_frame.scale = Vector2(0.98, 0.98)

	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color("#180207")
	frame_style.border_color = Color("#FFE36E")
	frame_style.set_border_width_all(3)
	frame_style.set_corner_radius_all(16)
	frame_style.shadow_color = Color(0, 0, 0, 0.75)
	frame_style.shadow_size = 12
	frame_style.shadow_offset = Vector2(0, 5)
	frame_style.content_margin_left = 8
	frame_style.content_margin_right = 8
	frame_style.content_margin_top = 8
	frame_style.content_margin_bottom = 8
	founders_frame.add_theme_stylebox_override("panel", frame_style)
	content.add_child(founders_frame)

	var founders_image := TextureRect.new()
	founders_image.texture = load(
		"res://assets/thespotfounderscorrected.png"
	)
	founders_image.custom_minimum_size = Vector2(0, 394)
	founders_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	founders_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	founders_image.texture_filter = (
		CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	)
	founders_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	founders_frame.add_child(founders_image)

	_animate_section(founders_frame)

	# Founder names and identity card.
	var names_panel := PanelContainer.new()
	names_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names_panel.modulate.a = 0.0
	names_panel.scale = Vector2(0.98, 0.98)

	var names_style := StyleBoxFlat.new()
	names_style.bg_color = Color("#650818")
	names_style.border_color = Color("#FFE36E")
	names_style.set_border_width_all(2)
	names_style.border_width_left = 6
	names_style.set_corner_radius_all(15)
	names_style.shadow_color = Color(0, 0, 0, 0.68)
	names_style.shadow_size = 9
	names_style.shadow_offset = Vector2(0, 4)
	names_style.content_margin_left = 18
	names_style.content_margin_right = 18
	names_style.content_margin_top = 16
	names_style.content_margin_bottom = 16
	names_panel.add_theme_stylebox_override("panel", names_style)
	content.add_child(names_panel)

	var names_stack := VBoxContainer.new()
	names_stack.add_theme_constant_override("separation", 5)
	names_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names_panel.add_child(names_stack)

	var founders_badge := Label.new()
	founders_badge.text = "FOUNDERS OF THE SPOT"
	founders_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	founders_badge.add_theme_font_size_override("font_size", 12)
	founders_badge.add_theme_color_override(
		"font_color",
		Color("#FFE36E")
	)
	founders_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names_stack.add_child(founders_badge)

	var founders_names := Label.new()
	founders_names.text = "BRYAN MOORE & STEFAN TYLER"
	founders_names.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	founders_names.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	founders_names.add_theme_font_size_override("font_size", 23)
	founders_names.add_theme_color_override(
		"font_color",
		Color("#FFF0B5")
	)
	founders_names.add_theme_color_override(
		"font_outline_color",
		Color("#3A080E")
	)
	founders_names.add_theme_constant_override("outline_size", 3)
	founders_names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names_stack.add_child(founders_names)

	var founders_subtitle := Label.new()
	founders_subtitle.text = "Built around fellowship, connection, and the belief that recovery can feel like life again."
	founders_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	founders_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	founders_subtitle.add_theme_font_size_override("font_size", 15)
	founders_subtitle.add_theme_color_override(
		"font_color",
		Color("#F5E9E1")
	)
	founders_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names_stack.add_child(founders_subtitle)

	_animate_section(names_panel)

	# The story card.
	var story_panel := PanelContainer.new()
	story_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	story_panel.modulate.a = 0.0
	story_panel.scale = Vector2(0.98, 0.98)

	var story_style := StyleBoxFlat.new()
	story_style.bg_color = Color("#21050A")
	story_style.border_color = Color("#B5273D")
	story_style.set_border_width_all(2)
	story_style.set_corner_radius_all(15)
	story_style.shadow_color = Color(0, 0, 0, 0.65)
	story_style.shadow_size = 8
	story_style.shadow_offset = Vector2(0, 3)
	story_style.content_margin_left = 18
	story_style.content_margin_right = 18
	story_style.content_margin_top = 17
	story_style.content_margin_bottom = 17
	story_panel.add_theme_stylebox_override("panel", story_style)
	content.add_child(story_panel)

	var story_stack := VBoxContainer.new()
	story_stack.add_theme_constant_override("separation", 10)
	story_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	story_panel.add_child(story_stack)

	var story_heading := Label.new()
	story_heading.text = "WHY THE SPOT EXISTS"
	story_heading.add_theme_font_size_override("font_size", 21)
	story_heading.add_theme_color_override(
		"font_color",
		Color("#FFE36E")
	)
	story_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	story_stack.add_child(story_heading)

	var story_divider := HSeparator.new()
	story_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	story_divider.add_theme_color_override(
		"separator",
		Color("#E30620")
	)
	story_stack.add_child(story_divider)

	var story_text := Label.new()
	story_text.text = "Recovery should be about more than simply staying sober. The Spot was created to give people a place to belong—somewhere to attend meetings, work steps, build friendships, laugh, have fun, and experience life in recovery together."
	story_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_text.add_theme_font_size_override("font_size", 15)
	story_text.add_theme_color_override(
		"font_color",
		Color("#F5E9E1")
	)
	story_text.add_theme_constant_override("line_spacing", 5)
	story_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	story_stack.add_child(story_text)

	var welcome_text := Label.new()
	welcome_text.text = "Whether someone has one day sober or many years, the goal is the same: walk in, feel welcome, and know you have a place here."
	welcome_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	welcome_text.add_theme_font_size_override("font_size", 15)
	welcome_text.add_theme_color_override(
		"font_color",
		Color("#FFF0B5")
	)
	welcome_text.add_theme_constant_override("line_spacing", 5)
	welcome_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	story_stack.add_child(welcome_text)

	_animate_section(story_panel)

	# Closing statement.
	var quote_panel := PanelContainer.new()
	quote_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quote_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quote_panel.modulate.a = 0.0
	quote_panel.scale = Vector2(0.98, 0.98)

	var quote_style := StyleBoxFlat.new()
	quote_style.bg_color = Color("#8A0B1D")
	quote_style.border_color = Color("#FFE36E")
	quote_style.set_border_width_all(2)
	quote_style.set_corner_radius_all(15)
	quote_style.shadow_color = Color(0.90, 0.02, 0.12, 0.45)
	quote_style.shadow_size = 10
	quote_style.shadow_offset = Vector2(0, 3)
	quote_style.content_margin_left = 18
	quote_style.content_margin_right = 18
	quote_style.content_margin_top = 18
	quote_style.content_margin_bottom = 18
	quote_panel.add_theme_stylebox_override("panel", quote_style)
	content.add_child(quote_panel)

	var quote_label := Label.new()
	quote_label.text = "“WALK IN. FEEL WELCOME.\nKNOW YOU HAVE A PLACE HERE.”"
	quote_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quote_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quote_label.add_theme_font_size_override("font_size", 19)
	quote_label.add_theme_color_override(
		"font_color",
		Color("#FFF0B5")
	)
	quote_label.add_theme_color_override(
		"font_outline_color",
		Color("#3A080E")
	)
	quote_label.add_theme_constant_override("outline_size", 3)
	quote_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quote_panel.add_child(quote_label)

	_animate_section(quote_panel)

	var bottom_space := Control.new()
	bottom_space.custom_minimum_size.y = 90
	bottom_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(bottom_space)

func _on_main_scroll_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		var max_scroll: float = maxf(0.0, main_scroll.get_v_scroll_bar().max_value - main_scroll.get_v_scroll_bar().page)
		var at_top := main_scroll.scroll_vertical <= 0
		var at_bottom := main_scroll.scroll_vertical >= max_scroll

		if (at_top and event.relative.y > 0.0) or (at_bottom and event.relative.y < 0.0):
			overscroll_offset += event.relative.y * 0.35
			overscroll_offset = clamp(overscroll_offset, -60.0, 60.0)
			content.position.y = -float(main_scroll.scroll_vertical) + overscroll_offset

	elif event is InputEventScreenTouch and not event.pressed:
		var target_y := -float(main_scroll.scroll_vertical)
		var tween := create_tween()
		tween.tween_property(content, "position:y", target_y, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		overscroll_offset = 0.0
	
func show_shop() -> void:
	_clear("Shop")
	title_label.visible = false
	main_scroll.scroll_vertical = 0
	_add_page_header(
		"SHOP",
		"Wear the message. Support the mission.",
		"shop",
		"SHOP\nNOW"
	)

	if shop_products.is_empty():
		if shop_request.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
			shop_request.request(SHOP_API_URL)

		var loading_panel := PanelContainer.new()
		loading_panel.custom_minimum_size.y = 96
		loading_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var loading_style := StyleBoxFlat.new()
		loading_style.bg_color = Color("#4A0612")
		loading_style.border_color = Color("#FFE36E")
		loading_style.set_border_width_all(2)
		loading_style.set_corner_radius_all(14)
		loading_panel.add_theme_stylebox_override("panel", loading_style)
		content.add_child(loading_panel)

		var loading_label := Label.new()
		loading_label.text = "Loading The Spot Shop..."
		loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		loading_label.add_theme_font_size_override("font_size", 17)
		loading_label.add_theme_color_override("font_color", Color("#FFF0B5"))
		loading_panel.add_child(loading_label)
		return

	for product in shop_products:
		var product_name := str(product.get("name", "Unnamed Product"))
		product_name = product_name.replace("&#8217;", "'")
		product_name = product_name.replace("&#8211;", "-")
		product_name = product_name.replace("&#8230;", "...")
		product_name = product_name.replace("&amp;", "&")

		var product_url := str(product.get("permalink", ""))
		var product_images = product.get("images", [])
		var image_url := ""

		if product_images.size() > 0:
			image_url = str(
				product_images[0].get(
					"thumbnail",
					product_images[0].get("src", "")
				)
			)

		var prices = product.get("prices", {})
		var price_raw := str(prices.get("price", "0"))
		var minor_unit := int(prices.get("currency_minor_unit", 2))
		var price_value := float(price_raw) / pow(10.0, minor_unit)
		var price_text := "$%.2f" % price_value

		var product_card := PanelContainer.new()
		product_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		product_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		product_card.modulate.a = 0.0
		product_card.scale = Vector2(0.98, 0.98)

		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color("#4A0612")
		card_style.border_color = Color("#FFE36E")
		card_style.set_border_width_all(2)
		card_style.set_corner_radius_all(16)
		card_style.shadow_color = Color(0, 0, 0, 0.72)
		card_style.shadow_size = 11
		card_style.shadow_offset = Vector2(0, 4)
		card_style.content_margin_left = 0
		card_style.content_margin_right = 0
		card_style.content_margin_top = 0
		card_style.content_margin_bottom = 0
		product_card.add_theme_stylebox_override("panel", card_style)
		content.add_child(product_card)
		_animate_section(product_card)

		var product_box := VBoxContainer.new()
		product_box.add_theme_constant_override("separation", 0)
		product_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		product_card.add_child(product_box)

		var image_frame := PanelContainer.new()
		image_frame.custom_minimum_size.y = 210
		image_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var image_frame_style := StyleBoxFlat.new()
		image_frame_style.bg_color = Color("#180207")
		image_frame_style.border_color = Color("#E30620")
		image_frame_style.border_width_bottom = 3
		image_frame_style.corner_radius_top_left = 14
		image_frame_style.corner_radius_top_right = 14
		image_frame_style.content_margin_left = 8
		image_frame_style.content_margin_right = 8
		image_frame_style.content_margin_top = 8
		image_frame_style.content_margin_bottom = 8
		image_frame.add_theme_stylebox_override("panel", image_frame_style)
		product_box.add_child(image_frame)

		var product_image := TextureRect.new()
		product_image.custom_minimum_size = Vector2(0, 194)
		product_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		product_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		product_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		product_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image_frame.add_child(product_image)

		if image_url != "":
			_load_product_image(image_url, product_image)

		var info_margin := MarginContainer.new()
		info_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info_margin.add_theme_constant_override("margin_left", 16)
		info_margin.add_theme_constant_override("margin_right", 16)
		info_margin.add_theme_constant_override("margin_top", 14)
		info_margin.add_theme_constant_override("margin_bottom", 16)
		product_box.add_child(info_margin)

		var info_box := VBoxContainer.new()
		info_box.add_theme_constant_override("separation", 10)
		info_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info_margin.add_child(info_box)

		var product_eyebrow := Label.new()
		product_eyebrow.text = "THE SPOT SHOP"
		product_eyebrow.add_theme_font_size_override("font_size", 11)
		product_eyebrow.add_theme_color_override("font_color", Color("#E94B5F"))
		product_eyebrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info_box.add_child(product_eyebrow)

		var product_title := Label.new()
		product_title.text = product_name
		product_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		product_title.custom_minimum_size.x = 0
		product_title.add_theme_font_size_override("font_size", 22)
		product_title.add_theme_color_override("font_color", Color("#FFF0B5"))
		product_title.add_theme_color_override("font_outline_color", Color("#3A080E"))
		product_title.add_theme_constant_override("outline_size", 3)
		product_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info_box.add_child(product_title)

		var price_badge := PanelContainer.new()
		price_badge.custom_minimum_size = Vector2(104, 40)
		price_badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		price_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var price_style := StyleBoxFlat.new()
		price_style.bg_color = Color("#FFD768")
		price_style.border_color = Color("#FFE9A0")
		price_style.set_border_width_all(2)
		price_style.set_corner_radius_all(10)
		price_badge.add_theme_stylebox_override("panel", price_style)
		info_box.add_child(price_badge)

		var price_label := Label.new()
		price_label.text = price_text
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		price_label.add_theme_font_size_override("font_size", 18)
		price_label.add_theme_color_override("font_color", Color("#3A080E"))
		price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		price_badge.add_child(price_label)

		var shop_button := Button.new()
		shop_button.text = "VIEW IN SHOP   ›"
		shop_button.custom_minimum_size.y = 56
		shop_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shop_button.add_theme_font_size_override("font_size", 16)
		shop_button.add_theme_color_override("font_color", Color("#FFF0B5"))
		shop_button.add_theme_color_override("font_hover_color", Color.WHITE)
		shop_button.add_theme_color_override("font_pressed_color", Color.WHITE)

		var button_style := StyleBoxFlat.new()
		button_style.bg_color = Color("#E30620")
		button_style.border_color = Color("#FFE36E")
		button_style.set_border_width_all(2)
		button_style.set_corner_radius_all(12)
		button_style.shadow_color = Color(0, 0, 0, 0.50)
		button_style.shadow_size = 6
		button_style.shadow_offset = Vector2(0, 3)
		shop_button.add_theme_stylebox_override("normal", button_style)

		var button_hover := button_style.duplicate() as StyleBoxFlat
		button_hover.bg_color = Color("#FF1733")
		shop_button.add_theme_stylebox_override("hover", button_hover)
		shop_button.add_theme_stylebox_override("focus", button_hover)

		var button_pressed := button_style.duplicate() as StyleBoxFlat
		button_pressed.bg_color = Color("#9E071A")
		shop_button.add_theme_stylebox_override("pressed", button_pressed)

		if product_url == "":
			shop_button.disabled = true
		else:
			shop_button.pressed.connect(
				_open_more_link.bind(product_url)
			)

		info_box.add_child(shop_button)

	var bottom_space := Control.new()
	bottom_space.custom_minimum_size.y = 26
	content.add_child(bottom_space)

	
func _on_shop_request_completed(
	_result: int,
	_response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if _result != HTTPRequest.RESULT_SUCCESS:
		print("SHOP REQUEST FAILED: ", _result)
		return

	if _response_code < 200 or _response_code >= 300:
		print("SHOP HTTP ERROR: ", _response_code)
		return

	var json := JSON.new()
	var parse_error := json.parse(body.get_string_from_utf8())

	if parse_error != OK:
		print(
			"SHOP JSON ERROR: ",
			json.get_error_message(),
			" at line ",
			json.get_error_line()
		)
		return

	var data = json.data

	if not data is Array:
		print("SHOP API ERROR: Response was not an array")
		return

	shop_products = data

	var _cache_file := FileAccess.open(
		"user://shop_cache.json",
		FileAccess.WRITE
	)

	if _cache_file != null:
		_cache_file.store_string(JSON.stringify(shop_products))

	if title_label.text == "Shop":
		show_shop()

	for product in shop_products:
		var product_name: String = str(
			product.get("name", "Unnamed Product")
		)
		product_name = product_name.replace(
			"&#8217;",
			"'"
		).replace(
			"&#8211;",
			"-"
		).replace(
			"&#8230;",
			"..."
		)
		print(product_name)

	print("SHOP PRODUCTS LOADED: ", shop_products.size())
		
func _load_product_image(_url: String, _target: TextureRect) -> void:
	var _cache_path: String = "user://shop_image_" + str(_url.hash()) + ".cache"

	if FileAccess.file_exists(_cache_path):
		var _file = FileAccess.open(_cache_path, FileAccess.READ)
		var _cached_body: PackedByteArray = _file.get_buffer(_file.get_length())
		_apply_product_image_bytes(_cached_body, _target)
		return

	var _image_request = HTTPRequest.new()
	add_child(_image_request)
	_image_request.request_completed.connect(
		_on_product_image_loaded.bind(_target, _image_request, _cache_path)
	)
	_image_request.request(_url)


func _on_product_image_loaded(
	_result: int,
	_response_code: int,
	_headers: PackedStringArray,
	_body: PackedByteArray,
	_target: TextureRect,
	_request: HTTPRequest,
	_cache_path: String
) -> void:
	if _response_code >= 200 and _response_code < 300:
		var _file = FileAccess.open(_cache_path, FileAccess.WRITE)
		_file.store_buffer(_body)

		_apply_product_image_bytes(_body, _target)

	_request.queue_free()


func _apply_product_image_bytes(_body: PackedByteArray, _target: TextureRect) -> void:
	var _image = Image.new()
	var _load_error = _image.load_jpg_from_buffer(_body)

	if _load_error != OK:
		_load_error = _image.load_png_from_buffer(_body)

	if _load_error != OK:
		_load_error = _image.load_webp_from_buffer(_body)

	if _load_error == OK:
		_target.texture = ImageTexture.create_from_image(_image)

func _on_events_request_completed(_result: int, _response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	var data = JSON.parse_string(_body.get_string_from_utf8())

	if data is Array:
		events_data = data
		var _cache_file = FileAccess.open("user://events_cache.json", FileAccess.WRITE)
		_cache_file.store_string(JSON.stringify(events_data))
		if title_label.text == "Events":
			show_events()
	else:
		print("EVENTS API ERROR")

func _on_membership_request_completed(_result: int, _response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	var data = JSON.parse_string(_body.get_string_from_utf8())

	if data is Array:
		print("MEMBERSHIPS LOADED: ", data.size())
	else:
		print("MEMBERSHIP API ERROR")
		
func _on_meetings_request_completed(_result: int, _response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	var data = JSON.parse_string(_body.get_string_from_utf8())

	if data is Array:
		print("MEETINGS PAGE LOADED: ", data.size())
		meetings_html = str(data[0].get("content", {}).get("rendered", ""))
		var meeting_regex := RegEx.new()
		meeting_regex.compile('<div class="dvmd_tm_cdata">([^<]*)</div>')
		var meeting_cells := meeting_regex.search_all(meetings_html)
		meetings_data.clear()
		var _current_day: String = ""
		var _pending_time: String = ""
		var _pending_meeting: String = ""
		for cell in meeting_cells:
			var cell_text: String = cell.get_string(1)
			if cell_text in ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]:
				_current_day = cell_text
			elif cell_text in ["Meeting", "Meeting Name", "Room"]:
				continue
			elif "AM" in cell_text or "PM" in cell_text:
				_pending_time = cell_text
			elif _pending_time != "" and _pending_meeting == "":
				_pending_meeting = cell_text
			elif _pending_time != "" and _pending_meeting != "":
				meetings_data.append({
					"day": _current_day,
					"time": _pending_time,
					"meeting": _pending_meeting,
					"room": cell_text
				})
				_pending_time = ""
				_pending_meeting = ""

		print("MEETING CELLS FOUND: ", meeting_cells.size())
		print("MEETINGS PARSED: ", meetings_data.size())
		var _cache_file = FileAccess.open("user://meetings_cache.json", FileAccess.WRITE)
		_cache_file.store_string(JSON.stringify(meetings_data))
		if title_label.text == "Meetings":
				show_meetings()
		elif title_label.text == "Welcome Home":
				show_home()
	else:
		print("MEETINGS API ERROR")

func _select_meeting_day(day_name: String) -> void:
	selected_meeting_day = day_name
	show_meetings()
