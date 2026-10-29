extends "res://tests/support/test_case.gd"
const KEYS=["oren_sequence_preview","bram_sequence_preview","tessa_motion_preview","adela_motion_preview"]
func _initialize():call_deferred("run")
func run():
    var app=root.get_node("App");app.presentation_preferences_path="user://accepted-defaults.cfg"
    if OS.get_environment("AMBER_DEFAULTS_RESTART")=="1":
        app.load_presentation_preferences()
        for key in KEYS:require(not app.get(key),"manual OFF survives process restart")
        require(not app.finn_motion_preview and app.neri_motion_preview,"legacy defaults unchanged")
        print("ACCEPTED_DEFAULTS_RESTART checks=",checks);quit();return
    if FileAccess.file_exists(app.presentation_preferences_path):DirAccess.remove_absolute(app.presentation_preferences_path)
    app.load_presentation_preferences()
    for key in KEYS:require(app.get(key),"fresh default ON")
    var config=ConfigFile.new();config.set_value("map","neri_motion_default_version",1)
    config.set_value("map","neri_motion_preview",true)
    require(config.save(app.presentation_preferences_path)==OK,"old config saved")
    app.load_presentation_preferences()
    for key in KEYS:require(app.get(key),"old config missing keys ON")
    for index in range(KEYS.size()):
        app.call("set_"+KEYS[index],false)
        require(config.load(app.presentation_preferences_path)==OK and config.get_value("map",KEYS[index],true)==false,"settings setter saves explicit OFF")
        app.load_presentation_preferences()
        for other in range(KEYS.size()):require(app.get(KEYS[other])==(other>index),"only explicit choices overridden")
    require(app.hero_map_refresh_previews=={"mara":true,"finn":true,"neri":true},"three hero defaults preserved")
    require(not app.finn_motion_preview and app.neri_motion_preview,"legacy defaults unchanged")
    print("ACCEPTED_DEFAULTS checks=",checks);quit()
