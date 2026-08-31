extends Control

const BG := Color("111111")
const CARD := Color("1c1c1c")
const GOLD := Color("d8ad48")
const TEXT := Color("f5f1e8")
const MUTED := Color("aaa69d")

var content: VBoxContainer
var title_label: Label
var nav: HBoxContainer

func _ready() -> void:
    _build_shell()
    show_home()

func _build_shell() -> void:
    var bg = ColorRect.new()
    bg.color = BG
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    var root = VBoxContainer.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_theme_constant_override("separation", 0)
    add_child(root)

    var header = VBoxContainer.new()
    header.custom_minimum_size.y = 112
    header.add_theme_constant_override("separation", 2)
    root.add_child(header)
    var brand = Label.new()
    brand.text = "THE SPOT"
    brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    brand.add_theme_font_size_override("font_size", 34)
    brand.add_theme_color_override("font_color", GOLD)
    header.add_child(brand)
    var sub = Label.new()
    sub.text = "SOBER LOUNGE  •  SOBER STATE OF MIND"
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sub.add_theme_font_size_override("font_size", 13)
    sub.add_theme_color_override("font_color", TEXT)
    header.add_child(sub)

    title_label = Label.new()
    title_label.add_theme_font_size_override("font_size", 24)
    title_label.add_theme_color_override("font_color", TEXT)
    title_label.custom_minimum_size.y = 52
    title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    root.add_child(title_label)

    var scroll = ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(scroll)
    content = VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 12)
    scroll.add_child(content)

    nav = HBoxContainer.new()
    nav.custom_minimum_size.y = 74
    nav.alignment = BoxContainer.ALIGNMENT_CENTER
    nav.add_theme_constant_override("separation", 4)
    root.add_child(nav)
    _nav_button("Home", show_home)
    _nav_button("Meetings", show_meetings)
    _nav_button("Events", show_events)
    _nav_button("VIP", show_vip)
    _nav_button("More", show_more)

func _nav_button(label: String, action: Callable) -> void:
    var b = Button.new()
    b.text = label
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    b.custom_minimum_size.y = 58
    b.add_theme_font_size_override("font_size", 13)
    b.pressed.connect(action)
    nav.add_child(b)

func _clear(page_title: String) -> void:
    title_label.text = page_title
    for c in content.get_children(): c.queue_free()

func _section(text: String, body: String, button_text := "", url := "") -> void:
    var panel = PanelContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var style = StyleBoxFlat.new()
    style.bg_color = CARD
    style.corner_radius_top_left = 16
    style.corner_radius_top_right = 16
    style.corner_radius_bottom_left = 16
    style.corner_radius_bottom_right = 16
    style.content_margin_left = 18
    style.content_margin_right = 18
    style.content_margin_top = 16
    style.content_margin_bottom = 16
    panel.add_theme_stylebox_override("panel", style)
    content.add_child(panel)
    var box = VBoxContainer.new()
    box.add_theme_constant_override("separation", 8)
    panel.add_child(box)
    var h = Label.new(); h.text = text; h.add_theme_font_size_override("font_size", 20); h.add_theme_color_override("font_color", GOLD); box.add_child(h)
    var p = Label.new(); p.text = body; p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; p.add_theme_font_size_override("font_size", 15); p.add_theme_color_override("font_color", TEXT); box.add_child(p)
    if button_text != "":
        var b = Button.new(); b.text = button_text; b.custom_minimum_size.y = 48; box.add_child(b)
        if url != "": b.pressed.connect(func(): OS.shell_open(url))

func show_home() -> void:
    _clear("Welcome Home")
    _section("Arizona's Sober Lounge", "A place for meetings, stepwork, conversation, games, events and sober community.")
    _section("Meetings", "CMA • HA • CA • NA • CoDA • Al-Anon • RA • FA • AA", "VIEW MEETINGS")
    content.get_child(content.get_child_count()-1).get_child(0).get_child(2).pressed.connect(show_meetings)
    _section("Events", "The Spot hosts sober events throughout the month — from game nights to parties and tournaments.", "VIEW EVENTS")
    content.get_child(content.get_child_count()-1).get_child(0).get_child(2).pressed.connect(show_events)
    _section("Visit The Spot", "4220 W Northern Ave, Suite 111\nPhoenix, Arizona", "GET DIRECTIONS", "https://www.google.com/maps/search/?api=1&query=4220+W+Northern+Ave+Suite+111+Phoenix+AZ")

func show_meetings() -> void:
    _clear("Meetings")
    _section("Sunday", "8:30 AM  West Valley Men's Group of CA\n2:00 PM  Healing Hearts\n3:45 PM  Broken Glass\n6:00 PM  Broken Glass\n7:15 PM  Bad Habits\n7:15 PM  Faith Over Fear")
    _section("Monday", "6:00 PM  Unloaded\n6:00 PM  Branching Out\n6:00 PM  Crack the Pipe\n7:15 PM  Inside Addiction\n7:15 PM  Faith Over Fear")
    _section("Tuesday", "6:00 PM  Tweakers at The Spot\n7:15 PM  Broken Glass\n7:15 PM  Faith Over Fear")
    _section("Wednesday", "6:00 PM  Broken Glass\n7:00 PM  Bluegrudge Grief Workshop\n7:15 PM  Faith Over Fear")
    _section("Thursday", "6:00 PM  F*** Fentanyl\n7:00 PM  Broken Glass\n7:15 PM  Faith Over Fear")
    _section("Friday", "10:00 AM  Morning Bowl\n6:00 PM  Unloaded\n6:00 PM  Branching Out\n7:15 PM  Crafty Rascals\n7:15 PM  Faith Over Fear\n8:30 PM  Walking Free Again")
    _section("Saturday", "9:30 AM  There Is A Way Out\n11:00 AM  Broken Glass\n12:30 PM  Wisdom of Self Love\n2:00 PM  It Takes A Village\n5:00 PM  CMA Rocks\n7:15 PM  Sleepers, Tweekers & Drinkers")

func show_events() -> void:
    _clear("Events")
    _section("Sober Events", "The Spot hosts sober events almost every weekend, including game nights, dance parties, tournaments and community celebrations.", "CURRENT EVENTS", "https://thespotlounge.com/events/")
    _section("Host an Event", "Looking for space for a special event? The Spot offers event-space rental. Visit the website for current information.", "VISIT WEBSITE", "https://thespotlounge.com/events/")

func show_vip() -> void:
    _clear("VIP Membership")
    _section("Become a VIP", "VIP members receive Spot perks, including free admission to events. Monthly and annual memberships are available through The Spot's online shop.", "VIEW MEMBERSHIPS", "https://thespotlounge.com/shop/")

func show_more() -> void:
    _clear("More")
    _section("The Lounge", "Reclining couches, giant-screen TV, pool tables, dart boards and space for stepwork or just hanging out.")
    _section("Shop", "Sober gear, Hope Dealers apparel, recovery literature and more.", "OPEN SHOP", "https://thespotlounge.com/shop/")
    _section("On The Spot Podcast", "Recovery-focused interviews covering a wide range of topics.", "VISIT THE SPOT", "https://thespotlounge.com/")
    _section("Website", "For current announcements, store purchases and additional information.", "THESPOTLOUNGE.COM", "https://thespotlounge.com/")
