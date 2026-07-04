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
	return _world_from_screen(camera, _screen_point(camera), origin)


## Screen-space point to aim through. Default is the viewport centre (crosshair).
func _screen_point(camera: Camera3D) -> Vector2:
	return camera.get_viewport().get_visible_rect().size * 0.5


## Shared projection: prefer an enemy under the pointer; otherwise the ground
## plane at the firing height; otherwise a point far along the ray.
func _world_from_screen(camera: Camera3D, screen: Vector2, origin: Vector3) -> Vector3:
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)

	var space := camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 200.0)
	query.collision_mask = ENEMY_MASK
	var hit := space.intersect_ray(query)
	if hit:
		return hit.position

	var ground := Plane(Vector3.UP, origin.y)
	var ground_hit = ground.intersects_ray(from, dir)
	if ground_hit != null:
		return ground_hit

	return from + dir * 30.0
