extends Node3D

## A small world-space health bar that floats above a sphere. Uses top_level so
## the parent ball's spin doesn't whirl it around; it tracks the parent's
## position and yaws to face the camera (the bar stays upright).

@export var height: float = 1.2

@onready var _fill: MeshInstance3D = $Fill
@onready var _anchor: Node3D = get_parent()

## Width of the Fill mesh in local units. Read from the mesh instead of
## assumed to be 1.0: the left-anchoring offset in update_bar() scales with
## it, so a bar authored wider than 1 unit (the Base's, phase 9.1) would
## otherwise drain from the wrong side.
var _fill_width: float = 1.0


func _ready() -> void:
	# Detach from the parent's (spinning) transform; we position it manually.
	top_level = true
	if _fill.mesh is BoxMesh:
		_fill_width = _fill.mesh.size.x


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
	# Shrink from full while keeping the left edge pinned where it was.
	_fill.scale.x = maxf(ratio, 0.0001)
	_fill.position.x = (ratio - 1.0) * _fill_width * 0.5
