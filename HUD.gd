extends Label

## Minimal debug HUD: shows the controller's current state, reactor aim angles,
## and speed so you can see exactly when GROUNDED / AIRBORNE / FLYING engages.

@export var ball: SphereController
@export var reactor: Reactor
@export var camera: CameraRig


func _ready() -> void:
	# Follow the active entity as consciousness transfers between entities.
	Consciousness.active_changed.connect(_on_active_changed)
	if Consciousness.active() != null:
		_on_active_changed(Consciousness.active())

	print("[HUD] ball=", ball, " reactor=", reactor, " camera=", camera)


## Type-agnostic retarget: show the sphere debug block when a sphere is
## possessed, otherwise just name the possessed entity.
func _on_active_changed(controllable: Controllable) -> void:
	ball = controllable.entity as SphereController
	reactor = ball.get_reactor() if ball != null else null


func _process(_delta: float) -> void:
	if ball == null or not is_instance_valid(ball):
		var c := Consciousness.active()
		if c == null or c.entity == null:
			text = "(no active entity)"
		else:
			text = "Possessing: %s  (Tab to transfer)" % c.entity.name
		return

	var mode_name: String = SphereController.Mode.keys()[ball.mode]
	var phase_name: String = SphereController.State.keys()[ball.movement_phase]
	# Read the possession layer's normalized input instead of polling Input.
	var ctx := Consciousness.last_context
	var boosting := ctx != null and ctx.pressed(&"boost")

	var lines := []
	var count := Consciousness.entities.size()
	if count > 1:
		lines.append("Entity: %d/%d  (Tab to transfer)" % [Consciousness.current_index + 1, count])
	lines.append("Mode: %s  (F to switch)" % mode_name)
	if ball.mode == SphereController.Mode.ATTACK:
		lines.append("  A: fire   Z: AOE orb (Z again to detonate)")
	else:
		lines.append("Phase: %s   Boost: %s" % [phase_name, ("yes" if boosting else "no")])
	lines.append("Speed: %.1f m/s" % ball.linear_velocity.length())
	if reactor != null:
		lines.append("Reactor yaw: %.0f°  pitch: %.0f°" % [reactor.yaw, reactor.pitch])
	if camera != null and camera.config != null:
		lines.append("Camera: %s  (C to toggle)" % String(camera.config.mode).to_upper())

	text = "\n".join(lines)
