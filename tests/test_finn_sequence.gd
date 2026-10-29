extends "res://tests/support/test_case.gd"
func _initialize():call_deferred("run")
func run():
    var Lib=preload("res://view/map_sequence.gd");var lib=Lib.new()
    var data=JSON.parse_string(FileAccess.get_file_as_string(Lib.PATH))
    check(lib.errors.is_empty() and lib.profiles.has("finn"),"Finn loaded")
    if not lib.profiles.has("finn"):quit(1);return
    for d in Lib.DIRECTIONS:
        var entry=lib.profiles.finn[d];var clip=entry.motion;var start=0
        check(entry.idle.is_empty() and clip.ticks==25 and clip.textures.size()==8,"motion only compact contract")
        for i in range(8):
            for tick in range(start,clip.ends[i]):
                check(lib.motion("finn",d,3+(tick+.5)/25,entry.guard)==clip.textures[i],"25 weighted ticks")
            start=clip.ends[i]
        check(lib.idle("finn",d,.5,entry.guard)==entry.guard,"no replacement idle")
        check(lib.textures_for("finn",d,entry.guard).size()==8,"only admitted motion in health cache")
        check(lib.motion("other_archer",d,.5,entry.guard)==null,"unit scoped")
    for value in [null,[],{},"true",1]:
        var bad=data.duplicate(true);bad.profiles.finn.motion_only=value;lib.configure(bad)
        check(not lib.profiles.has("finn") and lib.profiles.has("mara"),"bad mode atomic fallback")
    for value in [null,[],{},true,NAN,INF,0,-1,25.5,385,24]:
        var bad=data.duplicate(true);bad.profiles.finn.front_left.motion.cycle_ticks=value;lib.configure(bad)
        check(not lib.profiles.has("finn") and lib.profiles.has("mara"),"bad duration atomic fallback")
    var bad=data.duplicate(true);bad.profiles.finn.front_left.idle=null;lib.configure(bad)
    check(not lib.profiles.has("finn"),"motion only rejects contradictory idle")
    lib.configure(data)
    var app=root.get_node("App")
    app.presentation_preferences_path="user://finn-sequence-toggle-test.cfg"
    app.load_presentation_preferences()
    var other_before=app.map_sequence_enabled("oren")
    for mara in [false,true]:
        app.set_mara_sequence_preview(mara)
        for finn in [false,true]:
            app.set_finn_motion_preview(finn)
            app.load_presentation_preferences()
            check(app.map_sequence_enabled("mara") and app.map_sequence_enabled("finn"),"latest selection restored after QA override")
            check(app.map_sequence_enabled("oren")==other_before,"other actors unchanged")
    app.set_mara_sequence_preview(false);app.set_finn_motion_preview(false)
    print("FINN_SEQUENCE checks=",checks," failures=",failures);quit(1 if failures else 0)
