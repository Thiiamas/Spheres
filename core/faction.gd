extends RefCounted
class_name Faction

## Shared faction contract for the front-line level (Docs/phase7_front.md):
## Base and FrontUnit both read/write Faction.Kind so a spawner and its units
## agree on sides without duplicating the enum.

enum Kind { ALLY, ENEMY }

## Physics layer each faction's FrontUnit body sits on. ENEMY reuses layer 2 —
## the same layer entities/enemy/enemy.tscn uses — so the RuneMage's existing
## hover-aim raycast (core/aim_strategy.gd's hardcoded ENEMY_MASK) and
## RuneBolt's projectile (collision_mask = 2) pick up front-line cubes without
## any change to the mage's spell code.
const FLOOR_LAYER := 1
const ALLY_LAYER := 4
const ENEMY_LAYER := 2


## The opposing side — used to know which group to hunt and which base to
## treat as "not mine" when checking a GoalZone intrusion.
static func opposite(kind: Kind) -> Kind:
	return Kind.ENEMY if kind == Kind.ALLY else Kind.ALLY


## Group name a FrontUnit of this faction joins, so the opposing faction can
## query get_tree().get_nodes_in_group(...) without a Consciousness-style
## registry.
static func group_name(kind: Kind) -> StringName:
	return &"front_ally" if kind == Kind.ALLY else &"front_enemy"


## Physics layer this faction's FrontUnit body occupies.
static func physics_layer(kind: Kind) -> int:
	return ALLY_LAYER if kind == Kind.ALLY else ENEMY_LAYER


## The opposing faction's physics layer — what a unit's AttackZone or a
## Base's GoalZone should watch for.
static func opposing_physics_layer(kind: Kind) -> int:
	return physics_layer(opposite(kind))
