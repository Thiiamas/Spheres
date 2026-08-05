extends Controllable
class_name BaseControllable

## Possession contract of the RTS Base (phase 8.1). Sibling of the existing
## Base spawner (entities/base/base.tscn), like SphereControllable is for
## Sphere.tscn (phase 5) — Consciousness only ever talks to this contract,
## Base keeps owning its own combat/economy state.
##
## base.tscn is shared by both sides (PlayerBase and EnemyBase in
## level2_front.tscn), so this guards registration by faction: only an
## ALLY-faction Base joins the possession pool. An enemy Base has no
## Controllable-side behaviour to gate otherwise (it never calls drive()),
## but staying out of Consciousness.entities also keeps it out of the
## Tab-transfer cycle.

var base: Base = null


func _ready() -> void:
	base = get_parent() as Base
	if base != null and base.faction != Faction.Kind.ALLY:
		return # enemy bases are never possessable
	super()


func handle_input(ctx: InputContext) -> void:
	if base != null:
		base.drive(ctx)
