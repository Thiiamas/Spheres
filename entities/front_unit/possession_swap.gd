extends RefCounted
class_name PossessionSwap

## Possession complète FrontUnit <-> RuneMage (phase 8.2,
## Docs/Plans/phase8_foundations.md). A FrontUnit never joins the
## Consciousness pool itself — clicking one destroys it and spawns a fresh,
## player-controlled RuneMage in its place (and vice versa on release). Kept
## as a single static service rather than duplicated in every Controllable
## that can trigger a "select": Base and RuneMage both call
## try_select_at_cursor() when they see "select" pressed.

const RUNE_MAGE_SCENE := preload("res://entities/mage/rune_mage.tscn")
const ALLY_UNIT_SCENE := preload("res://entities/front_unit/ally_unit.tscn")


## Raycasts the ally layer under the cursor; if it hits something
## possessable (an ally FrontUnit, or an ALLY Base's SelectionArea), performs
## the swap/switch and returns true. Callers should treat true as "the click
## was consumed" and skip whatever else that same click would have done
## (e.g. Base's attack, also bound to left-click). Returns false when nothing
## possessable is under the cursor.
static func try_select_at_cursor(tree: SceneTree) -> bool:
	var cam: CameraRig = Consciousness.camera_rig
	if cam == null:
		return false
	var hit: Node3D = cam.raycast_at_cursor(Faction.ALLY_LAYER)
	if hit == null:
		return false

	if hit is FrontUnit:
		if hit.faction != Faction.Kind.ALLY:
			return false
		_release_current_mage(tree)
		var mage := possess_front_unit(hit, tree)
		Consciousness.request_possession(mage.controllable)
		return true

	var base := hit.get_parent() as Base
	if base != null and base.faction == Faction.Kind.ALLY and base.controllable != null:
		_release_current_mage(tree)
		Consciousness.request_possession(base.controllable)
		return true

	return false


## If a RuneMage is currently possessed, hand it back to the front as an
## autonomous FrontUnit before whatever the caller does next takes over.
static func _release_current_mage(tree: SceneTree) -> void:
	var active := Consciousness.active()
	var mage := active.entity as RuneMage if active != null else null
	if mage != null:
		release_to_front_unit(mage, tree)


## Destroys front_unit and spawns a RuneMage at its position, carrying over
## HP proportionally. The mage's Controllable self-registers with
## Consciousness the instant add_child() puts it in the tree
## (Controllable._ready()) — by the time this returns, mage.controllable is
## already a valid request_possession() target.
static func possess_front_unit(front_unit: FrontUnit, tree: SceneTree) -> RuneMage:
	var hp_ratio := front_unit.health.hp / front_unit.health.max_hp
	var pos := front_unit.global_position
	var faction := front_unit.faction
	front_unit.queue_free()

	var mage := RUNE_MAGE_SCENE.instantiate() as RuneMage
	mage.faction = faction
	tree.current_scene.add_child(mage)
	mage.global_position = pos
	mage.health.hp = mage.health.max_hp * hp_ratio
	return mage


## Inverse: a possessed RuneMage returns to being an autonomous FrontUnit at
## its current position/HP, resuming the front's siege targeting immediately
## (the same target_base/target_tower the player's Base hands its own waves).
static func release_to_front_unit(mage: RuneMage, tree: SceneTree) -> FrontUnit:
	var hp_ratio := mage.health.hp / mage.health.max_hp
	var pos := mage.global_position
	var faction := mage.faction
	if mage.controllable != null:
		Consciousness.unregister(mage.controllable)
	mage.queue_free()

	var base := find_ally_base()
	var unit := ALLY_UNIT_SCENE.instantiate() as FrontUnit
	unit.faction = faction
	unit.target_base = base.advance_target if base != null else null
	unit.target_tower = base.advance_target_tower if base != null else null
	tree.current_scene.add_child(unit)
	unit.global_position = pos
	unit.health.hp = unit.health.max_hp * hp_ratio
	return unit


## The player's own Base (there's exactly one in level2_front.tscn) — the
## fallback possession target on death (H3) and the source of
## advance_target/advance_target_tower when releasing a mage back to the front.
static func find_ally_base() -> Base:
	for c in Consciousness.entities:
		if is_instance_valid(c) and c.entity is Base and c.entity.faction == Faction.Kind.ALLY:
			return c.entity
	return null
