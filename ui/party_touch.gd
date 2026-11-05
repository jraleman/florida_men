extends Control

## Independent solo touch contacts feed the same adapter as keyboard and pads.

signal contact_changed(finger: int, verb: String)
const LABELS := {"left": "<", "right": ">", "up": "^", "down": "v", "action": "ACT"}
var _contacts: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_set_contact(event.index, _verb_at(event.position) if event.pressed else "")
		accept_event()
	elif event is InputEventScreenDrag:
		_set_contact(event.index, _verb_at(event.position))
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_set_contact(-1, _verb_at(event.position) if event.pressed else "")
		accept_event()


## Clearing emits releases so the adapter and the drawn controls stay in sync.
func clear() -> void:
	for finger: int in _contacts.keys():
		contact_changed.emit(finger, "")
	_contacts.clear()
	queue_redraw()


func _set_contact(finger: int, verb: String) -> void:
	if verb.is_empty():
		_contacts.erase(finger)
	else:
		_contacts[finger] = verb
	contact_changed.emit(finger, verb)
	queue_redraw()


func _regions() -> Dictionary:
	var unit := minf(size.x / 5.2, size.y / 2.2)
	var left := Vector2(unit * 1.75, size.y * 0.5)
	var result := {}
	result["left"] = Rect2(left + Vector2(-unit * 1.5, -unit * 0.5), Vector2.ONE * unit)
	result["right"] = Rect2(left + Vector2(unit * 0.5, -unit * 0.5), Vector2.ONE * unit)
	result["up"] = Rect2(left + Vector2(-unit * 0.5, -unit), Vector2.ONE * unit)
	result["down"] = Rect2(left + Vector2(-unit * 0.5, 0), Vector2.ONE * unit)
	result["action"] = Rect2(Vector2(size.x - unit * 2.2, size.y * 0.5 - unit * 0.6),
		Vector2(unit * 1.7, unit * 1.2))
	return result


func _verb_at(point: Vector2) -> String:
	var regions := _regions()
	for verb: String in regions:
		if (regions[verb] as Rect2).has_point(point):
			return verb
	return ""


func _draw() -> void:
	var regions := _regions()
	for verb: String in regions:
		var rect: Rect2 = regions[verb]
		var active := _contacts.values().has(verb)
		draw_style_box(_style(active), rect.grow(-3.0))
		var text: String = LABELS[verb]
		var font := ThemeDB.fallback_font
		var font_size := maxi(28, roundi(rect.size.y * 0.34))
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, rect.get_center() + Vector2(-width * 0.5, font_size * 0.35),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("fff3d4"))


func _style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("326a77") if active else Color("183e49")
	style.border_color = Color("f6c453") if active else Color("71a6ac")
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	return style
