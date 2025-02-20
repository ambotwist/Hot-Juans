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

# Lays down the seeds in given tile position and initiates the growth phase
func plant_seeds(tile_position):

	# Check if the given tile already has a plant
	if crops_map.get_cell_tile_data(tile_position) != null:
		return
		
	# Coordinates of the the (first) atlas region
	var atlas_coord: Vector2i = Vector2i(0, 0)
	
	# Check if the given tile accept seeds 
	if retrieve_custom_data(tile_position, can_place_seeds_custom_data, base_map):
		# Start growing the plant
		grow_plant(tile_position, 0, atlas_coord, 4)
	
# Grows plant in given tile position
func grow_plant(tile_position, level, atlas_coord, final_seed_level):
	# Id of the tile resource
	var source_id: int = 0
	# Show the frame at atlas_coord
	crops_map.set_cell(tile_position, source_id, atlas_coord)
	
	# Await 2 seconds
	await get_tree().create_timer(1.0).timeout
	
	# Check if the current frame is the final growth stage
	if level == final_seed_level:
		return
	else:
		# Update the frame
		var new_atlas: Vector2i = Vector2i(atlas_coord.x + 1, atlas_coord.y)
		# Recursively call the method to handle the next frame
		grow_plant(tile_position, level + 1, new_atlas, final_seed_level)

#
func lay_soil(tile_position):
	# Id of the tile resource
	var source_id: int = 1
	# Coordinates of the the (first) atlas region
	var atlas_coord: Vector2i = Vector2i(0, 0)
	if retrieve_custom_data(tile_position, can_place_soil_custom_data, base_map):
		base_map.set_cell(tile_position, source_id, atlas_coord)
	

# Retrieves the custom data of the given tile from the given tile layer if any
func retrieve_custom_data(tile_position, custom_data_name, tile_layer):

	# Retrieves the tile data
	var tile_data: TileData = tile_layer.get_cell_tile_data(tile_position)
	
	# Check if there's any data, otherwise return false
	if tile_data:
		return tile_data.get_custom_data(custom_data_name)
	else:
		false
		

func _on_plant_seeds_pressed() -> void:
	tap_mode_state = TAP_MODES.SEEDS


func _on_editor_pressed() -> void:
	tap_mode_state = TAP_MODES.TILES
