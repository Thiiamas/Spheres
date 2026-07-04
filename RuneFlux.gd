extends Node3D
class_name RuneFlux

## Spell E (phase 6, Ryze Spell Flux-style): a homing projectile cast on the
## enemy under the cursor. It chases its target and, on arrival, attaches a
## RuneMark to it (child node named "RuneMark", orbiting orb) — RuneBolt
## (spell A) deals amplified damage to marked enemies and chains between them.
##
## Recast on an ALREADY MARKED enemy: the mark refreshes and SPREADS —
## secondary fluxes fly from the carrier to every enemy in spread_radius and
## mark them too. Secondary fluxes never spread themselves (one ring per
## recast, no cascading ping-pong).

## Safety fuse if the target becomes unreachable.
@export var lifetime: float = 3.0

var _target: Node3D = null
var _speed: float = 20.0
var _mark_duration: float = 4.0
var _spread_radius: float = 0.0
var _can_spread: bool = true
var _time: float = 0.0

# The scene used to spawn secondary fluxes (handed in by the caster — avoids
# a script<->scene preload cycle).
var _scene: PackedScene = null


## Aim at the clicked enemy. Called by RuneMage (and by the spread, with
## can_spread = false).
func launch(target: Node3D, speed: float, mark_duration: float,
		spread_radius: float, can_spread: bool, scene: PackedScene) -> void:
	_target = target
	_speed = speed
	_mark_duration = mark_duration
	_spread_radius = spread_radius
	_can_spread = can_spread
	_scene = scene


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


## Arrived: mark the target — or, if it already carries a mark, refresh it and
## contaminate the neighbourhood.
func _attach() -> void:
	var existing := _target.get_node_or_null("RuneMark")
	if existing is RuneMark:
		existing.refresh(_mark_duration)
		if _can_spread and _spread_radius > 0.0:
			_spread_from(_target)
	else:
		var mark := RuneMark.new()
		mark.name = "RuneMark"
		mark.duration = _mark_duration
		_target.add_child(mark)
	queue_free()


## One ring of contagion: a secondary (non-spreading) flux flies from the
## carrier to every other enemy in radius, marking or refreshing each.
func _spread_from(carrier: Node3D) -> void:
	if _scene == null:
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == carrier or not is_instance_valid(enemy):
			continue
		if (enemy.global_position - carrier.global_position).length() > _spread_radius:
			continue
		var flux := _scene.instantiate()
		get_tree().current_scene.add_child(flux)
		flux.global_position = carrier.global_position + Vector3.UP * 0.5
		if flux is RuneFlux:
			flux.launch(enemy, _speed, _mark_duration, 0.0, false, _scene)
