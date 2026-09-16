extends Node3D
class_name EscortGate

## Reusable "objective" behavior (Docs/front/tower.md): an entity guarded by an
## EscortGate is only vulnerable while a hostile FrontUnit is inside its
## detection range, and fights back periodically either way (phase 10.2,
## Docs/Plans/phase10_meso_poc.md) — at the escorting FrontUnit while one is
## present, at an unescorted attacker lingering in range otherwise. Knows
## nothing about HP — pair it with a sibling Health and let the host decide
## how the two interact (see entities/tower/tower.gd).
##
## Instance escort_gate.tscn as a child of any host and call configure()
## from the host's own _ready(). Godot readies children before parents, so
## an @export faction set by the host wouldn't be visible yet inside this
## component's own _ready() — configure() sidesteps that by being an
## explicit call the host makes once its own _ready() actually runs.

@export var detection_radius: float = 6.0

@export_group("Retaliation")
## When true, this gate fights back periodically: at a hostile FrontUnit
## sieging it if one is in range (phase 10.2 — a siege is no longer free),
## otherwise at an unescorted attacker lingering in range (a MOBA turret
## punishing a solo dive). Same cooldown, same damage, same projectile for
## both — see _physics_process below for how the target is picked.
@export var retaliation_enabled: bool = true
@export var retaliation_damage: float = 12.0
@export var retaliation_cooldown: float = 1.5
## Scene fired at an unescorted attacker (e.g. entities/tower/tower_bolt.tscn)
## — a visible telegraph instead of the hit landing instantly with no
## warning. Duck-typed via has_method("launch") so this component never
## needs to know the concrete projectile class. Left null: falls back to
## instant damage, no visual.
@export var retaliation_projectile: PackedScene
@export var retaliation_projectile_speed: float = 14.0
## Spawn height above this node's origin — hosts are usually rooted at
## ground level, so the bolt should leave from around the structure's top.
@export var muzzle_height: float = 3.0

@export_group("AOE Retaliation")
## Independent mechanic added in phase 10.2 (Docs/Plans/phase10_meso_poc.md):
## while a hostile player is anywhere in detection range, this gate
## periodically lobs a shell at their CURRENT position — telegraphed, so
## standing still is what gets punished, not merely being nearby. Unlike
## the retaliation above, this is NOT gated by is_protected(): pushing with
## an escort no longer makes the player entirely safe from the Tower, which
## is the whole point (added at the user's request to give sieges more
## danger — the single-target retaliation alone read as toothless against a
## push once it also had to compete with the anti-siege branch above for
## the same timer). Runs on its own cooldown, so both can land independently.
@export var aoe_enabled: bool = true
@export var aoe_damage: float = 8.0
@export var aoe_radius: float = 3.0
@export var aoe_cooldown: float = 4.0
## e.g. entities/tower/tower_shell.tscn (TowerShell, a MortarShell subclass
## that calls take_damage instead of take_hit — see that script for why).
@export var aoe_shell: PackedScene
@export var aoe_flight_time: float = 1.1
## Cosmetic dome shown where the shell lands (e.g. tower_aoe_blast.tscn) —
## reuses AoeBlast as-is via PackedScene, same duck-typed play(radius) as
## MortarShell's own blast_scene.
@export var aoe_blast: PackedScene
## How far the gate can spot a hostile player to lob the AOE at, separate
## from detection_radius (playtest feedback: the AOE should reach further
## than the melee-range siege detection it originally piggybacked on, so it
## can threaten a player before they're already on top of the Tower). Its
## own zone (AoeZone) rather than resizing DetectionZone, so widening this
## doesn't also widen is_protected()'s range or the single-target branch's.
@export var aoe_range: float = 12.0

@onready var _zone: Area3D = $DetectionZone
@onready var _shape: CollisionShape3D = $DetectionZone/CollisionShape3D
@onready var _aoe_zone: Area3D = $AoeZone
@onready var _aoe_shape: CollisionShape3D = $AoeZone/CollisionShape3D

var _faction: Faction.Kind = Faction.Kind.ENEMY
var _configured: bool = false
var _retaliation_timer: float = 0.0
var _aoe_timer: float = 0.0


## Called once by the host's _ready(). Duplicates the shape resource first —
## sibling hosts (e.g. PlayerTower/EnemyTower) both instancing this same
## scene would otherwise share one SubResource and resize each other's zone.
func configure(faction: Faction.Kind) -> void:
	_faction = faction
	_zone.collision_mask = Faction.opposing_physics_layer(faction) | Faction.PLAYER_LAYER
	var shape := (_shape.shape as SphereShape3D).duplicate() as SphereShape3D
	shape.radius = detection_radius
	_shape.shape = shape

	# AoeZone only ever needs to find the player (_find_hostile_player already
	# ignores FrontUnit outright), so its mask stays narrower than DetectionZone's.
	_aoe_zone.collision_mask = Faction.PLAYER_LAYER
	var aoe_shape := (_aoe_shape.shape as SphereShape3D).duplicate() as SphereShape3D
	aoe_shape.radius = aoe_range
	_aoe_shape.shape = aoe_shape

	_configured = true


## True while a hostile FrontUnit (relative to this gate's faction) is inside
## detection range. The single condition driving both effects: the host
## should check it before forwarding damage to its Health, and it's what
## suppresses retaliation below — pushing your wave here both enables damage
## on the guarded target and stops the punishment.
func is_protected() -> bool:
	for body in _zone.get_overlapping_bodies():
		if body is FrontUnit and body.faction == Faction.opposite(_faction):
			return true
	return false


func _physics_process(delta: float) -> void:
	if not _configured:
		return

	if retaliation_enabled:
		_retaliation_timer -= delta
		if _retaliation_timer <= 0.0:
			# is_protected() being true is exactly "a hostile FrontUnit is
			# sieging this gate" — before phase 10.2 that only suppressed the
			# player-directed branch below; now it's also the trigger for the
			# branch that used to be missing entirely, which is why a siege
			# used to look like it did nothing.
			var target: Node = _find_hostile_front_unit() if is_protected() else _find_hostile_player(_zone)
			if target != null:
				_fire_at(target)
				_retaliation_timer = retaliation_cooldown

	if aoe_enabled:
		_aoe_timer -= delta
		if _aoe_timer <= 0.0:
			# Not gated by is_protected(): unlike the branch above, an escort
			# doesn't make the player safe from this one (phase 10.2 — see
			# the aoe_enabled doc comment for why). Its own, longer-range
			# zone (aoe_range), not DetectionZone.
			var player := _find_hostile_player(_aoe_zone)
			if player != null:
				_fire_aoe_at(player.global_position)
				_aoe_timer = aoe_cooldown


## The first hostile FrontUnit (relative to this gate's faction) in range —
## same condition as is_protected(), just returning the body instead of a
## bool. Picked whenever such a unit is present: a siege is no longer a free
## chip-away (phase 10.2, Docs/Plans/phase10_meso_poc.md).
func _find_hostile_front_unit() -> Node:
	for body in _zone.get_overlapping_bodies():
		if body is FrontUnit and body.faction == Faction.opposite(_faction):
			return body
	return null


## The first damage-capable body in `zone` that isn't itself a FrontUnit and
## isn't on this gate's own side — i.e. the enemy player, never an ally one.
## Takes the zone to search rather than always reading _zone: the
## single-target branch above calls it with _zone (unchanged range), the AOE
## branch with _aoe_zone (its own, wider range) — the function itself
## doesn't know or care which, or whether the caller is gated by
## is_protected(). `faction` is duck-typed via the `in` operator (a property
## check, not a method call) so this stays agnostic of the concrete detected
## type (RuneMage today) — a body without a `faction` field is never
## excluded, fail-open rather than fail-closed. Physics layer
## (Faction.PLAYER_LAYER) already narrowed the zone's overlaps down to "this
## is a player-controlled entity"; faction is the separate, semantic check
## for "which side".
func _find_hostile_player(zone: Area3D) -> Node:
	for body in zone.get_overlapping_bodies():
		if body is FrontUnit:
			continue
		if not body.has_method("take_damage"):
			continue
		if "faction" in body and body.faction == _faction:
			continue
		return body
	return null


func _fire_at(target: Node) -> void:
	if retaliation_projectile == null:
		target.take_damage(retaliation_damage)
		return
	var bolt := retaliation_projectile.instantiate()
	get_tree().current_scene.add_child(bolt)
	bolt.global_position = global_position + Vector3.UP * muzzle_height
	if bolt.has_method("launch"):
		bolt.launch(target, retaliation_projectile_speed, retaliation_damage)


## Lobs aoe_shell at target_pos (the player's position at the moment of
## firing, not tracked afterward — the shell doesn't home, so moving away
## during its flight is how a player dodges it).
func _fire_aoe_at(target_pos: Vector3) -> void:
	if aoe_shell == null:
		return
	var shell := aoe_shell.instantiate()
	get_tree().current_scene.add_child(shell)
	shell.global_position = global_position + Vector3.UP * muzzle_height
	if shell is MortarShell:
		shell.damage_mask = Faction.PLAYER_LAYER
		shell.setup(target_pos, aoe_radius, aoe_damage, aoe_flight_time, aoe_blast)
