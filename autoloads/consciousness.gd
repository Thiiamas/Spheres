extends Node

## Autoload singleton (registered as "Consciousness"). The player's persistent
## "soul": it tracks every possessable entity on the field and which one it
## currently inhabits. Only one entity is possessed at a time; the rest sit
## released (spheres crystallise — each entity decides what "released" means).
##
## Entities self-register through their Controllable child (see Controllable.gd
## — the consciousness only ever speaks to that contract, never to concrete
## types). The first registered entity becomes possessed (deferred, so
## cameras/HUD have a frame to subscribe); the rest start released. Pressing
## "transfer" (Tab) hands control to the next entity in the list, emitting
## active_changed so the camera and HUD can retarget.

## Emitted whenever control moves to a different entity (including the initial
## possession). Listeners receive the now-active Controllable.
signal active_changed(controllable: Controllable)

var entities: Array[Controllable] = []
var current_index: int = 0

## The camera (CameraRig) that resolves "where is the player aiming"
## (world_cursor). Registers itself in its _ready. Kept untyped so this
## autoload has no hard dependency on the rig's class.
var camera_rig = null

## The InputContext pushed to the active entity this frame (null when nothing
## is possessed). Readable by UI (HUD) so it doesn't poll Input itself.
var last_context: InputContext = null


## Build the frame's normalized input and push it to the possessed entity.
## Entities never read Input.* — this is the single sampling point.
func _process(delta: float) -> void:
	var c := active()
	if c == null:
		last_context = null
		return
	var ctx := InputContext.capture(delta)
	var entity_3d := c.entity as Node3D
	if camera_rig != null and entity_3d != null:
		var aim = camera_rig.get_aim_info(entity_3d.global_position)
		ctx.world_cursor = aim.position
		ctx.hover_target = aim.target
	last_context = ctx
	c.handle_input(ctx)


## Physics runs after _process capture, so re-sample the *held* state (move
## vector, pressed flags) each physics tick: roll/boost read input exactly as
## fresh as when they polled Input directly. Edges keep their frame timing.
func _physics_process(_delta: float) -> void:
	if last_context != null:
		last_context.refresh_held()


func register(controllable: Controllable) -> void:
	if controllable in entities:
		return
	entities.append(controllable)
	# Everyone starts released; the first one is promoted to possessed once the
	# whole scene tree has finished _ready (so listeners are connected).
	controllable.on_released()
	if entities.size() == 1:
		current_index = 0
		call_deferred("_activate_initial")


## Remove a destroyed entity from the pool. If it was the possessed one,
## control passes to the next surviving entity; otherwise the possessed entity
## is kept and the index is fixed up for the shrunken list.
func unregister(controllable: Controllable) -> void:
	var idx := entities.find(controllable)
	if idx == -1:
		return
	var was_active := idx == current_index
	entities.remove_at(idx)

	if entities.is_empty():
		current_index = 0
		return

	if was_active:
		current_index = current_index % entities.size()
		_activate(current_index)
	elif idx < current_index:
		current_index -= 1


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("transfer"):
		transfer_to_next()


## Move control to the next entity in registration order, wrapping around.
func transfer_to_next() -> void:
	if entities.size() < 2:
		return
	entities[current_index].on_released()
	current_index = (current_index + 1) % entities.size()
	_activate(current_index)


## The currently possessed entity's Controllable (null when the pool is empty).
func active() -> Controllable:
	if entities.is_empty():
		return null
	return entities[current_index]


## Clear the registry. Call before reloading the scene so freed entities from
## the old run don't linger in the list.
func reset() -> void:
	entities.clear()
	current_index = 0
	last_context = null


func _activate_initial() -> void:
	if entities.is_empty():
		return
	_activate(current_index)


func _activate(i: int) -> void:
	var controllable := entities[i]
	controllable.on_possessed()
	active_changed.emit(controllable)
