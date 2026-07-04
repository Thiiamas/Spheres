extends Node3D
class_name RuneMark

## The mark left by spell E (RuneFlux): a small emissive orb that orbits the
## enemy it is attached to, then expires. Its mere presence is the gameplay
## state — RuneBolt checks for a child named "RuneMark" to amplify its damage.
## The visual is built in code (no scene asset needed); RuneFlux adds this node
## as a child of the enemy and names it "RuneMark".

## Seconds before the mark expires (refreshed if the enemy is marked again).
var duration: float = 4.0
var orbit_radius: float = 0.8
## Radians per second around the carrier.
var orbit_speed: float = TAU * 1.2
var orbit_height: float = 0.6

var _angle: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	# Build the orbiting orb visual.
	var orb := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.14
	mesh.height = 0.28
	orb.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.8, 0.5, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.5, 1.0)
	mat.emission_energy_multiplier = 2.5
	orb.material_override = mat
	add_child(orb)


## Re-marking an already marked enemy restarts the clock.
func refresh(new_duration: float) -> void:
	duration = new_duration
	_time = 0.0


func _process(delta: float) -> void:
	_time += delta
	if _time >= duration:
		queue_free()
		return
	_angle += orbit_speed * delta
	position = Vector3(cos(_angle) * orbit_radius, orbit_height, sin(_angle) * orbit_radius)
