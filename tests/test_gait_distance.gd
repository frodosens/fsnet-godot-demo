# ARCHIVED: historical walk-frame diagnostic, not current idle-slide runtime.
extends "res://tests/support/test_case.gd"
func _initialize():call_deferred("run")
func run():
    var app=root.get_node("App");app.new_game(Content.reference_content())
    change_scene_to_file("res://main.tscn");await process_frame;await process_frame
    while not app.next_story().is_empty():app.advance_story(true)
    var game=current_scene;game.motion.set_process(false)
    for role in game.motion.gait:
        for direction in game.motion.gait[role]:
            check(game.motion.frames.get(role,{}).get(direction,[]).size()==4,"gait profile has four real frames: "+role+"/"+direction)
    check(app.session.submit({"kind":"move","unit":0,"x":3,"y":6}),"real two-segment corner path")
    game.battle=app.session.logic;game.refresh()
    var truth=game.battle.snapshot();var initial=game.motion.motions.duplicate(true)
    game.motion.advance(0.25)
    check(is_equal_approx(game.motion.motions.mara.distance,0.25) and is_equal_approx(game.motion.motions.mara.cycles,0.5),"8 fps / 4 frames times 0.5 world stride = 1 world/sec")
    var normal=game.figures[0].position;var pose=game.figures[0].texture
    game.motion.motions=initial.duplicate(true);game.motion.speed=2;game.motion.advance(0.125)
    check(game.figures[0].position.is_equal_approx(normal) and game.figures[0].texture==pose,"2x changes displacement and pose clock together")
    game.motion.speed=1;game.motion.motions=initial.duplicate(true);game.motion.advance(1.25)
    var corner=game.figures[0].position;var cycles=game.motion.motions.mara.cycles
    check(game.motion.motions.mara.segment==1 and is_equal_approx(cycles,2.5),"turn corner preserves continuous gait phase")
    game.motion.motions=initial.duplicate(true)
    for i in range(25):game.motion.advance(0.05)
    check(game.figures[0].position.is_equal_approx(corner) and is_equal_approx(game.motion.motions.mara.cycles,cycles),"frame partition leaves same path position and gait")
    game.motion.advance(5)
    check(not game.motion.active() and game.figures[0].position.is_equal_approx(Vector3(3,0.63,6)),"large delta crosses corners and settles exact cell")
    check(game.battle.snapshot()==truth,"gait never mutates rule snapshot or RNG")
    game.motion.last_step=-1;game.motion.consume(game.battle.step,game.battle.events);game.motion.advance(0.3);game.motion.finish()
    check(not game.motion.active() and game.figures[0].position.is_equal_approx(Vector3(3,0.63,6)),"skip/replayed presentation restores authoritative position")
    print("GAIT_DISTANCE checks=",checks," failures=",failures," art_contact_lock_verified=false")
    quit(1 if failures else 0)
