extends RefCounted
class_name SphereControlState

## State pattern for the *active* sphere's control mode. A control state maps
## player input to the sphere's capabilities and chooses which physics
## behaviours run each step. The sphere (SphereController) owns the mechanics —
## rolling, jumping, boosting, firing, AOE — and the state only drives them.
##
## Why state objects instead of swapping the node's script at runtime: Godot
## discourages set_script() mid-game (it discards node state and is fragile to
## refactors). A small RefCounted state held by the controller is the idiomatic,
## testable State-pattern approach and keeps one stable script on the node.

var sphere: SphereController


func _init(controller: SphereController) -> void:
	sphere = controller


## Called when this state becomes active / inactive.
func enter() -> void:
	pass


func exit() -> void:
	pass


## Per-frame input handling (called from the sphere's _process).
func handle_input(_delta: float) -> void:
	pass


## Per-physics-step behaviour (called from the sphere's _integrate_forces).
func physics(_physics_state: PhysicsDirectBodyState3D) -> void:
	pass


## Albedo / glow colour that signals this state on the ball.
func tint() -> Color:
	return Color.WHITE


## Short name shown in the HUD.
func label() -> String:
	return "?"
