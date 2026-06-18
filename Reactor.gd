extends Node3D
class_name Reactor

## The reactor nozzle. Holds two angles (pitch + yaw) in world-relative local
## space and produces a thrust direction for the SphereController.
##
## The nozzle points "somewhat downward" at all times: at neutral angles it
## points straight down (Vector3.DOWN). Pitch is clamped to [-80, +80] degrees
## so the nozzle can never point sideways or up, which keeps boost thrust
## (which is -reactorDir) pointing somewhat upward.

@export_group("Aim Input")
## Degrees of rotation per pixel of mouse movement.
@export var mouse_sensitivity: float = 0.15
## Degrees of rotation per second at full right-stick deflection.
@export var stick_sensitivity: float = 150.0
## Capture the mouse on start so motion drives aim. Esc toggles it.
@export var capture_mouse: bool = true

@export_group("Pitch Clamp")
@export var pitch_min: float = -80.0
@export var pitch_max: float = 80.0

@export_group("RTS Aim")
## When aiming at a world point, the thrust tilt (pitch) ramps from straight-up
## at this horizontal distance to fully tilted (pitch_max) at the far distance.
@export var aim_near_dist: float = 2.0
@export var aim_far_dist: float = 15.0

## Yaw around world UP (degrees). Read by the controller (for camera-relative
## rolling) and by the camera (for orbit position).
var yaw: float = 0.0
## Pitch tilt away from straight-down (degrees), clamped to [pitch_min, pitch_max].
var pitch: float = 0.0

## When true, mouse/stick input is ignored and yaw/pitch are set externally
## (e.g. by the RTS camera aiming at the cursor's ground point).
var external_aim: bool = false

var _mouse_delta: Vector2 = Vector2.ZERO


func _ready() -> void:
	if capture_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_delta += event.relative
	elif event.is_action_pressed("ui_cancel"):
		# Toggle mouse capture so you can click away / reclaim the cursor.
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	# Skip player input while an external driver (the RTS camera) owns the aim.
	if not external_aim:
		# --- Mouse contribution (accumulated since last frame) ---
		yaw -= _mouse_delta.x * mouse_sensitivity
		pitch -= _mouse_delta.y * mouse_sensitivity
		_mouse_delta = Vector2.ZERO

		# --- Right-stick contribution ---
		var stick := Vector2(
			Input.get_axis("aim_left", "aim_right"),
			Input.get_axis("aim_up", "aim_down")
		)
		yaw -= stick.x * stick_sensitivity * delta
		pitch -= stick.y * stick_sensitivity * delta

	# Keep the nozzle pointing somewhat downward, and keep yaw in a tidy range.
	pitch = clampf(pitch, pitch_min, pitch_max)
	yaw = wrapf(yaw, -180.0, 180.0)

	# Drive the visual orientation of this node. We set the *global* basis so the
	# nozzle ignores the spinning of the parent RigidBody and stays aim-aligned.
	global_transform.basis = _aim_basis()


## Point the thrust toward a world position (used by the RTS camera for
## cursor-aiming). Sets yaw so boost pushes the ball toward the target, and
## pitch so further targets give a more horizontal (stronger lateral) thrust.
func aim_toward(target_world: Vector3) -> void:
	var to := target_world - global_position
	var horizontal := Vector2(to.x, to.z)
	if horizontal.length() < 0.001:
		return
	# Thrust horizontal component points along Basis(UP, yaw) * +Z, so:
	yaw = rad_to_deg(atan2(to.x, to.z))
	# Map horizontal distance to tilt: near -> straight up, far -> pitch_max.
	var t := clampf((horizontal.length() - aim_near_dist) / (aim_far_dist - aim_near_dist), 0.0, 1.0)
	pitch = t * pitch_max


## Orientation basis built from yaw (around world UP) then pitch (around local right).
func _aim_basis() -> Basis:
	return Basis(Vector3.UP, deg_to_rad(yaw)) * Basis(Vector3.RIGHT, deg_to_rad(pitch))


## The direction the nozzle points (where exhaust goes). Neutral = straight down.
## Thrust applied to the ball is -reactorDir * boostForce, i.e. opposite the exhaust.
func get_reactor_dir() -> Vector3:
	return (_aim_basis() * Vector3.DOWN).normalized()
