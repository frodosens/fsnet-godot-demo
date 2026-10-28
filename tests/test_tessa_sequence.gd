extends SceneTree
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok,label):
    checks+=1
    if not ok:failures+=1;printerr("FAIL: ",label)
func run():
    var Lib=preload("res://view/map_sequence.gd");var lib=Lib.new()
    var data=JSON.parse_string(FileAccess.get_file_as_string(Lib.PATH))
    check(lib.errors.is_empty() and lib.profiles.has("tessa"),"Tessa loaded")
    if not lib.profiles.has("tessa"):quit(1);return
    for d in Lib.DIRECTIONS:
        var entry=lib.profiles.tessa[d];var clip=entry.motion;var start=0
        check(entry.idle.is_empty() and clip.ticks==24 and clip.textures.size()==8,"motion only compact contract")
        for i in range(8):
            for tick in range(start,clip.ends[i]):
                check(lib.motion("tessa",d,3+(tick+.5)/24,entry.guard)==clip.textures[i],"24 weighted ticks")
            start=clip.ends[i]
        check(lib.idle("tessa",d,.5,entry.guard)==entry.guard,"no replacement idle")
        check(lib.textures_for("tessa",d,entry.guard).size()==8,"only admitted motion in health cache")
        check(lib.motion("other_archer",d,.5,entry.guard)==null,"unit scoped")
    for value in [null,[],{},"true",1]:
        var bad=data.duplicate(true);bad.profiles.tessa.motion_only=value;lib.configure(bad)
        check(not lib.profiles.has("tessa") and lib.profiles.has("mara"),"bad mode atomic fallback")
    for value in [null,[],{},true,NAN,INF,0,-1,24.5,385,23]:
        var bad=data.duplicate(true);bad.profiles.tessa.front_left.motion.cycle_ticks=value;lib.configure(bad)
        check(not lib.profiles.has("tessa") and lib.profiles.has("mara"),"bad duration atomic fallback")
    var bad=data.duplicate(true);bad.profiles.tessa.front_left.idle=null;lib.configure(bad)
    check(not lib.profiles.has("tessa"),"motion only rejects contradictory idle")
    lib.configure(data)
    var app=root.get_node("App")
    app.presentation_preferences_path="user://tessa-sequence-toggle-test.cfg"
    app.load_presentation_preferences()
    var other_before=app.map_sequence_enabled("oren")
    for mara in [false,true]:
        app.set_mara_sequence_preview(mara)
        for tessa in [false,true]:
            app.set_tessa_motion_preview(tessa)
            app.load_presentation_preferences()
            check(app.map_sequence_enabled("mara")==mara and app.map_sequence_enabled("tessa")==tessa,"independent persistent settings")
            check(app.map_sequence_enabled("oren")==other_before,"other actors unchanged")
    app.set_mara_sequence_preview(false);app.set_tessa_motion_preview(false)
    print("TESSA_SEQUENCE checks=",checks," failures=",failures);quit(1 if failures else 0)
