extends SceneTree
func _initialize():call_deferred("run")
func frames(n):
    for i in range(n):await process_frame
func run():
    var app=root.get_node("App");app.sfx_enabled=false;app.presentation_preferences_path="user://hero-record.cfg"
    var output=OS.get_environment("AMBER_HERO_CAPTURE");assert(not output.is_empty())
    for hero in ["elsbet"]:
        var index=3
        for spec in [["front_right",false],["front_left",true],["front_right",true],["back_left",true],["back_right",true],["turn",true]]:
            var direction="front_right" if spec[0]=="turn" else spec[0];var on=spec[1]
            var data=preload("res://tests/walk_rear_fixture.gd").content(hero,direction)
            var target={"front_right":Vector2i(3,8),"front_left":Vector2i(4,7),"back_left":Vector2i(2,8),"back_right":Vector2i(4,6)}[direction]
            if spec[0]=="turn":
                data.units[0].x=0;data.units[0].y=6;data.units[1].x=6;data.units[1].y=7
                data.units[index].x=1;data.units[index].y=6;target=Vector2i(2,7)
            app.idle_sequence_previews.elsbet=true;app.new_game(data);change_scene_to_file("res://main.tscn");await frames(3)
            while not app.next_story().is_empty():app.advance_story(true)
            var game=current_scene;game.refresh();game.scene_view.set_fixed(OS.get_environment("ELSBET_VIEW")!="3d");game.selected=index;game.facing[hero]=direction
            app.set_elsbet_motion_preview(on);game.refresh()
            var title={"elsbet":"埃尔丝贝特"}[hero]+" · "+str(spec[0])+ (" · 保留旧待机 / 新移动" if on else " · 旧素材对照")
            var label=Style.label(title+"\n合法测试摆位 · 正常模拟速度 · 只移动镜像，旧待机不变",18);label.position=Vector2(300,90);label.mouse_filter=Control.MOUSE_FILTER_IGNORE;game.hud.root.add_child(label)
            await frames(12)
            if on and spec[0]!="turn":
                await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output+"/"+hero+"-"+direction+"-idle.png")
            assert(app.session.submit({"kind":"move","unit":index,"x":target.x,"y":target.y}))
            game.battle=app.session.logic;game.refresh();await frames(18)
            if on and spec[0]!="turn":
                await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output+"/"+hero+"-"+direction+"-motion.png")
            while game.motion.active():await process_frame
            await frames(12)
            app.set_elsbet_motion_preview(false)
    print("ELSBET_MOTION_RECORD four_facings_corner_idle_old_comparison=true normal_simulation_speed=true");quit()
