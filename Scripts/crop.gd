extends Node2D
class_name Crop

# The crop data
var crop_data: CropData

var tile_position: Vector2i
var crops_map: TileMapLayer

# Signal emitted when the crop reaches its final growth stage
signal growth_complete

# Tracks the current stage of growth (0 = seed, max = fully grown)
var current_growth_stage: int = 0

# Tracks if the crop is ready to be harvested
var is_harvestable: bool = false

func _init(new_tile_position: Vector2i) -> void:
	self.tile_position = new_tile_position

func setup(map: TileMapLayer) -> void:
	self.crops_map = map
	# Begin the growth cycle as soon as the crop is set up
	start_growing()

# Initializes the growth process after validating required data
func start_growing() -> void:
	# Ensure we have all required references before starting
	if crop_data == null or crops_map == null:
		push_error("crop_data or crops_map not set")
		return
	
	# Start the first growth stage    
	grow_next_stage()

# Handles the progression of growth stages and updates the visual representation
func grow_next_stage() -> void:
	# Calculate the atlas coordinates based on current growth stage
	# Each stage moves one tile to the right in the atlas (x + 1)
	var atlas_coord = Vector2i(current_growth_stage, 0)
	# Update the visual representation on the map
	crops_map.set_cell(tile_position, 0, atlas_coord)
	
	# Check if we've reached the final growth stage
	if current_growth_stage >= crop_data.max_growth_stage:
		# Notify any listeners that growth is complete
		growth_complete.emit()
		# Mark the crop as ready for harvest
		is_harvestable = true
		return
		
	# Increment the growth stage counter
	current_growth_stage += 1
	# Wait for the configured growth time before next stage
	await get_tree().create_timer(crop_data.growth_time).timeout
	# Progress to the next growth stage
	grow_next_stage()

# Returns true if the crop has completed its growth and can be harvested
func is_ready_for_harvest() -> bool:
	return is_harvestable
