class_name OpenXRSpatialAnchor3D
extends XRAnchor3D

var anchor_tracker : OpenXRAnchorTracker
var child_scene : Node
var made_persistent : bool = false

func _get_max_y(p_parent_node : Node3D, p_base_transform : Transform3D) -> float:
	var max_y : float = 0.0

	for child_node in p_parent_node.get_children():
		var t : Transform3D = p_base_transform * child_node.transform

		if child_node is VisualInstance3D:
			var child_aabb : AABB = child_node.get_aabb()

			# Get highest corner
			for i in range(8):
				var p = t * child_aabb.get_endpoint(i)
				max_y = maxf(max_y, p.y + 0.01)

		# Check our children
		max_y = maxf(max_y, _get_max_y(child_node, t))

	return max_y

## Set our child scene for this anchor
func set_child_scene(p_child_scene_path : String, p_new_anchor : bool = true) -> void:
	if child_scene:
		push_warning("A scene is already set for this anchor! It will be removed.")
		remove_child(child_scene)
		child_scene.queue_free()
		child_scene = null
		pass

	# Q: make this background loaded through our resource loader?
	# Also maybe add some caching?
	var packed_scene : PackedScene = load(p_child_scene_path)
	if not packed_scene:
		push_error("Couldn't load " + p_child_scene_path)
		return

	child_scene = packed_scene.instantiate()
	if not child_scene:
		push_error("Couldn't instantiate " + p_child_scene_path)
		return

	add_child(child_scene)

	# If we have a _on_anchor_creation method, call it!
	if child_scene.has_method("_on_anchor_creation"):
		child_scene._on_anchor_creation(p_new_anchor)

	# Position our description label
	$Description.position.y = _get_max_y(child_scene, child_scene.transform)

func _on_spatial_tracking_state_changed(new_state) -> void:
	# We should only show our anchor if it's being tracked
	visible = (new_state == OpenXRSpatialEntityTracker.ENTITY_TRACKING_STATE_TRACKING)

	# First time getting tracked status while not persistent, make it persistent.
	if new_state == OpenXRSpatialEntityTracker.ENTITY_TRACKING_STATE_TRACKING and not made_persistent:
		# Only attempt to do this once
		made_persistent = true

		# This warning is optional if you don't want to rely on persistence.
		if not OpenXRSpatialAnchorCapability.is_spatial_persistence_supported():
			push_warning("Persistent spatial anchors are not supported on this device!")
			return

		# Make this persistent, this will callback UUID changed on the anchor,
		# we can then store our scene path which we've already applied to our
		# tracked scene.
		OpenXRSpatialAnchorCapability.persist_anchor(anchor_tracker)

func _on_uuid_changed() -> void:
	_update_description()

	if anchor_tracker.uuid != "":
		made_persistent = true

		print_verbose("Anchor UUID set to: ", anchor_tracker.uuid)

		if not SpatialUuidDb:
			push_error("Spatial UUID DB is not setup as a singleton!")
			return

		if child_scene:
			# If we already have a subscene, save that with the UUID.
			if not SpatialUuidDb.get_scene_path(anchor_tracker.uuid).is_empty():
				push_warning("A scene was already cached for anchor " + anchor_tracker.uuid + ", it will be overwritten!")
				pass

			# Store the path to the scene we're showing so we can restore it.
			SpatialUuidDb.set_scene_path(anchor_tracker.uuid, child_scene.scene_file_path)
		else:
			# If we do not, look up the UUID in our stored cache.
			var scene_path :String = SpatialUuidDb.get_scene_path(anchor_tracker.uuid)
			if scene_path.is_empty():
				# Give a warning that we don't have a scene file stored for this UUID.
				push_warning("Unknown UUID given, can't determine child scene.")
				
				# Load a default scene so we can at least see something.
				set_child_scene("res://objects/unknown_entity.tscn", false)
				return

			set_child_scene(scene_path, false)


func _update_description():
	if anchor_tracker:
		var text : String = anchor_tracker.name 

		if anchor_tracker.uuid != "":
			text = text + "\n" + anchor_tracker.uuid

		$Description.text = text
	else:
		$Description.text = "No tracker"

func _ready():
	anchor_tracker = XRServer.get_tracker(tracker)
	if anchor_tracker:
		# Always get our UUID first, we should have it if it's an existing persistent anchor.
		_on_uuid_changed()

		# Process our initial tracking state.
		_on_spatial_tracking_state_changed(anchor_tracker.spatial_tracking_state)

		# Make sure we see when the status changes so we can trigger make permanent.
		anchor_tracker.spatial_tracking_state_changed.connect(_on_spatial_tracking_state_changed)

		# Make sure we see it when the UUID is changed.
		# This is potentially created async
		anchor_tracker.uuid_changed.connect(_on_uuid_changed)
