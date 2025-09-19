extends XRAnchor3D

## This script handles plane tracked anchors.
## A static collision will be maintained once we
## have a collider shape.
## We will also display a mesh that will occlude any
## objects behind our surface.

var plane_tracker : OpenXRPlaneTracker

func _update_mesh_and_collision():
	if plane_tracker:
		# Place our static body using our offset so both collision
		# and mesh are positioned correctly
		$StaticBody3D.transform = plane_tracker.get_mesh_offset()

		# Set our mesh so we can occlude the surface (see material override)
		var new_mesh = plane_tracker.get_mesh()
		if $StaticBody3D/MeshInstance3D.mesh != new_mesh:
			$StaticBody3D/MeshInstance3D.mesh = new_mesh

		# And set our shape so we can have things collide things with our surface
		var new_shape = plane_tracker.get_shape()
		if $StaticBody3D/CollisionShape3D.shape != new_shape:
			$StaticBody3D/CollisionShape3D.shape = new_shape


func _on_mesh_changed():
	_update_mesh_and_collision()


func _ready():
	plane_tracker = XRServer.get_tracker(tracker)
	if plane_tracker:
		print("Adding scene for ", plane_tracker.description)
		$Description.text = plane_tracker.description

		_update_mesh_and_collision()

		plane_tracker.mesh_changed.connect(_on_mesh_changed)
