extends Node

## This is our UUID DB and must be setup as an autoload script
## in project settings if you wish to use persistent anchors.

# Storage class for our data
class UUIDData:
	var scene_path : String
	# Add additional info you want to store here.

# Our UUID data
var uuid_map : Dictionary[String, UUIDData]

# If our map has changed and we need to save it, this will be true
var uuid_map_needs_saving : bool = false

# Name of our data file
var data_file_name = "user://spatial_uuid_map.json"

# Timer to trigger saving after changes
var save_timer : Timer


## Return the scene path for our UUID
func get_scene_path(p_uuid: String) -> String:
	if uuid_map.has(p_uuid):
		return uuid_map[p_uuid].scene_path
	return ""


## Set the scene path for our UUID
func set_scene_path(p_uuid : String, p_scene_path : String):
	if not uuid_map.has(p_uuid):
		uuid_map[p_uuid] = UUIDData.new()

	# print("Set scene path for " + p_uuid + " to " + p_scene_path)

	# Note, if no entry exists yet for this UUID,
	# a new one will be added with the default values set in our class.
	uuid_map[p_uuid].scene_path = p_scene_path

	# Trigger (delayed) save
	uuid_map_needs_saving = true
	save_timer.start()


## Remove a UUID from our db
func remove_uuid(p_uuid : String):
	if uuid_map.has(p_uuid):
		uuid_map.erase(p_uuid)
		uuid_map_needs_saving = true


## Load a UUID map file
func load_file(p_file_name, p_must_exist = false) -> bool:
	# Check if we have a file
	if not FileAccess.file_exists(p_file_name):
		return not p_must_exist

	# Load our uuid file
	var file = FileAccess.open(p_file_name, FileAccess.READ)
	if not file:
		# Must not have a save file yet and thats fine.
		return false

	var json_string = file.get_as_text()
	if json_string.is_empty():
		# Nothing saved?
		return true

	# print("Loading: ", json_string)

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())
		return false

	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("JSON Error: Root is not of the correct data type")
		return false

	# Loop through each entry
	var uuids: Dictionary = json.data
	for uuid in uuids:
		if typeof(uuid) != TYPE_STRING:
			push_error("JSON Error: Entry '", uuid, "' is not of the correct data type")
			continue

		# Parse individual values just in case our format has changed
		if typeof(uuids[uuid]) != TYPE_DICTIONARY:
			push_error("JSON Error: Data for entry '", uuid, "' is not of the correct data type")
			continue

		var data : UUIDData = UUIDData.new()
		var details : Dictionary = uuids[uuid]
		for detail in details:
			if detail == "scene_path":
				data.scene_path = details[detail]
			else:
				push_warning("JSON Warning: Unknown detail " + detail)

		# Add entry
		uuid_map[uuid] = data

	return true


## Save a UUID map file
func save_file(p_file_name) -> bool:
	# Convert our uuid_map to something we can export.
	var data : Dictionary
	for uuid : String in uuid_map:
		var entry : Dictionary
		entry["scene_path"] = uuid_map[uuid].scene_path

		data[uuid] = entry

	# Convert to JSON.
	var as_json = JSON.stringify(data)
	# print("Saving: ", as_json)

	# And save.
	var file = FileAccess.open(p_file_name, FileAccess.WRITE)
	if not file:
		push_error("Couldn't write to " + p_file_name)
		return false

	# Q: Should we encrypt this to make tampering harder?
	file.store_string(as_json)

	# print("UUID map saved")

	return true


# Called by our save timer
func _on_save_timeout():
	if uuid_map_needs_saving:
		uuid_map_needs_saving = false
		save_file(data_file_name)


# Called first time this is added to our scene tree
func _ready():
	load_file(data_file_name)

	# Create our save timer
	save_timer = Timer.new()
	save_timer.one_shot = true
	save_timer.wait_time = 1.0
	save_timer.timeout.connect(_on_save_timeout)
	add_child(save_timer, false, Node.INTERNAL_MODE_BACK)


# Called when this is removed from our scene tree
func _exit_tree():
	if uuid_map_needs_saving:
		save_file(data_file_name)
