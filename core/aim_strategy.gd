extends RefCounted
class_name AimStrategy

## Strategy pattern: turn the player's current pointing into a world-space aim
## point for the active sphere's attack. The concrete strategy depends on the
## camera mode (chosen by CameraRig): topdown uses the free mouse cursor, follow
## uses the screen centre because the mouse is captured for reactor aiming.
##
## Subclasses only decide *which screen point* to aim through; the screen→world
## projection below is shared.

## Enemies live on physics layer 2 (see Enemy.tscn).
const ENEMY_MASK := 2


func resolve(camera: Camera3D, origin: Vector3) -> Vector3:
	return resolve_info(camera, origin).position


## Full aim resolution: the world point AND the enemy body under the pointer
## (null when aiming at the ground). Targeted spells and the hover-reactive
## cursor need the collider, not just the point.
func resolve_info(camera: Camera3D, origin: Vector3) -> AimInfo:
	return _info_from_screen(camera, _screen_point(camera), origin)


class AimInfo:
	var position: Vector3 = Vector3.ZERO
	var target: Node3D = null


## Screen-space point to aim through. Default is the viewport centre (crosshair).
func _screen_point(camera: Camera3D) -> Vector2:
	return camera.get_viewport().get_visible_rect().size * 0.5


## Shared projection: prefer an enemy under the pointer (position + collider);
## otherwise the ground plane at the firing height; otherwise a point far
## along the ray.
func _info_from_screen(camera: Camera3D, screen: Vector2, origin: Vector3) -> AimInfo:
	var info := AimInfo.new()
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)

	var space := camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 200.0)
	query.collision_mask = ENEMY_MASK
	var hit := space.intersect_ray(query)
	if hit:
		info.position = hit.position
		info.target = hit.collider as Node3D
		return info

	var ground := Plane(Vector3.UP, origin.y)
	var ground_hit = ground.intersects_ray(from, dir)
	if ground_hit != null:
		info.position = ground_hit
		return info

	info.position = from + dir * 30.0
	return info
