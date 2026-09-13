class_name NavIcon
extends Control


var icon_name: String = "home"
var icon_color: Color = Color("#FFD23F")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(30, 30)


func setup(new_icon: String) -> void:
	icon_name = new_icon
	queue_redraw()


func _draw() -> void:
	match icon_name:
		"home":
			_draw_home()

		"meetings":
			_draw_meetings()

		"events":
			_draw_events()

		"shop":
			_draw_shop()

		"more":
			_draw_more()

		"more":
			_draw_more()


func _draw_home() -> void:
	var w := size.x
	var h := size.y

	var left := Vector2(w * 0.18, h * 0.48)
	var top := Vector2(w * 0.50, h * 0.18)
	var right := Vector2(w * 0.82, h * 0.48)

	draw_line(left, top, icon_color, 3.0, true)
	draw_line(top, right, icon_color, 3.0, true)

	draw_rect(
		Rect2(w * 0.27, h * 0.46, w * 0.46, h * 0.38),
		icon_color,
		false,
		3.0,
		true
	)

	draw_rect(
		Rect2(w * 0.43, h * 0.62, w * 0.14, h * 0.22),
		icon_color,
		false,
		2.5,
		true
	)


func _draw_meetings() -> void:
	var w := size.x
	var h := size.y

	draw_circle(
		Vector2(w * 0.50, h * 0.32),
		w * 0.11,
		icon_color
	)

	draw_circle(
		Vector2(w * 0.27, h * 0.42),
		w * 0.085,
		icon_color
	)

	draw_circle(
		Vector2(w * 0.73, h * 0.42),
		w * 0.085,
		icon_color
	)

	draw_arc(
		Vector2(w * 0.50, h * 0.78),
		w * 0.25,
		PI,
		TAU,
		24,
		icon_color,
		3.0,
		true
	)

	draw_arc(
		Vector2(w * 0.25, h * 0.75),
		w * 0.16,
		PI,
		TAU,
		24,
		icon_color,
		2.5,
		true
	)

	draw_arc(
		Vector2(w * 0.75, h * 0.75),
		w * 0.16,
		PI,
		TAU,
		24,
		icon_color,
		2.5,
		true
	)


func _draw_events() -> void:
	var w := size.x
	var h := size.y

	draw_rect(
		Rect2(w * 0.20, h * 0.25, w * 0.60, h * 0.58),
		icon_color,
		false,
		3.0,
		true
	)

	draw_line(
		Vector2(w * 0.20, h * 0.42),
		Vector2(w * 0.80, h * 0.42),
		icon_color,
		3.0,
		true
	)

	draw_line(
		Vector2(w * 0.35, h * 0.16),
		Vector2(w * 0.35, h * 0.32),
		icon_color,
		3.0,
		true
	)

	draw_line(
		Vector2(w * 0.65, h * 0.16),
		Vector2(w * 0.65, h * 0.32),
		icon_color,
		3.0,
		true
	)


func _draw_vip() -> void:
	var w := size.x
	var h := size.y

	var center := Vector2(w * 0.50, h * 0.50)

	var points := PackedVector2Array()

	for i in range(10):
		var angle := -PI / 2.0 + float(i) * PI / 5.0

		var radius := w * 0.30

		if i % 2 == 1:
			radius = w * 0.13

		points.append(
			center + Vector2(
				cos(angle),
				sin(angle)
			) * radius
		)

	draw_colored_polygon(points, icon_color)


func _draw_more() -> void:
	var w := size.x
	var h := size.y

	for y in [0.30, 0.50, 0.70]:
		draw_line(
			Vector2(w * 0.22, h * y),
			Vector2(w * 0.78, h * y),
			icon_color,
			3.5,
			true
		)
func _draw_shop() -> void:
	var w := size.x
	var h := size.y

	draw_rect(
		Rect2(w * 0.22, h * 0.34, w * 0.56, h * 0.46),
		icon_color,
		false,
		3.0,
		true
	)

	draw_arc(
		Vector2(w * 0.50, h * 0.35),
		w * 0.18,
		PI,
		TAU,
		24,
		icon_color,
		3.0,
		true
	)
