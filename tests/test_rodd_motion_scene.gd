extends "res://tests/support/test_case.gd"
func _initialize():call_deferred("run")
func frames(n=3):
    for i in range(n):await process_frame
func run():
    var app=root.get_node("App");app.presentation_preferences_path="user://hero-scene.cfg"
    var ids=["rodd"]
    for fixed in [true,false]:
        for size in [Vector2i(1280,800),Vector2i(960,600)]:
            root.size=size
            for id in ids:
                var index=ids.find(id)
                for direction in ["front_left","front_right","back_left","back_right"]:
                    var data=preload("res://tests/walk_rear_fixture.gd").content(id,direction)
                    var target=preload("res://tests/walk_rear_fixture.gd").target(direction)
                    app.new_game(data);change_scene_to_file("res://main.tscn");await frames()
                    while not app.next_story().is_empty():app.advance_story(true)
                    var game=current_scene;game.refresh();game.scene_view.set_fixed(fixed);game.motion.set_process(false);game.get_node("MapIdle").set_process(false)
                    game.selected=index;game.facing[id]=direction
                    app.set_rodd_motion_preview(false);var old=game.directional_idle_texture(index,direction)
                    app.set_rodd_motion_preview(true);var entry=game.hero_refresh_entry(index,direction);var figure=game.figures[index]
                    require(not entry.is_empty() and figure.texture==entry.idle.textures[0],"new static idle")
                    require(figure.flip_h==direction.ends_with("right") and figure.offset==Vector2(0,64),"idle mirroring/root")
                    require(game.figure_texture_pixel_position(index,Vector2(80,144)).is_equal_approx(figure.position),"idle root fixed")
                    var px=figure.pixel_size;var bar=game.badges[index].position
                    game.get_node("MapIdle").advance(.7)
                    require(figure.texture==entry.idle.textures[0] and figure.flip_h==entry.idle.flip_h,"idle updater preserves static mirror")
                    game.mode="move";game.hud.action_menu_open=false;game.update_move_preview(target)
                    require(game.preview_ghost.visible and game.preview_ghost.texture==entry.idle.textures[0] and game.preview_ghost.flip_h==entry.idle.flip_h and game.preview_ghost.offset==Vector2(0,64),"ghost uses matching idle and root")
                    require(app.session.submit({"kind":"move","unit":index,"x":target.x,"y":target.y}),"legal actual move")
                    game.battle=app.session.logic;game.refresh();var truth=game.battle.snapshot()
                    require(figure.flip_h==entry.idle.flip_h and figure.offset==Vector2(0,64),"first move frame has no legacy flash")
                    for tick in range(1,21):
                        game.motion.advance(.08/game.character_scale)
                        var travel=game.motion.motions[id].travelled
                        require(figure.texture==game.hero_refresh_libraries[id].pick(entry.motion,travel),"distance selects weighted frame")
                        require(figure.flip_h==entry.motion.flip_h and figure.offset==Vector2(0,64),"motion mirror/root")
                        require(game.figure_texture_pixel_position(index,Vector2(80,144)).is_equal_approx(figure.position),"moving foot anchor")
                        require(figure.pixel_size==px and figure.scale==Vector3.ONE,"no body rescale")
                    var pos=figure.position;var travel=game.motion.motions[id].travelled
                    game.refresh();require(game.motion.motions[id].travelled==travel and figure.position==pos,"same step cannot restart")
                    game.motion.speed=0;game.motion.advance(1);require(figure.position==pos,"pause stable")
                    app.set_rodd_motion_preview(false);require(figure.texture.get_height()!=160 and figure.offset==Vector2(0,56),"rollback restores old root")
                    app.set_rodd_motion_preview(true);require(figure.position==pos and figure.texture==game.hero_refresh_libraries[id].pick(entry.motion,travel),"toggle resumes distance phase")
                    game.skip_presentation();require(figure.texture==entry.idle.textures[0] and figure.flip_h==entry.idle.flip_h,"skip returns to consistent idle")
                    require(game.battle.snapshot()==truth,"presentation does not modify shared state")
                    app.set_rodd_motion_preview(false);require(game.directional_idle_texture(index,direction)==old,"old art retained")
    print("RODD_MOTION_SCENE checks=",checks," failures=0");quit()
