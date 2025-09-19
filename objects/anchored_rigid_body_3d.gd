class_name AnchoredRigidBody3D
extends RigidBody3D

## This is a node that when moved will create an anchor to save its position
## to ensure it remains in that physical space (RigidBody3D addition).
## When the user recenters the anchor position should automatically update.
## If persistent anchors are supported, the anchor location will be stored
## and recreated the next time the application starts.
## If shared anchors are supported, the anchor will be duplicated on other
## devices in the group.

var timer : Timer
var last_position : Vector3

## Called by grab handler when user drops this object at a new location
func dropped(_dropped_by) -> void:
	if not Trashcan3D.is_in_trashcan(self):
		# Note, anchors can't be updated, so we create a new anchor
		SpatialEntitiesManager.create_spatial_anchor(global_transform, scene_file_path)

	var parent = get_parent()
	if parent is XRAnchor3D:
		# Make sure we don't collide with our new incarnation!
		_disable_collisions()
		
		# Remove the old anchor.
		SpatialEntitiesManager.remove_spatial_anchor(parent)
	else:
		# Reset position, we were grabbed from our inventory board
		transform = Transform3D()


# Run the first time our node enters our scene tree
func _ready() -> void:
	# Make sure we're frozen, assume we're in our inventory.
	freeze = true

	# Create a timer object to check when we stop moving...
	timer = Timer.new()
	timer.timeout.connect(_on_timer_timeout)
	timer.one_shot = false
	timer.wait_time = 1
	add_child(timer, false, Node.INTERNAL_MODE_BACK)


# Disable all collision shapes
func _disable_collisions() -> void:
	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = true

# Called by our anchor parent after
func _on_anchor_creation(p_new_anchor : bool) -> void:
	if p_new_anchor:
		# If this is a new anchor, we want to make sure 
		freeze = false

		# Record are last position
		last_position = global_position

		# Start our timer
		timer.start()
	else:
		# If this is an existing anchor (e.g. we are reconstructing
		# a persistent anchor), we want this frozen in place
		freeze = true


# Called when our movement timer times out.
func _on_timer_timeout():
	if (global_position - last_position).length() < 0.001:
		# Stop our timer
		timer.stop()

		# Update anchor
		var parent = get_parent()
		if parent is XRAnchor3D:
			# Make sure we don't collide with our new incarnation!
			_disable_collisions()

			# Note, anchors can't be updated, so we create a new anchor
			# (but we don't want to trigger our physics logic) 
			SpatialEntitiesManager.create_spatial_anchor(global_transform, scene_file_path, false)

			# Remove the old anchor.
			SpatialEntitiesManager.remove_spatial_anchor(parent)

	# Update our last known position
	last_position = global_position
