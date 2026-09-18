extends Node
class_name Health

## Generic HP pool component (Docs/front/tower.md). No faction, no range, no gating
## logic — anything can own one. Drop it as a child on any entity and call
## take_damage()/take_hit() on it directly, or forward calls to it from the
## host (see entities/tower/tower.gd for a host that gates forwarding, and
## entities/front_unit/front_unit.gd for a host that forwards unconditionally).

@export var max_hp: float = 100.0
## Optional floating health bar (ui/hp_bar_3d.gd), duck-typed via has_method
## so it's fine to leave unset.
@export var hp_bar: Node3D

var hp: float = 0.0
var _dead: bool = false

signal died
signal hp_changed(current: float, max: float)


func _ready() -> void:
	hp = max_hp
	_update_hp_bar()


func take_damage(amount: float) -> void:
	if _dead:
		return
	hp -= amount
	hp_changed.emit(hp, max_hp)
	_update_hp_bar()
	if hp <= 0.0:
		_dead = true
		died.emit()


func take_hit(amount: float) -> void:
	take_damage(amount)


func is_dead() -> bool:
	return _dead


## Sets current HP directly — for carrying HP across a possession swap
## (PossessionSwap, phase 8.2), not a damage path: it never triggers `died`.
##
## Goes through here rather than letting callers assign `hp` from outside so the
## bar and hp_changed stay in step. Assigning it directly is why an entity handed
## 50% HP by a possession swap showed a FULL bar until its first hit — nothing
## refreshed the bar between _ready (which fills it) and the next take_damage.
func set_hp(value: float) -> void:
	if _dead:
		return
	hp = clampf(value, 0.0, max_hp)
	hp_changed.emit(hp, max_hp)
	_update_hp_bar()


## Moves the HP ceiling. `grant_delta` also adds the increase to current HP, so
## a max-HP upgrade bought mid-fight is immediately felt instead of only
## widening the bar (D4, Docs/Plans/phase9_micro_poc.md).
##
## Lives here rather than in the caller because refreshing hp_changed and the
## health bar are this component's own invariants — poking max_hp from outside
## would leave the bar showing a stale ratio.
func set_max_hp(value: float, grant_delta: bool = false) -> void:
	if value <= 0.0 or is_equal_approx(value, max_hp):
		return
	var delta := value - max_hp
	max_hp = value
	if grant_delta and delta > 0.0:
		hp += delta
	hp = minf(hp, max_hp)
	hp_changed.emit(hp, max_hp)
	_update_hp_bar()


## Reverses `died` — for an entity that reaches 0 HP but isn't removed, only
## changes state (Base capture, D1/D4, Docs/Plans/phase11_macro_poc.md).
## take_damage/set_hp/set_max_hp all no-op once `_dead`, so without this a
## "revived" pool would silently ignore every hit for the rest of the run.
func revive(value: float = max_hp) -> void:
	_dead = false
	hp = clampf(value, 0.0, max_hp)
	hp_changed.emit(hp, max_hp)
	_update_hp_bar()


func _update_hp_bar() -> void:
	if hp_bar and hp_bar.has_method("update_bar"):
		hp_bar.update_bar(hp, max_hp)
