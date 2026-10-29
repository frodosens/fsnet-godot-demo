extends "res://tests/support/test_case.gd"
func _initialize():call_deferred("run")
func run():
    var app=root.get_node("App");app.presentation_preferences_path="user://neri-default-migration.cfg"
    var config=ConfigFile.new()
    if FileAccess.file_exists(app.presentation_preferences_path):DirAccess.remove_absolute(app.presentation_preferences_path)
    app.load_presentation_preferences();require(app.neri_motion_preview,"new install ON")
    config.load(app.presentation_preferences_path);require(not FileAccess.file_exists(app.presentation_preferences_path),"new install does not write obsolete migration keys")
    for old in [null,false,true]:
        config=ConfigFile.new()
        if old!=null:config.set_value("map","neri_motion_preview",old)
        config.set_value("map","finn_motion_preview",true);config.set_value("map","neri_idle_preview",true)
        config.set_value("map","health_bar_avoidance",true);config.set_value("custom","untouched","keep")
        config.save(app.presentation_preferences_path)
        app.load_presentation_preferences()
        require(app.neri_motion_preview,"legacy value upgrades once")
        require(app.finn_motion_preview and app.idle_sequence_previews.neri and app.health_bar_avoidance,"unrelated flags retained")
        config.load(app.presentation_preferences_path);require(config.get_value("custom","untouched")=="keep","unknown section retained")
        var bytes=FileAccess.get_file_as_bytes(app.presentation_preferences_path)
        app.load_presentation_preferences();require(bytes==FileAccess.get_file_as_bytes(app.presentation_preferences_path),"relaunch without user action never rewrites")
        app.set_neri_motion_preview(false);app.load_presentation_preferences()
        require(app.neri_motion_preview,"temporary QA OFF is ignored on reload")
        require(app.finn_motion_preview and app.idle_sequence_previews.neri,"manual OFF isolated")
        config.load(app.presentation_preferences_path);require(not config.has_section_key("map","neri_motion_default_version"),"no obsolete migration stamp written")
    for version in [1,2]:
        config=ConfigFile.new();config.set_value("map","neri_motion_default_version",version);config.set_value("map","neri_motion_preview",false);config.save(app.presentation_preferences_path)
        var bytes=FileAccess.get_file_as_bytes(app.presentation_preferences_path);app.load_presentation_preferences()
        require(app.neri_motion_preview and bytes==FileAccess.get_file_as_bytes(app.presentation_preferences_path),"versioned OFF ignored without rewriting including future revision")
        app.set_neri_motion_preview(true);config.load(app.presentation_preferences_path)
        require(config.get_value("map","neri_motion_default_version")==version,"setter never downgrades version")
    for bad in ["1",false,-1]:
        config=ConfigFile.new();config.set_value("map","neri_motion_default_version",bad);config.set_value("map","neri_motion_preview",false);config.save(app.presentation_preferences_path)
        app.load_presentation_preferences();require(app.neri_motion_preview,"invalid old marker safely migrates")
    # Exact file is deliberately malformed; migration must not overwrite unknown existing data.
    var printed_errors=Engine.print_error_messages
    Engine.print_error_messages=false # This fixture intentionally triggers ConfigFile parse failure.
    FileAccess.open(app.presentation_preferences_path,FileAccess.WRITE).store_string("[broken\nkeep_original")
    var bytes=FileAccess.get_file_as_bytes(app.presentation_preferences_path);app.load_presentation_preferences()
    require(app.neri_motion_preview and bytes==FileAccess.get_file_as_bytes(app.presentation_preferences_path),"unreadable file preserved")
    app.set_neri_motion_preview(false);require(bytes==FileAccess.get_file_as_bytes(app.presentation_preferences_path),"manual change cannot overwrite unreadable settings")
    Engine.print_error_messages=printed_errors
    DirAccess.remove_absolute(app.presentation_preferences_path)
    print("NERI_DEFAULT_MIGRATION checks=",checks," failures=0");quit()
