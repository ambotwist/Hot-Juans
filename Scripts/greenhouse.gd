extends Node2D

# Get the base and crops map layers
@onready var base_map: TileMapLayer = $Map/Base
@onready var crops_map: TileMapLayer = $Map/Crops

# Base tiles have this property
var can_place_seeds_custom_data = "can_place_seeds"
var can_place_soil_custom_data = "can_place_soil"

# Enum for the different modes
enum TAP_MODES {NONE, SEEDS, TILES}

# Default tap mode
var tap_mode_state = TAP_MODES.NONE

const CROP_DATA_PATH = "res://Resources/chili.tres"
var crop_data_resource = preload(CROP_DATA_PATH)

const SOIL_TILE_ID = 1
const SOIL_ATLAS_COORD = Vector2i(0, 0)

# Called whenever an event is registered
func _input(event):
	if event is InputEventScreenTouch:
		handle_touch(event)

# Handle touch events
func handle_touch(event: InputEventScreenTouch):
	# Whenever a touch (tap) event happens
	if event.pressed:
		# Convert screen position to world position (adjusting for camera)
		var world_position = base_map.get_global_mouse_position()

		# Convert world position to tile position
		var tile_position = base_map.local_to_map(world_position)
		
		if tap_mode_state == TAP_MODES.SEEDS:
			plant_seeds(tile_position)
		if tap_mode_state == TAP_MODES.TILES:
			lay_soil(tile_position)
		else:
			harvest_crop(tile_position)

# Lays down the seeds in given tile position and initiates the growth phase
func plant_seeds(tile_position):
	if !is_valid_tile_position(tile_position):
		return
	
	# Check if we can place seeds here
	if !retrieve_custom_data(tile_position, can_place_seeds_custom_data, base_map):
		return
		
	# Check if the given tile already has a plant
	if crops_map.get_cell_tile_data(tile_position) != null:
		return

	# Check if the crop data resource is loaded
	if crop_data_resource == null:
		push_error("Failed to load crop data from: " + CROP_DATA_PATH)
		return

	# Create a new crop instance
	var crop = Crop.new(tile_position)

	# Set the crop data
	crop.crop_data = crop_data_resource

	# Add the crop as a child of this node (not crops_map)
	add_child(crop)
	
	# Setup the crop with reference to crops_map
	crop.setup(crops_map)

# Lays down the soil in given tile position
func lay_soil(tile_position):
	if retrieve_custom_data(tile_position, can_place_soil_custom_data, base_map):
		base_map.set_cell(tile_position, SOIL_TILE_ID, SOIL_ATLAS_COORD)

# Retrieves the custom data of the given tile from the given tile layer if any
func retrieve_custom_data(tile_position, custom_data_name, tile_layer):

	# Retrieves the tile data
	var tile_data: TileData = tile_layer.get_cell_tile_data(tile_position)
	
	# Check if there's any data, otherwise return false
	if tile_data:
		return tile_data.get_custom_data(custom_data_name)
	else:
		return false

# Handles the plant seeds button press
func _on_plant_seeds_pressed() -> void:
	# Toggle the tap mode state
	if tap_mode_state == TAP_MODES.NONE:
		tap_mode_state = TAP_MODES.SEEDS
	else:
		tap_mode_state = TAP_MODES.NONE

# Handles the lay soil button press
func _on_editor_pressed() -> void:
	# Toggle the tap mode state
	if tap_mode_state == TAP_MODES.NONE:
		tap_mode_state = TAP_MODES.TILES
	else:
		tap_mode_state = TAP_MODES.NONE

# Checks if the given tile position is valid (inbound)
func is_valid_tile_position(tile_position: Vector2i) -> bool:
	var map_rect = base_map.get_used_rect()
	return map_rect.has_point(tile_position)

# Harvests the crop at the given tile position if it's ready
func harvest_crop(tile_position: Vector2i) -> void:
	# Get the crop at this position
	for crop in get_children():
		if crop is Crop and crop.tile_position == tile_position:
			# Check if crop is ready for harvest
			if crop.is_ready_for_harvest():
				# Clear the tile in the crops map
				crops_map.erase_cell(tile_position)
				# Remove the crop node
				crop.queue_free()
				return
