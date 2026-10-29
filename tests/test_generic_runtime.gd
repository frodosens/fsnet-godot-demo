extends SceneTree
const Art=preload("res://view/generic_map_art.gd")
const Seq=preload("res://view/map_sequence.gd")
var checks=0
func check(ok,label):
    checks+=1
    if not ok:printerr("FAIL: ",label);quit(1)
    assert(ok,label)
func _initialize():call_deferred("run")
func frames(n=3):
    for i in range(n):await process_frame
func run():
    var app=root.get_node("App");app.sfx_enabled=false
    check(Art.profile("unknown_mod").is_empty() and Art.profile("mara").is_empty(),"explicit catalog identity only")
    for id in Seq.CATALOG_IDS:
        var a=Art.profile(id);check(not a.is_empty() and not a.static_fallback,"valid admitted profile "+id)
        check(preload("res://ui/style.gd").framed_portrait(id)==null,"missing portrait does not borrow hero")
        for fixed in [true,false]:
            for size in [Vector2i(1280,800),Vector2i(960,600)]:
                root.size=size
                for direction in Seq.DIRECTIONS:
                    app.new_game(preload("res://tests/walk_rear_fixture.gd").content(id,direction));change_scene_to_file("res://main.tscn");await frames()
                    while not app.next_story().is_empty():app.advance_story(true)
                    var g=current_scene;g.refresh();g.scene_view.set_fixed(fixed);g.motion.set_process(false);g.get_node("MapIdle").set_process(false)
                    g.facing[id]=direction;g.apply_map_idle_texture(0,direction);var f=g.figures[0];var entry=g.hero_refresh_entry(0,direction)
                    check(f.texture==entry.idle.textures[0] and f.flip_h==direction.ends_with("right") and f.offset==Vector2(0,64),"own static idle/mirror/root")
                    check(g.figure_texture_pixel_position(0,Vector2(80,144)).is_equal_approx(f.position),"canonical anchor")
                    g.get_node("MapIdle").advance(.5);check(f.texture==entry.idle.textures[0],"static idle not hero class animation")
                    g.selected=0;g.mode="move";g.hud.action_menu_open=false
                    var target=preload("res://tests/walk_rear_fixture.gd").target(direction);g.update_move_preview(target)
                    check(g.preview_ghost.texture==entry.idle.textures[0] and g.preview_ghost.flip_h==direction.ends_with("right"),"own ghost identity")
                    check(app.session.submit({"kind":"move","unit":0,"x":target.x,"y":target.y}),"legal fixture move")
                    g.battle=app.session.logic;g.refresh();var truth=g.battle.snapshot();var pixel=f.pixel_size
                    for tick in range(1,20):
                        g.motion.advance(.08/g.character_scale);var travel=g.motion.motions[id].travelled
                        check(f.texture==a.library.pick(entry.motion,travel),"weighted distance frame")
                        check(f.flip_h==direction.ends_with("right") and f.pixel_size==pixel and f.offset==Vector2(0,64),"mirror stable without body compensation")
                        check(g.figure_texture_pixel_position(0,Vector2(80,144)).is_equal_approx(f.position),"moving foot anchor")
                        g.get_node("MapIdle").advance(.1);check(f.texture==a.library.pick(entry.motion,travel),"idle cannot replace moving frame")
                    var pos=f.position;var dist=g.motion.motions[id].travelled;g.refresh();check(f.position==pos and g.motion.motions[id].travelled==dist,"same state does not replay")
                    g.motion.speed=0;g.motion.advance(1);check(f.position==pos,"pause stable")
                    var output=OS.get_environment("GENERIC_CAPTURE")
                    if not output.is_empty() and size.x==1280:
                        await RenderingServer.frame_post_draw
                        root.get_texture().get_image().save_png(output+"/"+id+"-"+direction+("-fixed" if fixed else "-3d")+".png")
                    g.skip_presentation();check(f.texture==entry.idle.textures[0] and f.flip_h==direction.ends_with("right"),"skip restores own static pose")
                    check(g.battle.snapshot()==truth,"presentation leaves rules unchanged")
    print("GENERIC_RUNTIME checks=",checks," failures=0");quit()
