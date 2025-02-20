extends Resource
class_name CropData

# Name of the crop
@export var crop_name: String

# Number of growth stages for this crop
@export var max_growth_stage: int = 4

# Does the crop need water to grow
@export var needs_water: bool = true

# Time between growth stages in seconds
@export var growth_time: float = 2.0

# Array of textures for each growth stage
@export var sprite_frames: Array[Texture2D]

# Description of the crop
@export var description: String
