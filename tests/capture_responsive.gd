extends SceneTree
var failures=0
func _initialize():call_deferred("run")
func frames():
    for i in range(8):await process_frame
func capture(name):
    await frames();await RenderingServer.frame_post_draw
    var image=root.get_texture().get_image()
    assert(image.save_png("res://docs/"+name+".png")==OK)
    print("RESPONSIVE_CAPTURE ",name," ",image.get_size())
func inside(control):
    var rect=control.get_global_rect();var view=root.get_visible_rect()
    if not (rect.position.x>=-1 and rect.position.y>=-1 and rect.end.x<=view.size.x+1 and rect.end.y<=view.size.y+1):
        failures+=1;printerr("OUTSIDE_VIEWPORT ",rect)
func run():
    var suffix=str(root.size.x)+"x"+str(root.size.y)
    change_scene_to_file("res://ui/menu.tscn");await frames()
    await capture("responsive-menu-"+suffix)
    current_scene.show_network();await frames();inside(current_scene.card)
    await capture("responsive-network-"+suffix)
    var app=root.get_node("App");app.new_game();change_scene_to_file("res://main.tscn");await frames()
    inside(current_scene.hud.story_panel);await capture("responsive-story-"+suffix)
    while not app.next_story().is_empty():app.advance_story(true)
    current_scene.refresh();await frames()
    for control in [current_scene.hud.status_panel,current_scene.hud.companion_panel,current_scene.hud.action_panel,current_scene.hud.turn_button]:inside(control)
    var camera=current_scene.camera
    for cell in current_scene.tiles:
        var projected=camera.unproject_position(Vector3(cell.x,0,cell.y))
        var origin=camera.project_ray_origin(projected);var ray=camera.project_ray_normal(projected)
        var point=origin+ray*(-origin.y/ray.y)
        if Vector2i(roundi(point.x),roundi(point.z))!=cell:failures+=1
    current_scene.update_move_preview(Vector2i(4,4));await capture("responsive-path-"+suffix)
    current_scene.hud.toggle_pause();await frames();inside(current_scene.hud.modal.get_child(0))
    await capture("responsive-pause-"+suffix)
    print("RESPONSIVE_RESULT ",suffix," failures=",failures);quit(1 if failures else 0)
