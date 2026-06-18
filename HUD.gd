extends Label

## Minimal debug HUD: shows the controller's current state, reactor aim angles,
## and speed so you can see exactly when GROUNDED / AIRBORNE / FLYING engages.

@export var ball: SphereController
@export var reactor: Reactor
@export var camera: SphereCamera


func _ready() -> void:
	print("[HUD] ball=", ball, " reactor=", reactor, " camera=", camera)


func _process(_delta: float) -> void:
	if ball == null:
		text = "(no ball assigned)"
		return

	var state_name: String = SphereController.State.keys()[ball.state]
	var boosting := Input.is_action_pressed("boost")

	var lines := [
		"State: %s" % state_name,
		"Boost held: %s" % ("yes" if boosting else "no"),
		"Speed: %.1f m/s" % ball.linear_velocity.length(),
	]
	if reactor != null:
		lines.append("Reactor yaw: %.0f°  pitch: %.0f°" % [reactor.yaw, reactor.pitch])
	if camera != null:
		var cam_mode: String = SphereCamera.Mode.keys()[camera.mode]
		lines.append("Camera: %s  (C to toggle)" % cam_mode)

	text = "\n".join(lines)
