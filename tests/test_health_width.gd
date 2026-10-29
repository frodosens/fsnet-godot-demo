extends "res://tests/support/test_case.gd"
var Meter
func _initialize():call_deferred("run")
func frames():
    for i in range(4):await process_frame
func run():
    Meter=load("res://view/unit_health.gd")
    var app=root.get_node("App");var original_path=app.presentation_preferences_path
    app.presentation_preferences_path="user://health-width-"+str(Time.get_ticks_usec())+".cfg"
    app.load_presentation_preferences();check(not app.health_bar_avoidance,"fresh preference defaults off")
    app.set_health_bar_avoidance(true);app.health_bar_avoidance=false;app.load_presentation_preferences()
    check(app.health_bar_avoidance,"local preference persists true")
    var config=ConfigFile.new();config.set_value("map","health_bar_avoidance","true");config.save(app.presentation_preferences_path)
    app.load_presentation_preferences();check(not app.health_bar_avoidance,"malformed local preference defaults off")
    app.set_health_bar_avoidance(false);app.health_bar_avoidance=true;app.load_presentation_preferences()
    check(not app.health_bar_avoidance,"local preference persists false")
    var image=Image.create(30,30,false,Image.FORMAT_RGBA8);image.fill(Color.TRANSPARENT)
    image.fill_rect(Rect2i(10,10,8,16),Color.WHITE);image.set_pixel(0,0,Color.WHITE);image.set_pixel(29,29,Color(1,1,1,.1))
    check(preload("res://tests/health_width_oracle.gd").body_width(ImageTexture.create_from_image(image))==8,"opaque isolated speck and faint margins excluded")
    if "--3d" in OS.get_cmdline_user_args():app.scene_renderer="3d"
    for data in [Content.reference_content(),preload("res://tests/reserve_art_fixture.gd").content()]:
        app.new_game(data);change_scene_to_file("res://main.tscn");await frames()
        while not app.next_story().is_empty():app.advance_story(true)
        var game=current_scene;game.refresh();game.get_node("MapIdle").set_process(false)
        var truth=game.battle.snapshot();var indices=range(6) if data.id!="reserve_art_demo" else [0,3]
        for size in [Vector2i(1280,800),Vector2i(960,600)]:
            root.size=size;await frames()
            for i in indices:
                var unit=game.battle.units[i];var bar=game.badges[i];var previous_width=-1.0
                for direction in ["front_left","front_right","back_left","back_right"]:
                    game.facing[unit.id]=direction
                    for phase in [0.0,.4,.8,1.2]:
                        game.get_node("MapIdle").clocks[unit.id]=phase;game.get_node("MapIdle").advance(0)
                        bar.update_health(1 if phase==.4 else unit.max_hp,unit.max_hp,unit.ally,phase==.8);bar._process(0)
                        var scale=minf(float(size.x)/root.get_visible_rect().size.x,float(size.y)/root.get_visible_rect().size.y)
                        var logical=root.get_visible_rect().size
                        var height=game.camera.size if game.camera.keep_aspect==Camera3D.KEEP_HEIGHT else game.camera.size*logical.y/logical.x
                        check(is_equal_approx(bar.rendered_size.x,50.0*scale*game.scene_view.saved_size/height),"requested base 50 follows scene, never body-clamped "+unit.id+direction)
                        check(bar.horizontal_offset==0 and bar.position.is_equal_approx(game.badge_position(i)),"default follows anchor without avoidance")
                        if previous_width>=0:check(is_equal_approx(previous_width,bar.rendered_size.x),"directions/idle/damage never oscillate width")
                        previous_width=bar.rendered_size.x
                bar._process(.1);bar._process(.1)
                check(is_equal_approx(bar.rendered_size.x,Meter.FIXED_WIDTH*minf(float(size.x)/root.get_visible_rect().size.x,float(size.y)/root.get_visible_rect().size.y)*game.scene_view.saved_size/(game.camera.size if game.camera.keep_aspect==Camera3D.KEEP_HEIGHT else game.camera.size*root.get_visible_rect().size.y/root.get_visible_rect().size.x)),"fixed logical width independent of texture")
        # Deliberately overlap a nearby face with the meter; this is presentation-only QA.
        var bar=game.badges[0];var other=game.figures[1];var old_position=other.position
        other.position=game.badge_position(0)-game.camera.global_basis.y*85*other.pixel_size
        app.set_health_bar_avoidance(true);bar._process(0)
        check(bar.horizontal_offset!=0,"opt-in restores face avoidance")
        app.set_health_bar_avoidance(false);bar._process(0)
        check(bar.horizontal_offset==0 and bar.position.is_equal_approx(game.badge_position(0)),"disable immediately restores owner anchor")
        other.position=old_position
        game.hud.show_feedback_settings()
        var controls=game.hud.modal.find_children("*","CheckButton",true,false);var toggle
        for control in controls:
            if control.text=="头顶血条自动避让":toggle=control
        check(toggle!=null and not toggle.button_pressed,"themed settings exposes off toggle")
        if toggle:
            await frames()
            var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.position=toggle.get_global_rect().get_center();click.pressed=true;root.push_input(click,true);await process_frame
            click=click.duplicate();click.pressed=false;root.push_input(click,true);await frames()
            check(app.health_bar_avoidance,"actual settings mouse click enables avoidance")
            toggle.grab_focus()
            var key=InputEventKey.new();key.keycode=KEY_SPACE;key.pressed=true;root.push_input(key,true);await process_frame
            key=key.duplicate();key.pressed=false;root.push_input(key,true);await frames()
            check(not app.health_bar_avoidance,"actual focused Space key disables avoidance")
        game.hud.clear_modal()
        check(game.battle.snapshot()==truth,"local settings and bars leave full rule state unchanged")
        # Real path animation retains anchor; no meter input collider/control steals board clicks.
        if data.id=="reserve_art_demo":
            check(app.session.submit({"kind":"move","unit":0,"x":3,"y":7}),"legal move")
            game.battle=app.session.logic;game.refresh();game.motion.advance(.15);bar._process(0)
            check(bar.position.is_equal_approx(game.badge_position(0)),"moving meter follows current sprite")
            game.skip_presentation();bar._process(0)
            check(bar.position.is_equal_approx(game.badge_position(0)),"completed move remains anchored")
        check(bar.find_children("*","Control",true,false).is_empty() and bar.find_children("*","CollisionObject3D",true,false).is_empty(),"meters add no clickable overlay")
    DirAccess.remove_absolute(app.presentation_preferences_path);app.presentation_preferences_path=original_path;app.load_presentation_preferences()
    print("HEALTH_WIDTH checks=",checks," failures=",failures)
    quit(1 if failures else 0)
