extends Node3D

## Headless proof of phase 8.1 (Docs/Plans/phase8_foundations.md): boots
## level2_front.tscn and asserts the player starts possessing their Base (not
## the RuneMage), that firing lobs a MortarShell which actually lands on and
## damages a ground unit (a flat Projectile was tried first and sailed clean
## over enemy_unit's ~1m-tall box — this is the regression check for that),
## and that buying a wave slot spends resources and raises wave_size. Run
## with:
##
##   godot --headless res://tests/base_possession_test.tscn
##
## Exit code 0 = PASS, 1 = FAIL.

enum State { SETTLE, FIRE, AWAIT_IMPACT, BUY_SLOT, CHECK_SLOT, KILL_ENEMY, CHECK_LOOT, DONE }

const SETTLE_FRAMES := 5 # let possession's deferred initial activation land
const IMPACT_TIMEOUT := 3.0 # generous margin over mortar_flight_time

var _state: State = State.SETTLE
var _frame := 0
var _elapsed := 0.0
var _base: Base = null
var _target_enemy: FrontUnit = null
var _initial_wave_size := 0
var _slot_cost := 0


func _process(delta: float) -> void:
	_frame += 1
	_elapsed += delta

	match _state:
		State.SETTLE:
			if _frame < SETTLE_FRAMES:
				return
			var c := Consciousness.active()
			_base = c.entity as Base if c != null else null
			if _base == null:
				_fail("initial possession is %s, expected the player Base" %
					(c.entity if c != null else "<nothing>"))
				return
			_clear_battlefield() # both bases keep spawning/fighting on their own —
			# stop that noise so only our synthetic hits land on the test enemy.
			_state = State.FIRE

		State.FIRE:
			# A ground unit standing where the shell should land — proof the
			# mortar lands ON it instead of sailing overhead like the flat
			# Projectile it replaced.
			var enemy_scene: PackedScene = load("res://entities/front_unit/enemy_unit.tscn")
			_target_enemy = enemy_scene.instantiate()
			get_tree().current_scene.add_child(_target_enemy)
			_target_enemy.global_position = _base.global_position + Vector3(0, 0.5, 5)

			var ctx := InputContext.new()
			ctx.delta = delta
			ctx.world_cursor = _target_enemy.global_position
			ctx.set_action(&"attack", false, true)
			Consciousness.active().handle_input(ctx)

			if not _any_mortar_shell():
				_fail("firing 'attack' spawned no MortarShell")
				return
			_elapsed = 0.0
			_state = State.AWAIT_IMPACT

		State.AWAIT_IMPACT:
			if not is_instance_valid(_target_enemy):
				_fail("target enemy freed before taking any damage (shouldn't die from one shell)")
				return
			if _target_enemy.health.hp < _target_enemy.health.max_hp:
				var expected := _target_enemy.health.max_hp - _base.mortar_damage
				if not is_equal_approx(_target_enemy.health.hp, expected):
					_fail("target hp %.1f after impact, expected exactly %.1f (mortar_damage=%.1f) — battlefield noise?"
						% [_target_enemy.health.hp, expected, _base.mortar_damage])
					return
				print("[BasePossessionTest] mortar landed on target: PASS (hp %.0f/%.0f)"
					% [_target_enemy.health.hp, _target_enemy.health.max_hp])
				_target_enemy.queue_free()
				_state = State.BUY_SLOT
				return
			if _elapsed > IMPACT_TIMEOUT:
				_fail("mortar never damaged the unit it was aimed at (still sailing overhead?)")
				return

		State.BUY_SLOT:
			_initial_wave_size = _base.wave_size
			_slot_cost = _base.slot_cost_base + _base.wave_size * _base.slot_cost_step
			Economy.add(_slot_cost)
			var ctx := InputContext.new()
			ctx.delta = delta
			ctx.set_action(&"buy_slot", false, true)
			Consciousness.active().handle_input(ctx)
			_state = State.CHECK_SLOT

		State.CHECK_SLOT:
			var slot_ok := _base.wave_size == _initial_wave_size + 1
			var resources_ok := Economy.resources == 0
			if not (slot_ok and resources_ok):
				_fail("wave_size %d -> %d (expected %d), resources left = %d (expected 0)"
					% [_initial_wave_size, _base.wave_size, _initial_wave_size + 1, Economy.resources])
				return
			print("[BasePossessionTest] wave_size %d -> %d (cost %d): PASS"
				% [_initial_wave_size, _base.wave_size, _slot_cost])
			_state = State.KILL_ENEMY

		State.KILL_ENEMY:
			# LootOnDeath (enemy_unit.tscn): killing an enemy should pay the player.
			var enemy_scene: PackedScene = load("res://entities/front_unit/enemy_unit.tscn")
			var enemy: FrontUnit = enemy_scene.instantiate()
			get_tree().current_scene.add_child(enemy)
			enemy.global_position = _base.global_position
			enemy.take_damage(9999.0)
			_state = State.CHECK_LOOT

		State.CHECK_LOOT:
			var passed := Economy.resources == 5 # LootOnDeath default resource_amount
			print("[BasePossessionTest] enemy death -> resources = %d -> %s"
				% [Economy.resources, "PASS" if passed else "FAIL"])
			get_tree().quit(0 if passed else 1)
			_state = State.DONE


## level2_front.tscn's two Base spawners fight autonomously the instant the
## level loads — real gameplay, but noise for a test that wants to control
## exactly what damages the one enemy it cares about.
func _clear_battlefield() -> void:
	for group in [&"front_ally", &"front_enemy"]:
		for unit in get_tree().get_nodes_in_group(group):
			unit.queue_free()
	for node in [get_node("Level2Front/PlayerBase"), get_node("Level2Front/EnemyBase")]:
		if node is Base:
			node.stop_spawning()


func _any_mortar_shell() -> bool:
	for child in get_tree().current_scene.get_children():
		if child is MortarShell:
			return true
	return false


func _fail(reason: String) -> void:
	print("[BasePossessionTest] FAIL: %s" % reason)
	get_tree().quit(1)
