extends Node3D

## Headless proof of the Tower's AOE retaliation (phase 10.2 addendum,
## Docs/Plans/phase10_meso_poc.md, added after playtest feedback that a
## single-target-only Tower gave sieges no real danger): an escorted push
## should NOT make the player safe from the Tower. A RuneMage and an
## escorting ally FrontUnit both sit in an EnemyTower's detection zone —
## is_protected() is true throughout, so the pre-existing single-target
## branch is busy retaliating against the FrontUnit the whole time — and the
## AOE must still land on the RuneMage on its own, independent cooldown.
## Run with:
##
##   godot --headless res://tests/tower_aoe_test.tscn
##
## Exit code 0 = PASS, 1 = FAIL.

const SETTLE_FRAMES := 5
# Area3D overlap detection lags a physics step behind add_child() + placing a
# body — enough headroom for that to land before is_protected() is asserted.
const OVERLAP_SETTLE_FRAMES := 15
# aoe_cooldown (4.0s) + aoe_flight_time (1.1s) + margin.
const AOE_TIMEOUT := 10.0

enum State { SETTLE, SPAWN, AWAIT_OVERLAP, CHECK_PROTECTED, AWAIT_AOE, DONE }

var _state: State = State.SETTLE
var _frame := 0
var _elapsed := 0.0
var _tower: Tower = null
var _mage: RuneMage = null


func _process(delta: float) -> void:
	_frame += 1

	match _state:
		State.SETTLE:
			if _frame < SETTLE_FRAMES:
				return
			_tower = get_node("EnemyTower") as Tower
			if _tower == null:
				_fail("EnemyTower missing or wrong type")
				return
			_state = State.SPAWN

		State.SPAWN:
			# The escort: makes is_protected() true for the whole test, so
			# the single-target branch is occupied elsewhere — proving the
			# AOE doesn't depend on the player being unescorted.
			var ally_scene: PackedScene = load("res://entities/front_unit/ally_unit.tscn")
			var escort := ally_scene.instantiate()
			add_child(escort)
			escort.global_position = _tower.global_position + Vector3(2, 0.5, 0)

			var mage_scene: PackedScene = load("res://entities/mage/rune_mage.tscn")
			_mage = mage_scene.instantiate()
			add_child(_mage)
			_mage.global_position = _tower.global_position + Vector3(-2, 0, 0)
			_frame = 0
			_state = State.AWAIT_OVERLAP

		State.AWAIT_OVERLAP:
			if _frame >= OVERLAP_SETTLE_FRAMES:
				_state = State.CHECK_PROTECTED

		State.CHECK_PROTECTED:
			if not _tower.escort_gate.is_protected():
				_fail("escorting FrontUnit not recognised — is_protected() should be true throughout")
				return
			_elapsed = 0.0
			_state = State.AWAIT_AOE

		State.AWAIT_AOE:
			_await_aoe(delta)


func _await_aoe(delta: float) -> void:
	_elapsed += delta
	if not _tower.escort_gate.is_protected():
		_fail("escorting FrontUnit no longer recognised mid-test — is_protected() should stay true")
		return
	if _mage.health.hp < _mage.health.max_hp:
		var expected := _mage.health.max_hp - _tower.escort_gate.aoe_damage
		if not is_equal_approx(_mage.health.hp, expected):
			_fail("mage hp %.1f after the AOE, expected exactly %.1f (aoe_damage=%.1f)"
				% [_mage.health.hp, expected, _tower.escort_gate.aoe_damage])
			return
		print("[TowerAoeTest] AOE hit the escorted player: PASS (hp %.0f/%.0f)"
			% [_mage.health.hp, _mage.health.max_hp])
		get_tree().quit(0)
		return
	if _elapsed > AOE_TIMEOUT:
		_fail("AOE never damaged the player within %.0fs, despite being escorted the whole time"
			% AOE_TIMEOUT)


func _fail(reason: String) -> void:
	print("[TowerAoeTest] FAIL: %s" % reason)
	get_tree().quit(1)
