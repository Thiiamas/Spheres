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


func _update_hp_bar() -> void:
	if hp_bar and hp_bar.has_method("update_bar"):
		hp_bar.update_bar(hp, max_hp)
