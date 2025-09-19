class_name TouchUI
extends AnimatableBody3D

@export var touch_id : int = 0

@export var enabled : bool = false:
	set(value):
		enabled = value
		if is_inside_tree():
			_update_enabled()


func _update_enabled():
	$CollisionShape3D.disabled = not enabled


func _ready():
	_update_enabled()
