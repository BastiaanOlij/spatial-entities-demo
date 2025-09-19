class_name CollisionCreationTool
extends Node3D

signal state_changed
signal finished

enum CreationState {
	DISABLED,
	START,
	SET_WIDTH,
	SET_SIZE,
	SET_HEIGHT
}

## Input on hand
@export_enum("Left","Right") var hand = 0:
	set(value):
		hand = value

		if is_inside_tree():
			_update_hand()

## Action on which to react
@export var pinch_action : String = "trigger"

## Parent node on which to create our objects
@export var create_on : Node3D

var state : CreationState = CreationState.DISABLED:
	set(value):
		if state != value:
			state = value

			if is_inside_tree():
				_update_state()

			state_changed.emit()

var _controller : XRControllerTracker

var _new_size : Vector3 = Vector3()
var _new_origin : Vector3 = Vector3()
var _new_basis : Basis = Basis()
var _plane : Plane

var _start_pos : Vector3 = Vector3()
var _was_pinched : bool = false

func _update_hand():
	if _controller:
		_controller.input_float_changed.disconnect(_on_input_float_changed)

	_controller = XRServer.get_tracker("left_hand" if hand == 0 else "right_hand")

	if _controller:
		_controller.input_float_changed.connect(_on_input_float_changed)


func _update_state():
	visible = (state != CreationState.DISABLED)
	$FloorMesh.visible = (state != CreationState.SET_HEIGHT)
	$CreationMesh.visible = (state != CreationState.START)

	match state:
		CreationState.START:
			_new_size = Vector3(0.01, 0.01, 0.01)
		CreationState.SET_HEIGHT:
			_plane = Plane(_new_basis.z, _new_origin)
		_:
			pass

func _update_orientation(p_side : Vector3):
	# Should be zero, but just in case.
	p_side.y = 0.0

	_new_basis.x = p_side.normalized()
	_new_basis.y = Vector3.UP
	_new_basis.z = _new_basis.x.cross(_new_basis.y).normalized()

func _update_creation_mesh():
	_new_origin = _start_pos
	_new_origin += _new_basis.x * _new_size.x * 0.5;
	_new_origin += _new_basis.y * _new_size.y * 0.5;
	_new_origin += _new_basis.z * _new_size.z * 0.5;
	$CreationMesh.position = _new_origin

	# We size this by scaling
	var apply_scale : Vector3 = Vector3(_new_size.x, abs(_new_size.y), abs(_new_size.z))
	$CreationMesh.basis = _new_basis * Basis.from_scale(apply_scale)

func _create_object():
	if not create_on:
		return

	# For now we just create a static body,
	# This should become an anchor of sorts so it can be reproduced.

	var new_body : StaticBody3D = StaticBody3D.new()
	var new_collision : CollisionShape3D = CollisionShape3D.new()
	var new_shape : BoxShape3D = BoxShape3D.new()
	new_shape.size = _new_size
	new_collision.shape = new_shape
	new_body.add_child(new_collision)
	new_body.transform.basis = _new_basis
	new_body.transform.origin = _new_origin
	new_body.transform = create_on.global_transform.inverse() * new_body.transform
	create_on.add_child(new_body)


func _ready():
	_update_state()


func _enter_tree():
	_update_hand()


func _exit_tree():
	if _controller:
		_controller.input_float_changed.disconnect(_on_input_float_changed)


func _on_input_float_changed(action_name : String, value : float):
	if action_name == pinch_action:
		var threshold : float = 0.7 if _was_pinched else 0.9
		var is_pinched : bool = (value > threshold)

		# Handle it on the release
		if _was_pinched and not is_pinched:
			match state:
				CreationState.START:
					if $FloorMesh.visible:
						_start_pos = $FloorMesh.global_position
						state = CreationState.SET_WIDTH
				CreationState.SET_WIDTH:
					if $FloorMesh.visible and _new_size.x > 0.01:
						state = CreationState.SET_SIZE
				CreationState.SET_SIZE:
					if $FloorMesh.visible and abs(_new_size.z) > 0.01:
						state = CreationState.SET_HEIGHT
				CreationState.SET_HEIGHT:
					if _new_size.y > 0.01:
						_create_object()

						state = CreationState.DISABLED

						finished.emit()
				_:
					return

		_was_pinched = is_pinched


func _process(_delta):
	match state:
		CreationState.START:
			var pos : Vector3 = global_position
			var forward : Vector3 = -global_basis.z
			if (forward.y < 0.0):
				pos += forward * pos.y / -forward.y;
				$FloorMesh.visible = true
				$FloorMesh.global_position = pos
			else:
				$FloorMesh.visible = false
		CreationState.SET_WIDTH:
			var pos : Vector3 = global_position
			var forward : Vector3 = -global_basis.z
			if (forward.y < 0.0):
				pos += forward * pos.y / -forward.y;
				$FloorMesh.visible = true
				$FloorMesh.global_position = pos

				var side : Vector3 = pos - _start_pos
				_new_size.x = side.length()
				if _new_size.x > 0.0:
					_update_orientation(side)
				_update_creation_mesh()
			else:
				$FloorMesh.visible = false
		CreationState.SET_SIZE:
			var pos : Vector3 = global_position
			var forward : Vector3 = -global_basis.z
			if (forward.y < 0.0):
				pos += forward * pos.y / -forward.y;
				$FloorMesh.visible = true
				$FloorMesh.global_position = pos

				# Make local to position
				pos = pos - _start_pos

				# Note _new_basis.x.y should be 0, and is normalized, so we can simplify this!
				_new_size.z = (_new_basis.x.x * pos.z) - (_new_basis.x.z * pos.x)

				_update_creation_mesh()
			else:
				$FloorMesh.visible = false
		CreationState.SET_HEIGHT:
				var pos = _plane.intersects_ray(global_position, -global_basis.z)
				if pos:
					_new_size.y = max(pos.y, 0.0)
					_update_creation_mesh()
		_:
			return
