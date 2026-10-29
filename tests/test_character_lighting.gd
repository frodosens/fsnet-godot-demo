extends "res://tests/support/test_case.gd"
func _initialize():call_deferred("run")
func run():
    root.size=Vector2i(1280,800)
    var app=root.get_node("App");app.new_game(Content.reference_content());change_scene_to_file("res://main.tscn")
    await process_frame;await process_frame
    while not app.next_story().is_empty():app.advance_story(true)
    var game=current_scene;var state=game.battle.snapshot()
    for figure in game.figures:
        figure.sync_material();var material=figure.actor_material
        check(material.shading_mode!=BaseMaterial3D.SHADING_MODE_UNSHADED and material.diffuse_mode==BaseMaterial3D.DIFFUSE_LAMBERT_WRAP,"retain wrapped light response")
        check(material.albedo_texture==figure.texture and material.emission_texture==figure.texture and material.emission_operator==BaseMaterial3D.EMISSION_OP_MULTIPLY,"emission uses current texture color")
        check(material.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR and figure.layers==2,"opaque silhouette depth and dedicated light mask")
    app.character_emission=0;await process_frame;await process_frame
    check(is_zero_approx(game.figures[0].actor_material.emission_energy_multiplier),"zero setting disables baseline")
    app.character_emission=0.35;await process_frame;await process_frame
    game.cutin.flash_material.set_shader_parameter("flash_strength",1.0);game.cutin.finish()
    check(is_equal_approx(game.figures[0].actor_material.emission_energy_multiplier,0.35) and game.cutin.flash_material.get_shader_parameter("flash_strength")==0.0,"hurt flash finishes independently of map emission")
    check(game.battle.snapshot()==state,"lighting controls do not affect rules")
    check(app.session.submit({"kind":"move","unit":0,"x":4,"y":4}),"real move for changing texture")
    game.battle=app.session.logic;game.refresh();game.motion.set_process(false);game.motion.advance(0.3);game.figures[0].sync_material()
    check(game.figures[0].actor_material.emission_texture==game.figures[0].texture,"walk frame updates both albedo and emission")
    game.skip_presentation();game.figures[0].sync_material()
    check(game.figures[0].actor_material.emission_texture==game.figures[0].texture,"idle restore updates emission too")
    game.hud.toggle_pause();await process_frame;await process_frame
    var panel=game.hud.modal.get_child(0)
    check(panel.get_global_rect().end.y<=root.get_visible_rect().size.y,"pause controls including emission slider remain in viewport")
    print("CHARACTER_LIGHTING checks=",checks," failures=",failures);quit(1 if failures else 0)
