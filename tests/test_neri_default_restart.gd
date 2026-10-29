extends SceneTree
func _initialize():call_deferred("run")
func run():
    var app=root.get_node("App");app.presentation_preferences_path="user://neri-cross-process.cfg"
    var phase=OS.get_environment("NERI_MIGRATION_PHASE")
    if phase=="upgrade":
        var old=ConfigFile.new();old.set_value("map","neri_motion_preview",false);old.set_value("map","finn_motion_preview",true);old.save(app.presentation_preferences_path)
        app.load_presentation_preferences();assert(app.neri_motion_preview and app.finn_motion_preview)
    elif phase=="manual_off":
        app.load_presentation_preferences();assert(app.neri_motion_preview and app.finn_motion_preview)
        app.set_neri_motion_preview(false)
    elif phase=="relaunch":
        app.load_presentation_preferences();assert(app.neri_motion_preview and app.finn_motion_preview)
    else:
        printerr("explicit migration phase required");quit(1);return
    app.new_game();var state=app.session.logic.snapshot();app.load_presentation_preferences();assert(app.session.logic.snapshot()==state)
    print("NERI_RESTART_PASS phase=",phase," state_unchanged=true");quit()
