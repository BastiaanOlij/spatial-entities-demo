extends XRAnchor3D

## This script handles marker anchors.

var marker_tracker : OpenXRMarkerTracker

func _ready():
	var text = "Unknown marker"
	marker_tracker = XRServer.get_tracker(tracker)
	if marker_tracker:
		match marker_tracker.marker_type:
			OpenXRSpatialComponentMarkerList.MARKER_TYPE_QRCODE:
				var data : Variant = marker_tracker.get_marker_data()
				var marker_file : String = ""
				if typeof(data) == TYPE_STRING:
					var data_str : String = data
					marker_file = "res://markers/scenes/" + data_str.to_lower() + ".tscn";
					# "res://markers/scenes/plush.tscn"

				if ResourceLoader.exists(marker_file):
					text = ""
					var scene : PackedScene = load(marker_file);
					if scene:
						var instance = scene.instantiate()
						if instance:
							add_child(instance)
						else:
							text = "Failed to instantiate " + data
					else:
						text = "Failed to load " + data
				else:
					text = "QR code marker"
					if typeof(data) == TYPE_STRING:
						text += "\nData: " + marker_file
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
