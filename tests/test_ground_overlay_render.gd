extends SceneTree
var failures=0
var results=[]
func _initialize():call_deferred("run")
func frames():
    for i in range(5):await process_frame
func shot():
    await frames();await RenderingServer.frame_post_draw
    return root.get_texture().get_image()
func run():
    assert(DisplayServer.get_name()!="headless")
    var app=root.get_node("App");app.scene_renderer="three_d";app.new_game(preload("res://logic/content.gd").reference_content());change_scene_to_file("res://main.tscn");await frames()
    while not app.next_story().is_empty():app.advance_story(true)
    var game=current_scene;game.refresh();game.hud.hide();game.preview_ghost.hide()
    var truth=game.battle.snapshot()
    # Rendering stress fixture ONLY: draw coverage over every tile, even occupied/water.
    # This is deliberately not a claim that those cells are legal move destinations.
    game.preview_reachable={}
    for cell in game.tiles:game.preview_reachable[cell]=true
    game.preview_path=[{"x":0,"y":0},{"x":9,"y":8}]
    for size in [Vector2i(960,600),Vector2i(1280,800)]:
        root.size=size;await frames()
        for fixed in [false,true]:
            assert(game.scene_view.set_fixed(fixed))
            game.preview_path=[{"x":0,"y":0},{"x":9,"y":8}]
            await frames()
            game.ground_overlay.hide()
            for tile in game.tiles.values():tile.overlay.hide()
            var off=await shot()
            game.ground_overlay.show()
            for tile in game.tiles.values():tile.overlay.show()
            var on=await shot()
            var scale=Vector2(root.size)/root.get_visible_rect().size
            for i in range(game.figures.size()):
                var figure=game.figures[i];var source=figure.texture.get_image();var samples=0;var changed=0
                for y in range(30,105,2):
                    for x in range(20,76,2):
                        var solid=true
                        for dy in range(-3,4):
                            for dx in range(-3,4):
                                if source.get_pixel(x+dx,y+dy).a<0.9:solid=false
                        if not solid:continue
                        var world=figure.position+game.camera.global_basis.x*(x-48)*figure.pixel_size+Vector3.UP*(64-y)*figure.pixel_size
                        var p=Vector2i(game.camera.unproject_position(world)*scale)
                        if p.x<0 or p.y<0 or p.x>=on.get_width() or p.y>=on.get_height():continue
                        samples+=1
                        if on.get_pixelv(p)!=off.get_pixelv(p):changed+=1
                if samples==0 or changed>0:failures+=1
                results.append({"viewport":[size.x,size.y],"fixed":fixed,"unit":game.battle.units[i].id,"solid_body_samples":samples,"changed_by_ground_overlay":changed})
            assert(game.battle.snapshot()==truth)
    print("GROUND_OVERLAY_RENDER ",JSON.stringify(results))
    print("GROUND_OVERLAY_RESULT failures=",failures," synthetic_coverage_fixture=true")
    var file=FileAccess.open("res://docs/ground-overlay-render-results.json",FileAccess.WRITE);file.store_string(JSON.stringify({"results":results,"failures":failures,"fixture":"all-tile rendering stress, not legal move range"},"  "))
    quit(1 if failures else 0)
