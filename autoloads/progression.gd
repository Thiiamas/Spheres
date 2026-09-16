extends Node

## Which upgrades the player has bought, and how many levels of each (phase 9.2,
## Docs/Plans/phase9_micro_poc.md). Spends through the Economy autoload, which
## stays the single shared wallet (D1) — improving the Base or the possessed
## unit competes for the same resources.
##
## Why an autoload rather than state on the entity: PossessionSwap destroys the
## FrontUnit and instantiates a fresh entity in its place, so anything stored on
## the instance dies at the next swap. Same reasoning that made CameraRig's
## _zoom/_yaw rig state instead of config state — this is PLAYER state. It also
## matches the fiction: the consciousness grows stronger, bodies are disposable.
##
## Entities never read _levels directly. They implement apply_progression() and
## are re-applied on `changed`, recomputing their stats from authored baselines.

signal changed

## Level per upgrade, keyed "<scope>/<id>". The scope dimension exists from day
## one so per-unit upgrades can be added later without touching a single caller
## (D2): today everything is bought and read at &"global", and a future
## per-unit track just passes a different scope.
var _levels: Dictionary = {}


func level_of(id: StringName, scope: StringName = &"global") -> int:
	return _levels.get(_key(id, scope), 0)


## Accumulated effect of this upgrade: level × its per_level. The caller decides
## what the number means (see Upgrade.per_level).
func bonus(up: Upgrade, scope: StringName = &"global") -> float:
	if up == null:
		return 0.0
	return float(level_of(up.id, scope)) * up.per_level


## Accumulated bonus for `id` among the upgrades an entity actually offers, or
## 0.0 when it offers no such upgrade — which is what keeps an entity with an
## empty array (the enemy Base) on its authored stats.
##
## Lives here rather than being rewritten as a private helper in every
## apply_progression(): the lookup is identical for each of them, and an entity
## matching on `id` instead of array position is the invariant that lets its
## `upgrades` array be reordered freely (see Upgrade.id).
func bonus_of(upgrades: Array[Upgrade], id: StringName, scope: StringName = &"global") -> float:
	for up in upgrades:
		if up != null and up.id == id:
			return bonus(up, scope)
	return 0.0


## The debug-HUD block for an entity's `upgrades` array — one line per buy key,
## carrying the level, the cap and the price of the next one.
##
## Also here rather than in each entity's get_hud_lines(): every field it prints
## is this autoload's to know, and the Base and the RuneMage would otherwise
## render the same thing twice and drift apart.
func hud_lines(upgrades: Array[Upgrade], scope: StringName = &"global") -> Array[String]:
	var lines: Array[String] = []
	for i in mini(upgrades.size(), InputContext.UPGRADE_ACTIONS.size()):
		var up: Upgrade = upgrades[i]
		if up == null:
			continue
		var level := level_of(up.id, scope)
		if level >= up.max_level:
			lines.append("  %d: %s  MAX (%d)" % [i + 1, up.display_name, level])
		else:
			lines.append("  %d: %s  %d/%d  cout %d" % [
				i + 1, up.display_name, level, up.max_level, up.cost_at(level)])
	return lines


## What the next level of this upgrade costs right now.
func cost_of(up: Upgrade, scope: StringName = &"global") -> int:
	if up == null:
		return 0
	return up.cost_at(level_of(up.id, scope))


func is_maxed(up: Upgrade, scope: StringName = &"global") -> bool:
	if up == null:
		return true
	return level_of(up.id, scope) >= up.max_level


## Buys one level if it's available and affordable. Returns whether it went
## through, so a caller can play a rejection cue — nothing is spent on failure
## (Economy.try_spend is only reached once the level cap has been checked).
func try_buy(up: Upgrade, scope: StringName = &"global") -> bool:
	if up == null or is_maxed(up, scope):
		return false
	var level := level_of(up.id, scope)
	if not Economy.try_spend(up.cost_at(level)):
		return false
	_levels[_key(up.id, scope)] = level + 1
	changed.emit()
	return true


## Wipes every purchase. For tests, which share one autoload across states and
## would otherwise inherit levels from whatever ran before.
func reset() -> void:
	_levels.clear()
	changed.emit()


func _key(id: StringName, scope: StringName) -> String:
	return "%s/%s" % [scope, id]
