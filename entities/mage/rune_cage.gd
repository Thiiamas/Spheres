extends Node3D
class_name RuneCage

## Spell Z's visual (phase 6, Ryze Rune Prison-style): a ring of glowing bars
## around the rooted enemy, self-destructing when the root expires. Built
## entirely in code (no scene asset) and added as a child of the enemy so it
## follows — not that a rooted cube goes anywhere.

## Seconds before the cage crumbles (matched to the root duration by the mage).
var duration: float = 1.5

const BARS := 8
const RADIUS := 0.85
const HEIGHT := 1.6


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.8, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.3)
	mat.emission_energy_multiplier = 2.0

	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(0.08, HEIGHT, 0.08)

	for i in BARS:
		var bar := MeshInstance3D.new()
		bar.mesh = bar_mesh
		bar.material_override = mat
		var angle := TAU * float(i) / float(BARS)
		bar.position = Vector3(cos(angle) * RADIUS, HEIGHT * 0.5, sin(angle) * RADIUS)
		add_child(bar)

	# Top ring binding the bars together.
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = RADIUS - 0.06
	ring_mesh.outer_radius = RADIUS + 0.06
	ring.mesh = ring_mesh
	ring.material_override = mat
	ring.position = Vector3(0.0, HEIGHT, 0.0)
	add_child(ring)


func _process(delta: float) -> void:
	duration -= delta
	if duration <= 0.0:
		queue_free()
