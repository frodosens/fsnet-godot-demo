extends SceneTree
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok,label):
    checks+=1
    if not ok:failures+=1;printerr("FAIL: ",label)
func frames(count=3):
    for i in range(count):await process_frame
func run():
    var Meter=load("res://view/unit_health.gd")
    var app=root.get_node("App");var Seq=preload("res://view/map_sequence.gd").shared()
    app.hero_map_refresh_previews={"mara":false,"finn":false,"neri":false} # Legacy compact fallback fixture.
    app.presentation_preferences_path="user://oren-test.cfg"
    app.oren_sequence_preview=false
    var capture=OS.get_environment("AMBER_COMPACT_CAPTURE")
    var stills=OS.get_environment("AMBER_OREN_STILLS")
    for fixed in [true,false]:
        for direction in Seq.DIRECTIONS:
            var data=preload("res://tests/walk_rear_fixture.gd").content("oren",direction)
            var target=preload("res://tests/walk_rear_fixture.gd").target(direction)
            if direction=="front_left":data.units[3].y=5;target=Vector2i(4,8)
            check(preload("res://logic/content.gd").validate(data)=="","fixture valid")
            app.new_game(data);change_scene_to_file("res://main.tscn");await frames()
            while not app.next_story().is_empty():app.advance_story(true)
            var game=current_scene;game.refresh();game.scene_view.set_fixed(fixed)
            game.motion.set_process(false);game.get_node("MapIdle").set_process(false)
            game.facing.oren=direction;game.selected=3;game.refresh()
            var other_before=game.directional_idle_texture(1,direction)
            var old=game.base_directional_idle_texture(3,direction)
            app.set_oren_sequence_preview(true)
            var entry=Seq.matching("oren",direction,old)
            check(not entry.is_empty(),"active exact binding")
            if entry.is_empty():quit(1);return
            var scale=game.figures[3].pixel_size
            check(is_equal_approx(scale,game.MAP_PIXEL_SIZE*game.character_scale*1.05),"Oren factor applied exactly once")
            game.get_node("MapIdle").clocks.clear();game.get_node("MapIdle").advance(0)
            check(game.figures[3].texture==entry.idle.textures[0],"idle phase zero")
            if not stills.is_empty():
                await RenderingServer.frame_post_draw
                root.get_texture().get_image().save_png(stills+"/"+direction+("-fixed-idle.png" if fixed else "-3d-idle.png"))
            var truth=game.battle.snapshot()
            game.hud.show_feedback_settings();await frames()
            var before=game.get_node("MapIdle").clocks.oren
            game.get_node("MapIdle").advance(1)
            check(game.get_node("MapIdle").clocks.oren==before,"modal pauses idle")
            game.hud.clear_modal();await frames()
            game.get_node("MapIdle").advance(.5)
            check(game.figures[3].texture==Seq.idle("oren",direction,.5,old),"natural idle time")
            check(game.battle.snapshot()==truth,"idle no rule effects")
            check(game.directional_idle_texture(1,direction)==other_before,"other actor unchanged")
            if not capture.is_empty():
                var title=Label.new();title.text="玛拉关键帧试验 · "+direction+(" · 固定背景" if fixed else " · 3D")+"\n测试摆位 / 每格一循环 / 单脚碎步尚未验收"
                title.position=Vector2(330,90);title.add_theme_font_size_override("font_size",19);title.mouse_filter=Control.MOUSE_FILTER_IGNORE;game.hud.root.add_child(title)
                game.get_node("MapIdle").set_process(true);await frames(100)
                await RenderingServer.frame_post_draw
                root.get_texture().get_image().save_png(capture+"/"+direction+("-fixed-idle.png" if fixed else "-3d-idle.png"))
                game.get_node("MapIdle").set_process(false)
            check(app.session.submit({"kind":"move","unit":3,"x":target.x,"y":target.y}),"legal authoritative move")
            game.battle=app.session.logic;game.refresh();truth=game.battle.snapshot()
            if not capture.is_empty():
                game.motion.set_process(true);await frames(24)
                await RenderingServer.frame_post_draw
                root.get_texture().get_image().save_png(capture+"/"+direction+("-fixed-motion.png" if fixed else "-3d-motion.png"))
                while game.motion.active():await process_frame
                await frames(50)
                game.motion.set_process(false)
                game.motion.last_step=-1;game.motion.consume(game.battle.step,game.battle.events)
            var meter=game.badges[3];meter._process(0);var width=meter.rendered_size.x
            # Deliberately sample 38 subdivisions/grid, independent of the 42 clip ticks.
            for tick in range(1,114):
                game.motion.advance(1.0/(38*game.character_scale))
                var tex=game.figures[3].texture
                var travelled=game.motion.motions.oren.travelled
                check(absf(travelled-tick/38.0)<.00002,"actual travel matches speed")
                check(tex==Seq.motion("oren",direction,travelled,old),"distance weighted frame")
                check(game.figures[3].pixel_size==scale,"padding never rescales actor")
                check(game.figure_texture_pixel_position(3,Vector2(64,120)).is_equal_approx(game.figures[3].position),"padded root fixed")
                check(meter.rendered_size.x==width,"fixed HP width without jitter")
                game.get_node("MapIdle").advance(.1)
                check(game.figures[3].texture==tex,"motion wins over idle")
                if tick==14 and not stills.is_empty():
                    await RenderingServer.frame_post_draw
                    root.get_texture().get_image().save_png(stills+"/"+direction+("-fixed-motion.png" if fixed else "-3d-motion.png"))
            game.motion.speed=0;var pos=game.figures[3].position;game.motion.advance(3)
            check(game.figures[3].position==pos,"speed zero freezes")
            app.set_oren_sequence_preview(false)
            check(game.figures[3].texture.get_width()==96 and game.figures[3].position==pos,"paused toggle restores old art without moving")
            app.set_oren_sequence_preview(true)
            check(game.figures[3].texture.get_width()==128 and game.figures[3].position==pos,"paused toggle restores compact art without moving")
            game.motion.speed=1;game.motion.finish()
            check(game.figures[3].position==Vector3(target.x,0,target.y),"skip true endpoint")
            check(game.figures[3].texture==entry.idle.textures[0],"stop returns compact idle")
            check(game.battle.snapshot()==truth,"animation no shared state changes")
            app.set_oren_sequence_preview(false)
            check(game.figures[3].texture==old,"disable restores original neutral")
            app.load_presentation_preferences();check(app.oren_sequence_preview,"latest resources restored on reload")
            app.hero_map_refresh_previews={"mara":false,"finn":false,"neri":false} # Legacy compact fallback fixture.
    print("OREN_SEQUENCE_SCENE checks=",checks," failures=",failures);quit(1 if failures else 0)
