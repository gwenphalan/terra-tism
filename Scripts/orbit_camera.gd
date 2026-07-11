class_name OrbitCamera
extends Node3D

# Orbit rig: place this node at the point to orbit (the cab) and give it a
# Camera3D child named "Camera3D". Hold right mouse to orbit, scroll to zoom.

@export var distance: float = 8.0
@export var min_distance: float = 2.0
@export var max_distance: float = 30.0
@export var zoom_step: float = 1.0
@export var orbit_sensitivity: float = 0.005
@export var min_pitch: float = -1.4
@export var max_pitch: float = 1.4

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	_update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					distance = maxf(min_distance, distance - zoom_step)
					_update_camera()
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					distance = minf(max_distance, distance + zoom_step)
					_update_camera()
			MOUSE_BUTTON_RIGHT:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Node3D's default YXZ euler order lets one node handle yaw + pitch
		rotation.y -= event.relative.x * orbit_sensitivity
		rotation.x = clampf(rotation.x - event.relative.y * orbit_sensitivity, min_pitch, max_pitch)

func _update_camera() -> void:
	camera.position = Vector3(0, 0, distance)
