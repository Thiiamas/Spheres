extends CharacterBody3D
class_name Enemy

## Angular grey cube. Walks toward the active sphere on the XZ plane and bites
## any sphere that enters its attack zone (passive crystallised spheres take
## reduced damage and physically block the cube — see SphereController).

@export var speed: float = 3.5
@export var attack_damage: float = 8.0
@export var attack_cooldown: float = 1.2
@export var gravity: float = 18.0

@onready var _attack_zone: Area3D = $AttackZone

var _attack_timer: float = 0.0


func _physics_process(delta: float) -> void:
	_attack_timer -= delta

	var target := Consciousness.active_sphere()
	if target == null:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	# Chase the active sphere, but only on the horizontal plane.
	var to := target.global_position - global_position
	to.y = 0.0
	var dir := to.normalized() if to.length() > 0.001 else Vector3.ZERO
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta
	move_and_slide()

	# Bite whatever damageable sphere is in range (could be a passive blocker,
	# not the chase target). Re-checked each frame so contact deals repeat hits.
	if _attack_timer <= 0.0:
		_try_attack()


func _try_attack() -> void:
	for body in _attack_zone.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(attack_damage)
			_attack_timer = attack_cooldown
			return
