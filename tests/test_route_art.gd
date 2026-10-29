extends "res://tests/support/test_case.gd"
func _initialize():call_deferred("run")
func frames(n=4):
    for i in range(n):await process_frame
func run():
    var Art=preload("res://view/route_art.gd");var art=Art.new();check(art.ready,"approved atlas loaded")
    for path in [null,[null],[{"x":null,"y":0},{"x":1,"y":0}],[],[{"x":0,"y":0}],[{"x":0,"y":0},{"x":2,"y":0}]]:check(art.plan(path).is_empty(),"empty/start=end/nonadjacent rejected")
    for key in art.materials:
        check(not art.materials[key].get_flag(BaseMaterial3D.FLAG_DISABLE_DEPTH_TEST),"depth test preserved")
        check(art.materials[key].render_priority==2,"art above range")
    var another=Art.new()
    for key in art.textures:check(art.textures[key]==another.textures[key],"cropped source cache reused")
    for first in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
        for second in [first,Vector2i(-first.y,first.x),Vector2i(first.y,-first.x),-first]:
            var positions=[Vector2i.ZERO,first,first+second];var path=[]
            for pos in positions:path.append({"x":pos.x,"y":pos.y})
            var parts=art.plan(path);check(not parts.is_empty(),"all orientations assemble")
            for part in parts:
                for p in part.points:
                    var inside=false
                    for pos in positions:
                        if absf(p.x-pos.x)<=.50001 and absf(p.y-pos.y)<=.50001:inside=true
                    check(inside,"entire module bounded by authorized cells")
    var app=root.get_node("App");app.new_game(preload("res://logic/content.gd").reference_content());change_scene_to_file("res://main.tscn");await frames()
    while not app.next_story().is_empty():app.advance_story(true)
    var g=current_scene;g.refresh();g.hud.choose_action("move");var overlay=g.ground_overlay;var truth=g.battle.snapshot()
    var out=OS.get_environment("AMBER_ROUTE_CAPTURE")
    for size in [Vector2i(1280,800),Vector2i(960,600)]:
        root.size=size;await frames()
        for fixed in [true,false]:
            g.scene_view.set_fixed(fixed)
            for cell in [Vector2i(4,6),Vector2i(4,4),Vector2i(3,6),Vector2i(5,8),Vector2i(4,7),Vector2i(0,7)]:
                g.update_move_preview(cell);overlay._process(1);await frames()
                check(overlay.art_parts.size()==overlay.route_art.plan(g.preview_path).size(),"actual BFS assembly")
                check(g.battle.snapshot()==truth,"presentation preserves rules")
                if not out.is_empty() and not g.preview_path.is_empty():
                    await RenderingServer.frame_post_draw
                    var image=root.get_texture().get_image()
                    if cell==Vector2i(4,4):
                        var pixel=(g.camera.unproject_position(Vector3(4,.029,5))*Vector2(image.get_size())/root.get_visible_rect().size).round()
                        var color=image.get_pixelv(Vector2i(pixel))
                        check(color.r>.6 and color.g>.55 and color.r>color.b,"actual ivory core visible above cyan range")
                    image.save_png(out+"/route-"+str(size.x)+("-fixed-" if fixed else "-3d-")+str(cell.x)+"-"+str(cell.y)+".png")
            g.update_move_preview(Vector2i(3,6));overlay._process(1);overlay.art_route_enabled=false;overlay._process(1)
            check(overlay.mesh.get_surface_count()>0,"old fallback available")
            overlay.art_route_enabled=true;g.clear_move_preview();overlay._process(.01)
            check(overlay.art_parts.is_empty() and overlay.cells.mesh.get_surface_count()==0,"cancel clears modules")
    var camera_position=g.camera.position
    g.update_move_preview(Vector2i(4,4));g.camera.position+=Vector3(8,0,0);overlay._process(.1);await frames()
    check(not overlay.art_parts.is_empty(),"viewport clipping keeps world assembly")
    g.camera.position=camera_position;g.clear_move_preview();g.selected=1;g.hud.choose_action("move");await frames()
    for cell in g.preview_reachable:
        if cell==g.battle.units[1].pos:continue
        g.update_move_preview(cell);overlay._process(1)
        check(overlay.last_path==g.preview_path and g.preview_path[0].x==g.battle.units[1].x and g.preview_path[0].y==g.battle.units[1].y,"reselection uses new actor path")
        break
    g.clear_move_preview();overlay._process(.1);check(overlay.cells.mesh.get_surface_count()==0,"new selection cancellation clears art")
    check(g.battle.snapshot()==truth,"all previews leave shared snapshot unchanged")
    print("ROUTE_ART checks=",checks," failures=",failures);quit(1 if failures else 0)
