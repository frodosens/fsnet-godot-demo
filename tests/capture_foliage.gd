extends SceneTree
func _initialize():call_deferred("run")
func run():
    var app=root.get_node("App");app.new_game(preload("res://logic/content.gd").reference_content());change_scene_to_file("res://main.tscn")
    for i in range(8):await process_frame
    while not app.next_story().is_empty():app.advance_story(true)
    var game=current_scene;game.refresh()
    Input.warp_mouse(game.camera.unproject_position(Vector3(4,0,4)))
    for i in range(8):await process_frame
    game.update_move_preview(Vector2i(4,4))
    var counts={};var visible={};var illegal=[];var path_overlap=[]
    for sprite in game.decorative_props:
        var species=sprite.get_meta("species");counts[species]=counts.get(species,0)+1
        var cell=sprite.get_meta("ground_cell")
        if cell.x>=-0.5 and cell.x<game.battle.size.x-0.5 and cell.y>=-0.5 and cell.y<game.battle.size.y-0.5:
            if game.battle.content.terrain[roundi(cell.y)][roundi(cell.x)]!="X":illegal.append([cell.x,cell.y])
        var bb=sprite.get_meta("alpha_bbox");var bounds=Rect2();var first=true
        for p in [Vector2(bb[0],bb[1]),Vector2(bb[2],bb[1]),Vector2(bb[2],bb[3]),Vector2(bb[0],bb[3])]:
            var world=sprite.position+game.camera.global_basis.x*(p.x-128)*sprite.pixel_size+Vector3.UP*(128-p.y)*sprite.pixel_size
            var screen=game.camera.unproject_position(world)
            if first:bounds=Rect2(screen,Vector2.ZERO);first=false
            else:bounds=bounds.expand(screen)
        if bounds.intersects(root.get_visible_rect()):visible[species]=visible.get(species,0)+1
        for cell_on_path in game.preview_path:
            var point=game.camera.unproject_position(Vector3(cell_on_path.x,0.04,cell_on_path.y))
            if bounds.has_point(point):path_overlap.append({"species":species,"path_cell":[cell_on_path.x,cell_on_path.y]})
    assert(illegal.is_empty())
    for i in range(4):await process_frame
    await RenderingServer.frame_post_draw
    var image=root.get_texture().get_image();assert(image.save_png("res://docs/foliage-v4-runtime.png")==OK)
    var report={"physical_viewport":[image.get_width(),image.get_height()],"counts":counts,"alpha_bounds_intersect_viewport":visible,"roots_on_walkable_cells":illegal,"preview_path_centers_inside_prop_bounds":path_overlap,"note":"Visible counts are projected alpha bounding rectangles, not per-pixel occlusion queries.","hash":game.battle.state_hash()}
    var file=FileAccess.open("res://docs/foliage-v4-counts.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "))
    print("FOLIAGE_CAPTURE ",JSON.stringify(report));quit()
