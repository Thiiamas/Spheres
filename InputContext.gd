extends RefCounted
class_name InputContext

## Normalized snapshot of one frame of player input, built ONCE per frame by the
## possession layer (Consciousness) and pushed to the active Controllable via
## handle_input(ctx). Possessable entities never read Input.* themselves — this
## class is the single place that samples the input singleton.
##
## Why: decouples input mapping from entity logic, and makes AI control trivial:
## drive any entity by synthesizing an InputContext by hand (set the fields,
## call handle_input) instead of faking InputEvents.

## Actions sampled into `actions` each frame. Entity-facing gameplay actions
## only — possession-layer actions (transfer) and camera actions (camera_toggle)
## stay with their owners. Key overlaps across entities (attack=A vs spell_a=A)
## are harmless: each entity only consumes its own actions.
const TRACKED_ACTIONS: Array[StringName] = [
	&"jump", &"boost", &"attack", &"aoe", &"mode_toggle",
	&"move_click", &"spell_a", &"spell_z", &"spell_e",
]

## WASD / left stick, in input space (x = left/right, y = forward/back).
var move_vector: Vector2 = Vector2.ZERO
## Mouse delta / right stick. (Reserved: reactor aiming still owns its own
## mouse handling for now — see Reactor.gd.)
var look_vector: Vector2 = Vector2.ZERO
## World-space point the player is aiming at (cursor projected by the camera:
## enemy under pointer, else ground plane). Resolved by the possession layer.
var world_cursor: Vector3 = Vector3.ZERO
## The enemy body under the cursor, if any (null otherwise). Resolved by the
## possession layer alongside world_cursor; used by targeted spells and the
## hover-reactive cursor.
var hover_target: Node3D = null
## action StringName -> { "pressed": bool, "just_pressed": bool }.
var actions: Dictionary = {}
## Frame delta, so handle_input(ctx) needs no second parameter.
var delta: float = 0.0


## Sample the real Input singleton for this frame.
static func capture(frame_delta: float) -> InputContext:
	var ctx := InputContext.new()
	ctx.delta = frame_delta
	ctx.move_vector = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	for action in TRACKED_ACTIONS:
		ctx.actions[action] = {
			"pressed": Input.is_action_pressed(action),
			"just_pressed": Input.is_action_just_pressed(action),
		}
	return ctx


func pressed(action: StringName) -> bool:
	return actions.get(action, {}).get("pressed", false)


func just_pressed(action: StringName) -> bool:
	return actions.get(action, {}).get("just_pressed", false)


## Set an action state by hand (AI / tests — synthetic contexts).
func set_action(action: StringName, is_pressed: bool, is_just_pressed: bool = false) -> void:
	actions[action] = { "pressed": is_pressed, "just_pressed": is_just_pressed }


## Re-sample the *held* state (move vector, pressed flags) at physics rate, so
## physics-driven behaviours (roll, boost) read input as fresh as they did when
## they polled Input directly. Edge flags (just_pressed) keep their per-frame
## timing and are not touched. Called by the possession layer only — never on
## synthetic contexts.
func refresh_held() -> void:
	move_vector = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	for action in actions:
		actions[action]["pressed"] = Input.is_action_pressed(action)
