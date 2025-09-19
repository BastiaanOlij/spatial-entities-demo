@tool
extends Area3D

## This is a very simple and straight forward grab and move script.
## The player will be able to move any AnimatedBody3D or RigidBody3D around.

#region Export variables
## Is our grab function enabled?
@export var enabled : bool = true:
	set(value):
		# Note, disabling just stops us from grabbing stuff.
		# We still want our area to keep working...
		enabled = value

		# If we're disabled, ignore grab
		if not enabled and was_grab:
			was_grab = false

		# Handle releasing held object if not enabled
		if not enabled and held_object:
			drop_held_object()

## Object detection range
@export var grab_range : float = 0.05:
	set(value):
		grab_range = value
		if is_inside_tree():
			_update_grab_range()


## Hand
@export_enum("left","right") var hand : int = 0:
	set(value):
		hand = value
		if is_inside_tree():
			_update_hand()

## Action 
@export var action = "grip"
#endregion


#region Private variables
# Static array of held objects
static var held_objects : Array[PhysicsBody3D]

# Our action map hand controller
var tracker : XRControllerTracker

# Previous grab value, we default to true so we don't auto grab stuff at init
var was_grab : bool = true

# Our held object
var held_object : PhysicsBody3D

# Offset between hand and object when picked up
var pickup_offset : Transform3D

# If we've picked up a RigidBody3D, was it frozen when we picked it up?
var was_frozen : bool
#endregion


#region Public functions
## Returns the currently held object (or null if nothing is held)
func get_held_object() -> PhysicsBody3D:
	return held_object


## Drop the object we are currently holding
func drop_held_object() -> void:
	if not held_object:
		return

	# Remove from our held objects array
	held_objects.erase(held_object)

	# If RigidBody3D, reset freeze!
	if held_object is RigidBody3D:
		held_object.freeze = was_frozen

	# Call dropped on held object if method exists.
	if held_object.has_method("dropped"):
		held_object.dropped(self)

	# Finally clear held object
	held_object = null


## Pickup this object
func pickup_object(p_object : PhysicsBody3D) -> void:
	# We can't pickup something already held
	if held_objects.has(p_object):
		return

	# Drop anything we're holding right now
	if held_object:
		drop_held_object()

	held_object = p_object
	if not held_object:
		return

	# Record that we're holding it now
	held_objects.push_back(held_object)

	# Record deltas
	pickup_offset = global_transform.inverse() * held_object.global_transform

	# If RigidBody3D, freeze!
	if held_object is RigidBody3D:
		was_frozen = held_object.freeze
		held_object.freeze = true

	# Call grabbed on held object if method exists.
	if held_object.has_method("grabbed"):
		held_object.grabbed(self)
#endregion


#region Misc private functions
# Update our range setting on the area node
func _update_grab_range() -> void:
	var shape : SphereShape3D = $CollisionShape3D.shape
	if shape:
		shape.radius = grab_range


# Update our tracker and subscribe to our signals
func _update_hand() -> void:
	if tracker:
		_unsubscribe_tracker()

	tracker = XRServer.get_tracker("left_hand" if hand == 0 else "right_hand")
	if tracker:
		print("yeah tracker!")
		_subscribe_tracker()
	else:
		push_error("No tracker for hand %d" % [ hand ])


# Subscribe to our input signals
func _subscribe_tracker() -> void:
	if tracker:
		tracker.input_float_changed.connect(_on_input_float_changed)


# Unsubscribe from our input signals
func _unsubscribe_tracker() -> void:
	if tracker:
		tracker.input_float_changed.disconnect(_on_input_float_changed)

# Get our closest object
func _get_nearest_object() -> PhysicsBody3D:
	var nearest_body : PhysicsBody3D
	var nearest_distance : float = 99999.99
	for body in get_overlapping_bodies():
		if !held_objects.has(body):
			var distance = (body.global_position - global_position).length_squared()
			if body is PhysicsBody3D and distance < nearest_distance:
				nearest_distance = distance
				nearest_body = body

	return nearest_body


# Removes the pitch from the provided basis
func _remove_pitch(p_basis : Basis) -> Basis:
	return Basis.looking_at(p_basis.z, Vector3.UP, true)


func _rotate_and_collide(p_node : Node3D, p_dest_basis : Basis) -> void:
	var last_basis : Basis = p_node.global_basis

	# TODO test collisions along rotation in steps,
	# update last_basis if there are no collisions

	# For now pretend we can rotate and just use destination basis
	last_basis = p_dest_basis

	# Use are last valid basis
	p_node.global_basis = last_basis

#endregion


#region Godot build in functions
# Run the first time our node enters our scene tree
func _ready() -> void:
	# Make sure we only run our logic when our game isn't pauzed (e.g. headset is off).
	process_mode = Node.PROCESS_MODE_PAUSABLE


# Run when our node is added to our scene tree
func _enter_tree() -> void:
	_update_grab_range()
	_update_hand()


# Run when our node is removed to our scene tree
func _exit_tree() -> void:
	if tracker:
		_unsubscribe_tracker()


# Called every physics frame
func _physics_process(_delta) -> void:
	# Are we holding an object? Then we attempt to move it.
	if held_object:
		if held_object is AnimatableBody3D or held_object is RigidBody3D:
			var target_transform : Transform3D = global_transform * pickup_offset

			# Attempt to move object to our destination.
			var move : Vector3 = target_transform.origin - held_object.global_position
			held_object.move_and_collide(move)

			# Attempt to rotate it
			_rotate_and_collide(held_object, _remove_pitch(target_transform.basis))
		elif held_object is StaticBody3D:
			# Ignore this for now, we can't move static bodies
			pass
		pass
#endregion


#region Signals
func _on_input_float_changed(p_action : String, p_value : float) -> void:
	if not enabled:
		# Ignore
		return

	if p_action == action:
		# Do our own threshold logic!
		var threshold = 0.25 if was_grab else 0.65
		var grab = (p_value > threshold)
		if grab != was_grab:
			was_grab = grab

			if grab:
				if not held_object:
					var nearest_object : PhysicsBody3D = _get_nearest_object()
					if nearest_object:
						pickup_object(nearest_object)
			elif held_object:
				drop_held_object()
#endregion
