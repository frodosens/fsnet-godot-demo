extends SceneTree
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok,label):
    checks+=1
    if not ok:failures+=1;printerr("FAIL: ",label)
func frames(n=3):
    for j in range(n):await process_frame
func run():
    var Meter=load("res://view/unit_health.gd")
    var app=root.get_node("App");app.presentation_preferences_path="user://idle-only-scene.cfg";app.save_root="user://idle-only-save-"+str(Time.get_ticks_usec())
    var Seq=preload("res://view/map_sequence.gd").shared()
    var output=OS.get_environment("AMBER_IDLE_STILLS")
    for fixed in [true,false]:
        for actor in ["neri","adela","elsbet"]:
            for d in Seq.DIRECTIONS:
                var data=preload("res://tests/walk_rear_fixture.gd").content(actor,d)
                var target=preload("res://tests/walk_rear_fixture.gd").target(d)
                var i=0
                for j in range(data.units.size()):
                    if data.units[j].id==actor:i=j
                app.set_idle_sequence_preview(false,actor);app.new_game(data);change_scene_to_file("res://main.tscn");await frames()
                while not app.next_story().is_empty():app.advance_story(true)
                var g=current_scene;g.refresh();g.scene_view.set_fixed(fixed);g.facing[actor]=d;g.selected=i;g.refresh()
                g.motion.set_process(false);var idle=g.get_node("MapIdle");idle.set_process(false)
                var old=g.base_directional_idle_texture(i,d);var oldposes=[]
                for tick in range(16):oldposes.append(g.map_motion_texture(i,d,tick/16.0))
                var other_clock={};var other_images={}
                for j in range(g.battle.units.size()):
                    var id=g.battle.units[j].id
                    if id!=actor:idle.clocks[id]=.37;other_clock[id]=.37;other_images[id]=g.figures[j].texture
                app.set_idle_sequence_preview(true,actor)
                for j in range(g.battle.units.size()):
                    var id=g.battle.units[j].id
                    if id!=actor:check(idle.clocks[id]==.37 and g.figures[j].texture==other_images[id],"other actor phase and image unchanged")
                var e=Seq.matching(actor,d,old);check(not e.is_empty(),"ID/neutral binding")
                check(g.directional_idle_texture(i,d)==e.idle.textures[0],"idle zero")
                for tick in range(16):check(g.map_motion_texture(i,d,tick/16.0)==oldposes[tick],"all old movement textures identical")
                var truth=g.battle.snapshot();idle.clocks[actor]=0;idle.advance(.9)
                g.badges[i]._process(0)
                var hp_width=g.badges[i].rendered_size.x
                check(hp_width>0,"idle HP visible")
                check(g.figures[i].texture==Seq.idle(actor,d,.9,old),"idle visible clock")
                check(g.figure_texture_pixel_position(i,Vector2(64,120)).is_equal_approx(g.figures[i].position),"padded foot anchor")
                g.hud.show_feedback_settings();await frames();var time=idle.clocks[actor];idle.advance(1);check(idle.clocks[actor]==time,"pause holds idle");g.hud.clear_modal()
                if not output.is_empty():
                    await RenderingServer.frame_post_draw
                    root.get_texture().get_image().save_png(output+"/"+actor+"-"+d+("-fixed" if fixed else "-3d")+".png")
                g.update_move_preview(target);check(g.preview_ghost.visible and g.preview_ghost.texture==g.figures[i].texture,"actual selected idle ghost")
                check(app.session.submit({"kind":"move","unit":i,"x":target.x,"y":target.y}),"legal old move")
                g.battle=app.session.logic;g.refresh();truth=g.battle.snapshot()
                check(g.figures[i].texture==old,"start uses OLD neutral")
                for tick in range(1,32):
                    g.motion.advance(1.0/(16*g.character_scale));var travel=g.motion.motions[actor].travelled
                    var expected=g.motion.walk_library.sample(actor,d,travel,old)
                    check(g.figures[i].texture==expected,"old walk during actual travel")
                    check(g.badges[i].rendered_size.x==hp_width,"fixed HP width stable")
                    var tex=g.figures[i].texture;idle.advance(.1);check(g.figures[i].texture==tex,"idle never replaces movement")
                g.motion.consume(g.battle.step,g.battle.events);check(g.motion.motions[actor].travelled>1,"duplicate no reset")
                g.motion.finish();check(g.figures[i].texture==e.idle.textures[0],"stop resumes idle zero")
                check(g.figures[i].position==Vector3(target.x,0,target.y),"true endpoint")
                check(g.battle.snapshot()==truth,"presentation leaves rules intact")
                check(app.save_slot("slot3")=="" and app.load_slot("slot3"),"save/load")
                check(app.session.logic.snapshot()==truth and app.map_sequence_enabled(actor),"state and local preference retained")
                app.set_idle_sequence_preview(false,actor);check(g.figures[i].texture==old,"old idle fallback")
    for actor in ["neri","adela","elsbet"]:
        var data=preload("res://tests/walk_rear_fixture.gd").content(actor,"front_right");data.units[1].x=6;data.units[1].y=7
        app.new_game(data);change_scene_to_file("res://main.tscn");await frames()
        while not app.next_story().is_empty():app.advance_story(true)
        var g=current_scene;g.refresh();g.motion.set_process(false);var i=0
        for j in range(g.battle.units.size()):
            if g.battle.units[j].id==actor:i=j
        app.set_idle_sequence_preview(true,actor)
        check(app.session.submit({"kind":"move","unit":i,"x":2,"y":7}),"legal corner path")
        g.battle=app.session.logic;g.refresh();var truth=g.battle.snapshot()
        g.motion.advance(1.2/g.character_scale)
        var d=g.facing[actor];var old=g.base_directional_idle_texture(i,d);var distance=g.motion.motions[actor].travelled
        check(g.figures[i].texture==g.motion.walk_library.sample(actor,d,distance,old),"corner preserves old walk")
        var tex=g.figures[i].texture;app.set_idle_sequence_preview(false,actor);app.set_idle_sequence_preview(true,actor)
        check(g.figures[i].texture==tex and g.motion.motions[actor].travelled==distance,"moving toggles do not reset or replace walk")
        g.motion.speed=0;var pos=g.figures[i].position;g.motion.advance(5);check(g.figures[i].position==pos,"speed zero")
        g.motion.speed=8;g.motion.advance(10)
        check(not g.motion.active() and g.figures[i].position==Vector3(2,0,7),"large delta finishes corner")
        check(g.battle.snapshot()==truth,"corner visual only")
    print("IDLE_ONLY_SCENE checks=",checks," failures=",failures);quit(1 if failures else 0)
