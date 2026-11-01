class_name UiKit
extends RefCounted
## Shared UI look: rounded panels, chunky buttons, star drawing.

const BG := Color("#1d3557")
const ACCENT := Color("#ff6b35")
const GOOD := Color("#06d6a0")
const BAD := Color("#ef476f")
const GOLD := Color("#ffd166")

static var _theme: Theme


static func theme() -> Theme:
	if _theme:
		return _theme
	_theme = Theme.new()
	_theme.default_font_size = 22
	var b := style(ACCENT, 14)
	b.content_margin_left = 24
	b.content_margin_right = 24
	b.content_margin_top = 10
	b.content_margin_bottom = 10
	var bh := b.duplicate()
	bh.bg_color = ACCENT.lightened(0.2)
	bh.border_width_bottom = 0
	var bf := bh.duplicate()
	bf.border_color = Color.WHITE
	bf.set_border_width_all(4)
	var bd := b.duplicate()
	bd.bg_color = Color("#6c757d")
	_theme.set_stylebox("normal", "Button", b)
	_theme.set_stylebox("hover", "Button", bh)
	_theme.set_stylebox("pressed", "Button", bh)
	_theme.set_stylebox("focus", "Button", bf)
	_theme.set_stylebox("disabled", "Button", bd)
	_theme.set_font_size("font_size", "Button", 26)
	_theme.set_color("font_color", "Button", Color.WHITE)
	_theme.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.6))
	_theme.set_constant("outline_size", "Label", 6)
	_theme.set_stylebox("panel", "PanelContainer", style(Color(0.11, 0.21, 0.34, 0.92), 18))
	return _theme


static func style(c: Color, radius := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.border_width_bottom = 4
	s.border_color = c.darkened(0.35)
	return s


static func label(text: String, size := 22, c := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	return l


static func button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	b.pressed.connect(func(): UiKit.click())
	return b


static var click_player: AudioStreamPlayer


static func click() -> void:
	if click_player and is_instance_valid(click_player):
		click_player.play()


class Stars extends Control:
	var stars := 5
	var size_px := 22.0

	func _init(n: int = 5, s: float = 22.0) -> void:
		stars = n
		size_px = s
		custom_minimum_size = Vector2(s * 5.4, s)

	func _draw() -> void:
		for i in 5:
			var c := Vector2(size_px * 0.5 + i * size_px * 1.08, size_px * 0.5)
			var pts := PackedVector2Array()
			for k in 10:
				var r := size_px * (0.5 if k % 2 == 0 else 0.22)
				var a := -PI / 2 + k * PI / 5
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(pts, UiKit.GOLD if i < stars else Color(1, 1, 1, 0.25))
