extends Control


const BG := Color("111111")
const CARD := Color("5C1F1F")
const GOLD := Color("D4AF37")
const TEXT := Color("f5f1e8")
const MUTED := Color("aaa69d")
const SHOP_API_URL := "https://thespotlounge.com/wp-json/wc/store/v1/products?per_page=100"
const EVENTS_URL := "https://thespotlounge.com/wp-json/wp/v2/event?per_page=100"
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
	photo.scale = Vector2(1.08, 1.08)

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
	logo_entrance.set_trans(Tween.TRANS_QUAD)
	logo_entrance.set_ease(Tween.EASE_OUT)
	logo_entrance.tween_property(logo_holder, "modulate:a", 1.0, 0.55)
	logo_entrance.tween_property(
		logo_holder,
		"position:y",
		logo_holder.position.y,
		0.55
	).from(logo_holder.position.y + 22.0)

	await get_tree().create_timer(0.20).timeout

	var button_entrance := create_tween()
	button_entrance.set_parallel(true)
	button_entrance.set_trans(Tween.TRANS_BACK)
	button_entrance.set_ease(Tween.EASE_OUT)
	button_entrance.tween_property(button_holder, "modulate:a", 1.0, 0.55)
	button_entrance.tween_property(
		button_holder,
		"position:y",
		button_holder.position.y,
		0.55
	).from(button_holder.position.y + 28.0)

	await enter_button.pressed
	enter_button.disabled = true
	Input.vibrate_handheld(60)

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

	var flash_tween := create_tween()
	flash_tween.tween_property(flash, "modulate:a", 0.28, 0.08)
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.20)

	var transition := create_tween()
	transition.set_parallel(true)
	transition.set_trans(Tween.TRANS_QUAD)
	transition.set_ease(Tween.EASE_IN)
	transition.tween_property(photo, "scale", Vector2(1.38, 1.38), 0.72)
	transition.tween_property(photo, "modulate:a", 0.0, 0.72).set_delay(0.18)
	transition.tween_property(shade, "modulate:a", 0.0, 0.55)
	transition.tween_property(logo_holder, "scale", Vector2(1.16, 1.16), 0.55)
	transition.tween_property(logo_holder, "modulate:a", 0.0, 0.46)
	transition.tween_property(button_holder, "scale", Vector2(1.12, 1.12), 0.48)
	transition.tween_property(button_holder, "modulate:a", 0.0, 0.40)

	await transition.finished
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
	scroll.gui_input.connect(_on_main_scroll_gui_input)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.scroll_deadzone = 0
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
		"More Than a Meeting",
		"A place to connect, laugh, grow, and experience life in recovery.\n\nMeetings • Fellowship • Events • Games • Community"
	)

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
		"Recovery Thought",
		recovery_thoughts[thought_index]
	)

	_section(
		"Visit The Spot",
		"4220 W Northern Ave, Suite 111\nPhoenix, Arizona",
		"GET DIRECTIONS",
		"https://www.google.com/maps/search/?api=1&query=4220+W+Northern+Ave+Suite+111+Phoenix+AZ"
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
		meeting_row.add_theme_constant_override("separation", 14)
		meeting_panel.add_child(meeting_row)

		var time_badge := PanelContainer.new()
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
		time_label.text = formatted_time
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		time_label.add_theme_font_size_override("font_size", 18)
		time_label.add_theme_color_override("font_color", Color("#3A080E"))
		time_badge.add_child(time_label)

		var meeting_info := VBoxContainer.new()
		meeting_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		meeting_info.alignment = BoxContainer.ALIGNMENT_CENTER
		meeting_info.add_theme_constant_override("separation", 5)
		meeting_row.add_child(meeting_info)

		var name_label := Label.new()
		name_label.text = display_name.to_upper()
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.custom_minimum_size.x = 0
		name_label.add_theme_font_size_override("font_size", 20)
		name_label.add_theme_color_override("font_color", Color("#FFF7F0"))
		meeting_info.add_child(name_label)

		if not detail_parts.is_empty():
			var detail_label := Label.new()
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

	for event_item in events_data:
		var _event_title: String = str(event_item.get("title", {}).get("rendered", "Untitled Event"))
		var _event_link: String = str(event_item.get("link", ""))
		_event_title = _event_title.replace("&#8216;", "'").replace("&#8217;", "'").replace("&#8211;", "-").replace("&#8230;", "...").replace("&amp;", "&")
		_section(_event_title, "Tap below for full event details.", "VIEW EVENT", _event_link)
		
func show_vip() -> void:
	_clear("VIP MEMBERSHP")
	_section("VIP Membership", "Join The Spot VIP and get member perks, including free admission to events. Choose the membership option that works best for you.")
	_section(
	"VIP Benefits",
	"The Spot VIP Membership is for people who want to support the sober community while getting extra benefits at The Spot. VIP members receive perks such as free admission to events, special member benefits, and easier access to everything The Spot offers. Membership is available in monthly or annual options.")
	_section(
	"Open Membership Shop",
	"Choose the monthly VIP option on The Spot website.",
	"OPEN MEMBERSHIP SHOP",
	"https://thespotlounge.com/shop/"
)

func show_more() -> void:
	_clear("")
	title_label.visible = false
	_add_page_header(
		"MORE",
		"Explore everything The Spot offers.",
		"more",
		"EXPLORE"
	)

	_section(
		"The Spot Sober Lounge",
		"More than a meeting space—a place for fellowship, connection, events, entertainment, and life in recovery."
	)

	var menu_panel := PanelContainer.new()
	menu_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_panel.modulate.a = 0.0
	menu_panel.scale = Vector2(0.98, 0.98)

	var menu_style := StyleBoxFlat.new()
	menu_style.bg_color = Color("#641A24")
	menu_style.border_color = Color("#D4AF37")
	menu_style.set_border_width_all(2)
	menu_style.corner_radius_top_left = 16
	menu_style.corner_radius_top_right = 16
	menu_style.corner_radius_bottom_left = 16
	menu_style.corner_radius_bottom_right = 16
	menu_style.shadow_color = Color(0, 0, 0, 0.55)
	menu_style.shadow_size = 10
	menu_style.shadow_offset = Vector2(0, 3)
	menu_style.content_margin_left = 14
	menu_style.content_margin_right = 14
	menu_style.content_margin_top = 16
	menu_style.content_margin_bottom = 16
	menu_panel.add_theme_stylebox_override("panel", menu_style)

	content.add_child(menu_panel)
	_animate_section(menu_panel)

	var menu_box := VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 8)
	menu_panel.add_child(menu_box)

	var menu_title := Label.new()
	menu_title.text = "Explore The Spot"
	menu_title.add_theme_font_size_override("font_size", 21)
	menu_title.add_theme_color_override("font_color", Color("#FFE06A"))
	menu_title.add_theme_color_override(
		"font_outline_color",
		Color("#3A080E")
	)
	menu_title.add_theme_constant_override("outline_size", 4)
	menu_box.add_child(menu_title)

	var menu_line := ColorRect.new()
	menu_line.color = Color("#D4AF37")
	menu_line.custom_minimum_size = Vector2(0, 2)
	menu_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_box.add_child(menu_line)

	menu_box.add_child(
		_more_action_button(
			"ABOUT THE FOUNDERS",
			show_founders,
			true
		)
	)

	menu_box.add_child(
		_more_action_button(
			"VIP MEMBERSHIP",
			show_vip
		)
	)

	menu_box.add_child(
		_more_action_button(
			"ON THE SPOT PODCAST",
			_open_more_link.bind(
				"https://www.youtube.com/@thespotsoberlounge1079"
			)
		)
	)

	menu_box.add_child(
		_more_action_button(
			"VISIT OUR WEBSITE",
			_open_more_link.bind(
				"https://thespotlounge.com/"
			)
		)
	)

	menu_box.add_child(
		_more_action_button(
			"CONTACT & SUPPORT",
			_open_more_link.bind(
				"mailto:thespotphoenix@gmail.com"
			)
		)
	)

	menu_box.add_child(
		_more_action_button(
			"PRIVACY POLICY",
			_open_more_link.bind(
				"https://isaacweigner51-arch.github.io/the-spot-sober-lounge-app/docs/index.html"
			)
		)
	)

	var contact_line := HSeparator.new()
	contact_line.modulate = Color(0.83, 0.69, 0.22, 0.55)
	menu_box.add_child(contact_line)

	var contact_info := Label.new()
	contact_info.text = (
		"thespotphoenix@gmail.com\n"
		+ "480-249-0492"
	)
	contact_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contact_info.add_theme_font_size_override("font_size", 14)
	contact_info.add_theme_color_override(
		"font_color",
		Color("#D9C9C1")
	)
	contact_info.add_theme_constant_override("line_spacing", 3)
	menu_box.add_child(contact_info)

	var version_label := Label.new()
	version_label.text = "THE SPOT SOBER LOUNGE • VERSION 1.0"
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	version_label.add_theme_font_size_override("font_size", 11)
	version_label.add_theme_color_override(
		"font_color",
		Color(0.83, 0.69, 0.22, 0.70)
	)
	menu_box.add_child(version_label)

	var bottom_space := Control.new()
	bottom_space.custom_minimum_size.y = 24
	content.add_child(bottom_space)


func _more_action_button(
	button_text: String,
	action: Callable,
	featured := false
) -> Button:
	var button := Button.new()
	button.text = button_text + "   ›"
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 54)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override(
		"font_color",
		Color("#FFE06A")
	)
	button.add_theme_color_override(
		"font_hover_color",
		Color.WHITE
	)
	button.add_theme_color_override(
		"font_pressed_color",
		Color.WHITE
	)
	button.add_theme_color_override(
		"font_outline_color",
		Color("#3A080E")
	)
	button.add_theme_constant_override("outline_size", 3)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = (
		Color("#C91932")
		if featured
		else Color("#4A161B")
	)
	normal_style.border_color = (
		Color("#FFE06A")
		if featured
		else Color("#8C6A2F")
	)
	normal_style.set_border_width_all(2 if featured else 1)
	normal_style.corner_radius_top_left = 10
	normal_style.corner_radius_top_right = 10
	normal_style.corner_radius_bottom_left = 10
	normal_style.corner_radius_bottom_right = 10
	normal_style.shadow_color = Color(0, 0, 0, 0.40)
	normal_style.shadow_size = 5
	normal_style.shadow_offset = Vector2(0, 2)
	normal_style.content_margin_left = 16
	normal_style.content_margin_right = 14
	normal_style.content_margin_top = 8
	normal_style.content_margin_bottom = 8

	var hover_style := normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = (
		Color("#E01E3C")
		if featured
		else Color("#721E27")
	)
	hover_style.border_color = Color("#FFF09A")

	var pressed_style := normal_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color("#8F1023")
	pressed_style.shadow_size = 2

	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("focus", hover_style)

	button.button_down.connect(
		_animate_more_button.bind(button, true)
	)
	button.button_up.connect(
		_animate_more_button.bind(button, false)
	)
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
	_clear("About the Founders")
	bg.modulate = Color("#3A161A")
	var founders_image = TextureRect.new()
	founders_image.texture = load("res://assets/thespotfounderscorrected.png")
	founders_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	founders_image.custom_minimum_size = Vector2(0, 420)
	founders_image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(founders_image)
	content.add_spacer(false)
	founders_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_section("Bryan Moore & Stefan Tyler", "Founders of The Spot Sober Lounge\n\nBuilt around fellowship, connection, and creating a place where recovery can feel like life again.")
	_section("Why The Spot Exists", "Recovery should be about more than simply staying sober. The Spot was created to give people a place to belong — somewhere to attend meetings, work steps, build friendships, laugh, have fun, and experience life in recovery together. Whether someone has one day sober or many years, the goal is the same: walk in, feel welcome, and know you have a place here.")
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
	_clear("")
	title_label.visible = false
	_add_page_header(
		"SHOP",
		"Wear the message. Support the mission.",
		"shop",
		"SHOP\nNOW"
	)
	if shop_products.size() > 0:
		for product in shop_products:
			var _product_name: String = str(product.get("name", "Unnamed Product"))
			_product_name = _product_name.replace("&#8217;", "'").replace("&#8211;", "-").replace("&#8230;", "...")
			var _product_url: String = str(product.get("permalink", ""))
			var _images = product.get("images", [])
			var _image_url: String = str(_images[0].get("thumbnail", _images[0].get("src", ""))) if _images.size() > 0 else ""
			var _product_image = TextureRect.new()
			_product_image.custom_minimum_size = Vector2(0, 180)
			_product_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_product_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			content.add_child(_product_image)
			if _image_url != "":
				_load_product_image(_image_url, _product_image)
			var _prices = product.get("prices", {})
			var _price_raw: String = str(_prices.get("price", "0"))
			var _minor_unit: int = int(_prices.get("currency_minor_unit", 2))
			var _price_value: float = float(_price_raw) / pow(10.0, _minor_unit)
			var _price_text: String = "$%.2f" % _price_value
			_section(_product_name, _price_text, "BUY ON WEBSITE", _product_url)
			
	if shop_products.is_empty():
		shop_request.request(SHOP_API_URL)
		return
	
	
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
