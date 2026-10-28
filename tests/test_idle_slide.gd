extends SceneTree
var checks=0
func check(ok,label):
    checks+=1
    if not ok:printerr("FAIL ",label);quit(1)
    assert(ok,label)
func _initialize():call_deferred("run")
func run():
    var app=root.get_node("App");app.neri_motion_preview=false # Explicit old-motion baseline; default-on trial has separate tests.
    app.new_game(preload("res://logic/content.gd").reference_content())
    change_scene_to_file("res://main.tscn");await process_frame;await process_frame
    while not app.next_story().is_empty():app.advance_story(true)
    var game=current_scene;game.refresh();game.motion.set_process(false)
    var truth=game.battle.snapshot();var step=1000
    # Presentation event fixtures cover all roles / directions, without modifying rules.
    for i in range(game.battle.units.size()):
        var unit=game.battle.units[i]
        for d in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
            step+=1;var origin=Vector2i(unit.x,unit.y)-d
            var path=[{"x":origin.x,"y":origin.y},{"x":unit.x,"y":unit.y}]
            game.motion.consume(step,[{"kind":"move","actor":unit.id,"path":path}])
            game.motion.advance(0.15)
            var direction=game.projected_facing(origin,unit.pos,true)
            check(game.figures[i].texture==game.directional_idle_texture(i,direction),unit.id+" correct idle direction "+direction)
            var texture=game.figures[i].texture;game.motion.advance(0.15)
            var expected=game.motion.walk_library.sample(unit.id,direction,game.motion.motions[unit.id].travelled,game.directional_idle_texture(i,direction))
            check(game.figures[i].texture==expected,"registered walk or static fallback")
            var before=game.figures[i].position;game.motion.consume(step,[])
            check(game.figures[i].position==before and game.motion.active(),"duplicate event doesn't restart")
            game.motion.finish()
            check(game.figures[i].position==Vector3(unit.x,game.figure_height(i),unit.y),"skip settles authoritative cell")
    # Real rule command with a corner; animation never chooses its own route.
    check(app.session.submit({"kind":"move","unit":0,"x":3,"y":6}),"real corner move")
    game.battle=app.session.logic;game.refresh();var settled=game.battle.snapshot()
    game.motion.advance(1.25)
    check(game.motion.motions.mara.segment==1,"turn follows complete Lua path")
    var facing=game.facing.mara
    game.motion.advance(8)
    check(not game.motion.active() and game.facing.mara==facing,"completion holds final facing")
    check(game.battle.snapshot()==settled,"presentation doesn't mutate hash/RNG/state")
    game.motion.last_step=-1;game.motion.consume(game.battle.step,game.battle.events);game.motion.advance(.1);game.motion.finish()
    check(game.battle.snapshot()==settled,"replay/cancel remains presentation only")
    check(game.find_children("*","SubViewport",true,false).is_empty(),"no IK compositor")
    print("IDLE_SLIDE checks=",checks," failures=0 roles=6 directions=4")
    quit()
