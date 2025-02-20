extends Node2D
class_name Crop

# Reference to the crop data resource
var crop_data: CropData
var current_stage: int = 0
var watered: bool = false

@onready var growth_timer: Timer = Timer.new()
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# Ensure we have valid crop data
	if not crop_data:
		push_error("Crop instantiated without crop_data!")
		return

	# Setup growth timer
	growth_timer.wait_time = crop_data.growth_time
	growth_timer.timeout.connect(_on_grow)
	add_child(growth_timer)

	# Initial sprite setup
	update_appearance()
	
	# Start growing if doesn't need water or is already watered
	if !crop_data.needs_water or watered:
		growth_timer.start()

func _on_grow() -> void:
	if current_stage < crop_data.max_growth_stage - 1:
		current_stage += 1
		update_appearance()
		growth_timer.start()

func update_appearance() -> void:
	if crop_data and crop_data.sprite_frames.size() > current_stage:
		sprite.texture = crop_data.sprite_frames[current_stage]
		print("Updated crop appearance to stage: ", current_stage) # Debug line
