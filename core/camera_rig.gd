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
##   &"topdown" - high, angled, StarCraft/LoL-style overhead view. By default
##                follows the entity; the mouse is freed and used to aim the
##                reactor, zoom with the mouse wheel, rotate by dragging the
##                middle mouse button (RuneScape-style). CameraConfig.free_pan
##                switches this to an RTS-style free camera instead (edge-scroll
##                + cam_pan_* fallback, no entity tracking) — see base_freepan.tres.
##   &"fixed"   - the camera stays where it is and only looks at the entity.

@export_group("Targets")
@export var target: Node3D   ## The entity to follow / center on.
@export var reactor: Reactor ## Source of orbit yaw in follow mode (spheres only).

@export_group("Topdown behaviour")
## Pan units/sec (scaled up when zoomed out). Only used when not following.
@export var pan_speed: float = 22.0
## Pixels from a screen edge that start scrolling.
@export var edge_margin: float = 90.0
## Mouse-edge panning. Overridden per possession by CameraConfig.free_pan in
## apply_config() — the export is only the value before any config has applied.
@export var edge_scroll: bool = false
## Snap focus to the entity when entering topdown.
@export var recenter_on_enter: bool = true
## Camera tracks the entity instead of free-panning. Overridden per possession
## by CameraConfig.free_pan in apply_config(), same as edge_scroll above.
@export var follow_target: bool = true
## Degrees of orbit per pixel of middle-button drag (phase 9.1 finitions).
@export var rotate_sensitivity: float = 0.35

## The configuration currently applied (null until the first possession).
var config: CameraConfig = null

# Zoom is RIG state, not config state: the player's wheel zoom survives config
# cycling and possession transfers (as it did when it was an export). It is
# seeded from the first topdown config applied, then only clamped.
var _zoom: float = -1.0
# Orbit yaw, same deal as _zoom: RIG state, not config state, so a camera the
# player turned stays turned across config cycling and possession transfers.
# Seeded from the first topdown CameraConfig applied (INF = never seeded);
# CameraConfig.yaw is therefore the *starting* compass angle, not a constant.
var _yaw: float = INF
# True while the middle mouse button is held (orbit drag in progress).
var _rotating: bool = false
# The ground point the topdown camera looks at.
var _rts_focus: Vector3 = Vector3.ZERO
const _ZOOM_REF: float = 18.0 # zoom at which pan_speed is unscaled

# Smoothed pan input (see _apply_pan) — keeps free-pan from snapping straight
# to full speed the instant the cursor crosses edge_margin.
var _pan_velocity: Vector2 = Vector2.ZERO
const _PAN_SMOOTHING: float = 10.0

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
	# Duck-typed rather than a SphereController check only: the RuneMage
	# (phase 8.2, camera-relative ZQSD) wants the same view-yaw feed and has
	# no other trait in common with the sphere.
	if target != null and target.has_method("bind_camera"):
		target.bind_camera(self)

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

	if config == null or config.mode != &"topdown":
		return

	# Mouse-wheel zoom and middle-drag orbit, topdown only. Both read raw mouse
	# events rather than Input Map actions: the wheel has no action either, and
	# keeping the orbit off the action list avoids competing with the arrows
	# (cam_pan_*) or the left click (select/attack — see PLAN.md's known debt).
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		_rotating = event.pressed
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = clampf(_zoom - config.zoom_step, config.zoom_min, config.zoom_max)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clampf(_zoom + config.zoom_step, config.zoom_min, config.zoom_max)
		return

	if _rotating and event is InputEventMouseMotion:
		# Horizontal drag only: pitch stays a per-config authored value, so the
		# view can't be tipped into an unreadable angle mid-fight.
		# Negated so the world follows the cursor (drag right and the scene
		# swings right, like grabbing the ground) — the opposite sign felt
		# backwards in playtest.
		_yaw = fposmod(_yaw - event.relative.x * rotate_sensitivity, 360.0)


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
		# The two pan behaviours below were exports on the rig itself before
		# free_pan existed on the config (they still are — this just makes
		# them follow the possessed entity's own config instead of staying
		# fixed for the whole scene). False for every config restores the
		# original follow-the-entity topdown (sphere_rts.tres, mage_topdown.tres).
		follow_target = not cfg.free_pan
		edge_scroll = cfg.free_pan
		if _zoom < 0.0:
			_zoom = cfg.zoom # first topdown ever: seed from data
		_zoom = clampf(_zoom, cfg.zoom_min, cfg.zoom_max)
		if is_inf(_yaw):
			_yaw = cfg.yaw # first topdown ever: seed from data, then player-owned
		if recenter_on_enter and target != null:
			_rts_focus = target.global_position


## Resolve where the active entity should shoot, based on the current mouse
## pointing and camera mode. Delegated to the mode's AimStrategy.
func get_aim_target(origin: Vector3) -> Vector3:
	return _aim_strategy.resolve(self, origin)


## Full aim resolution: world point + the enemy under the pointer (or null).
## The possession layer feeds both into each frame's InputContext.
func get_aim_info(origin: Vector3) -> AimStrategy.AimInfo:
	return _aim_strategy.resolve_info(self, origin)


## Raycasts the current mouse position against `mask`, independent of
## AimStrategy (which only ever looks for enemies, for combat aiming). Used
## by the possession layer's "select" action (phase 8.2,
## Docs/Plans/phase8_foundations.md) to find a clickable ally — a FrontUnit
## body, or a Base's Area3D SelectionArea — under the cursor.
func raycast_at_cursor(mask: int) -> Node3D:
	var m := get_viewport().get_mouse_position()
	var from := project_ray_origin(m)
	var dir := project_ray_normal(m)
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 200.0)
	query.collision_mask = mask
	query.collide_with_areas = true # Base's SelectionArea is an Area3D, not a body
	var hit := space.intersect_ray(query)
	return hit.collider as Node3D if hit else null


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
## sphere controller and the RuneMage's ZQSD use this so ground movement stays
## camera-relative in every mode: follow trails the reactor aim, topdown uses
## the current orbit angle — which the player can now turn, so "forward"
## follows the camera around rather than being a fixed compass direction.
func get_view_yaw() -> float:
	if config != null and config.mode == &"topdown":
		return _current_yaw()
	return reactor.yaw if reactor else 0.0


## Orbit angle in degrees: the player-turned value once a topdown config has
## seeded it, the raw config value before that.
func _current_yaw() -> float:
	if is_inf(_yaw):
		return config.yaw if config != null else 0.0
	return _yaw


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
	var offset := Basis(Vector3.UP, deg_to_rad(_current_yaw())) * Vector3(0.0, up, flat)

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
			# Graduated by proximity to the edge (0 at edge_margin, 1 at the
			# screen edge) rather than an on/off flag — a hard binary snap to
			# full speed the instant the cursor crosses edge_margin is what
			# made this feel jerky.
			if m.x < edge_margin:
				pan.x -= 1.0 - m.x / edge_margin
			elif m.x > view_size.x - edge_margin:
				pan.x += (m.x - (view_size.x - edge_margin)) / edge_margin
			if m.y < edge_margin:
				pan.y -= 1.0 - m.y / edge_margin
			elif m.y > view_size.y - edge_margin:
				pan.y += (m.y - (view_size.y - edge_margin)) / edge_margin

	pan = pan.limit_length(1.0)
	# Smooth the applied velocity itself, on top of the graduated edge speed
	# above, so panning ramps in/out instead of jumping frame-to-frame.
	_pan_velocity = _pan_velocity.lerp(pan, 1.0 - exp(-_PAN_SMOOTHING * delta))
	if _pan_velocity.length() < 0.001:
		return

	# Pan in the camera's compass plane; move faster when zoomed further out.
	# Reads the live orbit angle, so panning stays screen-relative ("left" is
	# always screen-left) after the player turns the view.
	var move := Basis(Vector3.UP, deg_to_rad(_current_yaw())) * Vector3(_pan_velocity.x, 0.0, _pan_velocity.y)
	_rts_focus += move * pan_speed * (_zoom / _ZOOM_REF) * delta
