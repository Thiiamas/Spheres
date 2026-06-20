extends Node3D
class_name AoeBlast

## Purely cosmetic: an expanding translucent dome that visualises an AOE blast,
## fading out as it grows, then frees itself. Damage is dealt by the caster; this
## just shows the radius.

@export var duration: float = 0.35

var _radius: float = 5.0
var _elapsed: float = 0.0
var _material: StandardMaterial3D

@onready var _mesh: MeshInstance3D = $MeshInstance3D


## Set the blast's final radius (matches the caster's aoe_radius).
func play(radius: float) -> void:
	_radius = radius


func _ready() -> void:
	# Own a private material copy so fading doesn't touch the shared resource.
	var m := _mesh.get_active_material(0)
	if m is StandardMaterial3D:
		_material = m.duplicate()
		_mesh.material_override = _material


func _process(delta: float) -> void:
	_elapsed += delta
	var t := _elapsed / duration
	if t >= 1.0:
		queue_free()
		return

	# Mesh is a unit-radius sphere, so scale == world radius.
	var s := maxf(_radius * t, 0.001)
	_mesh.scale = Vector3(s, s, s)

	if _material:
		var fade := 1.0 - t
		_material.albedo_color.a = 0.45 * fade
		_material.emission_energy_multiplier = 2.0 * fade
