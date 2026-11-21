class_name Joystick
extends Control

const RADIUS := 100.0
var _idx: int = -1
var _center: Vector2 = Vector2(160, 160)
var _knob: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed and _idx == -1:
			_idx = e.index
			_center = e.position
			_knob = Vector2.ZERO
			accept_event()
		elif not e.pressed and e.index == _idx:
			_idx = -1
			_knob = Vector2.ZERO
			Game.joy = Vector2.ZERO
			_center = Vector2(160, 160)
		queue_redraw()
	elif e is InputEventScreenDrag and e.index == _idx:
		var d: Vector2 = e.position - _center
		var v := (d / RADIUS).limit_length(1.0)
		_knob = v * RADIUS
		Game.joy = Vector2.ZERO if v.length() < 0.12 else v
		accept_event()
		queue_redraw()

func _draw() -> void:
	draw_circle(_center, RADIUS, Color(1, 1, 1, 0.07))
	draw_circle(_center + _knob, 40.0, Color(1, 1, 1, 0.40))
