extends Node3D

## Headless proof of the AI path (phase 5 validation): drive the possessed
## sphere with a *synthetic* InputContext — no keyboard, no mouse — and assert
## that it moves. Run with:
##
##   godot --headless res://Tests/SyntheticDriveTest.tscn
##
## Exit code 0 = PASS (the sphere rolled), 1 = FAIL.
##
## Note: Consciousness pushes its (empty) real InputContext to the possessed
## entity every frame before this node runs; pushing the synthetic context
## afterwards means ours is the one physics reads. An AI brain would work
## exactly like this.

const SETTLE_FRAMES := 40  # let the sphere land and the possession settle
const DRIVE_FRAMES := 120  # ~2s of synthetic forward input

var _frame := 0
var _start_pos := Vector3.ZERO


func _process(delta: float) -> void:
	var c := Consciousness.active()
	if c == null:
		return
	var sphere := c.entity as SphereController
	if sphere == null:
		return

	_frame += 1
	if _frame < SETTLE_FRAMES:
		return
	if _frame == SETTLE_FRAMES:
		_start_pos = sphere.global_position
		return

	if _frame <= SETTLE_FRAMES + DRIVE_FRAMES:
		# Synthesize the input an AI would: push forward, nothing else.
		var ctx := InputContext.new()
		ctx.delta = delta
		ctx.move_vector = Vector2(0.0, -1.0) # forward
		c.handle_input(ctx)
		return

	var moved := (sphere.global_position - _start_pos).length()
	var passed := moved > 1.0
	print("[SyntheticDriveTest] displacement = %.2f m -> %s"
		% [moved, "PASS" if passed else "FAIL"])
	get_tree().quit(0 if passed else 1)
