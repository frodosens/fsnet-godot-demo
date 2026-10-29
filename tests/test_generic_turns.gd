extends SceneTree
const Art=preload("res://view/generic_map_art.gd")
const Seq=preload("res://view/map_sequence.gd")
var checks=0
func check(ok,label):
    checks+=1
    if not ok:printerr("FAIL: ",label);quit(1)
    assert(ok,label)
func _initialize():call_deferred("run")
func frames():
    for n in range(3):await process_frame
func run():
    var app=root.get_node("App");var catalog=JSON.parse_string(FileAccess.get_file_as_string(Art.PATH))
    for id in Seq.CATALOG_IDS:
        var data=preload("res://tests/walk_rear_fixture.gd").content(id,"front_right")
        data.units[0].x=1;data.units[0].y=6;data.units[1].x=6;data.units[1].y=7
        app.new_game(data);change_scene_to_file("res://main.tscn");await frames()
        var g=current_scene;g.refresh();g.motion.set_process(false)
        var path=g.battle.path_to(0,Vector2i(2,7));check(path.size()==3,"legal corner fixture")
        check(app.session.submit({"kind":"move","unit":0,"x":2,"y":7}),"real corner command")
        g.battle=app.session.logic;g.refresh();var truth=g.battle.snapshot()
        g.motion.advance(1.2/g.character_scale)
        var direction=g.projected_facing(Vector2i(path[1].x,path[1].y),Vector2i(path[2].x,path[2].y),true)
        check(g.facing[id]==direction,"turn follows actual segment")
        var entry=g.hero_refresh_entry(0,direction);var travel=g.motion.motions[id].travelled
        check(g.figures[0].texture==Art.profile(id).library.pick(entry.motion,travel),"turn keeps distance-selected phase")
        g.motion.consume(g.battle.step,g.battle.events);check(g.motion.motions[id].travelled==travel,"duplicate event cannot replay")
        g.motion.speed=8;g.motion.advance(10)
        check(not g.motion.active() and g.figures[0].position==Vector3(2,0,7),"large delta ends at authority endpoint")
        check(g.figures[0].texture==entry.idle.textures[0] and g.figures[0].flip_h==direction.ends_with("right"),"stop retains correct own facing")
        check(g.battle.snapshot()==truth,"turn leaves settled state intact")
        var original=Art.cache[id]
        Art.cache[id]=Art.decode_profile(id,catalog.profiles[id],{},true)
        app.new_game(data);change_scene_to_file("res://main.tscn");await frames();g=current_scene;g.refresh()
        check(Art.cache[id].static_fallback,"bad motion profile reported")
        for d in Seq.DIRECTIONS:
            g.apply_map_motion_texture(0,d,.42)
            check(g.figures[0].texture==Art.cache[id].map[d] and g.figures[0].flip_h==d.ends_with("right"),"actual renderer fallback retains generic identity")
        Art.cache[id]=original
    print("GENERIC_TURNS checks=",checks," failures=0");quit()
