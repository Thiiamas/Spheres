extends Node
class_name Controllable

## Possession contract. A Controllable is a small component NODE added as a
## child of any entity the consciousness can possess (sphere, RTS base,
## vehicle…). It adapts its parent entity to the possession layer:
## Consciousness registers, drives and releases Controllables — never concrete
## entity types.
##
## Why a child component and not a base class: GDScript is single-inheritance.
## SphereController extends RigidBody3D, a future vehicle would too, but an RTS
## base would be a plain Node3D — no single base class fits every entity root.
## The contract therefore lives in a child node that forwards to its parent.

## Camera configurations this entity offers, cycled with "camera_toggle".
## Index 0 is applied on possession.
@export var camera_configs: Array[CameraConfig] = []

## The entity this component adapts (its parent, resolved in _ready).
var entity: Node = null
## True while possessed. Subclass hooks must call super() to keep it accurate.
var input_enabled: bool = false

var _camera_index: int = 0


func _ready() -> void:
	entity = get_parent()
	# Join the possession pool. Consciousness decides who starts possessed;
	# until then the entity sits released (on_released is called on register).
	Consciousness.register(self)


## Current camera configuration (null when the entity defines none).
func get_camera_config() -> CameraConfig:
	if camera_configs.is_empty():
		return null
	return camera_configs[_camera_index]


## Advance to the entity's next camera configuration and return it.
func cycle_camera_config() -> CameraConfig:
	if camera_configs.is_empty():
		return null
	_camera_index = (_camera_index + 1) % camera_configs.size()
	return get_camera_config()


## Per-frame normalized input, pushed by the possession layer while possessed.
## Overriding subclasses should call super(ctx) — the base implementation
## resolves the meta actions that belong to the possession layer rather than to
## any single entity's gameplay (currently: buying upgrades).
func handle_input(ctx: InputContext) -> void:
	_handle_upgrade_keys(ctx)


## Spends the player's wallet on the possessed entity's upgrades (phase 9.2).
##
## Handled here, not in each entity's drive(), for the same reason "select" is:
## it's meta — it spends a shared, player-level resource and doesn't belong to
## any one entity's gameplay. Every possessable entity that exposes an
## `upgrades` array therefore gets buying with no per-entity plumbing, which is
## what lets 9.3's mage participate without duplicating this loop.
##
## Duck-typed via get(): entities with nothing to upgrade (sphere, beacon)
## simply return null and are skipped.
func _handle_upgrade_keys(ctx: InputContext) -> void:
	if entity == null:
		return
	var upgrades = entity.get(&"upgrades")
	if upgrades == null:
		return
	for i in mini(upgrades.size(), InputContext.UPGRADE_ACTIONS.size()):
		if ctx.just_pressed(InputContext.UPGRADE_ACTIONS[i]):
			Progression.try_buy(upgrades[i])


## The consciousness takes control of this entity.
func on_possessed() -> void:
	input_enabled = true


## The consciousness leaves this entity.
func on_released() -> void:
	input_enabled = false
