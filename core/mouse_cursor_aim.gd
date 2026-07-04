extends AimStrategy
class_name MouseCursorAim

## RTS camera: the mouse is free, so aim through the actual cursor position.

func _screen_point(camera: Camera3D) -> Vector2:
	return camera.get_viewport().get_mouse_position()
