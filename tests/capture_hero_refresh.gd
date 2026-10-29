extends SceneTree
func _initialize():call_deferred("run")
func frames(n=3):
    for i in range(n):await process_frame
func run():
    var app=root.get_node("App");app.presentation_preferences_path="user://hero-stills.cfg";app.sfx_enabled=false
    var out=OS.get_environment("AMBER_HERO_CAPTURE");assert(not out.is_empty())
    var bridge=OS.get_environment("AMBER_HERO_BRIDGE")=="1"
    for physical in ([Vector2i(1280,800)] if bridge else [Vector2i(1280,800),Vector2i(960,600)]):
        root.size=physical
        for fixed in [true,false]:
            for hero in ["mara","finn","neri"]:
                var index=["mara","finn","neri"].find(hero);var direction="back_right" if bridge else "front_right"
                var data=preload("res://tests/walk_rear_fixture.gd").content(hero,direction)
                if bridge:data.units[index].x=4;data.units[index].y=5
                app.new_game(data);change_scene_to_file("res://main.tscn");await frames()
                while not app.next_story().is_empty():app.advance_story(true)
                var game=current_scene;game.refresh();game.scene_view.set_fixed(fixed);game.motion.set_process(false);game.get_node("MapIdle").set_process(false);game.selected=index;game.facing[hero]=direction
                app.set_hero_map_refresh_preview(true,hero);game.refresh()
                var meta=JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/iso4/"+hero+"_seedance_mini_v2/art_manifest.json"))
                var bottom=-1;var sample=0
                for frame in meta.frames:
                    if frame.kind=="motion" and frame.direction==("back_left" if bridge else "front_left") and frame.alpha_bbox_exclusive[3]>bottom:bottom=int(frame.alpha_bbox_exclusive[3]);sample=int(frame.frame)
                var entry=game.hero_refresh_entry(index,direction);var clip=entry.motion;var tick=0 if sample==0 else clip.ends[sample-1]
                assert(app.session.submit({"kind":"move","unit":index,"x":4,"y":2 if bridge else 8}));game.battle=app.session.logic;game.refresh()
                game.motion.advance((tick+0.5)/clip.ticks/game.motion.WORLD_SPEED/game.character_scale)
                var label=Style.label(hero+" V2 · "+("固定背景" if fixed else "3D")+" · 最低脚部采样相位\nroot=(80,144) · 不改变地面深度/身体比例",18);label.position=Vector2(300,90);label.mouse_filter=Control.MOUSE_FILTER_IGNORE;game.hud.root.add_child(label)
                await frames();await RenderingServer.frame_post_draw
                var file=out+"/"+hero+("-bridge" if bridge else "")+("-fixed-" if fixed else "-3d-")+str(physical.x)+".png"
                root.get_texture().get_image().save_png(file);print("HERO_CAPTURE ",file," opaque_bottom_exclusive=",bottom," sample=",sample)
                app.set_hero_map_refresh_preview(false,hero)
    quit()
