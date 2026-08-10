extends Controllable
class_name BeaconControllable

## Possession contract of the shore beacon — the proof-of-abstraction entity: a
## static, non-sphere possessable. It has no movement, no reactor, no combat;
## possessing it simply lights its crystal and hands the camera its top-down
## config. If Consciousness, the CameraRig and the HUD accept it without any
## change on their side, the possession abstraction holds.

## Crystal whose emission signals possession (bright = inhabited, dim = empty).
@export var crystal: MeshInstance3D

# Per-instance copy of the crystal material so the glow is per-beacon.
var _mat: StandardMaterial3D = null


func _ready() -> void:
	if crystal != null:
		var mat := crystal.get_active_material(0)
		if mat is StandardMaterial3D:
			_mat = mat.duplicate()
			crystal.material_override = _mat
	# Resolve entity and register with Consciousness (which immediately calls
	# on_released — the beacon starts dim until possessed).
	super()


## A beacon is a vantage point, not a fighter: input is simply ignored.
func handle_input(ctx: InputContext) -> void:
	super(ctx)


func on_possessed() -> void:
	super()
	_set_glow(2.2)


func on_released() -> void:
	super()
	_set_glow(0.35)


func _set_glow(energy: float) -> void:
	if _mat == null:
		return
	_mat.emission_enabled = true
	_mat.emission = _mat.albedo_color
	_mat.emission_energy_multiplier = energy
