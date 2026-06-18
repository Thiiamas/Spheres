extends Camera3D
class_name SphereCamera

## Two-mode camera.
##
##   FOLLOW - smooth chase cam that trails behind the ball based on reactor yaw
##            (the original behaviour). Mouse is captured for aiming.
##   RTS    - high, angled, StarCraft/LoL-style overhead view that follows the
##            ball. The mouse is freed and used only to aim the reactor (boost
##            flies toward the cursor); zoom with the mouse wheel. Free-panning
##            with arrow keys / edge-scroll is available via exports but off by
##            default so the mouse never moves the camera.
##
## Toggle modes with the "camera_toggle" action (C / gamepad Select).

enum Mode { FOLLOW, RTS }

@export var mode: Mode = Mode.FOLLOW

@export_group("Targets")
@export var target: Node3D   ## The ball to follow / center on.
@export var reactor: Reactor ## Source of orbit yaw in FOLLOW mode.

@export_group("Follow Mode")
@export var distance: float = 6.0
@export var height: float = 3.0
@export var look_height: float = 1.0
@export var follow_speed: float = 8.0

@export_group("RTS Mode")
@export var rts_pitch: float = 55.0       ## Downward tilt in degrees.
@export var rts_yaw: float = 45.0         ## Fixed compass yaw in degrees.
@export var rts_zoom: float = 18.0        ## Current distance from the focus point.
@export var rts_zoom_min: float = 8.0
@export var rts_zoom_max: float = 45.0
@export var rts_zoom_step: float = 2.5
@export var rts_pan_speed: float = 22.0   ## Pan units/sec (scaled up when zoomed out). Only used when not following.
@export var rts_edge_margin: float = 18.0 ## Pixels from a screen edge that start scrolling.
@export var rts_edge_scroll: bool = false ## Mouse-edge panning. Off so the mouse only aims the reactor.
@export var rts_recenter_on_enter: bool = true ## Snap focus to the ball when entering RTS.
@export var rts_follow_target: bool = true     ## Camera tracks the ball instead of free-panning.

# The ground point the RTS camera looks at.
var _rts_focus: Vector3 = Vector3.ZERO
const _RTS_ZOOM_REF: float = 18.0 # zoom at which pan_speed is unscaled


func _ready() -> void:
	_apply_mode_state()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_toggle"):
		_set_mode(Mode.RTS if mode == Mode.FOLLOW else Mode.FOLLOW)
		return

	# Mouse-wheel zoom, RTS only.
	if mode == Mode.RTS and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			rts_zoom = clampf(rts_zoom - rts_zoom_step, rts_zoom_min, rts_zoom_max)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			rts_zoom = clampf(rts_zoom + rts_zoom_step, rts_zoom_min, rts_zoom_max)


func _set_mode(new_mode: Mode) -> void:
	mode = new_mode
	if mode == Mode.RTS and rts_recenter_on_enter and target != null:
		_rts_focus = target.global_position
	_apply_mode_state()


## FOLLOW captures the mouse (for aiming) and lets the reactor read mouse/stick.
## RTS frees the mouse (edge scroll / cursor aim) and hands reactor aim to us.
func _apply_mode_state() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mode == Mode.FOLLOW else Input.MOUSE_MODE_VISIBLE
	if reactor != null:
		reactor.external_aim = mode == Mode.RTS


func _physics_process(delta: float) -> void:
	if target == null:
		return
	match mode:
		Mode.FOLLOW:
			_update_follow(delta)
		Mode.RTS:
			_update_rts(delta)


## The horizontal yaw the player is "looking along" in the current mode. The
## controller uses this so ground movement is camera-relative the same way in
## both modes: FOLLOW trails the reactor aim, RTS uses its fixed compass yaw.
func get_view_yaw() -> float:
	match mode:
		Mode.RTS:
			return rts_yaw
		_:
			return reactor.yaw if reactor else 0.0


func _update_follow(delta: float) -> void:
	var aim_yaw := reactor.yaw if reactor else 0.0
	var offset := Basis(Vector3.UP, deg_to_rad(aim_yaw)) * Vector3(0.0, height, distance)
	var desired := target.global_position + offset

	var t := 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(desired, t)
	look_at(target.global_position + Vector3.UP * look_height, Vector3.UP)


func _update_rts(delta: float) -> void:
	if rts_follow_target:
		_rts_focus = _rts_focus.lerp(target.global_position, 1.0 - exp(-4.0 * delta))
	else:
		_apply_pan(delta)

	# Place the camera up-and-back from the focus point at the configured tilt.
	var p := deg_to_rad(rts_pitch)
	var flat := cos(p) * rts_zoom # horizontal distance from focus
	var up := sin(p) * rts_zoom   # height above focus
	var offset := Basis(Vector3.UP, deg_to_rad(rts_yaw)) * Vector3(0.0, up, flat)

	global_position = _rts_focus + offset
	look_at(_rts_focus, Vector3.UP)

	_aim_reactor_at_cursor()


## Project the mouse cursor onto a horizontal plane at the ball's height and
## point the reactor toward it, so boosting flies the ball toward the cursor.
func _aim_reactor_at_cursor() -> void:
	if reactor == null:
		return
	var view_size := get_viewport().get_visible_rect().size
	var m := get_viewport().get_mouse_position()
	if m.x < 0.0 or m.y < 0.0 or m.x > view_size.x or m.y > view_size.y:
		return # cursor outside the window; keep last aim

	var ray_from := project_ray_origin(m)
	var ray_dir := project_ray_normal(m)
	var ground := Plane(Vector3.UP, target.global_position.y)
	var hit = ground.intersects_ray(ray_from, ray_dir)
	if hit != null:
		reactor.aim_toward(hit)


func _apply_pan(delta: float) -> void:
	var pan := Vector2(
		Input.get_axis("cam_pan_left", "cam_pan_right"),
		Input.get_axis("cam_pan_up", "cam_pan_down")
	)

	if rts_edge_scroll and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		var view_size := get_viewport().get_visible_rect().size
		var m := get_viewport().get_mouse_position()
		# Only react when the cursor is actually inside the window.
		if m.x >= 0.0 and m.y >= 0.0 and m.x <= view_size.x and m.y <= view_size.y:
			if m.x < rts_edge_margin:
				pan.x -= 1.0
			elif m.x > view_size.x - rts_edge_margin:
				pan.x += 1.0
			if m.y < rts_edge_margin:
				pan.y -= 1.0
			elif m.y > view_size.y - rts_edge_margin:
				pan.y += 1.0

	if pan == Vector2.ZERO:
		return

	pan = pan.limit_length(1.0)
	# Pan in the camera's compass plane; move faster when zoomed further out.
	var move := Basis(Vector3.UP, deg_to_rad(rts_yaw)) * Vector3(pan.x, 0.0, pan.y)
	_rts_focus += move * rts_pan_speed * (rts_zoom / _RTS_ZOOM_REF) * delta
