extends Node2D
class_name Crop

var crop_data: CropData
var tile_position: Vector2i
var crops_map: TileMapLayer
var current_growth_stage: int = 0
var is_harvestable: bool = false

@onready var watering_indicator = $WateringIndicator
@onready var harvest_indicator = $HarvestIndicator

signal growth_complete

# Initialize the crop with a position
func set_tile_position(new_tile_position: Vector2i) -> void:
	tile_position = new_tile_position

# Setup the crop
func setup(map: TileMapLayer) -> void:
	# Set the crops map
	self.crops_map = map
	
	# Start the timer to show watering indicator
	await get_tree().create_timer(2.0).timeout
	show_watering_indicator()

# Show the watering indicator if the crop needs water
func show_watering_indicator() -> void:
	if crop_data and crop_data.needs_water:
		watering_indicator.visible = true

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
	var atlas_coord = Vector2i(current_growth_stage, 0)
	
	# Update the tilemap
	crops_map.set_cell(tile_position, 0, atlas_coord)
	
	# Check if we've reached the final growth stage
	if current_growth_stage >= crop_data.max_growth_stage:
		# Notify any listeners that growth is complete
		growth_complete.emit()
		# Mark the crop as ready for harvest
		is_harvestable = true
		# Show harvest indicator after a delay
		await get_tree().create_timer(2.0).timeout
		show_harvest_indicator()
		return
		
	# Increment the growth stage counter
	current_growth_stage += 1
	# Wait for the configured growth time before next stage
	await get_tree().create_timer(crop_data.growth_time).timeout
	# Progress to the next growth stage
	grow_next_stage()

# Show the harvest indicator if the crop is ready for harvest
func show_harvest_indicator() -> void:
	if is_harvestable:
		harvest_indicator.visible = true

# Returns true if the crop has completed its growth and can be harvested
func is_ready_for_harvest() -> bool:
	return is_harvestable

func water() -> void:
	# Check if the crop needs water
	if crop_data.needs_water:
		crop_data.needs_water = false
		# Hide the watering indicator
		watering_indicator.visible = false
		# Start growing after being watered
		start_growing()
