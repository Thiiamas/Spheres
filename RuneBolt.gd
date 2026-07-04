extends Area3D
class_name RuneBolt

## Spell A (phase 6, Ryze Overload-style): straight line projectile cast toward
## the cursor. Damages the first enemy it touches; if that enemy carries a
## RuneMark (spell E, a child node named "RuneMark"), damage is multiplied —
## the core spell synergy of the kit.

## Seconds before the bolt fizzles if it hits nothing.
@export var lifetime: float = 2.0

var _dir: Vector3 = Vector3.ZERO
var _speed: float = 26.0
var _damage: float = 25.0
var _mark_multiplier: float = 2.0
var _time: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


## Aim and arm the bolt. Called by RuneMage right after instantiation.
func launch(dir: Vector3, damage: float, speed: float, mark_multiplier: float) -> void:
	_dir = dir.normalized()
	_damage = damage
	_speed = speed
	_mark_multiplier = mark_multiplier


func _physics_process(delta: float) -> void:
	global_position += _dir * _speed * delta
	_time += delta
	if _time >= lifetime:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if not body.has_method("take_hit"):
		return
	var dmg := _damage
	# Marked target (spell E attached a RuneMark child): amplified hit.
	if body.get_node_or_null("RuneMark") != null:
		dmg *= _mark_multiplier
	body.take_hit(dmg)
	queue_free()
