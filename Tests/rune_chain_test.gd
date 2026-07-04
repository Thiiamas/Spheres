extends Node3D

## Headless regression test for the Ryze-style propagation (phase 6):
##
##   1. CHAIN  - one RuneBolt fired at a row of 3 MARKED cubes must kill all
##               three (50 dmg each via shards), while a nearby UNMARKED cube
##               is untouched.
##   2. SPREAD - a RuneFlux recast on a marked cube must contaminate its
##               unmarked neighbour (one ring).
##
## Run with:  godot --headless res://Tests/RuneChainTest.tscn
## Exit code 0 = PASS, 1 = FAIL.

const ENEMY_SCENE := preload("res://Enemy.tscn")
const BOLT_SCENE := preload("res://RuneBolt.tscn")
const FLUX_SCENE := preload("res://RuneFlux.tscn")

var _phase := 0
var _timer := 0.0
var _marked_row: Array = []
var _bystander: Node3D = null
var _spread_carrier: Node3D = null
var _spread_neighbour: Node3D = null


func _ready() -> void:
	# Three marked cubes in a row (2 m apart, within the 6 m chain radius)...
	for x in [0.0, 2.0, 4.0]:
		_marked_row.append(_spawn_enemy(Vector3(x, 0.5, 0.0), true))
	# ...and an unmarked bystander off to the side: the chain must ignore it.
	_bystander = _spawn_enemy(Vector3(2.0, 0.5, 4.0), false)

	# Fire one line bolt at the row.
	var bolt := BOLT_SCENE.instantiate()
	add_child(bolt)
	bolt.global_position = Vector3(-3.0, 0.5, 0.0)
	bolt.launch(Vector3.RIGHT, 25.0, 26.0, 2.0, 6.0, BOLT_SCENE)


func _process(delta: float) -> void:
	_timer += delta
	if _phase == 0 and _timer > 2.0:
		_check_chain()
	elif _phase == 1 and _timer > 2.0:
		_check_spread()


func _check_chain() -> void:
	var alive := _marked_row.filter(func(e): return is_instance_valid(e))
	# Explicit bool: _bystander.hp is a dynamic access (Variant), := can't infer.
	var bystander_ok: bool = is_instance_valid(_bystander) and _bystander.hp == 40.0
	if alive.is_empty() and bystander_ok:
		print("[RuneChainTest] chain: PASS (3 marked cubes died, bystander untouched)")
		_start_spread_test()
	else:
		print("[RuneChainTest] chain: FAIL (%d marked alive, bystander ok=%s)"
			% [alive.size(), bystander_ok])
		get_tree().quit(1)


func _start_spread_test() -> void:
	_phase = 1
	_timer = 0.0
	_spread_carrier = _spawn_enemy(Vector3(10.0, 0.5, 0.0), true)
	_spread_neighbour = _spawn_enemy(Vector3(12.0, 0.5, 0.0), false)

	# Recast E on the already-marked carrier: the mark must spread.
	var flux := FLUX_SCENE.instantiate()
	add_child(flux)
	flux.global_position = Vector3(8.0, 1.0, 0.0)
	flux.launch(_spread_carrier, 20.0, 30.0, 5.0, true, FLUX_SCENE)


func _check_spread() -> void:
	var ok := is_instance_valid(_spread_neighbour) \
		and _spread_neighbour.get_node_or_null("RuneMark") != null
	if ok:
		print("[RuneChainTest] spread: PASS (neighbour contaminated)")
		get_tree().quit(0)
	else:
		print("[RuneChainTest] spread: FAIL (neighbour not marked)")
		get_tree().quit(1)


func _spawn_enemy(pos: Vector3, marked: bool) -> Node3D:
	var enemy := ENEMY_SCENE.instantiate()
	add_child(enemy)
	enemy.global_position = pos
	if marked:
		var mark := RuneMark.new()
		mark.name = "RuneMark"
		mark.duration = 30.0 # long fuse: must not expire mid-test
		enemy.add_child(mark)
	return enemy
