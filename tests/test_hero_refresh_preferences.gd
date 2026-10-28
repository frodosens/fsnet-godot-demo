extends SceneTree
var checks=0
func check(value,label):
    checks+=1
    if not value:printerr("FAIL: ",label);quit(1)
    assert(value,label)
func _initialize():call_deferred("run")
func run():
    var app=root.get_node("App");app.presentation_preferences_path="user://hero-refresh-prep.cfg"
    if FileAccess.file_exists(app.presentation_preferences_path):DirAccess.remove_absolute(app.presentation_preferences_path)
    app.load_presentation_preferences()
    check(app.hero_map_refresh_previews=={"mara":false,"finn":false,"neri":false},"new trials default off")
    check(app.neri_motion_preview,"approved Neri legacy default remains on")
    for id in ["mara","finn","neri"]:
        app.set_hero_map_refresh_preview(true,id);app.load_presentation_preferences()
        check(app.hero_map_refresh_previews[id],"selected trial persists")
        for other in ["mara","finn","neri"]:
            if other!=id:check(not app.hero_map_refresh_previews[other],"other trials unchanged")
        app.set_hero_map_refresh_preview(false,id);app.load_presentation_preferences()
        check(not app.hero_map_refresh_previews[id],"rollback persists")
        check(app.neri_motion_preview,"rollback preserves old Neri configuration")
    app.set_hero_map_refresh_preview(true,"unknown")
    check(app.hero_map_refresh_previews.size()==3,"unknown ID rejected")
    print("HERO_REFRESH_PREFERENCES checks=",checks," failures=0 no_art_registered=true");quit()
