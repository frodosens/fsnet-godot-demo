extends "res://tests/support/test_case.gd"
func _initialize():call_deferred("run")
func frames():
    for i in range(3):await process_frame
func run():
    var app=root.get_node("App");preload("res://tests/legacy_map_fixture.gd").apply(app);app.new_game(Content.reference_content());change_scene_to_file("res://main.tscn");await frames()
    var game=current_scene;var snapshot=game.battle.snapshot()
    for size in [Vector2i(1280,800),Vector2i(960,600)]:
        root.size=size;await frames()
        for fixed in [true,false]:
            game.scene_view.set_fixed(fixed);await frames()
            for i in range(6):
                var f=game.figures[i];var p=game.battle.units[i].pos
                require(f.position.is_equal_approx(Vector3(p.x,0,p.y)))
                require(game.figure_pixel_position(i,Vector2(48,120)).is_equal_approx(f.position))
                require(f.billboard==BaseMaterial3D.BILLBOARD_ENABLED and f.actor_material.billboard_mode==BaseMaterial3D.BILLBOARD_ENABLED)
                require(f.offset==Vector2(0,56) and f.scale==Vector3.ONE)
                var c=game.camera;var a=c.unproject_position(game.figure_pixel_position(i,Vector2(48,120)))
                var x=c.unproject_position(game.figure_pixel_position(i,Vector2(58,120)))
                var y=c.unproject_position(game.figure_pixel_position(i,Vector2(48,110)))
                require(absf(a.distance_to(x)-a.distance_to(y))<0.001)
                if fixed:require(game.scene_view.shadows[i].position.is_equal_approx(Vector3(p.x,0.008,p.y)))
            if not fixed:require(game.scene_view.shadows.is_empty()) # Never index deleted fixed-view shadows.
    while not app.next_story().is_empty():app.advance_story(true)
    game.refresh();game.select_mode("move");game.update_move_preview(Vector2i(3,6))
    require(game.preview_ghost.billboard==BaseMaterial3D.BILLBOARD_ENABLED and game.preview_ghost.offset==Vector2(0,56))
    require(game.preview_ghost.position.y==0);require(game.preview_ghost.pixel_size==game.figures[0].pixel_size)
    require(game.battle.snapshot()==snapshot)
    var content=Content.default_content();require(app.new_game(content));change_scene_to_file("res://main.tscn");await frames()
    require(not current_scene.scene_view.active);require(current_scene.figures[0].position.y==0)
    print("CHARACTER_PROJECTION checks=",checks," failures=0");quit()
