extends SceneTree
func _initialize():call_deferred("run")
func frames(n=8):
    for i in range(n):await process_frame
func shot(name):
    await frames();await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("/tmp/amber-arc-"+name+".png")
func run():
    root.size=Vector2i(1280,800)
    var app=root.get_node("App");app.new_game(preload("res://logic/content.gd").reference_content());change_scene_to_file("res://main.tscn");await frames()
    while not app.next_story().is_empty():app.advance_story(true)
    var game=current_scene;game.refresh();game.scene_view.set_fixed(true);await frames()
    await shot("1280")
    root.size=Vector2i(960,600);await frames();await shot("960")
    root.size=Vector2i(1280,800);game.scene_view.set_fixed(false);await frames()
    var old_camera=game.camera.global_transform
    for target in [Vector2(1190,390),Vector2(90,150),Vector2(650,680)]:
        game.camera.global_transform=old_camera
        var world=game.figures[0].position;var origin=game.camera.unproject_position(world)
        var px=game.camera.unproject_position(world+game.camera.global_basis.x).distance_to(origin)
        game.camera.global_position+=game.camera.global_basis.x*((origin.x-target.x)/px)+game.camera.global_basis.y*((target.y-origin.y)/px)
        await frames()
        assert(game.hud.arc_layout.anchor.distance_to(target)<1)
        for p in game.hud.arc_layout.positions:assert(not game.hud.ActionArc.visual_rect(p).intersects(game.hud.arc_layout.keepout))
        await shot("edge-%d-%d"%[target.x,target.y])
        print("ARC_EDGE_ACTUAL projected=",game.hud.arc_layout.anchor," side=",game.hud.arc_layout.side," keepout=",game.hud.arc_layout.keepout)
    quit()
