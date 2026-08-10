extends Node3D
class_name ResourceMote

## Purely cosmetic (phase 9.1 finitions, Docs/Plans/phase9_micro_poc.md): a
## small glowing mote that arcs from a kill to the base that banked it, so the
## resource gain reads as flowing home instead of just incrementing the HUD.
##
## Deliberately never touches Economy: LootOnDeath credits the player the
## instant the enemy dies (H4 of the phase 8 plan), so a mote that gets lost —
## or whose target base dies mid-flight — cannot cost the player anything.

@export var travel_time: float = 0.9
@export var arc_height: float = 2.0
@export var size: float = 0.22
@export var color: Color = Color(1.0, 0.85, 0.3)

var _target: Node3D = null
var _target_point: Vector3 = Vector3.ZERO
var _start: Vector3 = Vector3.ZERO
var _elapsed: float = 0.0
var _mesh: MeshInstance3D = null


## Configure right after instancing AND positioning (global_position is read
## here as the launch origin, same order MortarShell.setup expects). `target`
## is followed live, so a base that moves still receives its mote; if it goes
## away, the mote finishes travelling to where it last was.
func setup(target: Node3D) -> void:
	_start = global_position
	_target = target
	if target != null and is_instance_valid(target):
		_target_point = target.global_position + Vector3.UP * 1.5
	else:
		_target_point = _start


func _ready() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = size
	sphere.height = size * 2.0

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0

	_mesh = MeshInstance3D.new()
	_mesh.mesh = sphere
	_mesh.material_override = mat
	add_child(_mesh)


func _process(delta: float) -> void:
	_elapsed += delta
	var t := clampf(_elapsed / travel_time, 0.0, 1.0)

	if _target != null and is_instance_valid(_target):
		_target_point = _target.global_position + Vector3.UP * 1.5

	var pos := _start.lerp(_target_point, t)
	pos.y += arc_height * 4.0 * t * (1.0 - t) # parabola, apex at t = 0.5
	global_position = pos

	# Shrink into the base over the last quarter of the flight rather than
	# blinking out on arrival.
	var shrink := 1.0 if t < 0.75 else 1.0 - (t - 0.75) / 0.25
	_mesh.scale = Vector3.ONE * maxf(shrink, 0.001)

	if t >= 1.0:
		queue_free()
