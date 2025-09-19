extends XRNode3D

## Code in this class will select the correct tracker based on what is active.

## Signal that our tracker and/or pose have changed
signal changed

## Use for our left or right hand
@export_enum("Left","Right") var hand = 0

## Specify a child node that we adjust the transform of if needed.
@export var adjust_node : Node3D

func _process(_delta):
	# First see if our hand tracker is tracking
	var tracker_name = "/user/hand_tracker/left" if hand == 0 else "/user/hand_tracker/right"
	var hand_tracker : XRHandTracker = XRServer.get_tracker(tracker_name)
	if hand_tracker and hand_tracker.has_tracking_data:
		if tracker != tracker_name:
			tracker = tracker_name
			pose = "default"

			if adjust_node:
				adjust_node.transform = Transform3D()

			changed.emit()

		return

	# Check if our controller tracker is tracking
	tracker_name = "left_hand" if hand == 0 else "right_hand"
	var controller_tracker : XRPositionalTracker = XRServer.get_tracker(tracker_name)
	if controller_tracker:
		# Check our palm pose first
		var pose_name = "palm_pose"
		var adj_transform : Transform3D = Transform3D()
		var xr_pose : XRPose = controller_tracker.get_pose(pose_name)
		if xr_pose and xr_pose.tracking_confidence != XRPose.TrackingConfidence.XR_TRACKING_CONFIDENCE_NONE:
			# Offset palm position.
			adj_transform.origin = Vector3(-0.015 if hand == 0 else 0.015, 0.0, 0.04)
		else:
			# Just use grip regardless of tracking confidence.
			# This pose should always exist,
			# if it is not tracking, we're not tracking this hand.
			pose_name = "grip"

			# Grip is always rotated by 45 degrees it seems, so rotate it back. (TODO get correct values)
			adj_transform = adj_transform.rotated(Vector3.LEFT, deg_to_rad(45.0))

			# And offset it. (TODO get correct values)
			adj_transform.origin = Vector3(0.0 if hand == 0 else 0.0, 0.0, 0.0)

		if tracker != tracker_name or pose != pose_name:
			tracker = tracker_name
			pose = pose_name

			if adjust_node:
				adjust_node.transform = adj_transform

			changed.emit()
