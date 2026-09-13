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
	meetings_request.request(MEETINGS_API_URL)

	if not events_data.is_empty():
		events_request.request(EVENTS_URL)
	
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
	
	
func _build_shell() -> void:
	var bg_image = load("res://assets/freedom.jpeg")
	bg = TextureRect.new()
	bg.texture = bg_image
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root = VBoxContainer.new()
	root.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	var header = VBoxContainer.new()
	header.custom_minimum_size.y = 35
	header.add_theme_constant_override("separation", 2)
	root.add_child(header)
	

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", TEXT)
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_outline_color", Color("#000000"))
	title_label.add_theme_constant_override("outline_size", 12)
	title_label.custom_minimum_size.y = 20
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title_label)

	var scroll = ScrollContainer.new()
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

func _section(text: String, body: String, button_text := "", url := "") -> void:
	var panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style = StyleBoxFlat.new()
	style.bg_color = CARD
	style.border_color = Color("#8C6A2F")
	style.set_border_width_all(2)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 8
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	content.add_child(panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var h = Label.new()
	h.text = text
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.custom_minimum_size.x = 0
	h.add_theme_font_size_override("font_size", 20)
	h.add_theme_color_override("font_color", GOLD)
	box.add_child(h)
	h.add_theme_constant_override("outline_size", 5)
	h.add_theme_color_override("font_outline_color", Color("8B2E2E"))
	var p = Label.new(); p.text = body; p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; p.add_theme_font_size_override("font_size", 15); p.add_theme_color_override("font_color", TEXT); box.add_child(p)
	if button_text != "":
		var b = Button.new(); b.text = button_text; b.custom_minimum_size.y = 48; box.add_child(b)
		var button_style = StyleBoxFlat.new()
		button_style.bg_color = Color("4A161B")
		button_style.corner_radius_top_left = 10
		button_style.corner_radius_top_right = 10
		button_style.corner_radius_bottom_left = 10
		button_style.corner_radius_bottom_right = 10
		b.add_theme_stylebox_override("normal", button_style)  
	
		if url == "app://shop":
			b.pressed.connect(show_shop)
		elif url == "app://vip":
			b.pressed.connect(show_vip)
		elif url != "":
			b.pressed.connect(func(): OS.shell_open(url))

func show_home() -> void:
		_clear("Welcome Home")
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.custom_minimum_size.y = 58
		title_label.add_theme_font_size_override("font_size", 26)
		title_label.add_theme_color_override("font_color", Color("#FFE06A"))
		title_label.add_theme_color_override("font_outline_color", Color("#000000"))
		title_label.add_theme_constant_override("outline_size", 6)

		var title_style := StyleBoxFlat.new()
		title_style.bg_color = Color("#C91932")
		title_style.border_color = Color("#F3D36A")
		title_style.set_border_width_all(3)
		title_style.corner_radius_top_left = 18
		title_style.corner_radius_top_right = 18
		title_style.corner_radius_bottom_left = 18
		title_style.corner_radius_bottom_right = 18
		title_style.shadow_color = Color(0, 0, 0, 0.65)
		title_style.shadow_size = 10
		title_style.content_margin_left = 12
		title_style.content_margin_right = 12
		title_style.content_margin_top = 8
		title_style.content_margin_bottom = 8

		title_label.add_theme_stylebox_override("normal", title_style)
		
		
		
		var sub = Label.new()
		sub.text = "SOBER LOUNGE • SOBER STATE OF MIND"
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.add_theme_constant_override("outline_size", 8)
		sub.add_theme_color_override("font_outline_color", Color("#7A232A"))
		sub.add_theme_font_size_override("font_size", 16)
		sub.add_theme_color_override("font_color", Color("#D4AF37"))
		content.add_child(sub)
		var logo = TextureRect.new()
		logo.texture = load("res://assets/Spotlogo.png")
		logo.custom_minimum_size = Vector2(300, 150)
		logo.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.modulate = Color(1, 1, 1, 0.96)
		content.add_child(logo)
		content.add_spacer(false)
	
		_section(
	"More Than a Meeting",
	"A place to connect, laugh, grow, and experience life in recovery.\n\nMeetings • Fellowship • Events • Games • Community"
)
		var _date: Dictionary = Time.get_date_dict_from_system()
		var _weekday: int = int(_date.get("weekday", 0))
		var _day_names: Array[String] = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
		var _today: String = _day_names[_weekday]

		var _today_text: String = ""
		if meetings_data.is_empty():
			_section("Today at The Spot", "Loading today's meetings...")
			return
			
		for _meeting in meetings_data:
			if str(_meeting.get("day", "")) != _today:
				continue

			var _time: String = str(_meeting.get("time", ""))
			var _name: String = str(_meeting.get("meeting", ""))
			var _room: String = str(_meeting.get("room", ""))
			_name = _name.replace("&amp;", "&")
			_name = _name.replace("&#8217;", "'")
			_name = _name.replace("&#8211;", "-")
			_room = _room.replace("&amp;", "&")

			if _today_text != "":
				_today_text += "\n"

			_today_text += _time + " • " + _name + " • " + _room

		if _today_text == "":
			_today_text = "No meetings scheduled today."

		_section("Today at The Spot — " + _today, _today_text)
		var _today_card := content.get_child(content.get_child_count() - 1) as PanelContainer
		var _today_style := StyleBoxFlat.new()

		_today_style.bg_color = Color("#721E27")
		_today_style.border_color = Color("#F3D36A")
		_today_style.set_border_width_all(4)
		_today_style.corner_radius_top_left = 16
		_today_style.corner_radius_top_right = 16
		_today_style.corner_radius_bottom_left = 16
		_today_style.corner_radius_bottom_right = 16
		_today_style.shadow_color = Color(0, 0, 0, 0.55)
		_today_style.shadow_size = 12
		_today_style.content_margin_left = 14
		_today_style.content_margin_right = 14
		_today_style.content_margin_top = 12
		_today_style.content_margin_bottom = 12

		_today_card.add_theme_stylebox_override("panel", _today_style)

		var _today_heading := _today_card.get_child(0).get_child(0) as Label
		_today_heading.add_theme_font_size_override("font_size", 20)
		_today_heading.add_theme_color_override("font_color", Color("#FFE08A"))
		_today_heading.add_theme_color_override("font_outline_color", Color("#000000"))
		_today_heading.add_theme_constant_override("outline_size", 6)
		var _recovery_thoughts: Array[String] = [
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

		var _thought_key: int = (
			int(_date.get("year", 0)) * 372
		+ int(_date.get("month", 0)) * 31
		+ int(_date.get("day", 0))
	)

		var _thought_index: int = posmod(_thought_key, _recovery_thoughts.size())

		_section("Recovery Thought", _recovery_thoughts[_thought_index])
		_section("Visit The Spot", "4220 W Northern Ave, Suite 111\nPhoenix, Arizona", "GET DIRECTIONS", "https://www.google.com/maps/search/?api=1&query=4220+W+Northern+Ave+Suite+111+Phoenix+AZ")
		
		var bottom_space := Control.new()
		bottom_space.custom_minimum_size.y = 24
		content.add_child(bottom_space)

func show_meetings() -> void:
	_clear("Meetings")

	if meetings_data.is_empty():
		meetings_request.request(MEETINGS_API_URL)
		return

	var _days := [
		"Sunday",
		"Monday",
		"Tuesday",
		"Wednesday",
		"Thursday",
		"Friday",
		"Saturday"
	]

	var _day_dropdown := OptionButton.new()
	_day_dropdown.custom_minimum_size = Vector2(0, 52)
	_day_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_day_dropdown.add_theme_font_size_override("font_size", 16)
	_day_dropdown.add_theme_color_override(
		"font_color",
		Color.from_rgba8(243, 211, 106, 255)
	)
	_day_dropdown.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_day_dropdown.add_theme_font_size_override("font_size", 18)


	var _dropdown_style := StyleBoxFlat.new()
	_dropdown_style.bg_color = Color.from_rgba8(150, 20, 35, 255)
	_dropdown_style.border_color = Color.from_rgba8(212, 175, 55, 255)
	_dropdown_style.set_border_width_all(3)

	_dropdown_style.corner_radius_top_left = 12
	_dropdown_style.corner_radius_top_right = 12
	_dropdown_style.corner_radius_bottom_left = 12
	_dropdown_style.corner_radius_bottom_right = 12

	_day_dropdown.add_theme_stylebox_override(
		"normal",
		_dropdown_style
	)

	for _day_name in _days:
		_day_dropdown.add_item(_day_name)

	var _selected_index: int = _days.find(selected_meeting_day)

	if _selected_index >= 0:
		_day_dropdown.select(_selected_index)

	_day_dropdown.item_selected.connect(
		func(index: int):
			selected_meeting_day = _days[index]
			show_meetings()
	)

	content.add_child(_day_dropdown)


	for meeting in meetings_data:
		var _day: String = str(meeting.get("day", ""))

		if _day != selected_meeting_day:
			continue

		var _time: String = str(meeting.get("time", ""))
		var _meeting_name: String = str(
			meeting.get("meeting", "")
		)
		var _room: String = str(meeting.get("room", ""))

		_meeting_name = _meeting_name.replace("&amp;", "&")
		_meeting_name = _meeting_name.replace("&#8217;", "'")
		_meeting_name = _meeting_name.replace("&#8211;", "-")

		_section(
			_meeting_name,
			_time + " • " + _room
		)

func show_events() -> void:
	_clear("Events")

	if events_data.is_empty():
		if events_request.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
			events_request.request(EVENTS_URL)
		return

	for event_item in events_data:
		var _event_title: String = str(event_item.get("title", {}).get("rendered", "Untitled Event"))
		var _event_link: String = str(event_item.get("link", ""))
		_event_title = _event_title.replace("&#8217;", "'").replace("&#8211;", "-").replace("&#8230;", "...")
		_section(_event_title, "Tap below for full event details.", "VIEW EVENT", _event_link)
		
func show_vip() -> void:
	_clear("VIP MEMBERSHP")
	_section("VIP Membership", "Join The Spot VIP and get member perks, including free admission to events. Choose the membership option that works best for you.")
	_section(
	"VIP Benefits",
	"The Spot VIP Membership is for people who want to support the sober community while getting extra benefits at The Spot. VIP members receive perks such as free admission to events, special member benefits, and easier access to everything The Spot offers. Membership is available in monthly or annual options.")
	_section("Open Membership Shop", "Choose the monthly VIP option on The Spot website.", "https://thespotlounge.com/shop/")
	


func show_more() -> void:
	_clear("More")
	_section("The Lounge", "Reclining couches, giant-screen TV, pool tables, dart boards and space for stepwork or just hanging out.")
	_section(
	"VIP Membership",
	"Support The Spot and unlock VIP member benefits, including free admission to events and other member perks.",
	"VIEW VIP MEMBERSHIP",
	"app://vip"
)
	_section("On The Spot Podcast", "Recovery-focused interviews covering a wide range of topics.", "VISIT THE SPOT", "https://www.youtube.com/@thespotsoberlounge1079")
	_section("Website", "For current announcements, store purchases and additional information.", "THESPOTLOUNGE.COM", "https://thespotlounge.com/")
	_section("Contact The Spot", "Email: thespotphoenix@gmail.com\nPhone: 480-249-0492")
	var founders_button = Button.new()
	var founders_style = StyleBoxFlat.new()
	founders_style.bg_color = Color("#5C1F1F")
	founders_style.border_color = Color("#D4AF37")
	founders_style.set_border_width_all(2)
	founders_style.corner_radius_top_left = 10
	founders_style.corner_radius_top_right = 10
	founders_style.corner_radius_bottom_left = 10
	founders_style.corner_radius_bottom_right = 10
	founders_button.add_theme_stylebox_override("normal", founders_style)
	founders_button.add_theme_color_override("font_color", Color("#D4AF37"))
	founders_button.text = "About the Founders"
	founders_button.pressed.connect(show_founders)
	content.add_child(founders_button)
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
	_clear("Shop")
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
