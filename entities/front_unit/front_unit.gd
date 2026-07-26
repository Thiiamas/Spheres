extends CharacterBody3D
class_name FrontUnit

## Foxhole-style front-line combatant (Docs/phase7_front.md). Self-contained —
## no Consciousness/GameManager coupling, so level 1's wave-defense loop
## (entities/enemy/enemy.gd) stays untouched.
##
## Advances toward the opposing Base; if a hostile FrontUnit comes within
## engage range along the way, it closes in and bites instead — two lines
## advancing toward each other meet and grind in between, which is the front.
##
## Steering stays direction_to()-style, no NavigationAgent3D (see
## Docs/PLAN.md "Hors scope v0.1"). Two mechanisms, in order of importance:
##
## 1. Surround offset: naively walking straight at hostile.global_position (or
##    target_base.global_position) means every unit converging on the same
##    target computes the exact same destination point — that single-point
##    convergence, not a lack of steering, is why a whole line queues up
##    directly behind whoever got there first. Each unit instead aims at a
##    fixed point on a ring around the goal, offset by an angle derived from
##    its own instance ID — stable across frames, no coordination needed — so
##    a crowd fans out around a target from the start instead of tunneling
##    into one spot.
## 2. Local avoidance: a short-range push away from every other unit nearby
##    (the current target excluded) mops up whatever residual crowding the
##    ring offset doesn't — e.g. two units whose ring slots happen to be close.

signal died(unit: FrontUnit)
## Fired the instant a hit lands (same moment _attacking_timer is armed) — for
## one-shot visual feedback (a flash, a lunge) that shouldn't retrigger every
## frame. For a continuous effect (glow, color shift) poll `is_attacking`
## instead. See Docs/front_unit_ai.md.
signal attack_started

const ENGAGE_RANGE := 6.0

@export var faction: Faction.Kind = Faction.Kind.ALLY
@export var speed: float = 3.5
@export var attack_damage: float = 8.0
## Time between the start of one attack and the next being allowed.
@export var attack_cooldown: float = 1.2
## League of Legends basic-attack feel: the unit plants itself for this long
## once an attack lands, same as attack_cooldown by default (busy for the
## whole swing) — lower it to let a unit start moving again before its next
## swing is off cooldown, LoL's "attack move" kiting window.
@export var attack_duration: float = 1.2
@export var gravity: float = 18.0
@export var max_hp: float = 40.0
## Distance from a goal (hostile or base) this unit's own ring slot sits at.
@export var surround_radius: float = 1.4
## Other units closer than this push this one sideways (its own hostile
## target is exempt — you're supposed to walk into what you're biting).
@export var avoidance_radius: float = 1.6
## How strongly the sideways push competes with the forward seek direction.
@export var avoidance_weight: float = 2.2
## Optional floating health bar (ui/hp_bar_3d.gd), same contract as
## SphereController's — duck-typed via has_method so it's fine if unset.
@export var hp_bar: Node3D

## The opposing base to advance toward when no hostile is in engage range.
## Base sets this right after instantiate(), before the unit enters the tree.
var target_base: Node3D = null

@onready var _attack_zone: Area3D = $AttackZone
@onready var _mesh: MeshInstance3D = $MeshInstance3D

## Per-instance duplicate of the mesh's ShaderMaterial (front_unit_attack.gdshader
## on both ally_unit.tscn and enemy_unit.tscn) — null if the mesh doesn't use
## one. Duplicated in _ready so driving attack_amount on one unit doesn't leak
## across every instance sharing the same underlying mesh resource.
var _attack_shader: ShaderMaterial = null

## True while mid-swing (see _attacking_timer / attack_duration) — read this
## from a shader-driving script or any other visual reactor to show the unit
## is attacking. Poll every frame; pair with attack_started for one-shot FX.
var is_attacking: bool:
	get:
		return _attacking_timer > 0.0

var hp: float = 0.0
var _attack_timer: float = 0.0
var _attacking_timer: float = 0.0
var _root_timer: float = 0.0
var _dead: bool = false


func _ready() -> void:
	hp = max_hp
	_update_hp_bar()
	add_to_group(Faction.group_name(faction))
	if faction == Faction.Kind.ENEMY:
		# Lets the RuneMage's spells (RuneBolt chain, RuneFlux spread) find
		# front-line cubes the same way they find level 1's Enemy — see
		# entities/mage/rune_bolt.gd:113, rune_flux.gd:76.
		add_to_group("enemies")
	collision_layer = Faction.physics_layer(faction)
	collision_mask = Faction.FLOOR_LAYER | Faction.ALLY_LAYER | Faction.ENEMY_LAYER
	_attack_zone.collision_mask = Faction.opposing_physics_layer(faction)

	var mat := _mesh.get_active_material(0)
	if mat is ShaderMaterial:
		_attack_shader = mat.duplicate()
		_mesh.material_override = _attack_shader


## Drives front_unit_attack.gdshader's attack_amount from is_attacking every
## rendered frame — kept separate from _physics_process, which only owns
## gameplay state (movement, combat timers), not visuals.
func _process(_delta: float) -> void:
	if _attack_shader != null:
		_attack_shader.set_shader_parameter("attack_amount", 1.0 if is_attacking else 0.0)


## RuneCage (spell Z): pin the unit in place for `duration`; it keeps biting
## whatever's in its AttackZone meanwhile. Mirrors entities/enemy/enemy.gd's
## `root`, which is the interface RuneMage checks with `has_method("root")`.
func root(duration: float) -> void:
	_root_timer = maxf(_root_timer, duration)


func _physics_process(delta: float) -> void:
	_attack_timer -= delta
	_attacking_timer -= delta
	_root_timer -= delta

	if _root_timer > 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		if _attack_timer <= 0.0:
			_try_attack()
		return

	if _attacking_timer > 0.0:
		# Planted for the swing (LoL basic-attack feel) — no seeking/avoidance
		# this frame, just settle under gravity until the attack finishes.
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			velocity.y = 0.0
		move_and_slide()
		return

	var hostile := _nearest_hostile()
	var goal_point: Vector3
	if hostile != null:
		goal_point = hostile.global_position
	elif target_base != null:
		goal_point = target_base.global_position
	else:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var move_goal := goal_point + _surround_offset()
	var to := move_goal - global_position
	to.y = 0.0
	var seek := to.normalized() if to.length() > 0.001 else Vector3.ZERO
	var blended := seek + _avoidance(hostile) * avoidance_weight
	var dir := blended.normalized() if blended.length() > 0.001 else seek
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta
	move_and_slide()

	if _attack_timer <= 0.0:
		_try_attack()


## Take damage from an opposing FrontUnit's bite. Reports its own death via
## `died` so its spawning Base can decrement its alive count.
func take_damage(amount: float) -> void:
	if _dead:
		return
	hp -= amount
	_update_hp_bar()
	if hp <= 0.0:
		_dead = true
		died.emit(self)
		queue_free()


func _update_hp_bar() -> void:
	if hp_bar and hp_bar.has_method("update_bar"):
		hp_bar.update_bar(hp, max_hp)


## Damage from the RuneMage's spells (RuneBolt direct hit and chain shards) —
## same interface as entities/enemy/enemy.gd's `take_hit`, checked with
## `has_method("take_hit")` in rune_bolt.gd:88.
func take_hit(damage: float) -> void:
	take_damage(damage)


## Closest hostile FrontUnit within engage range, found via the opposing
## faction's group — no physics query, mirrors enemy.gd's Consciousness scan.
func _nearest_hostile() -> FrontUnit:
	var best: FrontUnit = null
	var best_dist := ENGAGE_RANGE * ENGAGE_RANGE
	var opposing_group := Faction.group_name(Faction.opposite(faction))
	for node in get_tree().get_nodes_in_group(opposing_group):
		var unit := node as FrontUnit
		if unit == null or not is_instance_valid(unit):
			continue
		var to := unit.global_position - global_position
		to.y = 0.0
		var d := to.length_squared()
		if d < best_dist:
			best_dist = d
			best = unit
	return best


## Stable per-instance point on a ring of radius surround_radius, so many
## units converging on the same goal each aim at their own spot around it
## instead of all computing the identical destination point.
func _surround_offset() -> Vector3:
	var angle := float(get_instance_id() % 360) * (TAU / 360.0)
	return Vector3(cos(angle), 0.0, sin(angle)) * surround_radius


## Short-range separation from every other FrontUnit (either faction) within
## avoidance_radius, stronger the closer they are, zero at and beyond it.
## `exclude` is the unit's own hostile target, if any — it should be walked
## into, not avoided.
func _avoidance(exclude: FrontUnit) -> Vector3:
	var push := Vector3.ZERO
	for group in [Faction.group_name(Faction.Kind.ALLY), Faction.group_name(Faction.Kind.ENEMY)]:
		for node in get_tree().get_nodes_in_group(group):
			var other := node as FrontUnit
			if other == null or other == self or other == exclude or not is_instance_valid(other):
				continue
			var away := global_position - other.global_position
			away.y = 0.0
			var dist := away.length()
			if dist > 0.001 and dist < avoidance_radius:
				push += away.normalized() * (1.0 - dist / avoidance_radius)
	return push


func _try_attack() -> void:
	for body in _attack_zone.get_overlapping_bodies():
		if body is FrontUnit and body.faction != faction:
			body.take_damage(attack_damage)
			_attack_timer = attack_cooldown
			_attacking_timer = attack_duration
			attack_started.emit()
			return
