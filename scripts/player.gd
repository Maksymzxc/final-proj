extends CharacterBody2D

# Movement settings
@export var speed: float = 200.0
@export var jump_velocity: float = -400.0
@export var acceleration: float = 800.0
@export var friction: float = 1000.0

# Get the gravity from the project settings
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")


func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# Handle jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity
	
	# Get horizontal input direction
	var direction := Input.get_axis("ui_left", "ui_right")
	
	# Apply movement with acceleration and friction
	if direction != 0:
		velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)
	
	move_and_slide()


func _ready() -> void:
	pass


func _process(delta: float) -> void:
	pass


#HELLO MAKSmakktkktktasadadadadadda
