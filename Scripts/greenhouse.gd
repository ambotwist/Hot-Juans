extends Node2D

# Get the base and crops map layers
@onready var base_map: TileMapLayer = $Map/Base
@onready var crops_map: TileMapLayer = $Map/Crops
@onready var overlay_map: TileMapLayer = $Map/Overlays

# Base tiles have this property
var can_place_seeds_custom_data = "can_place_seeds"
var can_place_soil_custom_data = "can_place_soil"

# Enum for the different modes
enum TAP_MODES {NONE, SEEDS, TILES, WATER, HARVEST}

# Default tap mode
var tap_mode_state = TAP_MODES.NONE

var crop_data_resource = preload("res://Resources/chili.tres")

const SOIL_TILE_ID = 1
const SOIL_ATLAS_COORD = Vector2i(0, 0)
const SOIL_OVERLAY_TILE_ID = 1
const GRASS_OVERLAY_TILE_ID = 0

# Array of possible soil overlay coordinates
const SOIL_OVERLAY_COORDS = [
	Vector2i(0, 0),
	Vector2i(1, 0),
	Vector2i(2, 0),
	Vector2i(3, 0)
]

# Enum for neighbor positions in isometric layout
enum NEIGHBOR {TOP_RIGHT, BOTTOM_RIGHT, BOTTOM_LEFT, TOP_LEFT}

# Dictionary mapping neighbor combinations to possible overlay coordinates
const GRASS_OVERLAY_COORDS = {
	"TOP_RIGHT": [Vector2i(2, 0), Vector2i(3, 0)],
	"BOTTOM_RIGHT": [Vector2i(0, 1), Vector2i(1, 1)],
	"BOTTOM_LEFT": [Vector2i(2, 1), Vector2i(3, 1)],
	"TOP_LEFT": [Vector2i(4, 0), Vector2i(5, 0)],
	"BOTTOM_LEFT_TOP_LEFT": [Vector2i(0, 2), Vector2i(1, 2)],
	"TOP_RIGHT_TOP_LEFT": [Vector2i(5, 1)],
	"BOTTOM_LEFT_BOTTOM_RIGHT": [Vector2i(4, 1)],
	"TOP_RIGHT_BOTTOM_RIGHT": [Vector2i(0, 0), Vector2i(1, 0)]
}

var planted_crops = {}
var pepper_counter = 0

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
		if tap_mode_state == TAP_MODES.WATER:
			water_crop(tile_position)
		if tap_mode_state == TAP_MODES.HARVEST:
			harvest_crop(tile_position)
			

# Plant the seeds in given tile position and initiates the growth phase
func plant_seeds(tile_position):
	# Check if the tile position is valid
	if !is_valid_tile_position(tile_position):
		return
	
	# Check if we can place seeds here
	if !retrieve_custom_data(tile_position, can_place_seeds_custom_data, base_map):
		return
		
	# Check if the given tile already has a plant
	if crops_map.get_cell_tile_data(tile_position) != null or planted_crops.has(tile_position):
		return

	# Create a new crop instance
	var new_crop = Crop.new(tile_position)

	# Add the crop as a child of this node
	add_child(new_crop)
	
	# Create a unique copy of the crop data for this crop
	new_crop.crop_data = crop_data_resource.duplicate()
	
	# Setup the crop with reference to crops_map
	new_crop.setup(crops_map)

	# Show crop
	var initial_atlas_coord = Vector2i(0, 0)
	crops_map.set_cell(tile_position, 0, initial_atlas_coord)

	# Add the crop to the dictionary
	planted_crops[tile_position] = new_crop

# Waters the crop at the given position if it exists and needs water
func water_crop(tile_position: Vector2i) -> void:
	# Find crop at this position
	var crop = planted_crops.get(tile_position)
	if crop is Crop and crop.tile_position == tile_position and crop.crop_data.needs_water:
		crop.water()
		# Update the soil appearance in the base map
		base_map.set_cell(tile_position, SOIL_TILE_ID, Vector2i(1, 0))
		return

# Harvests the crop at the given tile position if it's ready
func harvest_crop(tile_position: Vector2i) -> void:
	# Get the crop at this position
	var crop = planted_crops.get(tile_position)
	if crop is Crop and crop.tile_position == tile_position:
		# Check if crop is ready for harvest
		if crop.is_ready_for_harvest():
			# Clear the tile in the crops map
			crops_map.erase_cell(tile_position)
			# Remove the crop node
			crop.queue_free()
			# Remove the crop from the dictionary
			planted_crops.erase(tile_position)
			# Update the soil appearance in the base map
			base_map.set_cell(tile_position, SOIL_TILE_ID, Vector2i(0, 0))
			# Increment the pepper counter by 1
			pepper_counter += 1
			# Update the label with the new pepper counter value
			%Label.text = str(pepper_counter)
			return

# Lays down the soil in given tile position
func lay_soil(tile_position):
	# Check if we can place soil here
	if retrieve_custom_data(tile_position, can_place_soil_custom_data, base_map):
		# Place the soil in base layer
		base_map.set_cell(tile_position, SOIL_TILE_ID, SOIL_ATLAS_COORD)
		
		# Choose a random overlay coordinate for the soil
		var random_overlay = SOIL_OVERLAY_COORDS[randi() % SOIL_OVERLAY_COORDS.size()]
		overlay_map.set_cell(tile_position, SOIL_OVERLAY_TILE_ID, random_overlay)
		
		# Update grass overlays for neighboring tiles
		update_neighboring_grass_overlays(tile_position)

# Updates grass overlays for tiles neighboring a soil tile
func update_neighboring_grass_overlays(soil_position: Vector2i) -> void:
	# Define neighbor offsets for isometric diamond-down layout
	var neighbor_offsets = {
		NEIGHBOR.TOP_RIGHT: Vector2i(0, -1),
		NEIGHBOR.BOTTOM_RIGHT: Vector2i(1, 0),
		NEIGHBOR.BOTTOM_LEFT: Vector2i(0, 1),
		NEIGHBOR.TOP_LEFT: Vector2i(-1, 0)
	}
	
	print("\nChecking neighbors for soil at position: ", soil_position)
	
	# Check each neighboring tile
	for neighbor_pos in neighbor_offsets:
		var check_pos = soil_position + neighbor_offsets[neighbor_pos]
		print("Checking neighbor ", NEIGHBOR.keys()[neighbor_pos], " at position: ", check_pos)
		
		# Skip if not a valid tile position
		if !is_valid_tile_position(check_pos):
			print("- Invalid tile position")
			continue
			
		# Skip if this neighbor is a soil tile
		if base_map.get_cell_source_id(check_pos) == SOIL_TILE_ID:
			print("- Is a soil tile, skipping")
			continue
			
		# Get all soil neighbors for this grass tile
		var soil_neighbors = get_soil_neighbors(check_pos)
		print("- Found all soil neighbors: ", soil_neighbors.map(func(n): return NEIGHBOR.keys()[n]))
		
		# Update grass overlay based on all soil neighbors
		update_grass_overlay(check_pos, soil_neighbors)

# Gets a list of directions where soil neighbors exist
func get_soil_neighbors(grass_position: Vector2i) -> Array:
	var soil_neighbors = []
	var neighbor_offsets = {
		NEIGHBOR.TOP_RIGHT: Vector2i(0, -1),
		NEIGHBOR.BOTTOM_RIGHT: Vector2i(1, 0),
		NEIGHBOR.BOTTOM_LEFT: Vector2i(0, 1),
		NEIGHBOR.TOP_LEFT: Vector2i(-1, 0)
	}
	
	for direction in neighbor_offsets:
		var check_pos = grass_position + neighbor_offsets[direction]
		if is_valid_tile_position(check_pos) and base_map.get_cell_source_id(check_pos) == SOIL_TILE_ID:
			soil_neighbors.append(direction)
	
	return soil_neighbors

# Updates the grass overlay based on soil neighbors
func update_grass_overlay(grass_position: Vector2i, soil_neighbors: Array) -> void:
	if soil_neighbors.is_empty():
		print("No soil neighbors for grass at ", grass_position, ", removing overlay")
		overlay_map.erase_cell(grass_position)
		return
		
	# If more than 2 soil neighbors, remove overlay
	if soil_neighbors.size() > 2:
		print("More than 2 soil neighbors at ", grass_position, ", removing overlay")
		overlay_map.erase_cell(grass_position)
		return
		
	# Generate key for overlay coordinates lookup
	var key = ""
	if soil_neighbors.size() == 1:
		key = NEIGHBOR.keys()[soil_neighbors[0]]
	elif soil_neighbors.size() == 2:
		# Sort the neighbors to match our predefined combinations
		var n1 = NEIGHBOR.keys()[soil_neighbors[0]]
		var n2 = NEIGHBOR.keys()[soil_neighbors[1]]
		
		# Try both combinations
		key = n1 + "_" + n2
		if !GRASS_OVERLAY_COORDS.has(key):
			key = n2 + "_" + n1
	
	print("Looking up overlay for key: ", key)
	
	# Get possible overlay coordinates for this configuration
	var possible_coords = GRASS_OVERLAY_COORDS.get(key, [])
	if !possible_coords.is_empty():
		# Choose random variation
		var overlay_coord = possible_coords[randi() % possible_coords.size()]
		print("Selected overlay coordinates: ", overlay_coord)
		overlay_map.set_cell(grass_position, GRASS_OVERLAY_TILE_ID, overlay_coord)
		
		# Verify the cell was set
		var placed_cell = overlay_map.get_cell_atlas_coords(grass_position)
		var placed_id = overlay_map.get_cell_source_id(grass_position)
		print("Verification - Cell at ", grass_position, ": ID=", placed_id, " Coords=", placed_cell)
	else:
		print("No overlay coordinates found for key: ", key)

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
	if tap_mode_state != TAP_MODES.SEEDS:
		tap_mode_state = TAP_MODES.SEEDS
	elif tap_mode_state == TAP_MODES.SEEDS:
		tap_mode_state = TAP_MODES.NONE

# Handles the lay soil button press
func _on_editor_pressed() -> void:
	# Toggle the tap mode state
	if tap_mode_state != TAP_MODES.TILES:
		tap_mode_state = TAP_MODES.TILES
	elif tap_mode_state == TAP_MODES.TILES:
		tap_mode_state = TAP_MODES.NONE

# Handles the water button press
func _on_water_pressed() -> void:
	# Toggle the tap mode state
	if tap_mode_state != TAP_MODES.WATER:
		tap_mode_state = TAP_MODES.WATER
	elif tap_mode_state == TAP_MODES.WATER:
		tap_mode_state = TAP_MODES.NONE

# Handles the harvest button press
func _on_harvest_pressed() -> void:
	# Toggle the tap mode state
	if tap_mode_state != TAP_MODES.HARVEST:
		tap_mode_state = TAP_MODES.HARVEST
	elif tap_mode_state == TAP_MODES.HARVEST:
		tap_mode_state = TAP_MODES.NONE

# Checks if the given tile position is valid (inbound)
func is_valid_tile_position(tile_position: Vector2i) -> bool:
	var map_rect = base_map.get_used_rect()
	return map_rect.has_point(tile_position)
