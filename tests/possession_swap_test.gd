extends Node3D

## Headless proof of phase 8.2's core mechanic (Docs/Plans/phase8_foundations.md):
## the FrontUnit <-> RuneMage swap, ZQSD movement, and the death-while-possessed
## fallback to the Base (H3). Drives PossessionSwap directly rather than
## through a simulated mouse click — there's no real cursor in headless mode,
## so the raycast-under-the-cursor resolution itself (CameraRig.
## raycast_at_cursor + Base's SelectionArea) is confirmed by manual playtest
## instead; this test covers everything downstream of "the right thing got
## clicked" (HP transfer, Consciousness registration, targeting handoff).
##
## Run with:
##   godot --headless res://tests/possession_swap_test.tscn
##
## Exit code 0 = PASS, 1 = FAIL.

enum State { SETTLE, SWAP_IN, CHECK_SWAP_IN, MOVE, CHECK_MOVE, SWAP_OUT, CHECK_SWAP_OUT, KILL_MAGE, CHECK_DEATH_FALLBACK, DONE }

const SETTLE_FRAMES := 5
const MOVE_FRAMES := 20

var _state: State = State.SETTLE
var _frame := 0
var _ally_base: Base = null
var _test_unit: FrontUnit = null
var _mage: RuneMage = null
var _start_pos: Vector3 = Vector3.ZERO
var _released_unit: FrontUnit = null


func _process(delta: float) -> void:
	_frame += 1

	match _state:
		State.SETTLE:
			if _frame < SETTLE_FRAMES:
				return
			_ally_base = PossessionSwap.find_ally_base()
			if _ally_base == null:
				_fail("no ALLY Base registered with Consciousness")
				return
			for group in [&"front_ally", &"front_enemy"]:
				for unit in get_tree().get_nodes_in_group(group):
					unit.queue_free()
			get_node("Level2Front/PlayerBase").stop_spawning()
			get_node("Level2Front/EnemyBase").stop_spawning()
			_state = State.SWAP_IN

		State.SWAP_IN:
			var scene: PackedScene = load("res://entities/front_unit/ally_unit.tscn")
			_test_unit = scene.instantiate()
			get_tree().current_scene.add_child(_test_unit)
			_test_unit.global_position = _ally_base.global_position + Vector3(0, 0.5, 5)
			_test_unit.health.hp = 20.0 # half of max_hp(40) — checked below

			_mage = PossessionSwap.possess_front_unit(_test_unit, get_tree())
			Consciousness.request_possession(_mage.controllable)
			_state = State.CHECK_SWAP_IN

		State.CHECK_SWAP_IN:
			var active := Consciousness.active()
			if active == null or active.entity != _mage:
				_fail("possess_front_unit + request_possession didn't make the mage active")
				return
			if not is_equal_approx(_mage.health.hp, _mage.health.max_hp * 0.5):
				_fail("HP not carried over proportionally: mage hp=%.1f/%.1f, expected 50%%"
					% [_mage.health.hp, _mage.health.max_hp])
				return
			# The bar has to agree with the carried-over HP, not just the number:
			# the swap used to assign Health.hp directly, which refreshes nothing,
			# so a mage handed 50% HP displayed a FULL bar until its first hit.
			# Health.set_hp() fixed that; this pins it.
			var fill := _mage.health.hp_bar.get_node_or_null("Fill") as Node3D
			if fill == null:
				_fail("mage's HPBar3D has no Fill node — can't verify the bar")
				return
			if not is_equal_approx(fill.scale.x, 0.5):
				_fail("health bar shows %.0f%% after a 50%% swap — bar not refreshed"
					% [fill.scale.x * 100.0])
				return
			print("[PossessionSwapTest] FrontUnit -> RuneMage: PASS (hp %.0f/%.0f, bar %.0f%%, active=%s)"
				% [_mage.health.hp, _mage.health.max_hp, fill.scale.x * 100.0, active.entity.name])
			_start_pos = _mage.global_position
			_state = State.MOVE

		State.MOVE:
			# Synthetic ZQSD input — same trick as synthetic_drive_test.
			var ctx := InputContext.new()
			ctx.delta = delta
			ctx.move_vector = Vector2(0.0, -1.0) # forward
			_mage.controllable.handle_input(ctx)
			if _frame < SETTLE_FRAMES + MOVE_FRAMES:
				return
			_state = State.CHECK_MOVE

		State.CHECK_MOVE:
			var moved := (_mage.global_position - _start_pos).length()
			if moved < 0.5:
				_fail("ZQSD input didn't move the mage (moved %.2f m)" % moved)
				return
			print("[PossessionSwapTest] ZQSD movement: PASS (moved %.2f m)" % moved)
			_state = State.SWAP_OUT

		State.SWAP_OUT:
			_released_unit = PossessionSwap.release_to_front_unit(_mage, get_tree())
			Consciousness.request_possession(_ally_base.controllable)
			_state = State.CHECK_SWAP_OUT

		State.CHECK_SWAP_OUT:
			var active := Consciousness.active()
			var ok := active != null and active.entity == _ally_base \
				and _released_unit.target_base == _ally_base.advance_target \
				and _released_unit.target_tower == _ally_base.advance_target_tower \
				and is_equal_approx(_released_unit.health.hp, _released_unit.health.max_hp * 0.5)
			if not ok:
				_fail("release_to_front_unit didn't restore targeting/HP or hand control back to the Base")
				return
			print("[PossessionSwapTest] RuneMage -> FrontUnit release: PASS (targeting resumed, control back on Base)")
			_state = State.KILL_MAGE

		State.KILL_MAGE:
			# H3: dying while possessed returns control to the Base, no respawn.
			var scene: PackedScene = load("res://entities/front_unit/ally_unit.tscn")
			var unit: FrontUnit = scene.instantiate()
			get_tree().current_scene.add_child(unit)
			unit.global_position = _ally_base.global_position + Vector3(0, 0.5, 5)
			_mage = PossessionSwap.possess_front_unit(unit, get_tree())
			Consciousness.request_possession(_mage.controllable)
			_mage.take_damage(99999.0)
			_state = State.CHECK_DEATH_FALLBACK

		State.CHECK_DEATH_FALLBACK:
			var active := Consciousness.active()
			var passed := active != null and active.entity == _ally_base
			print("[PossessionSwapTest] death while possessed -> Base: %s"
				% ("PASS" if passed else "FAIL (active=%s)" % [active.entity if active else "<none>"]))
			get_tree().quit(0 if passed else 1)


func _fail(reason: String) -> void:
	print("[PossessionSwapTest] FAIL: %s" % reason)
	get_tree().quit(1)
