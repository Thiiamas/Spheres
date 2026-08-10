extends Resource
class_name Upgrade

## One purchasable, permanent improvement — pure data, no behaviour (phase 9.2,
## Docs/Plans/phase9_micro_poc.md). Authored as .tres files exactly like
## CameraConfig (phase 5): the entity that owns the stat decides what a level
## is worth, this only says how much a level costs and how many there are.

## Stable key the owning entity matches on (e.g. &"mortar_rate"). Never derive
## behaviour from display_name or from the resource's position in a list —
## reordering an inspector array must not silently change what an upgrade does.
@export var id: StringName = &""
## Shown in the debug HUD next to its buy key.
@export var display_name: String = ""
@export var max_level: int = 5
@export var cost_base: int = 20
## Each level bought makes the next one this much pricier.
@export var cost_step: int = 10
## What ONE level is worth, interpreted by the owning entity: a fraction for a
## rate (0.08 = -8% cooldown per level), a flat amount for damage or HP, a
## whole number for a slot count. Progression only multiplies it by the level.
@export var per_level: float = 0.08


## Cost of moving from `level` to `level + 1`.
func cost_at(level: int) -> int:
	return cost_base + level * cost_step
