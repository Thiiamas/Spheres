extends Node3D

## Headless proof of phase 9.2 (Docs/Plans/phase9_micro_poc.md): the
## Upgrade / Progression system actually gates purchases, applies to a live
## entity, and — the point that matters most — applies to an entity created
## AFTER the purchase. That last one is why progression lives in an autoload
## instead of on the entity: PossessionSwap frees the FrontUnit and instantiates
## a replacement, so from 9.3 on, "already bought" has to survive entity churn
## with no state handover. Run with:
##
##   godot --headless res://tests/progression_test.tscn
##
## Exit code 0 = PASS, 1 = FAIL.

enum State { SETTLE, REFUSE_BROKE, BUY_ONE, CHECK_APPLIED, CHECK_FRESH, CHECK_MAX, DONE }

const SETTLE_FRAMES := 5 # let possession's deferred initial activation land

var _state: State = State.SETTLE
var _frame := 0
var _base: Base = null
var _damage_up: Upgrade = null
var _damage_index := -1
## Authored mortar damage, captured before any purchase.
var _baseline_damage := 0.0


func _process(_delta: float) -> void:
	_frame += 1

	match _state:
		State.SETTLE:
			if _frame < SETTLE_FRAMES:
				return
			var c := Consciousness.active()
			_base = c.entity as Base if c != null else null
			if _base == null:
				_fail("initial possession is not the player Base")
				return
			# Autoloads outlive scenes, so start from a known slate.
			Progression.reset()
			Economy.resources = 0
			_stop_waves() # no enemy deaths paying the player mid-test

			for i in _base.upgrades.size():
				if _base.upgrades[i] != null and _base.upgrades[i].id == &"mortar_damage":
					_damage_up = _base.upgrades[i]
					_damage_index = i
					break
			if _damage_up == null:
				_fail("player Base offers no mortar_damage upgrade")
				return
			# Captured after reset(), so this really is the authored value.
			_baseline_damage = _base.mortar_damage
			_state = State.REFUSE_BROKE

		State.REFUSE_BROKE:
			# Broke: the purchase must fail without spending or levelling.
			if Progression.try_buy(_damage_up):
				_fail("bought an upgrade with 0 resources")
				return
			if Progression.level_of(_damage_up.id) != 0:
				_fail("a refused purchase still raised the level")
				return
			if not is_equal_approx(_base.mortar_damage, _baseline_damage):
				_fail("a refused purchase still changed the stat")
				return
			print("[ProgressionTest] refused when broke, nothing spent: PASS")
			_state = State.BUY_ONE

		State.BUY_ONE:
			# Exact cost, so a leftover resource would show up as a failure.
			Economy.add(Progression.cost_of(_damage_up))
			if not Progression.try_buy(_damage_up):
				_fail("purchase failed with exactly enough resources")
				return
			if Economy.resources != 0:
				_fail("purchase left %d resources, expected the full cost spent"
					% Economy.resources)
				return
			_state = State.CHECK_APPLIED

		State.CHECK_APPLIED:
			var expected := _baseline_damage + _damage_up.per_level
			if not is_equal_approx(_base.mortar_damage, expected):
				_fail("mortar_damage %.1f after 1 level, expected %.1f"
					% [_base.mortar_damage, expected])
				return
			# Idempotence: `changed` fires on every purchase, so apply runs many
			# times per session. Recomputing from the baseline must land on the
			# same number rather than compounding.
			_base.apply_progression()
			_base.apply_progression()
			if not is_equal_approx(_base.mortar_damage, expected):
				_fail("re-applying progression drifted mortar_damage to %.1f (expected %.1f) — stat mutated in place instead of recomputed from baseline"
					% [_base.mortar_damage, expected])
				return
			print("[ProgressionTest] applied to live entity + idempotent: PASS (%.1f -> %.1f)"
				% [_baseline_damage, _base.mortar_damage])
			_state = State.CHECK_FRESH

		State.CHECK_FRESH:
			# The crux: an entity built AFTER the purchase must come up already
			# upgraded, with nothing copied across. Spawned ENEMY-faction so its
			# BaseControllable stays out of the possession pool (see
			# base_controllable.gd) and this test's own possession is untouched.
			var base_scene: PackedScene = load("res://entities/base/base.tscn")
			var fresh: Base = base_scene.instantiate()
			fresh.faction = Faction.Kind.ENEMY
			get_tree().current_scene.add_child(fresh)
			var expected := _baseline_damage + _damage_up.per_level
			var fresh_damage := fresh.mortar_damage
			fresh.queue_free()
			if not is_equal_approx(fresh_damage, expected):
				_fail("a Base created after the purchase has mortar_damage %.1f, expected %.1f — progression didn't survive entity creation"
					% [fresh_damage, expected])
				return
			print("[ProgressionTest] entity created after purchase inherits it: PASS (%.1f)"
				% fresh_damage)
			_state = State.CHECK_MAX

		State.CHECK_MAX:
			# Buy up to the cap, then prove it holds.
			while Progression.level_of(_damage_up.id) < _damage_up.max_level:
				Economy.add(Progression.cost_of(_damage_up))
				if not Progression.try_buy(_damage_up):
					_fail("purchase failed below max_level (level %d/%d)"
						% [Progression.level_of(_damage_up.id), _damage_up.max_level])
					return
			Economy.add(9999)
			if Progression.try_buy(_damage_up):
				_fail("bought level %d past max_level %d"
					% [Progression.level_of(_damage_up.id), _damage_up.max_level])
				return
			if Economy.resources != 9999:
				_fail("a capped purchase still spent resources")
				return
			print("[ProgressionTest] max_level %d enforced, nothing spent past it: PASS"
				% _damage_up.max_level)
			get_tree().quit(0)
			_state = State.DONE


## Both bases spawn on load; their waves would kill each other's units and pay
## the player mid-test, moving the resource counts this test asserts on.
func _stop_waves() -> void:
	for group in [&"front_ally", &"front_enemy"]:
		for unit in get_tree().get_nodes_in_group(group):
			unit.queue_free()
	for node in [get_node("MicroBaseDefense/PlayerBase"), get_node("MicroBaseDefense/EnemyBase")]:
		if node is Base:
			node.stop_spawning()


func _fail(reason: String) -> void:
	print("[ProgressionTest] FAIL: %s" % reason)
	get_tree().quit(1)
