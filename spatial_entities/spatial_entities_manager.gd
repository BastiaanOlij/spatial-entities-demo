## Spatial entity manager handles adding subscenes as new spatial entities are discovered.
## Right now this is implemented on the assumption that we automatically discover entities
## in our OpenXR implementation. We may change way from this in which case we'll add info
## about our query parameters here and select nodes based on that.
class_name SpatialEntitiesManager
extends Node3D

#region Signals
## Signals a new spatial entity node was added.
signal added_spatial_entity(node: XRNode3D)

## Signals a spatial entity node is about to be removed.
signal removed_spatial_entity(node: XRNode3D)
#endregion

#region Export variables
## Scene to instantiate for spatial anchor entities.
@export var spatial_anchor_scene: PackedScene

## Scene to instantiate for plane tracking spatial entities.
@export var plane_tracker_scene: PackedScene

## Scene to instantiate for mark tracking spatial entities.
@export var marker_tracker_scene: PackedScene
#endregion

#region Private variables
# Our current active spatial entities manager (last one instantiated)
static var _current_manager: SpatialEntitiesManager

# Trackers we manage nodes for.
var _managed_nodes: Dictionary[XRTracker, XRAnchor3D]
#endregion

#region Public methods
## Create a new spatial anchor with the associated child scene
## If persistent anchors are supported, this will be created as a persistent node
## and we will store the child scene path with the anchor's UUID for future recreation.
static func create_spatial_anchor(p_transform : Transform3D, p_child_scene_path : String, p_new_anchor : bool = true) -> void:
	# Do we have anchor support?
	if not OpenXRSpatialAnchorCapability.is_spatial_anchor_supported():
		push_error("Spatial anchors are not supported or enabled on this device!")
		return

	if not _current_manager:
		push_error("No current spatial entities manager set!")
		return

	# Adjust our transform to local space
	var t : Transform3D = _current_manager.global_transform.inverse() * p_transform

	# Create anchor on our current manager.
	var new_anchor = OpenXRSpatialAnchorCapability.create_new_anchor(t, RID())
	if not new_anchor:
		push_error("Couldn't create an anchor for %s." % [ p_child_scene_path ])
		return

	# Creating a new anchor should have resulted in an XRAnchor being added to the scene
	var anchor_scene = _current_manager.get_tracked_scene(new_anchor)
	if not anchor_scene:
		push_error("Couldn't locate anchor scene for %s, has the manager been configured with an applicable anchor scene?" % [ new_anchor.name ])
		return
	if not anchor_scene is OpenXRSpatialAnchor3D:
		push_error("Anchor scene for %s is not an OpenXRSpatialAnchor3D scene, has the manager been configured with an applicable anchor scene?" % [ new_anchor.name ])
		return

	anchor_scene.set_child_scene(p_child_scene_path, p_new_anchor)


## Removes this spatial anchor from our scene.
## If the spatial anchor is persistent, the associated UUID will be cleared.
static func remove_spatial_anchor(p_anchor : XRAnchor3D) -> void:
	# Do we have anchor support?
	if not OpenXRSpatialAnchorCapability.is_spatial_anchor_supported():
		push_error("Spatial anchors are not supported on this device!")
		return

	var tracker : XRTracker = XRServer.get_tracker(p_anchor.tracker)
	if tracker and tracker is OpenXRAnchorTracker:
		var anchor_tracker : OpenXRAnchorTracker = tracker
		if anchor_tracker.has_uuid() and OpenXRSpatialAnchorCapability.is_spatial_persistence_supported():
			# If we have a UUID we should first make the anchor unpersistent
			# and then remove it on its callback.
			if SpatialUuidDb:
				SpatialUuidDb.remove_uuid(anchor_tracker.uuid)

			var future_result = OpenXRSpatialAnchorCapability.make_anchor_unpersistent(anchor_tracker)
			var success : bool = await future_result.completed

			if success:
				# Our tracker is now no longer persistent, we can remove it.
				OpenXRSpatialAnchorCapability.remove_anchor(anchor_tracker)
		else:
			# Otherwise we can just remove it.
			# This will remove it from the XRServer, which in turn will trigger cleaning up our node.
			OpenXRSpatialAnchorCapability.remove_anchor(tracker)

## Retrieve the scene we've added for a given tracker (if any).
func get_tracked_scene(p_tracker : XRTracker) -> XRNode3D:
	for node in get_children():
		if node is XRNode3D and node.tracker == p_tracker.name:
			return node

	return null
#endregion


#region Build in private functions
# Enter tree is called whenever our node is added into our scene.
func _enter_tree():
	# This is now our current manager
	_current_manager = self

	# Connect to signals that inform us about tracker changes.
	XRServer.tracker_added.connect(_on_tracker_added)
	XRServer.tracker_updated.connect(_on_tracker_updated)
	XRServer.tracker_removed.connect(_on_tracker_removed)

	# Set up existing trackers.
	var trackers : Dictionary = XRServer.get_trackers(XRServer.TRACKER_ANCHOR)
	for tracker_name in trackers:
		var tracker : XRTracker = trackers[tracker_name]
		if tracker:
			_add_tracker(tracker)


# Exit tree is called whenever our node is removed from out scene.
func _exit_tree():
	# If we are the current manager, bye!
	if _current_manager == self:
		_current_manager = null

	# Clean up our signals.
	XRServer.tracker_added.disconnect(_on_tracker_added)
	XRServer.tracker_updated.disconnect(_on_tracker_updated)
	XRServer.tracker_removed.disconnect(_on_tracker_removed)

	# Clean up
	for tracker in _managed_nodes:
		removed_spatial_entity.emit(_managed_nodes[tracker])
		remove_child(_managed_nodes[tracker])
		_managed_nodes[tracker].queue_free()
	_managed_nodes.clear()
#endregion

#region Private methods
# See if this tracker should be managed by us and add it
func _add_tracker(tracker : XRTracker):
	var new_node : XRAnchor3D

	if _managed_nodes.has(tracker):
		# Already being managed by us!
		return

	if tracker is OpenXRAnchorTracker:
		# Note: Generally spatial anchors are controlled by the developer and
		# are unlikely to be handled by our manager.
		# But just for completion we'll add it in.
		if spatial_anchor_scene:
			var new_scene = spatial_anchor_scene.instantiate()
			if new_scene is XRAnchor3D:
				new_node = new_scene
			else:
				push_error("Spatial anchor scene doesn't have an XRAnchor3D as a root node and can't be used!")
				new_scene.free()
	elif tracker is OpenXRPlaneTracker:
		if plane_tracker_scene:
			var new_scene = plane_tracker_scene.instantiate()
			if new_scene is XRAnchor3D:
				new_node = new_scene
			else:
				push_error("Plane tracking scene doesn't have an XRAnchor3D as a root node and can't be used!")
				new_scene.free()
	elif tracker is OpenXRMarkerTracker:
		if marker_tracker_scene:
			var new_scene = marker_tracker_scene.instantiate()
			if new_scene is XRAnchor3D:
				new_node = new_scene
			else:
				push_error("Marker tracking scene doesn't have an XRAnchor3D as a root node and can't be used!")
				new_scene.free()
	elif tracker is OpenXRSpatialEntityTracker:
		# Type of spatial entity tracker we're not supporting?
		push_warning("OpenXR Spatial Entities: Unsupported anchor tracker " + tracker.get_name() + " of type " + tracker.get_class())
	else:
		# Not a type managed by us!
		return

	if not new_node:
		# No scene defined or able to be instantiated? We're done!
		return

	# Set up and add to our scene.
	new_node.tracker = tracker.name
	new_node.pose = "default"
	_managed_nodes[tracker] = new_node
	add_child(new_node)

	added_spatial_entity.emit(new_node)
#endregion

#region Signal handling
# A new tracker was added to our XRServer.
func _on_tracker_added(tracker_name: StringName, type: int):
	print("Added tracker ", tracker_name)
	if type == XRServer.TRACKER_ANCHOR:
		var tracker : XRTracker = XRServer.get_tracker(tracker_name)
		if tracker:
			_add_tracker(tracker)


# A tracked managed by XRServer was changed.
func _on_tracker_updated(_tracker_name: StringName, _type: int):
	# For now we ignore this, there aren't changes here we need to react
	# to and the instanced scene can react to this itself if needed.
	pass


# A tracker was removed from our XRServer.
func _on_tracker_removed(tracker_name: StringName, type: int):
	if type == XRServer.TRACKER_ANCHOR:
		var tracker : XRTracker = XRServer.get_tracker(tracker_name)
		if _managed_nodes.has(tracker):
			# We emit this right before we remove it!
			removed_spatial_entity.emit(_managed_nodes[tracker])

			# Remove the node.
			remove_child(_managed_nodes[tracker])

			# Queue free the node.
			_managed_nodes[tracker].queue_free()

			# And remove from our managed nodes.
			_managed_nodes.erase(tracker)
#endregion
