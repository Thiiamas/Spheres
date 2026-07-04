extends CharacterBody3D
class_name Enemy

## Angular grey cube. Walks toward the *nearest* sphere on the XZ plane and bites
## any sphere that enters its attack zone (passive crystallised spheres take
## reduced damage and physically block the cube — see SphereController).
##
## Targeting the closest sphere (not the active one) is what makes positioning a
## skill: keep the active sphere — which takes full damage — away from enemies,
## let the tanky passive spheres absorb hits, and switch when it's safe.

@export var speed: float = 3.5
@export var attack_damage: float = 8.0
@export var attack_cooldown: float = 1.2
@export var gravity: float = 18.0
## Hit points; depleted by player projectiles (take_hit).
@export var hp: float = 40.0

@onready var _attack_zone: Area3D = $AttackZone

var _attack_timer: float = 0.0
var _root_timer: float = 0.0
var _dead: bool = false


func _ready() -> void:
	# Lets area spells (RuneBolt chain, RuneFlux spread) find nearby cubes
	# without physics queries.
	add_to_group("enemies")


## Root the cube in place (RuneMage's cage, phase 6): movement is locked for
## the duration but it keeps biting whatever stands in its attack zone.
func root(duration: float) -> void:
	_root_timer = maxf(_root_timer, duration)


func _physics_process(delta: float) -> void:
	_attack_timer -= delta
	_root_timer -= delta

	# Rooted: pinned to the spot, gravity and bites still apply.
	if _root_timer > 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		if _attack_timer <= 0.0:
			_try_attack()
		return

	var target := _nearest_sphere()
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


## Take damage from a player projectile. Reports its death to GameManager so the
## wave counter advances.
func take_hit(damage: float) -> void:
	if _dead:
		return
	hp -= damage
	if hp <= 0.0:
		_dead = true
		GameManager.on_enemy_died()
		queue_free()


## Closest sphere by horizontal (XZ) distance — enemies move on the ground, so
## reachability is what matters, not a sphere that's flown overhead. The
## possession pool can hold non-sphere entities (bases…); cubes only ever hunt
## spheres, so anything else is filtered out.
func _nearest_sphere() -> SphereController:
	var best: SphereController = null
	var best_dist := INF
	for c in Consciousness.entities:
		if not is_instance_valid(c):
			continue
		var s := c.entity as SphereController
		if s == null or not is_instance_valid(s):
			continue
		var to := s.global_position - global_position
		to.y = 0.0
		var d := to.length_squared()
		if d < best_dist:
			best_dist = d
			best = s
	return best


func _try_attack() -> void:
	for body in _attack_zone.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(attack_damage)
			_attack_timer = attack_cooldown
			return
