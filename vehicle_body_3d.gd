extends VehicleBody3D

# Basic arcade-style controller for the VehicleBody3D in scenes/car_player.tscn
@export var steer_speed: float = 5.0
@export var steer_limit: float = 0.6
@export var engine_force_forward: float = 55.0
@export var engine_force_reverse: float = 35.0
@export var brake_strength: float = 2.5
@export var traction_force: float = 15.0
@export var drift_slip: float = 0.8
@export var grip_slip: float = 3.0

@export_node_path("VehicleWheel3D") var front_left_wheel_path: NodePath
@export_node_path("VehicleWheel3D") var front_right_wheel_path: NodePath
@export_node_path("VehicleWheel3D") var rear_left_wheel_path: NodePath
@export_node_path("VehicleWheel3D") var rear_right_wheel_path: NodePath
@export_node_path("Label") var speed_label_path: NodePath

@onready var front_left_wheel: VehicleWheel3D = _get_wheel(front_left_wheel_path)
@onready var front_right_wheel: VehicleWheel3D = _get_wheel(front_right_wheel_path)
@onready var rear_left_wheel: VehicleWheel3D = _get_wheel(rear_left_wheel_path)
@onready var rear_right_wheel: VehicleWheel3D = _get_wheel(rear_right_wheel_path)
@onready var speed_label: Label = get_node_or_null(speed_label_path)

func _physics_process(delta: float) -> void:
	var speed := linear_velocity.length()
	_update_speedometer(speed)
	_apply_traction(speed)
	steering = move_toward(steering, _get_steer_target() * steer_limit, steer_speed * delta)
	_update_engine_force()
	_update_brake()
	_update_handbrake()

func _get_wheel(path: NodePath) -> VehicleWheel3D:
	if path.is_empty():
		return null
	return get_node_or_null(path) as VehicleWheel3D

func _get_steer_target() -> float:
	return Input.get_action_strength("ui_left") - Input.get_action_strength("ui_right")

func _update_engine_force() -> void:
	var accel := Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	if accel > 0.0:
		engine_force = accel * engine_force_forward
	elif accel < 0.0:
		engine_force = accel * engine_force_reverse
	else:
		engine_force = 0.0

func _update_brake() -> void:
	brake = brake_strength if Input.is_action_pressed("ui_accept") else 0.0

func _update_handbrake() -> void:
	var slip := drift_slip if Input.is_action_pressed("ui_select") else grip_slip
	for wheel in [rear_left_wheel, rear_right_wheel]:
		if wheel:
			wheel.wheel_friction_slip = slip

func _apply_traction(speed: float) -> void:
	apply_central_force(Vector3.DOWN * traction_force * speed)

func _update_speedometer(speed: float) -> void:
	if speed_label:
		speed_label.text = str(int(speed * 3.6)) + " km/h"
