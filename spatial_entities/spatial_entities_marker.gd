extends XRAnchor3D

## This script handles marker anchors.

var marker_tracker : OpenXRMarkerTracker

func _ready():
	var text = "Unknown marker"
	marker_tracker = XRServer.get_tracker(tracker)
	if marker_tracker:
		match marker_tracker.marker_type:
			OpenXRSpatialComponentMarkerList.MARKER_TYPE_QRCODE:
				text = "QR code marker"

				var data : Variant = marker_tracker.get_marker_data()
				if typeof(data) == TYPE_STRING:
					text += "\nData: " + data
				elif typeof(data) == TYPE_PACKED_BYTE_ARRAY:
					text += "\nData: " + data.hex_encode()
			OpenXRSpatialComponentMarkerList.MARKER_TYPE_MICRO_QRCODE:
				text = "Micro QR code marker"

				var data = marker_tracker.get_marker_data()
				if data.type_of() == TYPE_STRING:
					text += "\nData: " + data
				elif data.type_of() == TYPE_PACKED_BYTE_ARRAY:
					text += "\nData: " + data.hex_encode()
			OpenXRSpatialComponentMarkerList.MARKER_TYPE_ARUCO:
				text = "Aruco marker %d" % [ marker_tracker.marker_id ]
			OpenXRSpatialComponentMarkerList.MARKER_TYPE_APRIL_TAG:
				text = "April Tag marker %d" % [ marker_tracker.marker_id ]

	$Description.text = text
