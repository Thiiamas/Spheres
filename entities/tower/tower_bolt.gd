extends Node3D
class_name TowerBolt

## Visual carrier for an EscortGate's retaliation strike (Docs/front/tower.md):
## homes onto whoever triggered it and deals damage on arrival, instead of
## the hit landing instantly with no warning. Mirrors entities/mage/rune_flux.gd's
## homing-projectile shape.

## Safety fuse if the target becomes unreachable (dies mid-flight, etc.).
@export var lifetime: float = 3.0

var _target: Node3D = null
var _speed: float = 14.0
var _damage: float = 0.0
var _time: float = 0.0


## Called by EscortGate the instant a retaliation strike is decided.
func launch(target: Node3D, speed: float, damage: float) -> void:
	_target = target
	_speed = speed
	_damage = damage


func _physics_process(delta: float) -> void:
	_time += delta
	if _time >= lifetime or _target == null or not is_instance_valid(_target):
		queue_free()
		return

	var to := _target.global_position + Vector3.UP * 0.5 - global_position
	var step := _speed * delta
	if to.length() <= step + 0.3:
		_hit()
		return
	global_position += to.normalized() * step


func _hit() -> void:
	if is_instance_valid(_target) and _target.has_method("take_damage"):
		_target.take_damage(_damage)
	queue_free()
