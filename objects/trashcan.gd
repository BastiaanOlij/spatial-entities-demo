class_name Trashcan3D
extends AnchoredAnimatableBody3D

static var detectors : Array[Area3D]

## Check all our current trashcans to see if this object is positioned within
static func is_in_trashcan(body : Node) -> bool:
	for detector : Area3D in detectors:
		if detector.overlaps_body(body):
			return true

	return false


func _enter_tree():
	detectors.push_back($Detector)


func _exit_tree():
	detectors.erase($Detector)
