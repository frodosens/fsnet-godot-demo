extends SceneTree
const Library=preload("res://view/map_sequence.gd")
var checks=0
func check(ok,label):
    checks+=1
    if not ok:printerr("FAIL: ",label);quit(1)
    assert(ok,label)
func _initialize():call_deferred("run")
func run():
    var app=root.get_node("App");app.presentation_preferences_path="user://elsbet-prefs-test.cfg"
    if OS.get_environment("ELSBET_RESTART")=="1":
        app.load_presentation_preferences();check(app.elsbet_motion_preview,"latest profile restored in fresh process");print("ELSBET_RESTART checks=",checks," failures=0");quit();return
    DirAccess.remove_absolute(app.presentation_preferences_path);app.load_presentation_preferences();check(app.elsbet_motion_preview,"latest profile enabled")
    var heroes=app.hero_map_refresh_previews.duplicate();app.set_elsbet_motion_preview(true);app.load_presentation_preferences();check(app.elsbet_motion_preview and app.hero_map_refresh_previews==heroes,"independent persisted ON")
    app.set_elsbet_motion_preview(false);app.load_presentation_preferences();check(app.elsbet_motion_preview and app.hero_map_refresh_previews==heroes,"temporary QA override cannot persist across reload")
    var path="res://assets/sprites/iso4/elsbet_seedance_mini_v2/runtime_manifest.json";var lib=Library.new(path)
    check(lib.errors.is_empty() and lib.profiles.keys()==["elsbet"],"Elsbet-only validated profile")
    var data=JSON.parse_string(FileAccess.get_file_as_string(path))
    for direction in lib.DIRECTIONS:
        var entry=lib.profiles.elsbet[direction]
        check(entry.guard.get_size()==Vector2(96,128),"canonical guard dimensions")
        check(entry.motion.textures.size()==8 and entry.motion.ticks==(20 if direction.begins_with("front") else 30),"eight weighted frames with facing-specific cycle")
        check(entry.idle.textures.size()==1 and entry.idle.flip_h==direction.ends_with("right"),"static idle consistent mirror")
        check(entry.idle.root==Vector2(80,144) and entry.motion.root==Vector2(80,144),"fixed foot root")
        check(lib.matching("elsbet",direction,load("res://assets/characters/chapter3/vera/map/"+direction+".png")).is_empty(),"different identity guard cannot borrow Elsbet")
        for distance in [0.0,1.0,2.0,3.0]:check(lib.motion("elsbet",direction,distance,entry.guard)==entry.motion.textures[0],"whole-grid phase reset")
    for field in ["neutral_root","neutral_canvas_width"]:
        var bad=data.duplicate(true);bad.profiles.elsbet.front_left[field]=[47,120] if field=="neutral_root" else 128
        lib.configure(bad);check(lib.profiles.is_empty(),"invalid legacy guard rejected")
    var bad=data.duplicate(true);bad.profiles.elsbet.front_right.motion.flip_h=false;lib.configure(bad);check(lib.profiles.is_empty(),"inconsistent mirror rejected")
    bad=data.duplicate(true);bad.profiles["unknown_mod"]=bad.profiles.elsbet;bad.profiles.erase("elsbet");lib.configure(bad);check(lib.profiles.is_empty(),"unknown Mod does not inherit profile")
    print("ELSBET_MOTION checks=",checks," failures=0");quit()
