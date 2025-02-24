extends Camera2D

# Export variables to the UI
@export var max_zoom_in: float = 5
@export var max_zoom_out: float = 1.5
@export var default_zoom: float = 3.0
@export var zoom_speed: float = 0.1
@export var pan_speed: float = 1.0

@export var can_zoom: bool
@export var can_pan: bool

# Dictionary of touch points coordinates from different fingers
var touch_points: Dictionary = {}
# Original distance value between 2 touch events (for zoom)
var start_distance
# Original zoom value
var start_zoom

# Called when the node enters the scene tree for the first time.
func _ready():
	zoom = Vector2(default_zoom, default_zoom)

# Called whenever an event is registered
func _input(event):
	# Touch
	if event is InputEventScreenTouch:
		handle_touch(event)
	# Drag
	elif event is InputEventScreenDrag:
		handle_drag(event)

# Handle touch events
func handle_touch(event: InputEventScreenTouch):
	# Whenever a touch event happens, register the touch points
	if event.pressed:
		# Get the position of the event (index 0 == 1 finger, indexes 0,1 == 2 fingers, etc.)
		touch_points[event.index] = event.position
	# Remove the touch point from the dictionary once the touch event is over
	else:
		touch_points.erase(event.index)
	
	# Whenever there's 2 fingers in the touch event
	if touch_points.size() == 2:
		# Get the positions of the touch events
		var touch_point_positions = touch_points.values()
		# Set the intial distance between the 2 touch events
		start_distance = touch_point_positions[0].distance_to(touch_point_positions[1])
		# Set the initial zoom factor
		start_zoom = zoom
	# If there's only a finger or less, set start_distance to 0
	elif touch_points.size() < 2:
		start_distance = 0
		
# Handle drag events
func handle_drag(event: InputEventScreenDrag):
	# Whenever a drag event happens, register the touch points
	touch_points[event.index] = event.position
	
	# Drag iff there's exactly 1 finger on the screen
	if touch_points.size() == 1:
		# Check if panning is allowed
		if can_pan:
			# Calculate destionation of the pan (dependent on the zoom factor)
			offset -= event.relative * pan_speed / zoom.x
	# Zoom iff there's exactly 2 fingers on the screen
	elif touch_points.size() == 2:
		# Get the positions of the touch events
		var touch_point_positions = touch_points.values()
		# Calculate the distance between the touch events
		var current_distance = touch_point_positions[0].distance_to(touch_point_positions[1])
		# Calculate the zoom factor
		var zoom_factor = start_distance / current_distance
		# Check if zooming is allowed
		if can_zoom:
			# Calculate the zoom value
			zoom = start_zoom / zoom_factor
		# Limit the zooom 
		limit_zoom(zoom, max_zoom_out, max_zoom_in)
			
# Limit the zoom
func limit_zoom(limited_zoom, min_value, max_value):
	if limited_zoom.x < min_value:
		zoom.x = min_value
	if limited_zoom.y < min_value:
		zoom.y = min_value
	if limited_zoom.x > max_value:
		zoom.x = max_value
	if limited_zoom.y > max_value:
		zoom.y = max_value
