extends Node3D

# We should only be reacting on physics bodies
# that are in layer 10.

## Wrist UI is enabled
@export var enabled : bool = false

## Our users camera
@export var camera : Camera3D

## How far above the surface can our touch be to count as a button press?
@export_range(-0.1, 0.1, 0.01) var pressed_offset : float = 0.0

## Creation tool we manage
@export var collision_creation_tool : CollisionCreationTool

@onready var ui : WristUIDisplay = $SubViewport/WristUIDisplay
@onready var display_size : Vector2 = $Display.mesh.size
@onready var viewport_size : Vector2 = $SubViewport.size

class MouseInfo:
	var pos : Vector2 = Vector2()
	var is_pressed : bool = false

var last_mouse_info : MouseInfo = MouseInfo.new()

func _ready():
	ui.collision_creation_tool = collision_creation_tool

# Obtain mouse information from coordinates
func _get_mouse_info(p_position : Vector3) -> MouseInfo:
	var mouse_info : MouseInfo = MouseInfo.new()

	# convert to local
	var local_pos = $Display.global_transform.inverse() * p_position

	# Scale
	mouse_info.pos = Vector2(local_pos.x, -local_pos.y) / display_size

	# Offset
	mouse_info.pos += Vector2(0.5, 0.5)

	# Adjust to screen size
	mouse_info.pos *= viewport_size

	# Check is pressed
	mouse_info.is_pressed = (local_pos.z < pressed_offset)

	# Update cursor
	$SubViewport/WristUIDisplay/Cursor.visible = true
	$SubViewport/WristUIDisplay/Cursor.position = mouse_info.pos - Vector2(25.0, 25.0)
	$SubViewport/WristUIDisplay/Cursor.modulate = Color(0.0, 0.0, 1.0) if mouse_info.is_pressed else Color(1.0, 1.0, 1.0)

	return mouse_info


func _send_mouse_down_event(pos : Vector2):
	var mouse_event : InputEventMouseButton = InputEventMouseButton.new()
	mouse_event.button_index = MOUSE_BUTTON_LEFT
	mouse_event.pressed = true
	mouse_event.button_mask = MOUSE_BUTTON_MASK_LEFT
	mouse_event.global_position = pos
	mouse_event.position = pos
	$SubViewport.push_input(mouse_event, true)

	last_mouse_info.is_pressed = true
	last_mouse_info.pos = pos


func _send_mouse_up_event():
	var mouse_event : InputEventMouseButton = InputEventMouseButton.new()
	mouse_event.button_index = MOUSE_BUTTON_LEFT
	mouse_event.pressed = false
	mouse_event.button_mask = 0
	mouse_event.global_position = last_mouse_info.pos
	mouse_event.position = last_mouse_info.pos
	$SubViewport.push_input(mouse_event, true)

	last_mouse_info.is_pressed = false


func _send_mouse_moved_event(pos : Vector2, delta : float):
	var mouse_event : InputEventMouseMotion = InputEventMouseMotion.new()
	mouse_event.button_mask = MOUSE_BUTTON_MASK_LEFT if last_mouse_info.is_pressed else 0
	mouse_event.global_position = pos
	mouse_event.position = pos
	mouse_event.relative = pos - last_mouse_info.pos
	mouse_event.velocity = mouse_event.relative / delta
	mouse_event.screen_relative = mouse_event.relative
	mouse_event.screen_velocity = mouse_event.velocity
	$SubViewport.push_input(mouse_event, true)

	last_mouse_info.pos = pos

func _process(delta):
	if not camera:
		return

	# If we're facing away from the camera, no point in showing this.
	var dot : float = camera.global_basis.z.dot(-global_basis.z)
	visible = dot > 0.0

	if enabled and dot > 0.0:
		for body in $UIDetect.get_overlapping_bodies():
			if body is TouchUI:
				# Emulate mouse
				var mouse_info : MouseInfo = _get_mouse_info(body.global_position)

				if last_mouse_info.pos != mouse_info.pos:
					_send_mouse_moved_event(mouse_info.pos, delta)

				if mouse_info.is_pressed and not last_mouse_info.is_pressed:
					_send_mouse_down_event(mouse_info.pos)
				elif not mouse_info.is_pressed and last_mouse_info.is_pressed:
					_send_mouse_up_event()

				# We only process the first body we found, so exit!
				return

	# Nothing touching us? Send a mouse up event if needed.
	if last_mouse_info.is_pressed:
		_send_mouse_up_event()

	# Hide cursor
	$SubViewport/WristUIDisplay/Cursor.visible = false
