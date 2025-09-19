class_name WristUIDisplay
extends Node

## Creation tool we manage
@export var collision_creation_tool : CollisionCreationTool:
	set(value):
		if collision_creation_tool:
			collision_creation_tool.state_changed.disconnect(_on_creation_tool_state_changed)
			collision_creation_tool.finished.disconnect(_on_creation_finished)

		collision_creation_tool = value

		if collision_creation_tool:
			collision_creation_tool.state_changed.connect(_on_creation_tool_state_changed)
			collision_creation_tool.finished.connect(_on_creation_finished)

@onready var cct_label : Label = $MainContainer/AddMenu/Label

func _set_menu(p_menu):
	for child in $MainContainer.get_children():
		child.visible = (child.name == p_menu)


func _ready():
	_set_menu("MainMenu")

# Main container buttons

func _on_add_button_pressed():
	_set_menu("AddMenu")

	# Enable creation function
	if collision_creation_tool:
		collision_creation_tool.state = CollisionCreationTool.CreationState.START


func _on_settings_button_pressed():
	_set_menu("SettingsMenu")


func _on_exit_button_pressed():
	_set_menu("QuitMenu")

# Add menu

func _on_creation_tool_state_changed():
	if collision_creation_tool:
		match collision_creation_tool.state:
			CollisionCreationTool.CreationState.DISABLED:
				cct_label.text = "Disabled"
			CollisionCreationTool.CreationState.START:
				cct_label.text = "Point at floor and pinch"
			CollisionCreationTool.CreationState.SET_WIDTH:
				cct_label.text = "Adjust width and pinch"
			CollisionCreationTool.CreationState.SET_SIZE:
				cct_label.text = "Adjust size and pinch"
			CollisionCreationTool.CreationState.SET_HEIGHT:
				cct_label.text = "Adjust height and pinch"
			_:
				cct_label.text = "Error: Unknown state"


func _on_creation_finished():
	_set_menu("MainMenu")


func _on_add_cancel_button_pressed():
	if collision_creation_tool:
		collision_creation_tool.state = CollisionCreationTool.CreationState.DISABLED

	_set_menu("MainMenu")

# Settings menu

func _on_settings_return_button_pressed():
	_set_menu("MainMenu")

# Quit menu

func _on_quit_cancel_button_pressed():
	_set_menu("MainMenu")


func _on_quit_ok_button_pressed():
	get_tree().quit()
