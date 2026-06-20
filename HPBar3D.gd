extends Node3D

## A small world-space health bar that floats above a sphere. Uses top_level so
## the parent ball's spin doesn't whirl it around; it tracks the parent's
## position and yaws to face the camera (the bar stays upright).

@export var height: float = 1.2

@onready var _fill: MeshInstance3D = $Fill
@onready var _anchor: Node3D = get_parent()


func _ready() -> void:
	# Detach from the parent's (spinning) transform; we position it manually.
	top_level = true


func _process(_delta: float) -> void:
	if _anchor == null or not is_instance_valid(_anchor):
		return
	global_position = _anchor.global_position + Vector3.UP * height

	# Yaw toward the camera only (keep the bar level) for a clean billboard.
	var cam := get_viewport().get_camera_3d()
	if cam:
		var look := cam.global_position
		look.y = global_position.y
		if look.distance_to(global_position) > 0.001:
			look_at(look, Vector3.UP)


func update_bar(current: float, maximum: float) -> void:
	var ratio := clampf(current / maximum, 0.0, 1.0)
	# Bar mesh is 1 unit wide; shrink from full and keep it left-anchored.
	_fill.scale.x = maxf(ratio, 0.0001)
	_fill.position.x = (ratio - 1.0) * 0.5
