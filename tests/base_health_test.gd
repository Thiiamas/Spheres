extends Node3D

## Headless proof of phase 9.1 (Docs/Plans/phase9_micro_poc.md): boots
## micro_base_defense.tscn and asserts an enemy FrontUnit can actually damage
## the player's Base — which nothing could do before this milestone (Base had
## no solid body at all, and FrontUnit._try_attack only recognised FrontUnit
## and Tower) — and that draining it emits `died` without freeing the Base or
## crashing the possession that's still pointed at it. Run with:
##
##   godot --headless res://tests/base_health_test.tscn
##
## Exit code 0 = PASS, 1 = FAIL.

enum State { SETTLE, AWAIT_BITE, KILL_BASE, CHECK_DEFEAT, DONE }

const SETTLE_FRAMES := 5 # let possession's deferred initial activation land
const BITE_TIMEOUT := 5.0 # generous margin over FrontUnit.attack_cooldown

var _state: State = State.SETTLE
var _frame := 0
var _elapsed := 0.0
var _base: Base = null
var _biter: FrontUnit = null
var _died_fired := false


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
			if _base.health == null:
				_fail("player Base has no Health child wired")
				return
			_base.died.connect(func() -> void: _died_fired = true)
			_clear_battlefield() # the enemy Base spawns on its own; only our
			# single planted unit should be biting the Base under test.

			# Planted right next to the Base so its AttackZone overlaps the new
			# Hull immediately, rather than waiting for it to walk over.
			var enemy_scene: PackedScene = load("res://entities/front_unit/enemy_unit.tscn")
			_biter = enemy_scene.instantiate()
			# target_base matters even standing still: with nothing to seek,
			# FrontUnit._physics_process returns before ever trying to attack.
			# Base sets this on every unit it spawns; mirror that here.
			_biter.target_base = _base
			get_tree().current_scene.add_child(_biter)
			_biter.global_position = _base.global_position + Vector3(0, 0.5, 2.2)
			_elapsed = 0.0
			_state = State.AWAIT_BITE

		State.AWAIT_BITE:
			if _base.health.hp < _base.health.max_hp:
				var expected := _base.health.max_hp - _biter.attack_damage
				if not is_equal_approx(_base.health.hp, expected):
					_fail("base hp %.1f after one bite, expected exactly %.1f (attack_damage=%.1f)"
						% [_base.health.hp, expected, _biter.attack_damage])
					return
				print("[BaseHealthTest] enemy bit the Base: PASS (hp %.0f/%.0f)"
					% [_base.health.hp, _base.health.max_hp])
				_biter.queue_free()
				_state = State.KILL_BASE
				return
			if _elapsed > BITE_TIMEOUT:
				_fail("no enemy damage reached the Base (Hull missing from AttackZone's layer?)")
				return

		State.KILL_BASE:
			_base.take_damage(9999.0)
			_state = State.CHECK_DEFEAT

		State.CHECK_DEFEAT:
			# H5: the Base goes inert but stays in the tree — it's the possessed
			# entity, and this POC has no fallback to hand control to.
			if not _died_fired:
				_fail("draining the Base's HP never emitted `died`")
				return
			if not is_instance_valid(_base):
				_fail("Base freed itself on death (H5 says it must stay in the tree)")
				return
			# Driving a defeated Base must no-op rather than throw.
			var ctx := InputContext.new()
			ctx.delta = 0.016
			ctx.world_cursor = _base.global_position
			ctx.set_action(&"attack", false, true)
			Consciousness.active().handle_input(ctx)
			print("[BaseHealthTest] defeat: died fired, Base alive in tree, input inert: PASS")
			get_tree().quit(0)
			_state = State.DONE


## The scene's EnemyBase spawns a wave the instant it loads — real gameplay,
## but noise for a test that wants exactly one known bite to land.
func _clear_battlefield() -> void:
	for group in [&"front_ally", &"front_enemy"]:
		for unit in get_tree().get_nodes_in_group(group):
			unit.queue_free()
	for node in [get_node("MicroBaseDefense/PlayerBase"), get_node("MicroBaseDefense/EnemyBase")]:
		if node is Base:
			node.stop_spawning()


func _fail(reason: String) -> void:
	print("[BaseHealthTest] FAIL: %s" % reason)
	get_tree().quit(1)
