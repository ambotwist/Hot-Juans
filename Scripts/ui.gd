extends MarginContainer

func _ready():
	var safe_area = DisplayServer.get_display_safe_area()
	var screen_size = DisplayServer.screen_get_size()
	
	# Print debug information
	print("Safe area: ", safe_area)
	print("Screen size: ", screen_size)
	
	# Only apply safe area margins on mobile platforms
	if OS.get_name() in ["iOS", "Android"]:
		# Calculate margins based on safe area
		var top_margin = safe_area.position.y * 0.7 # Reduced to 70%
		var left_margin = safe_area.position.x
		var right_margin = safe_area.size.x - screen_size.x + safe_area.position.x
		# No bottom margin, we want the navbar to connect to the bottom of the display
		# var bottom_margin = safe_area.size.y - screen_size.y + safe_area.position.y
		
		# Apply the margins
		add_theme_constant_override("margin_top", top_margin)
		add_theme_constant_override("margin_left", left_margin)
		add_theme_constant_override("margin_right", right_margin)
		# add_theme_constant_override("margin_bottom", bottom_margin)
