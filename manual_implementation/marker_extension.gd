extends Node

var qrcode_config : OpenXRSpatialCapabilityConfigurationQrCode
var aruco_config : OpenXRSpatialCapabilityConfigurationAruco
var spatial_context : RID
var discovery_result : OpenXRFutureResult
var entities : Dictionary[int, OpenXRMarkerTracker]

func _set_up_spatial_context():
	# Already set up?
	if spatial_context:
		return

	var configurations : Array

	# Add our QR code configuration
	if not OpenXRSpatialMarkerTrackingCapability.is_qrcode_supported():
		qrcode_config = OpenXRSpatialCapabilityConfigurationQrCode.new()
		configurations.push_back(qrcode_config)

	# Add our Aruco marker configuration
	if not OpenXRSpatialMarkerTrackingCapability.is_aruco_supported():
		aruco_config = OpenXRSpatialCapabilityConfigurationAruco.new()
		aruco_config.aruco_dict = OpenXRSpatialCapabilityConfigurationAruco.ARUCO_DICT_7X7_1000
		configurations.push_back(aruco_config)

	# Nothing supported?
	if configurations.is_empty():
		return

	var future_result : OpenXRFutureResult = OpenXRSpatialEntityExtension.create_spatial_context(configurations)

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
		# call our spatial context creation on start.
		openxr_interface.session_begun.connect(_set_up_spatial_context)

		# And in case it is already up and running, call it already,
		# it will exit if we've called it too early.
		_set_up_spatial_context()


func _exit_tree():
	if spatial_context:
		# Disconnect from our discovery signal.
		OpenXRSpatialEntityExtension.spatial_discovery_recommended.disconnect(_on_perform_discovery)

		# Free our spatial context, this will clean it up.
		OpenXRSpatialEntityExtension.free_spatial_context(spatial_context)
		spatial_context = RID()

	var openxr_interface : OpenXRInterface = XRServer.find_interface("OpenXR")
	if openxr_interface and openxr_interface.is_initialized():
		openxr_interface.session_begun.disconnect(_set_up_spatial_context)


func _on_perform_discovery(p_spatial_context):
	# We get this signal for all spatial contexts, so exit if this is not for us
	if p_spatial_context != spatial_context:
		return
		
	# If we currently have an ongoing discovery result, cancel it.
	if discovery_result:
		discovery_result.cancel_discovery()

	# Perform our discovery
	discovery_result = OpenXRSpatialEntityExtension.discover_spatial_entities(spatial_context, [\
		OpenXRSpatialEntityExtension.COMPONENT_TYPE_MARKER, \
		OpenXRSpatialEntityExtension.COMPONENT_TYPE_BOUNDED_2D \
	])

	# Wait for async completion.
	await discovery_result.completed

	var snapshot : RID = discovery_result.get_spatial_snapshot()
	if snapshot:
		# Process our snapshot result.
		_process_snapshot(snapshot)

		# And clean up our snapshot.
		OpenXRSpatialEntityExtension.free_spatial_snapshot(snapshot)


func _process_snapshot(p_snapshot):
	var result_data : Array

	# Make a copy of the entities we've currently found
	var org_entities : PackedInt64Array
	for entity_id in entities:
		org_entities.push_back(entity_id)

	# Always include our query result data
	var query_result_data : OpenXRSpatialQueryResultData = OpenXRSpatialQueryResultData.new()
	result_data.push_back(query_result_data)

	# And our marker component data.
	var marker_list : OpenXRSpatialComponentMarkerList = OpenXRSpatialComponentMarkerList.new()
	result_data.push_back(marker_list)

	# Add our bounded 2D component data.
	var bounded2d_list : OpenXRSpatialComponentBounded2DList = OpenXRSpatialComponentBounded2DList.new()
	result_data.push_back(bounded2d_list)

	if OpenXRSpatialEntityExtension.query_snapshot(p_snapshot, result_data):
		for i in query_result_data.get_entity_id_size():
			var entity_id = query_result_data.get_entity_id(i)
			var entity_state = query_result_data.get_entity_state(i)

			# Remove the entity from our original list
			if org_entities.has(entity_id):
				org_entities.erase(entity_id)

			if entity_state == OpenXRSpatialEntityTracker.ENTITY_TRACKING_STATE_STOPPED:
				# We're not doing update snapshots so we shouldn't get this,
				# but just to future proof:
				if entities.has(entity_id):
					var entity_tracker : OpenXRMarkerTracker = entities[entity_id]
					entity_tracker.spatial_tracking_state = entity_state
					XRServer.remove_tracker(entity_tracker)
					entities.erase(entity_id)
			else:
				var entity_tracker : OpenXRMarkerTracker
				var register_with_xr_server : bool = false
				if entities.has(entity_id):
					entity_tracker = entities[entity_id]
				else:
					entity_tracker = OpenXRMarkerTracker.new()
					entity_tracker.entity = OpenXRSpatialEntityExtension.make_spatial_entity(spatial_context, entity_id)
					entities[entity_id] = entity_tracker
					register_with_xr_server = true

				# Copy the state
				entity_tracker.spatial_tracking_state = entity_state

				# If we're tracking, we should query the rest of our components.
				if entity_state == OpenXRSpatialEntityTracker.ENTITY_TRACKING_STATE_TRACKING:
					var center_pose : Transform3D = bounded2d_list.get_center_pose(i)
					entity_tracker.set_pose("default", center_pose, Vector3(), Vector3(), XRPose.XR_TRACKING_CONFIDENCE_HIGH)

					entity_tracker.bounds_size = bounded2d_list.get_size(i)

					entity_tracker.marker_type = marker_list.get_marker_type(i)
					entity_tracker.marker_id = marker_list.get_marker_id(i)
					entity_tracker.marker_data = marker_list.get_marker_data(p_snapshot, i)
				else:
					entity_tracker.invalidate_pose("default")

				# We don't register our tracker until after we've set our initial data.
				if register_with_xr_server:
					XRServer.add_tracker(entity_tracker)

	# Any entities we've got left over, we can remove
	for entity_id in org_entities:
		var entity_tracker : OpenXRMarkerTracker = entities[entity_id]
		entity_tracker.spatial_tracking_state = OpenXRSpatialEntityTracker.ENTITY_TRACKING_STATE_STOPPED
		XRServer.remove_tracker(entity_tracker)
		entities.erase(entity_id)
