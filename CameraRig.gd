extends Camera3D
class_name CameraRig

## The single scene camera, reconfigured per possessed entity (data-driven).
## Behaviour comes from CameraConfig resources exposed by the possessed
## entity's Controllable: index 0 is applied on possession and "camera_toggle"
## (C / gamepad Select) cycles through the entity's configs.
##
## Modes (CameraConfig.mode):
##   &"follow"  - smooth chase cam trailing the entity based on reactor yaw.
##                Mouse is captured for aiming.
##   &"topdown" - high, angled, StarCraft/LoL-style overhead view that follows
##                the entity. The mouse is freed and used to aim the reactor;
##                zoom with the mouse wheel. Free-panning is available via
##                exports but off by default.
##   &"fixed"   - the camera stays where it is and only looks at the entity.

@export_group("Targets")
@export var target: Node3D   ## The entity to follow / center on.
@export var reactor: Reactor ## Source of orbit yaw in follow mode (spheres only).

@export_group("Topdown behaviour")
## Pan units/sec (scaled up when zoomed out). Only used when not following.
@export var pan_speed: float = 22.0
## Pixels from a screen edge that start scrolling.
@export var edge_margin: float = 18.0
## Mouse-edge panning. Off so the mouse only aims the reactor.
@export var edge_scroll: bool = false
## Snap focus to the entity when entering topdown.
@export var recenter_on_enter: bool = true
## Camera tracks the entity instead of free-panning.
@export var follow_target: bool = true

## The configuration currently applied (null until the first possession).
var config: CameraConfig = null

# Zoom is RIG state, not config state: the player's wheel zoom survives config
# cycling and possession transfers (as it did when it was an export). It is
# seeded from the first topdown config applied, then only clamped.
var _zoom: float = -1.0
# The ground point the topdown camera looks at.
var _rts_focus: Vector3 = Vector3.ZERO
const _ZOOM_REF: float = 18.0 # zoom at which pan_speed is unscaled

# How the active entity's attack resolves "where the mouse points", swapped per
# camera mode (Strategy pattern). See AimStrategy.
var _aim_strategy: AimStrategy = ScreenCenterAim.new()

# The possessed entity's contract — supplies the camera configs we cycle.
var _active: Controllable = null


func _ready() -> void:
	# The possession layer asks us where the player is aiming (world_cursor)
	# when it builds each frame's InputContext.
	Consciousness.camera_rig = self

	# Follow whichever entity the consciousness currently inhabits, and keep up
	# as control transfers between entities.
	Consciousness.active_changed.connect(_on_active_changed)
	if Consciousness.active() != null:
		_on_active_changed(Consciousness.active())

	# Until an entity supplies a config (activation is deferred one frame),
	# behave like a default chase cam.
	if config == null:
		apply_config(CameraConfig.new())


## Retarget onto the newly possessed entity: track it, apply its camera config
## and, when it's a sphere, read its reactor for orbit / cursor aiming and let
## it know which camera drives its camera-relative rolling.
func _on_active_changed(controllable: Controllable) -> void:
	_active = controllable
	target = controllable.entity as Node3D
	var sphere := controllable.entity as SphereController
	reactor = sphere.get_reactor() if sphere != null else null
	if sphere != null:
		sphere.bind_camera(self)

	var cfg := controllable.get_camera_config()
	apply_config(cfg if cfg != null else config)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_toggle"):
		# Cycle the possessed entity's camera configs (entities with a single
		# config simply keep it).
		if _active != null:
			var cfg := _active.cycle_camera_config()
			if cfg != null:
				apply_config(cfg)
		return

	# Mouse-wheel zoom, topdown only.
	if config != null and config.mode == &"topdown" \
			and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = clampf(_zoom - config.zoom_step, config.zoom_min, config.zoom_max)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clampf(_zoom + config.zoom_step, config.zoom_min, config.zoom_max)


## Reconfigure the rig from data. Follow captures the mouse (for aiming) and
## lets the reactor read mouse/stick; anything else frees the mouse (cursor
## aim) and hands reactor aim to us.
func apply_config(cfg: CameraConfig) -> void:
	if cfg == null:
		return
	config = cfg
	fov = cfg.fov

	var is_follow := cfg.mode == &"follow"
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if is_follow else Input.MOUSE_MODE_VISIBLE
	if reactor != null:
		reactor.external_aim = not is_follow
	# Follow aims through the screen centre; the rest through the free cursor.
	_aim_strategy = ScreenCenterAim.new() if is_follow else MouseCursorAim.new()

	if cfg.mode == &"topdown":
		if _zoom < 0.0:
			_zoom = cfg.zoom # first topdown ever: seed from data
		_zoom = clampf(_zoom, cfg.zoom_min, cfg.zoom_max)
		if recenter_on_enter and target != null:
			_rts_focus = target.global_position


## Resolve where the active entity should shoot, based on the current mouse
## pointing and camera mode. Delegated to the mode's AimStrategy.
func get_aim_target(origin: Vector3) -> Vector3:
	return _aim_strategy.resolve(self, origin)


func _physics_process(delta: float) -> void:
	if config == null or target == null or not is_instance_valid(target):
		return
	match config.mode:
		&"follow":
			_update_follow(delta)
		&"topdown":
			_update_topdown(delta)
		&"fixed":
			_update_fixed()


## The horizontal yaw the player is "looking along" in the current mode. The
## sphere controller uses this so ground movement is camera-relative the same
## way in every mode: follow trails the reactor aim, topdown uses its fixed
## compass yaw.
func get_view_yaw() -> float:
	if config != null and config.mode == &"topdown":
		return config.yaw
	return reactor.yaw if reactor else 0.0


func _update_follow(delta: float) -> void:
	var aim_yaw := reactor.yaw if reactor else 0.0
	var offset := Basis(Vector3.UP, deg_to_rad(aim_yaw)) \
		* Vector3(0.0, config.height, config.follow_distance)
	var desired := target.global_position + offset

	var t := 1.0 - exp(-config.follow_speed * delta)
	global_position = global_position.lerp(desired, t)
	look_at(target.global_position + Vector3.UP * config.look_height, Vector3.UP)


func _update_topdown(delta: float) -> void:
	if follow_target:
		_rts_focus = _rts_focus.lerp(target.global_position, 1.0 - exp(-4.0 * delta))
	else:
		_apply_pan(delta)

	# Place the camera up-and-back from the focus point at the configured tilt.
	var p := deg_to_rad(config.pitch)
	var flat := cos(p) * _zoom # horizontal distance from focus
	var up := sin(p) * _zoom   # height above focus
	var offset := Basis(Vector3.UP, deg_to_rad(config.yaw)) * Vector3(0.0, up, flat)

	global_position = _rts_focus + offset
	look_at(_rts_focus, Vector3.UP)

	_aim_reactor_at_cursor()


## Fixed camera: stay put, keep the entity in view.
func _update_fixed() -> void:
	look_at(target.global_position + Vector3.UP * config.look_height, Vector3.UP)


## Project the mouse cursor onto a horizontal plane at the entity's height and
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

	if edge_scroll and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		var view_size := get_viewport().get_visible_rect().size
		var m := get_viewport().get_mouse_position()
		# Only react when the cursor is actually inside the window.
		if m.x >= 0.0 and m.y >= 0.0 and m.x <= view_size.x and m.y <= view_size.y:
			if m.x < edge_margin:
				pan.x -= 1.0
			elif m.x > view_size.x - edge_margin:
				pan.x += 1.0
			if m.y < edge_margin:
				pan.y -= 1.0
			elif m.y > view_size.y - edge_margin:
				pan.y += 1.0

	if pan == Vector2.ZERO:
		return

	pan = pan.limit_length(1.0)
	# Pan in the camera's compass plane; move faster when zoomed further out.
	var move := Basis(Vector3.UP, deg_to_rad(config.yaw)) * Vector3(pan.x, 0.0, pan.y)
	_rts_focus += move * pan_speed * (_zoom / _ZOOM_REF) * delta
