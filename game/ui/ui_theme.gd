class_name UiTheme
extends RefCounted
## Stil-B interface look: Chakra Petch for display, JetBrains Mono for data. No engine defaults.

const CYAN := Color("#4de8ff")
const RED := Color("#ff3b3b")
const AMBER := Color("#ffb347")
const TEXT := Color("#e4ebf2")
const MUTED := Color("#8897a6")
const PANEL := Color(0.04, 0.07, 0.11, 0.72)

static var display: FontFile = load("res://assets/fonts/ChakraPetch-SemiBold.ttf")
static var display_bold: FontFile = load("res://assets/fonts/ChakraPetch-Bold.ttf")
static var mono: FontFile = load("res://assets/fonts/JetBrainsMono-Regular.ttf")
static var _theme: Theme


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = display
	t.default_font_size = 20
	t.set_color(&"font_color", &"Label", TEXT)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0) if state == "normal" else Color(CYAN, 0.12)
		sb.border_color = CYAN if state in ["hover", "focus", "pressed"] else Color(CYAN, 0.35)
		sb.border_width_left = 3
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		t.set_stylebox(state, &"Button", sb)
	t.set_color(&"font_color", &"Button", TEXT)
	t.set_color(&"font_hover_color", &"Button", CYAN)
	t.set_color(&"font_focus_color", &"Button", CYAN)
	t.set_color(&"font_pressed_color", &"Button", Color.WHITE)
	t.set_font_size(&"font_size", &"Button", 34)
	t.set_constant(&"h_separation", &"Button", 10)
	_theme = t
	return t


static func label(text: String, size: int, color: Color = TEXT, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	if font:
		l.add_theme_font_override(&"font", font)
	return l


static func button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func() -> void:
		if Engine.get_main_loop().root.has_node(^"Sfx"):
			Sfx.play(&"ui_click")
		on_press.call())
	return b
