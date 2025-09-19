extends Node

var persistence_context : RID
var spatial_context : RID
var discovery_result : OpenXRFutureResult
var entities : Dictionary[int, OpenXRAnchorTracker]

func _set_up_persistence_context():
	# Already set up?
	if persistence_context:
		# Check our spatial context
		_set_up_spatial_context()
		return

	# Not supported or we're not yet ready? Just exit.
	if not OpenXRSpatialAnchorCapability.is_spatial_anchor_supported():
		return

	# If we can't use a persistence store, just create our spatial context without one.
	if not OpenXRSpatialAnchorCapability.is_spatial_persistence_supported():
		_set_up_spatial_context()
		return

	var store : int = 0
	if OpenXRSpatialAnchorCapability.is_persistence_scope_supported(OpenXRSpatialAnchorCapability.PERSISTENCE_SCOPE_LOCAL_ANCHORS):
		store = OpenXRSpatialAnchorCapability.PERSISTENCE_SCOPE_LOCAL_ANCHORS
	elif OpenXRSpatialAnchorCapability.is_persistence_scope_supported(OpenXRSpatialAnchorCapability.PERSISTENCE_SCOPE_SYSTEM_MANAGED):
		store = OpenXRSpatialAnchorCapability.PERSISTENCE_SCOPE_SYSTEM_MANAGED
	else:
		# Don't have a known persistence store, report and just setup without it.
		push_error("No known persistence store is supported.")
		_set_up_spatial_context()
		return

	# Create our persistence store
	var future_result : OpenXRFutureResult = OpenXRSpatialAnchorCapability.create_persistence_context(store)
	if not future_result:
		# Couldn't create persistence store? Just setup without it.
		_set_up_spatial_context()
		return

	# Now wait for our process to complete.
	await future_result.completed

	# Get our result
	persistence_context = future_result.get_result_value()
	if persistence_context:
		# Now set up our spatial context.
		_set_up_spatial_context()


func _set_up_spatial_context():
	# Already set up?
	if spatial_context:
		return

	# Not supported or we're not yet set up.
	if not OpenXRSpatialAnchorCapability.is_spatial_anchor_supported():
		return

	# Create our anchor capability.
	var anchor_capability : OpenXRSpatialCapabilityConfigurationAnchor = OpenXRSpatialCapabilityConfigurationAnchor.new()

	# And set up our persistence configuration object (if needed).
	var persistence_config : OpenXRSpatialContextPersistenceConfig
	if persistence_context:
		persistence_config = OpenXRSpatialContextPersistenceConfig.new()
		persistence_config.add_persistence_context(persistence_context)

	var future_result : OpenXRFutureResult = OpenXRSpatialEntityExtension.create_spatial_context([ anchor_capability ], persistence_config)

	# Wait for async completion.
	await future_result.completed

	# Obtain our result.
	spatial_context = future_result.get_spatial_context()
	if spatial_context:
		# Connect to our discovery signal.
		OpenXRSpatialEntityExtension.spatial_discovery_recommended.connect(_on_perform_discovery)

		# Perform our initial discovery.
		_on_perform_discovery(spatial_context)


func _enter_tree():
	var openxr_interface : OpenXRInterface = XRServer.find_interface("OpenXR")
	if openxr_interface and openxr_interface.is_initialized():
		# Just in case our session hasn't started yet,
		# call our context creation on start beginning with our persistence store.
		openxr_interface.session_begun.connect(_set_up_persistence_context)

		# And in case it is already up and running, call it already,
		# it will exit if we've called it too early.
		_set_up_persistence_context()


func _exit_tree():
	if spatial_context:
		# Disconnect from our discovery signal.
		OpenXRSpatialEntityExtension.spatial_discovery_recommended.disconnect(_on_perform_discovery)

		# Free our spatial context, this will clean it up.
		OpenXRSpatialEntityExtension.free_spatial_context(spatial_context)
		spatial_context = RID()

	if persistence_context:
		# Free our persistence store...
		OpenXRSpatialAnchorCapability.free_persistence_context(persistence_context)
		persistence_context = RID()

	var openxr_interface : OpenXRInterface = XRServer.find_interface("OpenXR")
	if openxr_interface and openxr_interface.is_initialized():
		openxr_interface.session_begun.disconnect(_set_up_persistence_context)


func _on_perform_discovery(p_spatial_context):
	# We get this signal for all spatial contexts, so exit if this is not for us
	if p_spatial_context != spatial_context:
		return

	# Skip this if we don't have a persistence context
	if not persistence_context:
		return

	# If we currently have an ongoing discovery result, cancel it.
	if discovery_result:
		discovery_result.cancel_discovery()

	# Perform our discovery.
	discovery_result = OpenXRSpatialEntityExtension.discover_spatial_entities(spatial_context, [ \
		OpenXRSpatialEntityExtension.COMPONENT_TYPE_ANCHOR, \
		OpenXRSpatialEntityExtension.COMPONENT_TYPE_PERSISTENCE \
	])

	# Wait for async completion.
	await discovery_result.completed

	var snapshot : RID = discovery_result.get_spatial_snapshot()
	if snapshot:
		# Process our snapshot result.
		_process_snapshot(snapshot, true)

		# And clean up our snapshot.
		OpenXRSpatialEntityExtension.free_spatial_snapshot(snapshot)


func _process(_delta):
	if not spatial_context:
		return

	var entity_rids : Array[RID]
	for entity_id in entities:
		entity_rids.push_back(entities[entity_id].entity)

	# We just want our anchor component here.
	var snapshot : RID = OpenXRSpatialEntityExtension.update_spatial_entities(spatial_context, entity_rids, [ \
		OpenXRSpatialEntityExtension.COMPONENT_TYPE_ANCHOR, \
	])
	if snapshot:
		# Process our snapshot here...
		_process_snapshot(snapshot, false)

		# And clean up our snapshot.
		OpenXRSpatialEntityExtension.free_spatial_snapshot(snapshot)


func _process_snapshot(p_snapshot, p_get_uuids):
	var result_data : Array
	
	# Always include our query result data
	var query_result_data : OpenXRSpatialQueryResultData = OpenXRSpatialQueryResultData.new()
	result_data.push_back(query_result_data)

	# Add in our anchor component data
	var anchor_list : OpenXRSpatialComponentAnchorList = OpenXRSpatialComponentAnchorList.new()
	result_data.push_back(anchor_list)

	# And our persistent component data
	var persistent_list : OpenXRSpatialComponentPersistenceList
	if p_get_uuids:
		# Only add this when we need it
		persistent_list = OpenXRSpatialComponentPersistenceList.new()
		result_data.push_back(persistent_list)

	if OpenXRSpatialEntityExtension.query_snapshot(p_snapshot, result_data):
		for i in query_result_data.get_entity_id_size():
			var entity_id = query_result_data.get_entity_id(i)
			var entity_state = query_result_data.get_entity_state(i)

			if entity_state == OpenXRSpatialEntityTracker.ENTITY_TRACKING_STATE_STOPPED:
				# This state should only appear when doing an update snapshot
				# and tells us this entity is no longer tracked.
				# We thus remove it from our dictionary which should result
				# in the entity being cleaned up.
				if entities.has(entity_id):
					var entity_tracker : OpenXRAnchorTracker = entities[entity_id]
					entity_tracker.spatial_tracking_state = entity_state
					XRServer.remove_tracker(entity_tracker)
					entities.erase(entity_id)
			else:
				var entity_tracker : OpenXRAnchorTracker
				var register_with_xr_server : bool = false
				if entities.has(entity_id):
					entity_tracker = entities[entity_id]
				else:
					entity_tracker = OpenXRAnchorTracker.new()
					entity_tracker.entity = OpenXRSpatialEntityExtension.make_spatial_entity(spatial_context, entity_id)
					entities[entity_id] = entity_tracker
					register_with_xr_server = true

				# Copy the state.
				entity_tracker.spatial_tracking_state = entity_state

				# If we're tracking, we update our position.
				if entity_state == OpenXRSpatialEntityTracker.ENTITY_TRACKING_STATE_TRACKING:
					var anchor_transform = anchor_list.get_entity_pose(i)
					entity_tracker.set_pose("default", anchor_transform, Vector3(), Vector3(), XRPose.XR_TRACKING_CONFIDENCE_HIGH)
				else:
					entity_tracker.invalidate_pose("default")

				# But persistence data is a big exception, it can be provided even if we're not tracking.
				if p_get_uuids:
					var persistent_state = persistent_list.get_persistent_state(i)
					if persistent_state == 1:
						entity_tracker.uuid = persistent_list.get_persistent_uuid(i)

				# We don't register our tracker until after we've set our initial data.
				if register_with_xr_server:
					XRServer.add_tracker(entity_tracker)
