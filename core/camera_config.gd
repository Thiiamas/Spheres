extends Resource
class_name CameraConfig

## Data-driven camera configuration. Each possessable entity exposes one or more
## of these via its Controllable; the camera rig applies them on possession (and
## cycles them with "camera_toggle"). The two current camera behaviours become
## resources: sphere_follow.tres (chase cam) and sphere_rts.tres (overhead).

## Camera behaviour this config drives:
##   &"follow"  - chase cam trailing the entity (mouse captured for aiming)
##   &"topdown" - high angled RTS-style view (mouse free, aims via cursor)
##   &"fixed"   - camera stays where it is, only looks at the entity
@export var mode: StringName = &"follow"

@export_group("Follow")
## Distance behind the entity (follow mode).
@export var follow_distance: float = 6.0
## Height above the entity (follow mode).
@export var height: float = 3.0
## Vertical offset of the look-at point.
@export var look_height: float = 1.0
## Exponential smoothing speed of the chase.
@export var follow_speed: float = 8.0

@export_group("Topdown")
## Downward tilt in degrees.
@export var pitch: float = 55.0
## Fixed compass yaw in degrees.
@export var yaw: float = 45.0
## Starting distance from the focus point.
@export var zoom: float = 18.0
@export var zoom_min: float = 8.0
@export var zoom_max: float = 45.0
## Mouse-wheel zoom step.
@export var zoom_step: float = 2.5
## RTS free-pan (topdown only): the camera doesn't track the entity and is
## panned by the player instead (edge-scroll + cam_pan_* fallback, see
## CameraRig._apply_pan). False keeps the classic entity-following topdown
## (sphere_rts.tres).
@export var free_pan: bool = false

@export_group("Lens")
@export var fov: float = 75.0
