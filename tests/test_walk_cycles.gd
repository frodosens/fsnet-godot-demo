extends SceneTree
var checks=0
var failures=0
func check(ok,label):
    checks+=1
    if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize():call_deferred("run")
func run():
    var Library=load("res://view/walk_library.gd")
    var lib=Library.new();check(lib.errors.is_empty() and lib.clips.has("finn:front_right") and lib.clips.has("oren:front_right"),"valid pilot manifest")
    var source=JSON.parse_string(FileAccess.get_file_as_string(Library.MANIFEST))
    source.clips={"finn:front_right":source.clips["finn:front_right"]}
    var neutral=lib.clips["finn:front_right"].textures[0]
    for entry in [null,[],1,"bad",{}, {"cycle_distance":null}]:
        var test=source.duplicate(true);test.clips["finn:front_right"]=entry;lib.configure(test)
        check(lib.clips.is_empty() and not lib.errors.is_empty(),"invalid nested spec fails closed")
    for key in ["neutral","left","right","cycle_distance"]:
        for value in [null,[],{},true,INF,NAN,-1,"../wrong.png","assets/../../wrong.png","assets/icon.PNG","assets/portraits/finn.png","assets/missing-walk.png"]:
            var test=source.duplicate(true);test.clips["finn:front_right"][key]=value;lib.configure(test)
            check(lib.clips.is_empty() and not lib.errors.is_empty(),"reject malformed "+key)
    for key in ["finn:front","finn:front_right:extra",":front_right","bad/id:front_right"]:
        lib.configure({"version":1,"clips":{key:source.clips["finn:front_right"]}})
        check(lib.clips.is_empty(),"invalid key rejected before loading")
    lib.configure(source)
    var clip=lib.clips["finn:front_right"]
    for distance in [0.0,.25,.5,.75,1.0,1.25,3.75,4.0]:
        check(lib.sample("finn","front_right",distance,neutral)==clip.textures[int(fposmod(distance,1)*4)],"four beats by distance")
    check(lib.sample("finn","front_right",.99999999,neutral)==neutral,"boundary tolerance returns neutral")
    check(lib.sample("unknown","front_right",.25,neutral)==neutral,"unknown ID fallback")
    check(lib.sample("finn","back_right",.25,neutral)==neutral,"unregistered direction fallback")
    check(lib.sample("finn","front_right",.25,clip.textures[1])==clip.textures[1],"changed neutral rejects stale binding")
    check(lib.sample("finn","front_right",NAN,neutral)==neutral,"nonfinite travel safe")
    var app=root.get_node("App");app.new_game(preload("res://logic/content.gd").reference_content())
    change_scene_to_file("res://main.tscn");await process_frame;await process_frame
    while not app.next_story().is_empty():app.advance_story(true)
    var game=current_scene;game.refresh();game.motion.set_process(false);game.get_node("MapIdle").set_process(false)
    var i=1;check(game.battle.units[i].id=="finn","fixture identity")
    var truth=game.battle.snapshot();var step=1000
    var unit=game.battle.units[i]
    var path=[{"x":unit.x-2,"y":unit.y},{"x":unit.x-1,"y":unit.y},{"x":unit.x,"y":unit.y}]
    for speed in [1.0,2.0,8.0]:
        step+=1;game.motion.speed=speed;game.motion.consume(step,[{"kind":"move","actor":"finn","path":path}])
        for beat in range(1,8):
            game.motion.advance(.25/game.character_scale/speed)
            check(game.figures[i].texture==clip.textures[beat%4],"actual travel selects beat")
            check(absf(game.motion.motions.finn.travelled-beat*.25)<.00001,"actual travelled distance")
        var position=game.figures[i].position;var texture=game.figures[i].texture
        game.motion.speed=0;game.motion.advance(5)
        check(game.figures[i].position==position and game.figures[i].texture==texture,"zero speed freezes pose and root")
        game.motion.consume(step,[])
        check(game.figures[i].position==position,"repeat step does not restart")
        game.motion.speed=speed;game.motion.advance(20)
        check(not game.motion.active() and game.figures[i].texture==neutral,"large delta settles neutral")
        check(game.battle.snapshot()==truth,"no rules/state mutation")
    step+=1;game.motion.consume(step,[{"kind":"move","actor":"finn","path":path}]);game.motion.advance(.2)
    game.motion.finish();check(game.figures[i].texture==neutral,"skip returns canonical neutral")
    step+=1
    var corner=[{"x":unit.x-1,"y":unit.y+1},{"x":unit.x,"y":unit.y+1},{"x":unit.x,"y":unit.y}]
    game.motion.speed=1;game.motion.consume(step,[{"kind":"move","actor":"finn","path":corner}])
    game.motion.advance(1.0/game.character_scale)
    check(game.figures[i].texture==neutral and game.motion.motions.finn.segment==1,"corner grid boundary is neutral")
    game.motion.advance(.25/game.character_scale)
    check(game.facing.finn=="back_right" and game.figures[i].texture==game.motion.walk_library.sample("finn","back_right",game.motion.motions.finn.travelled,game.directional_idle_texture(i,"back_right")),"turn uses registered direction or static fallback")
    var position=game.figures[i].position;var distance=game.motion.motions.finn.travelled
    game.motion.set_process(true);paused=true
    await process_frame;await process_frame
    check(game.figures[i].position==position and game.motion.motions.finn.travelled==distance,"SceneTree pause freezes travel and phase")
    game.motion.set_process(false);paused=false
    step+=1;game.motion.consume(step,[{"kind":"move","actor":"finn","path":path}])
    check(game.motion.motions.finn.travelled==0 and game.figures[i].texture==neutral,"new event starts neutral with independent travel")
    game.motion.advance(.25/game.character_scale)
    check(game.figures[i].texture==clip.textures[1],"resume new motion owns phase")
    game.get_node("MapIdle").advance(.5)
    check(game.figures[i].texture==clip.textures[1],"idle never overwrites moving pose")
    game.motion.finish();game.get_node("MapIdle").advance(0)
    check(game.figures[i].texture==neutral,"finish resets idle to same neutral")
    var health=game.badges[i];var Meter=load("res://view/unit_health.gd")
    health._process(0)
    check(health.rendered_size.x>0,"fixed HP visible during walk")
    check(game.motion.walk_library==Library.shared(),"shared cache")
    print("WALK_CYCLES checks=",checks," failures=",failures)
    quit(1 if failures else 0)
