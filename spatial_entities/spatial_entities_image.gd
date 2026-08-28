extends XRAnchor3D

## This script handles image anchors.

var image_tracker : OpenXRImageTracker

func _ready():
	var text = "Unknown image"
	image_tracker = XRServer.get_tracker(tracker)
	if image_tracker:
		text = "Image: " + image_tracker.get_image_name()

	$Description.text = text
