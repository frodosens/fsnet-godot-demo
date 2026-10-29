extends SceneTree
func _initialize():call_deferred("run")
func frames():
    for i in range(4):await process_frame
func run():
    root.size=Vector2i(1280,800)
    var app=root.get_node("App");app.new_game(Content.reference_content());change_scene_to_file("res://main.tscn");await frames()
    var game=current_scene;var rig=game.layer_rig;assert(rig.available)
    var truth=game.battle.snapshot();var maximum=0.0;var clamped=0;var worst_drift=0.0;var planted={}
    var delta=Vector2(5.625,-5.625)
    for i in range(401):
        var cycles=i/200.0;rig.canvas.pose(cycles,delta);maximum=maxf(maximum,rig.canvas.max_error)
        if rig.canvas.max_error>0.01:clamped+=1
        for side in ["near","far"]:
            var leg=rig.canvas.legs[side];var phase=fposmod(cycles+leg.phase_offset,1)
            var contact_key=side+str(int(floor(cycles+leg.phase_offset)))
            if phase<rig.canvas.stance:
                var foot=rig.canvas.commands[side+"_boot"].position+(leg.sole-leg.ankle)+delta*cycles
                if not planted.has(contact_key):planted[contact_key]=foot
                worst_drift=maxf(worst_drift,foot.distance_to(planted[contact_key]))
            assert(rig.canvas.commands[side+"_boot"].rotation==0)
    assert(clamped==0 and worst_drift<0.001 and game.battle.snapshot()==truth)
    while not app.next_story().is_empty():app.advance_story(true)
    game.refresh();app.mara_layer_preview=true;assert(game.scene_view.set_fixed(true))
    assert(app.session.submit({"kind":"move","unit":0,"x":4,"y":6}))
    game.battle=app.session.logic;game.refresh();game.motion.set_process(false);game.motion.advance(0.2)
    assert(game.figures[0].texture==rig.viewport.get_texture())
    var moved=game.battle.snapshot();game.skip_presentation()
    assert(game.figures[0].texture!=rig.viewport.get_texture() and rig.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED and game.battle.snapshot()==moved)
    app.mara_layer_preview=false
    print("LAYER_RIG_LIFECYCLE_PASS skip_restores_idle=true viewport_stopped=true rules_unchanged=true")
    print("LAYER_RIG_ASSETS_PASS samples=401 boots_untwisted=true clamp_count=",clamped," max_clamp_px=",maximum," ideal_marker_stance_drift_px=",worst_drift," authored_marker_uncertainty_px=1.5")
    quit()
