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
    check(lib.errors.is_empty() and lib.profiles.size()==7,"seven profiles loaded")
    if not lib.profiles.has("oren"):quit(1);return
    for d in Lib.DIRECTIONS:
        var entry=lib.profiles.oren[d]
        for kind in ["idle","motion"]:
            var clip=entry[kind];var start=0
            check(clip.ticks==(48 if kind=="idle" else 42),"correct cycle weight")
            check(clip.root==Vector2(64,120),"same padded root")
            for i in range(clip.textures.size()):
                check(clip.textures[i].get_size()==Vector2(128,128),"padded canvas unchanged")
                for tick in range(start,clip.ends[i]):
                    var phase=(tick+.5)/clip.ticks
                    var actual=lib.idle("oren",d,phase*2,entry.guard) if kind=="idle" else lib.motion("oren",d,2+phase,entry.guard)
                    check(actual==clip.textures[i],"every weighted tick")
                start=clip.ends[i]
        check(lib.motion("other_brute",d,.5,entry.guard)==null,"unit scoped")
        check(lib.idle("oren",d,2,entry.guard)==entry.idle.textures[0],"two second idle wraps")
    for value in [null,[],{},true,"128",NAN,INF,0,127,128.5,256,96]:
        var bad=data.duplicate(true);bad.profiles.oren.front_left.idle_canvas_width=value;lib.configure(bad)
        check(not lib.profiles.has("oren") and lib.profiles.has("mara") and lib.profiles.has("finn"),"bad width only invalidates Oren")
    for value in [null,[],{},true,NAN,INF,-1,47,49]:
        var bad=data.duplicate(true);bad.profiles.oren.front_left.idle.cycle_ticks=value;lib.configure(bad)
        check(not lib.profiles.has("oren"),"bad idle cycle fallback")
    var app=root.get_node("App");app.presentation_preferences_path="user://oren-three-toggle-test.cfg"
    for mara in [false,true]:
        app.set_mara_sequence_preview(mara)
        for finn in [false,true]:
            app.set_finn_motion_preview(finn)
            for oren in [false,true]:
                app.set_oren_sequence_preview(oren);app.load_presentation_preferences()
                check(app.map_sequence_enabled("mara")==mara and app.map_sequence_enabled("finn")==finn and app.map_sequence_enabled("oren")==oren,"three independent persistent switches")
                check(not app.map_sequence_enabled("bram"),"other actors unchanged")
    app.set_mara_sequence_preview(false);app.set_finn_motion_preview(false);app.set_oren_sequence_preview(false)
    print("OREN_SEQUENCE checks=",checks," failures=",failures);quit(1 if failures else 0)
