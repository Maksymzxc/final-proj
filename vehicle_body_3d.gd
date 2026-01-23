extends VehicleBody3D

const ACTION_THROTTLE := "ui_up"
const ACTION_REVERSE := "ui_down"
const ACTION_LEFT := "ui_left"
const ACTION_RIGHT := "ui_right"
const ACTION_BRAKE := "ui_accept"
const ACTION_HANDBRAKE := "ui_select"
const KEY_FORWARD := KEY_W
const KEY_REVERSE := KEY_S
const KEY_LEFT := KEY_A
const KEY_RIGHT := KEY_D
const KEY_HANDBRAKE := KEY_SPACE

@export_group("Engine")
@export var forward_engine_force: float = 320.0
@export var reverse_engine_force: float = 70.0
@export var throttle_response: float = 1.2
@export var top_speed_kmh: float = 320.0
@export var accel_curve_power: float = 2.2
@export var reverse_top_speed_kmh: float = 50.0
@export var forward_force_sign: float = -1.0 # VehicleBody3D moves along -Z by default.
@export var auto_detect_drive_direction: bool = true

@export_group("Brakes")
@export var foot_brake_strength: float = 12.0
@export var idle_brake_strength: float = 2.5
@export var brake_response: float = 1.0

@export_group("Steering")
@export var steer_speed_low: float = 4.5
@export var steer_speed_high: float = 0.9
@export var steer_angle_low_speed: float = 0.95
@export var steer_angle_high_speed: float = 0.09
@export var steer_high_speed_kmh: float = 120.0
@export var steer_limit_curve_power: float = 2.6
@export var steer_input_smoothing: float = 8.0
@export var steering_deadzone: float = 0.05
@export var counter_steer_strength: float = 0.22

@export_group("Traction & Effects")
@export var grip_slip: float = 3.2
@export var slip_blend_speed: float = 8.0
@export var downforce_per_kmh: float = 0.18
@export var traction_push: float = 16.0

@export_group("Handbrake")
@export var handbrake_extra_brake: float = 6.0
@export var handbrake_rear_brake: float = 45.0
@export var handbrake_rear_slip: float = 0.55

@export_group("Stability")
@export var yaw_stability_strength: float = 520.0
@export var yaw_alignment_gain: float = 0.25
@export var stability_min_speed_kmh: float = 35.0

@export_group("Collisions")
@export var chassis_friction: float = 0.15
@export var chassis_roughness: float = 1.0

@export_group("Wheel References")
@export_node_path("VehicleWheel3D") var front_left_wheel_path: NodePath
@export_node_path("VehicleWheel3D") var front_right_wheel_path: NodePath
@export_node_path("VehicleWheel3D") var rear_left_wheel_path: NodePath
@export_node_path("VehicleWheel3D") var rear_right_wheel_path: NodePath

@export_group("HUD")
@export_node_path("Label") var speed_label_path: NodePath

@onready var speed_label: Label = get_node_or_null(speed_label_path)

var _wheels: Array[VehicleWheel3D] = []
var _traction_wheels: Array[VehicleWheel3D] = []
var _front_wheels: Array[VehicleWheel3D] = []
var _rear_wheels: Array[VehicleWheel3D] = []
var _rear_slip_state: float = grip_slip
var _throttle: float = 0.0
var _steer_state: float = 0.0
var _handbrake_engaged: bool = false
var _base_brake_force: float = 0.0
var _handbrake_force: float = 0.0
var _directional_brake_request: float = 0.0

func _ready() -> void:
	_cache_wheels()
	_auto_configure_drive_direction()
	_apply_default_wheel_setup()
	_apply_selected_skin()
	_apply_chassis_physics_material()
	_ensure_handbrake_binding()
	_update_wheel_slip(grip_slip)
	_update_rear_slip(grip_slip)
	_rear_slip_state = grip_slip

func _physics_process(delta: float) -> void:
	var speed_ms: float = linear_velocity.length()
	var speed_kmh: float = speed_ms * 3.6
	_update_speedometer(speed_kmh)
	_update_throttle(delta, speed_ms)
	_update_steering(delta, speed_kmh)
	_update_brakes(delta)
	_update_handbrake(delta)
	_apply_combined_brakes()
	_apply_stability_control(speed_ms, delta)
	_apply_downforce(speed_kmh)
	apply_central_force(-global_transform.basis.y * traction_push * speed_ms)

func _cache_wheels() -> void:
	_wheels.clear()
	_traction_wheels.clear()
	_front_wheels.clear()
	_rear_wheels.clear()
	var wheel_paths := {
		"front_left": front_left_wheel_path,
		"front_right": front_right_wheel_path,
		"rear_left": rear_left_wheel_path,
		"rear_right": rear_right_wheel_path,
	}
	for label in wheel_paths.keys():
		var wheel := _get_wheel(wheel_paths[label])
		if not wheel:
			continue
		_wheels.append(wheel)
		if wheel.use_as_traction:
			_traction_wheels.append(wheel)
		var label_str := String(label)
		if label_str.begins_with("rear"):
			_rear_wheels.append(wheel)
		elif label_str.begins_with("front"):
			_front_wheels.append(wheel)
	if _traction_wheels.is_empty():
		_traction_wheels = _wheels.duplicate()
	if _front_wheels.is_empty():
		_front_wheels = _traction_wheels.duplicate()
	if _rear_wheels.is_empty():
		_rear_wheels = _traction_wheels.duplicate()

func _apply_default_wheel_setup() -> void:
	for wheel in _wheels:
		if is_equal_approx(wheel.wheel_friction_slip, 0.0):
			wheel.wheel_friction_slip = grip_slip
		if wheel.suspension_travel <= 0.0:
			wheel.suspension_travel = 0.35

func _apply_selected_skin() -> void:
	var body := get_node_or_null("Body")
	if body and GameSettings:
		GameSettings.apply_skin_to_car(body)

func _apply_chassis_physics_material() -> void:
	var material := physics_material_override
	if material == null:
		material = PhysicsMaterial.new()
		physics_material_override = material
	material.friction = max(0.0, chassis_friction)
	if material.has_method("set_roughness"):
		material.roughness = clamp(chassis_roughness, 0.0, 1.0)

func _ensure_handbrake_binding() -> void:
	if not InputMap.has_action(ACTION_HANDBRAKE):
		InputMap.add_action(ACTION_HANDBRAKE)
	var events := InputMap.action_get_events(ACTION_HANDBRAKE)
	for event in events:
		if event is InputEventKey and event.physical_keycode == KEY_HANDBRAKE:
			return
	var key_event := InputEventKey.new()
	key_event.physical_keycode = KEY_HANDBRAKE
	key_event.keycode = KEY_HANDBRAKE
	InputMap.action_add_event(ACTION_HANDBRAKE, key_event)

func _auto_configure_drive_direction() -> void:
	if not auto_detect_drive_direction:
		return
	if _front_wheels.is_empty() or _rear_wheels.is_empty():
		return
	var front_pos := _average_local_wheel_position(_front_wheels)
	var rear_pos := _average_local_wheel_position(_rear_wheels)
	forward_force_sign = -1.0 if front_pos.z < rear_pos.z else 1.0

func _average_local_wheel_position(wheels: Array[VehicleWheel3D]) -> Vector3:
	var sum := Vector3.ZERO
	var count := 0
	for wheel in wheels:
		sum += to_local(wheel.global_transform.origin)
		count += 1
	if count == 0:
		return Vector3.ZERO
	return sum / count

func _get_wheel(path: NodePath) -> VehicleWheel3D:
	if path.is_empty():
		return null
	return get_node_or_null(path) as VehicleWheel3D

func _update_speedometer(speed_kmh: float) -> void:
	if speed_label:
		speed_label.text = str(int(speed_kmh)) + " km/h"

func _update_throttle(delta: float, speed_ms: float) -> void:
	var input_value: float = _get_axis(ACTION_THROTTLE, ACTION_REVERSE, KEY_FORWARD, KEY_REVERSE)
	var response: float = clamp(throttle_response * delta, 0.0, 1.0)
	_throttle = lerp(_throttle, input_value, response)
	var target_top_speed_ms: float = _get_top_speed_ms() if _throttle >= 0.0 else _get_reverse_top_speed_ms()
	var speed_ratio: float = clamp(speed_ms / max(0.1, target_top_speed_ms), 0.0, 1.0)
	var limiter: float = pow(max(0.0, 1.0 - speed_ratio), max(0.5, accel_curve_power))
	var forward_speed: float = -global_transform.basis.z.dot(linear_velocity)
	var braking_with_reverse: bool = forward_speed > 1.0 and _throttle < 0.0
	var braking_with_forward: bool = forward_speed < -1.0 and _throttle > 0.0
	if braking_with_reverse or braking_with_forward:
		_directional_brake_request = max(_directional_brake_request, abs(_throttle))
		engine_force = 0.0
		return
	if _throttle >= 0.0:
		engine_force = forward_force_sign * forward_engine_force * _throttle * limiter
	else:
		engine_force = forward_force_sign * reverse_engine_force * _throttle

func _update_brakes(delta: float) -> void:
	var brake_input: float = Input.get_action_strength(ACTION_BRAKE)
	var target_brake: float = brake_input * foot_brake_strength
	if abs(_throttle) < 0.05:
		target_brake = max(target_brake, idle_brake_strength)
	if _directional_brake_request > 0.0:
		target_brake = max(target_brake, _directional_brake_request * foot_brake_strength)
		_directional_brake_request = 0.0
	var response: float = clamp(brake_response, 0.0, 1.0)
	if response <= 0.0:
		_base_brake_force = target_brake
	else:
		_base_brake_force = lerp(_base_brake_force, target_brake, response)
	brake = _base_brake_force

func _update_steering(delta: float, speed_kmh: float) -> void:
	var steer_axis: float = _get_axis(ACTION_LEFT, ACTION_RIGHT, KEY_LEFT, KEY_RIGHT)
	if abs(steer_axis) < steering_deadzone:
		steer_axis = 0.0
	var smoothing: float = clamp(steer_input_smoothing * delta, 0.0, 1.0)
	_steer_state = lerp(_steer_state, steer_axis, smoothing)
	var limit: float = _steer_limit_for_speed(speed_kmh)
	var response: float = _steer_response_for_speed(speed_kmh)
	var target: float = _steer_state * limit
	steering = move_toward(steering, target, response * delta)
	if counter_steer_strength > 0.0:
		var counter: float = clamp(-angular_velocity.y * counter_steer_strength * delta, -0.3, 0.3)
		steering = clamp(steering + counter, -limit, limit)

func _update_handbrake(delta: float) -> void:
	var engaged: bool = Input.is_action_pressed(ACTION_HANDBRAKE) or Input.is_physical_key_pressed(KEY_HANDBRAKE)
	_handbrake_engaged = engaged
	var blend: float = clamp(delta * slip_blend_speed, 0.0, 1.0)
	var target_rear_slip: float = handbrake_rear_slip if engaged else grip_slip
	var new_slip: float = lerp(_rear_slip_state, target_rear_slip, blend)
	_update_rear_slip(new_slip)
	_rear_slip_state = new_slip
	_handbrake_force = handbrake_rear_brake if engaged else 0.0
	if engaged:
		_handbrake_force += handbrake_extra_brake

func _get_axis(positive_action: String, negative_action: String, positive_key: Key, negative_key: Key) -> float:
	var axis: float = Input.get_action_strength(positive_action) - Input.get_action_strength(negative_action)
	var key_axis: float = 0.0
	if Input.is_physical_key_pressed(positive_key):
		key_axis += 1.0
	if Input.is_physical_key_pressed(negative_key):
		key_axis -= 1.0
	if abs(key_axis) > abs(axis):
		axis = key_axis
	return clamp(axis, -1.0, 1.0)

func _update_wheel_slip(value: float) -> void:
	for wheel in _traction_wheels:
		wheel.wheel_friction_slip = value

func _update_rear_slip(value: float) -> void:
	for wheel in _rear_wheels:
		wheel.wheel_friction_slip = value

func _apply_combined_brakes() -> void:
	var base_force: float = _base_brake_force
	for wheel in _wheels:
		var force: float = base_force
		if wheel in _rear_wheels:
			force = max(force, _handbrake_force)
		wheel.brake = max(0.0, force)

func _apply_stability_control(speed_ms: float, delta: float) -> void:
	if yaw_stability_strength <= 0.0 or _handbrake_engaged:
		return
	var min_speed_ms: float = stability_min_speed_kmh / 3.6
	if speed_ms < min_speed_ms:
		return
	var forward_speed: float = -global_transform.basis.z.dot(linear_velocity)
	var desired_yaw_rate: float = steering * forward_speed * yaw_alignment_gain
	var yaw_error: float = angular_velocity.y - desired_yaw_rate
	var torque: float = -yaw_error * yaw_stability_strength * delta
	apply_torque(Vector3.UP * torque)

func _steer_limit_for_speed(speed_kmh: float) -> float:
	var t: float = clamp(speed_kmh / max(steer_high_speed_kmh, 1.0), 0.0, 1.0)
	var curved: float = pow(t, max(0.5, steer_limit_curve_power))
	return lerp(steer_angle_low_speed, steer_angle_high_speed, curved)

func _steer_response_for_speed(speed_kmh: float) -> float:
	var t: float = clamp(speed_kmh / max(steer_high_speed_kmh, 1.0), 0.0, 1.0)
	return lerp(steer_speed_low, steer_speed_high, t)

func _get_top_speed_ms() -> float:
	return top_speed_kmh / 3.6

func _get_reverse_top_speed_ms() -> float:
	return reverse_top_speed_kmh / 3.6

func _apply_downforce(speed_kmh: float) -> void:
	var force: float = downforce_per_kmh * speed_kmh
	if force <= 0.0:
		return
	apply_central_force(-global_transform.basis.y * force)
