extends Node2D

# Get the base and crops map layers
@onready var base_map: TileMapLayer = $Map/Base
@onready var crops_map: TileMapLayer = $Map/Crops
@onready var overlay_map: TileMapLayer = $Map/Overlays

@onready var chiliCounter = $CanvasLayer/UIMarginContainer/UI/StatsMarginContainer/Stats/ChiliCounterRow/ChiliCounterLabel

# Action bar buttons
@onready var tile_button = $CanvasLayer/UIMarginContainer/UI/BottomUI/MarginContainer/ActionBar/TileButton
@onready var plant_button = $CanvasLayer/UIMarginContainer/UI/BottomUI/MarginContainer/ActionBar/PlantButton
@onready var edit_button = $CanvasLayer/UIMarginContainer/UI/BottomUI/MarginContainer/ActionBar/EditButton
@onready var done_button = $CanvasLayer/UIMarginContainer/UI/BottomUI/MarginContainer/ActionBar/DoneButton

# Base tiles have this property
var can_place_seeds_custom_data = "can_place_seeds"
var can_place_soil_custom_data = "can_place_soil"

# Enum for the different modes
enum TAP_MODES {NONE, SEEDS, TILES}

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
	"TOP_RIGHT_BOTTOM_RIGHT": [Vector2i(0, 0), Vector2i(1, 0)],
	"BOTTOM_LEFT_TOP_LEFT_TOP_RIGHT": [Vector2i(2, 2)],
	"BOTTOM_RIGHT_BOTTOM_LEFT_TOP_LEFT": [Vector2i(3, 2)],
	"TOP_RIGHT_BOTTOM_RIGHT_BOTTOM_LEFT": [Vector2i(4, 2)],
	"TOP_LEFT_TOP_RIGHT_BOTTOM_RIGHT": [Vector2i(5, 2)]
}

var planted_crops = {}
var pepper_counter = 0

# Called when the node enters the scene tree for the first time
func _ready():
	# Ensure the Done button is hidden and disabled at start
	done_button.visible = false
	done_button.disabled = true

# Called whenever an event is registered
func _unhandled_input(event):
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
		
		# First check if there's a crop that needs watering or can be harvested
		var crop = planted_crops.get(tile_position)
		if crop is Crop and crop.tile_position == tile_position:
			if crop.crop_data.needs_water:
				water_crop(tile_position)
				return
			elif crop.is_ready_for_harvest():
				harvest_crop(tile_position)
				return
		
		if tap_mode_state == TAP_MODES.SEEDS:
			plant_seeds(tile_position)
		if tap_mode_state == TAP_MODES.TILES:
			lay_soil(tile_position)

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

	# Load and instance the Crop scene
	var crop_scene = preload("res://Scenes/Objects/Crop.tscn")
	var new_crop = crop_scene.instantiate()
	
	# Add the crop as a child of this node
	add_child(new_crop)
	
	# Set up the crop's position and data
	new_crop.set_tile_position(tile_position)
	var cell_position = crops_map.map_to_local(tile_position)
	new_crop.position = cell_position
	
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
		
		# Get current overlay coordinates and update to watered version
		var current_overlay = overlay_map.get_cell_atlas_coords(tile_position)
		if current_overlay != Vector2i(-1, -1): # Check if overlay exists
			var watered_overlay = Vector2i(current_overlay.x, current_overlay.y + 1)
			overlay_map.set_cell(tile_position, SOIL_OVERLAY_TILE_ID, watered_overlay)
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
			
			# Reset soil to dry state
			# Set the base soil tile back to dry
			base_map.set_cell(tile_position, SOIL_TILE_ID, Vector2i(0, 0))
			
			# Get current overlay coordinates and update to dry version
			var current_overlay = overlay_map.get_cell_atlas_coords(tile_position)
			if current_overlay != Vector2i(-1, -1): # Check if overlay exists
				# If it's a watered overlay (y > 0), get the dry version
				if current_overlay.y > 0:
					var dry_overlay = Vector2i(current_overlay.x, current_overlay.y - 1)
					overlay_map.set_cell(tile_position, SOIL_OVERLAY_TILE_ID, dry_overlay)
			
			# Increment the pepper counter by 1
			pepper_counter += 1
			# Update the label with the new pepper counter value
			chiliCounter.text = str(pepper_counter)
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
	
	# Check each neighboring tile
	for neighbor_pos in neighbor_offsets:
		var check_pos = soil_position + neighbor_offsets[neighbor_pos]
		
		# Skip if not a valid tile position
		if !is_valid_tile_position(check_pos):
			continue
			
		# Skip if this neighbor is a soil tile
		if base_map.get_cell_source_id(check_pos) == SOIL_TILE_ID:
			continue
			
		# Get all soil neighbors for this grass tile
		var soil_neighbors = get_soil_neighbors(check_pos)
		
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
	print("\nUpdating grass overlay at position: ", grass_position)
	print("Soil neighbors count: ", soil_neighbors.size())
	
	if soil_neighbors.is_empty():
		print("No soil neighbors, removing overlay")
		overlay_map.erase_cell(grass_position)
		return
		
	# If more than 3 soil neighbors, remove overlay
	if soil_neighbors.size() > 3:
		print("More than 3 soil neighbors, removing overlay")
		overlay_map.erase_cell(grass_position)
		return
		
	# Generate key for overlay coordinates lookup
	var key = ""
	if soil_neighbors.size() == 1:
		key = NEIGHBOR.keys()[soil_neighbors[0]]
		print("Single neighbor key: ", key)
	elif soil_neighbors.size() == 2 or soil_neighbors.size() == 3:
		# For 2 or 3 neighbors, try different combinations
		var direction_names = []
		for neighbor in soil_neighbors:
			direction_names.append(NEIGHBOR.keys()[neighbor])
		
		print("Direction names: ", direction_names)
		
		# Try all possible orderings
		var found_key = false
		# Start with original order
		key = "_".join(direction_names)
		print("Trying key: ", key)
		if GRASS_OVERLAY_COORDS.has(key):
			found_key = true
			print("Key found in dictionary")
		else:
			print("Key not found, trying permutations")
			# Try different permutations for 2 or 3 neighbors
			# This is a simple approach - we just try a few common patterns
			if soil_neighbors.size() == 2:
				# Just swap the two directions
				key = direction_names[1] + "_" + direction_names[0]
				print("Trying swapped key: ", key)
				if GRASS_OVERLAY_COORDS.has(key):
					found_key = true
					print("Swapped key found in dictionary")
			else: # 3 neighbors
				# Try some common orderings for 3 neighbors
				var orderings = [
					[0, 1, 2],
					[0, 2, 1],
					[1, 0, 2],
					[1, 2, 0],
					[2, 0, 1],
					[2, 1, 0]
				]
				
				for order in orderings:
					var test_key = direction_names[order[0]] + "_" + direction_names[order[1]] + "_" + direction_names[order[2]]
					print("Trying ordered key: ", test_key)
					if GRASS_OVERLAY_COORDS.has(test_key):
						key = test_key
						found_key = true
						print("Ordered key found in dictionary")
						break
		
		# If no matching key found, use the first ordering (this shouldn't happen with proper data)
		if !found_key:
			print("No matching key found in dictionary")
			key = "_".join(direction_names)
	
	print("Final key: ", key)
	print("Available keys in dictionary: ", GRASS_OVERLAY_COORDS.keys())
	
	# Get possible overlay coordinates for this configuration
	var possible_coords = GRASS_OVERLAY_COORDS.get(key, [])
	print("Possible coordinates: ", possible_coords)
	
	if !possible_coords.is_empty():
		# Choose random variation
		var overlay_coord = possible_coords[randi() % possible_coords.size()]
		print("Selected overlay coordinate: ", overlay_coord)
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
func _on_plant_button_pressed() -> void:
	# Toggle the tap mode state
	if tap_mode_state != TAP_MODES.SEEDS:
		tap_mode_state = TAP_MODES.SEEDS
		_show_done_button()
	elif tap_mode_state == TAP_MODES.SEEDS:
		tap_mode_state = TAP_MODES.NONE
		_hide_done_button()

# Handles the lay soil button press
func _on_tile_button_pressed() -> void:
	# Toggle the tap mode state
	if tap_mode_state != TAP_MODES.TILES:
		tap_mode_state = TAP_MODES.TILES
		_show_done_button()
	elif tap_mode_state == TAP_MODES.TILES:
		tap_mode_state = TAP_MODES.NONE
		_hide_done_button()

# Handles the done button press
func _on_done_button_pressed() -> void:
	tap_mode_state = TAP_MODES.NONE
	_hide_done_button()

# Shows the done button and hides action buttons
func _show_done_button() -> void:
	# Hide action buttons
	tile_button.visible = false
	tile_button.disabled = true
	plant_button.visible = false
	plant_button.disabled = true
	edit_button.visible = false
	edit_button.disabled = true
	
	# Show done button
	done_button.visible = true
	done_button.disabled = false

# Hides the done button and shows action buttons
func _hide_done_button() -> void:
	# Show action buttons
	tile_button.visible = true
	tile_button.disabled = false
	plant_button.visible = true
	plant_button.disabled = false
	edit_button.visible = true
	edit_button.disabled = false
	
	# Hide done button
	done_button.visible = false
	done_button.disabled = true

# Checks if the given tile position is valid (inbound)
func is_valid_tile_position(tile_position: Vector2i) -> bool:
	var map_rect = base_map.get_used_rect()
	return map_rect.has_point(tile_position)
