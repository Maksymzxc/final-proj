extends Node

@onready var play_button: Button = $"../UI/VBoxContainer/PlayButton"
@onready var quit_button: Button = $"../UI/VBoxContainer/QuitButton"
@onready var skins_button: Button = $"../UI/VBoxContainer/SkinsButton"
@onready var car_display: Node3D = $"../CarDisplay"
@onready var skin_menu: Control = $"../UI/SkinMenu"
@onready var back_button: Button = $"../UI/SkinMenu/BackButton"
@onready var main_menu_container: VBoxContainer = $"../UI/VBoxContainer"

# Skin color buttons
@onready var red_button: Button = $"../UI/SkinMenu/ColorGrid/RedButton"
@onready var blue_button: Button = $"../UI/SkinMenu/ColorGrid/BlueButton"
@onready var green_button: Button = $"../UI/SkinMenu/ColorGrid/GreenButton"
@onready var yellow_button: Button = $"../UI/SkinMenu/ColorGrid/YellowButton"
@onready var black_button: Button = $"../UI/SkinMenu/ColorGrid/BlackButton"

var fall_speed: float = 0.0
var gravity: float = 15.0
var ground_y: float = 0.05
var is_falling: bool = true
var bounce_count: int = 0
var max_bounces: int = 2

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	skins_button.pressed.connect(_on_skins_pressed)
	back_button.pressed.connect(_on_back_pressed)
	
	# Connect color buttons
	red_button.pressed.connect(_on_skin_selected.bind("red"))
	blue_button.pressed.connect(_on_skin_selected.bind("blue"))
	green_button.pressed.connect(_on_skin_selected.bind("green"))
	yellow_button.pressed.connect(_on_skin_selected.bind("yellow"))
	black_button.pressed.connect(_on_skin_selected.bind("black"))
	
	# Hide skin menu initially
	skin_menu.visible = false
	
	# Apply the currently selected skin to the display car
	_apply_current_skin()

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

func _on_skins_pressed() -> void:
	main_menu_container.visible = false
	skin_menu.visible = true

func _on_back_pressed() -> void:
	skin_menu.visible = false
	main_menu_container.visible = true

func _on_skin_selected(skin_name: String) -> void:
	GameSettings.selected_skin = skin_name
	_apply_current_skin()

func _apply_current_skin() -> void:
	var body = car_display.get_node_or_null("Body")
	if body:
		GameSettings.apply_skin_to_car(body)
