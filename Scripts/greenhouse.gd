extends Node2D

# Get the base and crops map layers
@onready var base_map: TileMapLayer = $Map/Base
@onready var crops_map: TileMapLayer = $Map/Crops

var can_place_seeds_custom_data = "can_place_seeds"

# Called whenever an event is registered
func _input(event):
	if event is InputEventScreenTouch:
		handle_touch(event)

# Handle touch events
func handle_touch(event: InputEventScreenTouch):
	# Whenever a touch (tap) event happens
	if event.pressed:
		# Convert screen position to world position (adjusting for camera)
		var world_position = crops_map.get_local_mouse_position()
		
		# Convert world position to tile position
		var tile_position = crops_map.local_to_map(world_position)
		
		# Id of the tile in the tileset 
		var source_id = 0
		var atlas_coord : Vector2i = Vector2i(0, 0)
		
		# Get the base tile data (to check if seeds can be planted)
		var base_data : TileData = base_map.get_cell_tile_data(tile_position)
		
		# Null check
		if base_data:
			var can_place_seeds = base_data.get_custom_data(can_place_seeds_custom_data)
			if can_place_seeds:
				handle_seeds(tile_position, 0, atlas_coord, 4)

func handle_seeds(tile_position, level, atlas_coord, final_seed_level):
	var source_id : int = 0
	crops_map.set_cell(tile_position, source_id, atlas_coord)
	
	await get_tree().create_timer(1.0).timeout
	
	if level == final_seed_level:
		return
	else:
		var new_atlas : Vector2i = Vector2i(atlas_coord.x + 1, atlas_coord.y)
		crops_map.set_cell(tile_position, source_id, new_atlas)
		handle_seeds(tile_position, level + 1, new_atlas, final_seed_level)
		
