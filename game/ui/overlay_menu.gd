class_name OverlayMenu
extends CanvasLayer
## Full-screen dimmed overlay with a title, optional stats line and buttons (pause and end screens).

var _title: Label
var _stats: Label
var _buttons: VBoxContainer
## Called when Esc is pressed while the overlay is open.
var on_cancel: Callable


func _init() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.theme()
	add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.02, 0.04, 0.62)
	root.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	box.position = Vector2(140, -170)
	box.add_theme_constant_override(&"separation", 14)
	root.add_child(box)
	_title = UiTheme.label("", 96, UiTheme.TEXT, UiTheme.display_bold)
	box.add_child(_title)
	_stats = UiTheme.label("", 24, UiTheme.MUTED, UiTheme.mono)
	box.add_child(_stats)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	box.add_child(spacer)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override(&"separation", 8)
	box.add_child(_buttons)


func open(title: String, color: Color, stats: String, buttons: Array) -> void:
	_title.text = title
	_title.add_theme_color_override(&"font_color", color)
	_stats.text = stats
	_stats.visible = stats != ""
	for c in _buttons.get_children():
		c.queue_free()
	for b: Array in buttons:
		_buttons.add_child(UiTheme.button(b[0], b[1]))
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _buttons.get_child_count() > 0:
		(_buttons.get_child(0) as Button).grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if visible and on_cancel.is_valid() and event.is_action_pressed(&"pause"):
		on_cancel.call()
		if is_inside_tree():
			get_viewport().set_input_as_handled()


func close() -> void:
	visible = false
