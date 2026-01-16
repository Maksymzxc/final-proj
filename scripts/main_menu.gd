extends Node

@onready var play_button: Button = $"../UI/VBoxContainer/PlayButton"
@onready var quit_button: Button = $"../UI/VBoxContainer/QuitButton"
@onready var car_display: Node3D = $"../CarDisplay"

var fall_speed: float = 0.0
var gravity: float = 15.0
var ground_y: float = 0.05
var is_falling: bool = true
var bounce_count: int = 0
var max_bounces: int = 2

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _process(delta: float) -> void:
	if not is_falling:
		return
	
	# Apply gravity
	fall_speed += gravity * delta
	
	# Move car down
	var pos = car_display.position
	pos.y -= fall_speed * delta
	
	# Check if car hit the ground
	if pos.y <= ground_y:
		pos.y = ground_y
		if bounce_count < max_bounces:
			# Bounce up with reduced speed
			fall_speed = -fall_speed * 0.4
			bounce_count += 1
		else:
			# Stop falling
			fall_speed = 0.0
			is_falling = false
	
	car_display.position = pos

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/racing_map.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
