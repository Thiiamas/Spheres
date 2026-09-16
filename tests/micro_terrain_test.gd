extends Node3D

## Headless answer to milestone 9.4's central question (Docs/Plans/
## phase9_micro_poc.md): does FrontUnit steering survive a corridor with relief,
## given that _avoidance() pushes away from other units only and NOTHING pushes
## away from static geometry? The single thing routing a unit around a rock is
## move_and_slide()'s own slide response, which handles an isolated convex shape
## but can pin a body against a concave corner or a bottleneck.
##
## "Does a unit get stuck" is measurable, so it is measured here rather than
## eyeballed: every unit's distance to its goal is sampled, and a unit that
## stops improving that distance for STALL_SECONDS while still far from the goal
## is reported as stalled, with where it happened. The manual playtest then only
## has to judge *feel*, not detect blocking.
##
## Deliberately combat-free — the roster bodies are removed and nothing shoots,
## so a unit standing still is a movement fact, not a unit that planted itself
## for a swing.
##
## Run with:
##   tools/run_tests.sh micro_terrain
##
## Exit code 0 = PASS, 1 = FAIL.

const WAVE_SIZE := 6
const CLEAR_FRAME := 10
const SPAWN_FRAME := 12
## Sampled at physics rate; 40 m at speed 3.5 is ~11.5 s of simulated travel, so
## this leaves room for detours while staying inside run_tests.sh's watchdog.
const DEADLINE_FRAME := 1100
const SAMPLE_EVERY := 15
## No progress for this long, while still far from the goal, counts as stuck.
const STALL_SECONDS := 7.0
## Distance improvement that counts as progress at all.
const IMPROVE_EPS := 0.5
## Close enough to the Base to call it arrived (its GoalZone is around here).
const ARRIVED_DIST := 4.5
## Below run_tests.sh's --quit-after backstop for this test (8000), so it always
## concludes itself rather than being killed silently — the flag quits with code
## 0, which would read as a pass. Headless steps ~0.42 physics frames per loop
## iteration, so this is roughly 2500 physics frames of headroom for a crossing
## that takes about 1000.
const LOOP_SAFETY_FRAMES := 6000

var _frame := 0
var _level: Node3D = null
var _goal: Node3D = null
var _done := false
## unit -> { best: float, last_gain: int, start: float }
var _tracked: Dictionary = {}
var _arrived: Array = []
var _stalled: Array = []
## True when the loop-iteration net fired before every unit had a verdict.
var _inconclusive := false


func _ready() -> void:
	_level = get_node("MicroTerrain")


func _physics_process(_delta: float) -> void:
	_frame += 1
	if _done:
		return

	if _frame == CLEAR_FRAME:
		_clear()
		return
	if _frame == SPAWN_FRAME:
		_spawn_wave()
		return
	if _frame < SPAWN_FRAME:
		return

	if _frame % SAMPLE_EVERY == 0:
		_sample()

	if _frame >= DEADLINE_FRAME or _all_resolved():
		_report()


## Runs on main-loop iterations, which is what run_tests.sh's --quit-after
## counts — and that flag quits with code 0. Concluding here, below the
## backstop, is what stops an unfinished run from being reported as a pass.
func _process(_delta: float) -> void:
	if _done:
		return
	if Engine.get_process_frames() >= LOOP_SAFETY_FRAMES:
		_inconclusive = true
		_report()


## Silence the level's own spawner and empty the field. stop_spawning() also
## aborts the opening wave's still-pending coroutine (it re-checks `_spawning`
## between units), which is what otherwise dropped a 7th cube into the sample.
func _clear() -> void:
	_goal = _level.get_node("PlayerBase")
	var enemy_base: Base = _level.get_node("EnemyBase")
	enemy_base.stop_spawning()
	# Movement only: no bodies to bite on the way, nothing to fight over.
	for child in _level.get_node("Roster").get_children():
		child.queue_free()
	for group in [&"front_ally", &"front_enemy"]:
		for unit in get_tree().get_nodes_in_group(group):
			unit.queue_free()


## Places the wave by hand instead of through Base: what's under test is
## FrontUnit's steering against static geometry, not the spawner's scheduling,
## and a fixed line-up makes a stall reproducible rather than timing-dependent.
func _spawn_wave() -> void:
	var scene: PackedScene = load("res://entities/front_unit/enemy_unit.tscn")
	var origin: Vector3 = _level.get_node("EnemyBase").global_position
	for i in WAVE_SIZE:
		var unit: FrontUnit = scene.instantiate()
		unit.faction = Faction.Kind.ENEMY
		unit.target_base = _goal
		get_tree().current_scene.add_child(unit)
		var t := float(i) / float(WAVE_SIZE - 1)
		unit.global_position = origin + Vector3(lerpf(-3.0, 3.0, t), 0.5, -2.0)
		var d: float = unit.global_position.distance_to(_goal.global_position)
		_tracked[unit] = { "best": d, "last_gain": _frame, "start": d }
	if _tracked.size() != WAVE_SIZE:
		_fail("expected %d cubes on the field, found %d" % [WAVE_SIZE, _tracked.size()])


func _sample() -> void:
	for unit in _tracked.keys():
		var rec: Dictionary = _tracked[unit]
		if rec.has("verdict"):
			continue
		if not is_instance_valid(unit):
			rec["verdict"] = "gone" # nothing kills units here, but be safe
			continue
		var d: float = unit.global_position.distance_to(_goal.global_position)
		if d <= ARRIVED_DIST:
			rec["verdict"] = "arrived"
			_arrived.append(unit)
			continue
		if d < rec["best"] - IMPROVE_EPS:
			rec["best"] = d
			rec["last_gain"] = _frame
			continue
		var stalled_frames: int = _frame - int(rec["last_gain"])
		if stalled_frames > int(STALL_SECONDS * Engine.physics_ticks_per_second):
			rec["verdict"] = "stalled"
			rec["at"] = unit.global_position
			rec["dist"] = d
			rec["contacts"] = _contacts_of(unit)
			_stalled.append(unit)


## What the unit is physically touching, so a failure names the geometry instead
## of leaving it to be guessed from coordinates.
func _contacts_of(unit: FrontUnit) -> String:
	var out: Array[String] = []
	for i in unit.get_slide_collision_count():
		var c := unit.get_slide_collision(i)
		var col := c.get_collider() as Node
		var n := c.get_normal()
		out.append("%s n=(%.2f, %.2f, %.2f)" % [col.name if col != null else "?", n.x, n.y, n.z])
	return "nothing" if out.is_empty() else ", ".join(out)


func _all_resolved() -> bool:
	for unit in _tracked.keys():
		if not _tracked[unit].has("verdict"):
			return false
	return true


func _report() -> void:
	_done = true
	var en_route := 0
	for unit in _tracked.keys():
		if not _tracked[unit].has("verdict"):
			en_route += 1

	print("[MicroTerrainTest] %d cubes: %d arrived, %d stalled, %d still en route (%d physics frames, %d loop iterations)"
		% [_tracked.size(), _arrived.size(), _stalled.size(), en_route,
			Engine.get_physics_frames(), Engine.get_process_frames()])
	for unit in _stalled:
		var rec: Dictionary = _tracked[unit]
		print("    STALLED at (%.1f, %.1f, %.1f), still %.1f m from the Base (came %.1f m)
      touching: %s"
			% [rec["at"].x, rec["at"].y, rec["at"].z, rec["dist"],
				float(rec["start"]) - float(rec["best"]), rec["contacts"]])
	for unit in _tracked.keys():
		var rec: Dictionary = _tracked[unit]
		if rec.has("verdict"):
			continue
		print("    EN ROUTE, %.1f m closed of %.1f m — still improving, not stuck"
			% [float(rec["start"]) - float(rec["best"]), float(rec["start"])])

	if _inconclusive and en_route > 0:
		print("[MicroTerrainTest] FAIL: ran out of frames with %d unit(s) unresolved — inconclusive, not a pass"
			% en_route)
		get_tree().quit(1)
		return
	if not _stalled.is_empty():
		print("[MicroTerrainTest] FAIL: %d unit(s) pinned by static geometry — move_and_slide's slide response is not enough for this layout"
			% _stalled.size())
		get_tree().quit(1)
		return
	print("[MicroTerrainTest] no unit pinned by the relief: PASS")
	get_tree().quit(0)


func _fail(reason: String) -> void:
	_done = true
	print("[MicroTerrainTest] FAIL: %s" % reason)
	get_tree().quit(1)
