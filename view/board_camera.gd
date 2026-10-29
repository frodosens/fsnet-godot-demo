class_name BoardCamera
extends RefCounted
# Orthographic board camera helpers: screen <-> grid, projected facing and the
# pixel offset of a billboarded figure. Pure math over a Camera3D, so they can be
# tested without a scene.

var camera: Camera3D


func _init(cam: Camera3D) -> void:
    camera = cam


func cell_at(screen, scene_view):
    if scene_view and not scene_view.accepts_point(screen):return Vector2i(-1,-1)
    var origin=camera.project_ray_origin(screen);var direction=camera.project_ray_normal(screen)
    if absf(direction.y)<0.001:return Vector2i(-1,-1)
    var hit=origin+direction*(-origin.y/direction.y)
    return Vector2i(floori(hit.x+0.5),floori(hit.z+0.5))


func facing(from_cell,to_cell,diagonal=false):
    var start=camera.unproject_position(Vector3(from_cell.x,0,from_cell.y))
    var finish=camera.unproject_position(Vector3(to_cell.x,0,to_cell.y))
    var delta=finish-start
    if diagonal:return ("front_right" if delta.x>=0 else "front_left") if delta.y>=0 else ("back_right" if delta.x>=0 else "back_left")
    if absf(delta.x)>absf(delta.y):return "right" if delta.x>0 else "left"
    return "front" if delta.y>0 else "back"


func pixel_position(figure, pixel):
    if figure.get_meta("formal_art"):
        return figure.position+camera.global_basis.x*(pixel.x-48)*figure.pixel_size+camera.global_basis.y*(120-pixel.y)*figure.pixel_size
    return figure.position+camera.global_basis.x*(pixel.x-12)*figure.pixel_size+Vector3.UP*(16-pixel.y)*figure.pixel_size
