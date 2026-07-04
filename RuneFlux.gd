extends Node3D
class_name RuneFlux

## Spell E (phase 6, Ryze Spell Flux-style): a homing projectile cast on the
## enemy under the cursor. It chases its target and, on arrival, attaches a
## RuneMark to it (child node named "RuneMark", orbiting orb) for a few
## seconds — RuneBolt (spell A) deals amplified damage to marked enemies.

## Safety fuse if the target becomes unreachable.
@export var lifetime: float = 3.0

var _target: Node3D = null
var _speed: float = 20.0
var _mark_duration: float = 4.0
var _time: float = 0.0


## Aim at the clicked enemy. Called by RuneMage right after instantiation.
func launch(target: Node3D, speed: float, mark_duration: float) -> void:
	_target = target
	_speed = speed
	_mark_duration = mark_duration


func _physics_process(delta: float) -> void:
	_time += delta
	if _time >= lifetime or _target == null or not is_instance_valid(_target):
		queue_free()
		return

	var to := _target.global_position + Vector3.UP * 0.5 - global_position
	var step := _speed * delta
	if to.length() <= step + 0.3:
		_attach()
		return
	global_position += to.normalized() * step


## Arrived: mark the target (or refresh an existing mark) and vanish.
func _attach() -> void:
	var existing := _target.get_node_or_null("RuneMark")
	if existing is RuneMark:
		existing.refresh(_mark_duration)
	else:
		var mark := RuneMark.new()
		mark.name = "RuneMark"
		mark.duration = _mark_duration
		_target.add_child(mark)
	queue_free()
