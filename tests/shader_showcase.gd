extends Node3D

## Space toggles ActiveSphere (and the shared HeroSphere) between the
## sphere-world amber and cube-world green "consciousness" palette. R toggles
## DestroyedSphere's dissolve/reconstruct animation. Both demo the tween
## patterns from the showcase design briefing without any gameplay wiring.

const RED_BASE := Color(0.47598857, 0.3510271, 0.0)
const RED_RIM := Color(0.89243644, 0.4952876, 0.0)
const RED_RING := Color(0.86177963, 0.777099, 0.0)
const GREEN_BASE := Color(0.04, 0.45, 0.10)
const GREEN_RIM := Color(0.2, 1.0, 0.35)
const GREEN_RING := Color(0.4, 1.0, 0.55)

@onready var active_sphere: MeshInstance3D = $ZoneSpherique/ActiveSphere
@onready var destroyed_sphere: MeshInstance3D = $ZoneSpherique/DestroyedSphere

var _is_green := false
var _is_destroyed := false

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	if event.keycode == KEY_SPACE:
		_is_green = not _is_green
		switch_conscience(active_sphere, _is_green)
	elif event.keycode == KEY_R:
		_is_destroyed = not _is_destroyed
		if _is_destroyed:
			destroy_sphere(destroyed_sphere)
		else:
			reconstruct_sphere(destroyed_sphere)

func switch_conscience(sphere: MeshInstance3D, to_green: bool) -> void:
	var mat: ShaderMaterial = sphere.get_surface_override_material(0)
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if to_green:
		tw.tween_method(func(c): mat.set_shader_parameter("base_color", c), RED_BASE, GREEN_BASE, 1.2)
		tw.parallel().tween_method(func(c): mat.set_shader_parameter("rim_color", c), RED_RIM, GREEN_RIM, 1.2)
		tw.parallel().tween_method(func(c): mat.set_shader_parameter("ring_color", c), RED_RING, GREEN_RING, 1.2)
	else:
		tw.tween_method(func(c): mat.set_shader_parameter("base_color", c), GREEN_BASE, RED_BASE, 1.2)
		tw.parallel().tween_method(func(c): mat.set_shader_parameter("rim_color", c), GREEN_RIM, RED_RIM, 1.2)
		tw.parallel().tween_method(func(c): mat.set_shader_parameter("ring_color", c), GREEN_RING, RED_RING, 1.2)

func destroy_sphere(sphere: MeshInstance3D) -> void:
	var mat: ShaderMaterial = sphere.get_surface_override_material(0)
	create_tween().tween_method(func(v): mat.set_shader_parameter("dissolve_amount", v), 0.0, 1.0, 1.4)

func reconstruct_sphere(sphere: MeshInstance3D) -> void:
	var mat: ShaderMaterial = sphere.get_surface_override_material(0)
	create_tween().tween_method(func(v): mat.set_shader_parameter("dissolve_amount", v), 1.0, 0.0, 1.4)
