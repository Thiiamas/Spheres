extends Node3D

## Headless proof of phase 10.1 (Docs/Plans/phase10_meso_poc.md): boots
## meso_front.tscn and asserts what's genuinely new about this milestone —
## a real allied wave spawns on its own, a pushed wave can damage the Base
## behind it in EITHER direction (only ever proven enemy->player in 9.1's
## base_health_test), both Base.died signals actually end the run, and a
## dead Base stops producing units on its own (D7) instead of leaking waves
## forever. Run with:
##
##   godot --headless res://tests/meso_front_test.tscn
##
## Exit code 0 = PASS, 1 = FAIL.

enum State {
	SETTLE, AWAIT_AUTO_WAVE, PLANT_ALLY_BITER, AWAIT_ENEMY_BITE,
	KILL_ENEMY_BASE, CHECK_VICTORY, KILL_PLAYER_BASE, CHECK_DEFEAT,
	AWAIT_LEAK_WINDOW, CHECK_NO_LEAK, DONE,
}

const SETTLE_FRAMES := 5 # let possession's deferred initial activation land
const AUTO_WAVE_TIMEOUT := 3.0 # wave_unit_spacing * wave_size margin
const BITE_TIMEOUT := 5.0 # generous margin over FrontUnit.attack_cooldown
const LEAK_WINDOW := 8.0 # > wave_interval (6s): long enough to catch a leak

var _state: State = State.SETTLE
var _frame := 0
var _elapsed := 0.0
var _player_base: Base = null
var _enemy_base: Base = null
var _biter: FrontUnit = null
var _player_died := false
var _enemy_died := false


func _process(delta: float) -> void:
	_frame += 1
	_elapsed += delta

	match _state:
		State.SETTLE:
			if _frame < SETTLE_FRAMES:
				return
			_player_base = get_node("MesoFront/PlayerBase") as Base
			_enemy_base = get_node("MesoFront/EnemyBase") as Base
			if _player_base == null or _enemy_base == null:
				_fail("PlayerBase/EnemyBase missing or wrong type")
				return
			_player_base.died.connect(func() -> void: _player_died = true)
			_enemy_base.died.connect(func() -> void: _enemy_died = true)
			_elapsed = 0.0
			_state = State.AWAIT_AUTO_WAVE

		State.AWAIT_AUTO_WAVE:
			# The point of 10.1: PlayerBase.unit_scene is assigned for the first
			# time outside level2_front, and wave_size is non-zero from the start
			# — no wave_slot purchase needed to see it (D2/10.1 sub-task 2).
			if get_tree().get_nodes_in_group(&"front_ally").size() > 0:
				print("[MesoFrontTest] allied wave spawned on its own: PASS")
				_clear_battlefield()
				_state = State.PLANT_ALLY_BITER
				return
			if _elapsed > AUTO_WAVE_TIMEOUT:
				_fail("no allied unit spawned within %.1fs of load" % AUTO_WAVE_TIMEOUT)
				return

		State.PLANT_ALLY_BITER:
			# Planted right next to the enemy Base so AttackZone overlaps its
			# Hull immediately — mirrors base_health_test, but in the direction
			# that milestone never exercised (ally -> enemy Base).
			var ally_scene: PackedScene = load("res://entities/front_unit/ally_unit.tscn")
			_biter = ally_scene.instantiate()
			_biter.target_base = _enemy_base
			get_tree().current_scene.add_child(_biter)
			_biter.global_position = _enemy_base.global_position + Vector3(0, 0.5, -2.2)
			_elapsed = 0.0
			_state = State.AWAIT_ENEMY_BITE

		State.AWAIT_ENEMY_BITE:
			if _enemy_base.health.hp < _enemy_base.health.max_hp:
				var expected := _enemy_base.health.max_hp - _biter.attack_damage
				if not is_equal_approx(_enemy_base.health.hp, expected):
					_fail("enemy base hp %.1f after one bite, expected exactly %.1f"
						% [_enemy_base.health.hp, expected])
					return
				print("[MesoFrontTest] an allied unit damaged the enemy Base: PASS")
				_biter.queue_free()
				_state = State.KILL_ENEMY_BASE
				return
			if _elapsed > BITE_TIMEOUT:
				_fail("no allied damage reached the enemy Base")
				return

		State.KILL_ENEMY_BASE:
			_enemy_base.take_damage(9999.0)
			_state = State.CHECK_VICTORY

		State.CHECK_VICTORY:
			if not _enemy_died:
				_fail("draining the enemy Base's HP never emitted `died`")
				return
			print("[MesoFrontTest] enemy Base destroyed -> died fired: PASS")
			_state = State.KILL_PLAYER_BASE

		State.KILL_PLAYER_BASE:
			_player_base.take_damage(9999.0)
			_state = State.CHECK_DEFEAT

		State.CHECK_DEFEAT:
			if not _player_died:
				_fail("draining the player Base's HP never emitted `died`")
				return
			print("[MesoFrontTest] player Base destroyed -> died fired: PASS")
			_clear_battlefield()
			_elapsed = 0.0
			_state = State.AWAIT_LEAK_WINDOW

		State.AWAIT_LEAK_WINDOW:
			# D7: both Bases are dead now; neither should still be producing
			# waves. wave_interval is 6s on both — wait comfortably past it.
			if _elapsed > LEAK_WINDOW:
				_state = State.CHECK_NO_LEAK
				return

		State.CHECK_NO_LEAK:
			var leaked := get_tree().get_nodes_in_group(&"front_ally").size() \
				+ get_tree().get_nodes_in_group(&"front_enemy").size()
			if leaked > 0:
				_fail("%d units spawned %.0fs after both Bases died (D7 regression)"
					% [leaked, LEAK_WINDOW])
				return
			print("[MesoFrontTest] no unit spawned after both Bases died: PASS")
			get_tree().quit(0)
			_state = State.DONE


func _clear_battlefield() -> void:
	for group in [&"front_ally", &"front_enemy"]:
		for unit in get_tree().get_nodes_in_group(group):
			unit.queue_free()


func _fail(reason: String) -> void:
	print("[MesoFrontTest] FAIL: %s" % reason)
	get_tree().quit(1)
