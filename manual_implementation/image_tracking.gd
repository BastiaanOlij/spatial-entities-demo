extends Node

@export var tracking_images: Array[Image]

var openxr_interface : OpenXRInterface
var image_database: RID

func _set_up_image_tracking():
	# No OpenXR interface
	if not openxr_interface:
		return

	# This will be false if our session hasn't started yet.
	if not OpenXRSpatialImageTrackingCapability.is_supported():
		return

	# Already created?
	if image_database:
		return

	if tracking_images.is_empty():
		if !Engine.is_editor_hint():
			push_warning("No tracking images were setup")
		return

	image_database = OpenXRSpatialImageTrackingCapability.image_database_create()
	if image_database:
		var i: int = 1
		for tracking_image in tracking_images:
			OpenXRSpatialImageTrackingCapability.image_database_add(image_database, "image-%d" % [ i ], tracking_image, 0.1, false)
			i += 1

		OpenXRSpatialImageTrackingCapability.image_database_submit(image_database, _on_image_database_submitted)


func _on_image_database_submitted(p_image_database):
	if p_image_database != image_database:
		# Huh? This shouldn't happen
		push_warning("Image database RID does not match!")
		return

	print("Starting image tracking...")
	OpenXRSpatialImageTrackingCapability.start_built_in_tracking(p_image_database)


func _enter_tree():
	openxr_interface = XRServer.find_interface("OpenXR")
	if openxr_interface and openxr_interface.is_initialized():
		# Just in case our session hasn't started yet,
		# call our context creation on start beginning with our persistence store.
		openxr_interface.session_begun.connect(_set_up_image_tracking)

		# And in case it is already up and running, call it already,
		# it will exit if we've called it too early.
		_set_up_image_tracking()


func _exit_tree():
	if image_database:
		OpenXRSpatialImageTrackingCapability.image_database_free(image_database)
		image_database = RID()

	if openxr_interface and openxr_interface.is_initialized():
		openxr_interface.session_begun.disconnect(_set_up_image_tracking)
		openxr_interface = null
