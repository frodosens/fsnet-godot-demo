extends "res://tests/support/test_case.gd"
func _initialize():call_deferred("run")
func frames(n=3):
    for i in range(n):await process_frame
func run():
    var app=root.get_node("App")
    for fixed in [true,false]:
        for size in [Vector2i(1280,800),Vector2i(960,600)]:
            root.size=size
            for direction in ["front_left","front_right","back_left","back_right"]:
                app.new_game(preload("res://tests/walk_rear_fixture.gd").content("neri",direction));change_scene_to_file("res://main.tscn");await frames()
                while not app.next_story().is_empty():app.advance_story(true)
                var g=current_scene;g.refresh();g.scene_view.set_fixed(fixed);g.motion.set_process(false);g.get_node("MapIdle").set_process(false)
                var i=2;g.selected=i;g.facing.neri=direction;g.apply_map_idle_texture(i,direction)
                var f=g.figures[i];var entry=g.hero_refresh_entry(i,direction)
                var expected=load("res://assets/sprites/iso4/neri_idle_standing_v1/"+direction.replace("right","left")+"_idle_00.png")
                require(f.texture==expected and entry.idle.textures==[expected],"startup uses standing frame")
                require(f.flip_h==direction.ends_with("right") and f.offset==Vector2(0,64),"same mirror/root")
                require(g.figure_texture_pixel_position(i,Vector2(80,144)).is_equal_approx(f.position),"foot anchored")
                var px=f.pixel_size;var scale=f.scale;var badge=g.badges[i].position-f.position
                var target=preload("res://tests/walk_rear_fixture.gd").target(direction);g.mode="move";g.hud.action_menu_open=false;g.update_move_preview(target)
                require(g.preview_ghost.texture==expected and g.preview_ghost.flip_h==f.flip_h,"matching standing ghost")
                var capture=OS.get_environment("NERI_STANDING_CAPTURE")
                if not capture.is_empty():
                    await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(capture+"/"+direction+"-"+str(fixed)+"-"+str(size.x)+".png")
                require(app.session.submit({"kind":"move","unit":i,"x":target.x,"y":target.y}),"legal move")
                g.battle=app.session.logic;g.refresh();g.motion.advance(.08/g.character_scale)
                require(f.texture==g.hero_refresh_libraries.neri.pick(entry.motion,g.motion.motions.neri.travelled),"accepted walk unchanged")
                require(f.pixel_size==px and f.scale==scale,"body scale unchanged")
                if direction.ends_with("left"):g.motion.advance(100)
                else:g.skip_presentation()
                require(f.texture==expected and f.flip_h==entry.idle.flip_h,"natural completion or skip standing")
                g.get_node("MapIdle").advance(1);require(f.texture==expected,"stopped standing")
                var snapshot=g.battle.snapshot();var runtime=Runtime.new(g.battle.content);require(runtime.restore(snapshot),"restore")
                app.session.logic=runtime;g.battle=runtime;g.refresh();require(f.texture==expected and g.battle.snapshot()==snapshot,"same-state replacement keeps standing")
                require(g.badges[i].visible,"health visible after replacement")
    print("NERI_STANDING_IDLE checks=",checks," failures=0");quit()
