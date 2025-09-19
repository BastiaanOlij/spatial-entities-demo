class_name AnchoredAnimatableBody3D
extends AnimatableBody3D

## This is a node that when moved will create an anchor to save its position
## to ensure it remains in that physical space (AnimatableBody3D addition).
## When the user recenters the anchor position should automatically update.
## If persistent anchors are supported, the anchor location will be stored
## and recreated the next time the application starts.
## If shared anchors are supported, the anchor will be duplicated on other
## devices in the group.

## If this is an object without an anchor,
## we reset its position if needed.
@export var reset_on_drop : bool = true

## Use can add this to the trash can (and delete the anchor)
@export var can_trash : bool = true

## If true we can only have one instance of this,
## the last one added will be kept.
@export var is_unique : bool = false

## Dictionary of nodes that must be unique
static var unique_nodes : Dictionary[String, AnchoredAnimatableBody3D]

## Called by grab handler when user drops this object at a new location
func dropped(_dropped_by) -> void:
	if not can_trash or not Trashcan3D.is_in_trashcan(self):
		# Note, anchors can't be updated, so we create a new anchor
		SpatialEntitiesManager.create_spatial_anchor(global_transform, scene_file_path)

	var parent = get_parent()
	if parent is XRAnchor3D:
		# Remove the old anchor.
		SpatialEntitiesManager.remove_spatial_anchor(parent)
	elif reset_on_drop:
		# Reset position, we were grabbed from our inventory board
		transform = Transform3D()
	elif parent:
		# Remove this.
		parent.remove_child(self)
		queue_free()


## Called when scene is loaded
func _ready():
	if is_unique:
		if unique_nodes.has(scene_file_path):
			# We're replacing this one!
			var remove_node = unique_nodes[scene_file_path]

			var parent = remove_node.get_parent()
			if parent is XRAnchor3D:
				# Remove this.
				SpatialEntitiesManager.remove_spatial_anchor(parent)
			elif parent:
				parent.remove_child(remove_node)
				remove_node.queue_free()

		# Remember us.
		unique_nodes[scene_file_path] = self
