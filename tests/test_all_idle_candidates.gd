extends SceneTree
var checks=0
func check(ok,label):
    checks+=1
    assert(ok,label)
func _initialize():call_deferred("run")
func run():
    var app=root.get_node("App");preload("res://tests/legacy_map_fixture.gd").apply(app);app.neri_motion_preview=false # Explicit old-motion baseline; default-on trial has separate tests.
    app.reduced_motion=false;app.new_game(preload("res://logic/content.gd").reference_content())
    change_scene_to_file("res://main.tscn");await process_frame;await process_frame
    while not app.next_story().is_empty():app.advance_story(true)
    var g=current_scene;g.refresh();var idle=g.get_node("MapIdle");idle.set_process(false);g.motion.set_process(false)
    check(idle.library.errors.is_empty(),"all clips load")
    var truth=g.battle.snapshot();var step=1000
    for i in range(6):
        var u=g.battle.units[i];var origin=g.figures[i].position
        for direction in ["front_left","front_right","back_left","back_right"]:
            var key=u.role+":"+direction;var clip=idle.library.clips.map[key]
            check(clip.unit_ids==[u.id],"unit-scoped candidate "+u.id)
            var fallback=g.direction_textures[u.id+":"+direction]
            check(idle.library.sample("map",key,.5,fallback,false,"mod-copy")==fallback,"same role other identity fallback")
            g.facing[u.id]=direction;idle.directions.erase(u.id);idle.clocks.erase(u.id);idle.advance(0)
            check(g.figures[i].texture==clip.textures[0],"new direction starts neutral")
            check(g.directional_idle_texture(i,direction)==clip.textures[0],"moving texture matches new neutral")
            for phase in range(clip.seconds.size()):
                idle.clocks[u.id]=phase*.4;idle.advance(0)
                check(g.figures[i].texture==clip.textures[phase],"correct authored phase")
                check(g.figures[i].position==origin,"no whole-sprite bob")
            app.reduced_motion=true;idle.advance(.4);check(g.figures[i].texture==clip.textures[0],"reduced motion neutral");app.reduced_motion=false
            g.hud.toggle_pause();var before=idle.clocks[u.id];var texture=g.figures[i].texture;idle.advance(2)
            check(idle.clocks[u.id]==before and g.figures[i].texture==texture,"pause freezes all roles")
            g.hud.clear_modal()
        for d in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
            step+=1;var start=u.pos-d
            g.motion.consume(step,[{"kind":"move","actor":u.id,"path":[{"x":start.x,"y":start.y},{"x":u.x,"y":u.y}]}])
            check(g.figures[i].texture==g.directional_idle_texture(i,g.facing[u.id]),"command consumes directly into neutral")
            g.motion.advance(.15);idle.advance(.15)
            var texture=g.directional_idle_texture(i,g.facing[u.id])
            check(g.figures[i].texture==texture and idle.clocks[u.id]==0,"static neutral slide and reset phase")
            g.motion.advance(.15);idle.advance(.15)
            var moving=g.motion.walk_library.sample(u.id,g.facing[u.id],g.motion.motions[u.id].travelled,texture)
            check(g.figures[i].texture==moving and idle.clocks[u.id]==0,"walk registry owns movement; idle remains reset")
            g.motion.finish(false);idle.advance(0)
            check(g.figures[i].texture==texture and g.figures[i].position==origin,"stop has identical neutral and exact rule footpoint")
    # Consume + skip in the same frame must reset even before MapIdle._process runs.
    idle.clocks.mara=.5;step+=1
    g.motion.consume(step,[{"kind":"move","actor":"mara","path":[{"x":3,"y":7},{"x":4,"y":7}]}])
    check(idle.clocks.mara==0,"immediate consumption resets stale idle phase")
    g.motion.finish(false);idle.advance(0)
    check(idle.clocks.mara==0 and g.figures[0].texture==g.directional_idle_texture(0,g.facing.mara),"same-frame skip stays neutral")
    check(g.battle.snapshot()==truth,"all presentation fixtures preserve rule state")
    check(is_equal_approx(idle.library.clips.map["mage:front_left"].duration,1.2),"Neri1200ms three slots")
    # Oren defence uses LEFT old group; his right-facing attack remains untouched.
    var c=load("res://ui/battle_cutin.gd").new();root.add_child(c);c.set_process(false)
    var data=preload("res://logic/content.gd").reference_content();data.units[3].x=data.units[0].x+1;data.units[3].y=data.units[0].y
    var logic=preload("res://logic/runtime.gd").new(data);check(logic.apply_command({"kind":"attack","unit":0,"target":3,"step":1}),"real attack")
    c.consume(1,logic.events,logic.units,data);c.draw_tick(5)
    check(c.defender.texture.resource_path=="res://assets/battle/oren/idle/01_inhale.png" and not c.defender.flip_h,"Oren left inhale no double mirror")
    c.draw_tick(8);check(c.defender.texture.resource_path.ends_with("battle/oren/01_brace.png"),"Oren brace takes priority")
    c.draw_tick(23);check(c.defender.texture.resource_path.ends_with("battle/oren/03_recover.png"),"Oren recover preserved")
    check(c.idle_library.clips.battle["oren:right"].textures[0]==c.actor_sets.oren.textures[0],"separate right attack neutral")
    c.finish();print("ALL_IDLE_CANDIDATES checks=",checks," failures=0");quit()
