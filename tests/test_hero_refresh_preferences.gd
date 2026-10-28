extends SceneTree
var checks=0
func check(value,label):
    checks+=1
    if not value:printerr("FAIL: ",label);quit(1)
    assert(value,label)
func _initialize():call_deferred("run")
func run():
    var app=root.get_node("App");app.presentation_preferences_path="user://hero-refresh-prep.cfg"
    if OS.get_environment("AMBER_HERO_PREF_RESTART")=="1":
        app.load_presentation_preferences()
        check(app.hero_map_refresh_previews=={"mara":false,"finn":true,"neri":false},"explicit OFF/missing ON survive separate process restart")
        check(not app.neri_motion_preview and app.finn_motion_preview,"legacy choices survive separate process restart")
        print("HERO_REFRESH_RESTART checks=",checks," failures=0");quit();return
    if FileAccess.file_exists(app.presentation_preferences_path):DirAccess.remove_absolute(app.presentation_preferences_path)
    app.load_presentation_preferences()
    var enabled={"mara":true,"finn":true,"neri":true}
    check(app.hero_map_refresh_previews==enabled,"fresh configuration defaults all three on")
    check(app.neri_motion_preview,"approved Neri legacy default remains on")
    var config=ConfigFile.new()
    config.set_value("map","neri_motion_default_version",1)
    config.set_value("map","neri_motion_preview",false)
    config.set_value("map","finn_motion_preview",true)
    check(config.save(app.presentation_preferences_path)==OK,"legacy fixture saved")
    app.load_presentation_preferences()
    check(app.hero_map_refresh_previews==enabled,"old configuration missing new keys defaults on")
    check(not app.neri_motion_preview and app.finn_motion_preview,"legacy explicit preferences unchanged")
    for id in ["mara","finn","neri"]:
        app.set_hero_map_refresh_preview(false,id)
        enabled[id]=false
        # Recreate startup defaults before loading, rather than retaining in-memory state.
        app.hero_map_refresh_previews={"mara":true,"finn":true,"neri":true}
        app.load_presentation_preferences()
        check(app.hero_map_refresh_previews==enabled,"manual OFF survives startup reload independently")
        check(not app.neri_motion_preview and app.finn_motion_preview,"rollback preserves legacy choices")
    for id in ["mara","finn","neri"]:
        app.set_hero_map_refresh_preview(true,id);enabled[id]=true
        app.load_presentation_preferences()
        check(app.hero_map_refresh_previews==enabled,"individual re-enable preserves other explicit OFF keys")
    config.load(app.presentation_preferences_path)
    config.erase_section_key("map","hero_refresh_v2_finn")
    config.set_value("map","hero_refresh_v2_mara",false)
    config.set_value("map","hero_refresh_v2_neri",false)
    check(config.save(app.presentation_preferences_path)==OK,"mixed fixture saved")
    app.load_presentation_preferences()
    check(app.hero_map_refresh_previews=={"mara":false,"finn":true,"neri":false},"missing key ON never overwrites explicit OFF siblings")
    app.set_hero_map_refresh_preview(true,"unknown")
    check(app.hero_map_refresh_previews.size()==3,"unknown ID rejected")
    print("HERO_REFRESH_PREFERENCES checks=",checks," failures=0");quit()
