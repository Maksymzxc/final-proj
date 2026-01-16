extends VehicleBody3D

# Basic arcade-style controller for the VehicleBody3D in scenes/car_player.tscn
@export var steer_speed: float = 7.0
@export var low_speed_steer_limit: float = 1.05
@export var high_speed_steer_limit: float = 0.65
@export var high_speed_threshold_kmh: float = 300.0
@export var engine_force_forward: float = 520.0
@export var engine_force_reverse: float = 90.0
@export var top_speed_kmh: float = 270.0
@export var brake_strength: float = 4.0
@export var traction_force: float = 16.0
@export var drift_slip: float = 0.35
@export var grip_slip: float = 3.5
@export var drift_front_slip_blend: float = 0.35
@export var drift_yaw_torque: float = 2600.0
@export var drift_lateral_force: float = 260.0
@export var drift_min_speed_kmh: float = 30.0
@export var drift_force_speed_curve: float = 1.15
@export var top_speed_power: float = 3.0

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
	var speed: float = linear_velocity.length()
	_update_speedometer(speed)
	_apply_traction(speed)
	var steer_cap: float = _get_dynamic_steer_limit(speed)
	steering = move_toward(steering, _get_steer_target() * steer_cap, steer_speed * delta)
	_update_engine_force()
	_update_brake()
	_update_handbrake()
	_apply_drift(speed, delta)

func _get_wheel(path: NodePath) -> VehicleWheel3D:
	if path.is_empty():
		return null
	return get_node_or_null(path) as VehicleWheel3D

func _get_steer_target() -> float:
	return Input.get_action_strength("ui_left") - Input.get_action_strength("ui_right")

func _update_engine_force() -> void:
	var accel: float = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	if accel > 0.0:
		var speed_ratio: float = clamp(linear_velocity.length() / _get_top_speed_ms(), 0.0, 1.0)
		var limiter: float = clamp(1.0 - pow(speed_ratio, top_speed_power), 0.0, 1.0)
		engine_force = accel * engine_force_forward * limiter
	elif accel < 0.0:
		engine_force = accel * engine_force_reverse
	else:
		engine_force = 0.0

func _update_brake() -> void:
	brake = brake_strength if Input.is_action_pressed("ui_accept") else 0.0

func _update_handbrake() -> void:
	var drifting: bool = Input.is_action_pressed("ui_select")
	var rear_slip: float = drift_slip if drifting else grip_slip
	var front_slip: float = lerp(grip_slip, drift_slip, drift_front_slip_blend) if drifting else grip_slip
	if front_left_wheel:
		front_left_wheel.wheel_friction_slip = front_slip
	if front_right_wheel:
		front_right_wheel.wheel_friction_slip = front_slip
	if rear_left_wheel:
		rear_left_wheel.wheel_friction_slip = rear_slip
	if rear_right_wheel:
		rear_right_wheel.wheel_friction_slip = rear_slip

func _get_dynamic_steer_limit(speed_ms: float) -> float:
	var threshold_ms: float = high_speed_threshold_kmh / 3.6
	if threshold_ms <= 0.0:
		return high_speed_steer_limit
	var t: float = clamp(speed_ms / threshold_ms, 0.0, 1.0)
	return lerp(low_speed_steer_limit, high_speed_steer_limit, t)

func _get_top_speed_ms() -> float:
	return top_speed_kmh / 3.6

func _apply_traction(speed: float) -> void:
	apply_central_force(Vector3.DOWN * traction_force * speed)

func _update_speedometer(speed: float) -> void:
	if speed_label:
		speed_label.text = str(int(speed * 3.6)) + " km/h"

func _apply_drift(speed: float, delta: float) -> void:
	if not Input.is_action_pressed("ui_select"):
		return
	if speed * 3.6 < drift_min_speed_kmh:
		return
	var steer_sign: float = sign(steering)
	if steer_sign == 0.0:
		return
	var kmh: float = speed * 3.6
	var drift_window: float = max(5.0, top_speed_kmh - drift_min_speed_kmh)
	var speed_factor: float = clamp((kmh - drift_min_speed_kmh) / drift_window, 0.0, 1.0)
	var drift_strength: float = pow(speed_factor, drift_force_speed_curve)
	apply_torque(Vector3.UP * drift_yaw_torque * steer_sign * drift_strength * delta)
	var lateral: Vector3 = -global_transform.basis.x * steer_sign
	apply_central_force(lateral * drift_lateral_force * drift_strength)
	if drift_strength > 0.0:
		var up_relief: Vector3 = Vector3.UP * traction_force * speed * -0.3 * drift_strength
		apply_central_force(up_relief)
