extends "res://tests/support/test_case.gd"
func _initialize():call_deferred("run")
func run():
    var Lib=preload("res://view/map_sequence.gd");var lib=Lib.new()
    var data=JSON.parse_string(FileAccess.get_file_as_string(Lib.PATH))
    check(lib.errors.is_empty() and lib.profiles.size()==8,"eight profiles loaded")
    if not lib.profiles.has("bram"):quit(1);return
    for d in Lib.DIRECTIONS:
        var entry=lib.profiles.bram[d]
        for kind in ["idle","motion"]:
            var clip=entry[kind];var start=0
            check(clip.ticks==(41 if kind=="idle" else 23),"correct cycle weight")
            check(clip.root==Vector2(64,120),"same padded root")
            for i in range(clip.textures.size()):
                check(clip.textures[i].get_size()==Vector2(128,128),"padded canvas unchanged")
                for tick in range(start,clip.ends[i]):
                    var phase=(tick+.5)/clip.ticks
                    var actual=lib.idle("bram",d,phase*41/24,entry.guard) if kind=="idle" else lib.motion("bram",d,2+phase,entry.guard)
                    check(actual==clip.textures[i],"every weighted tick")
                start=clip.ends[i]
        check(lib.motion("other_brute",d,.5,entry.guard)==null,"unit scoped")
        check(lib.idle("bram",d,41.0/24,entry.guard)==entry.idle.textures[0],"41 tick idle wraps")
    for value in [null,[],{},true,"128",NAN,INF,0,127,128.5,256,96]:
        var bad=data.duplicate(true);bad.profiles.bram.front_left.idle_canvas_width=value;lib.configure(bad)
        check(not lib.profiles.has("bram") and lib.profiles.has("mara") and lib.profiles.has("finn"),"bad width only invalidates Bram")
    for value in [null,[],{},true,NAN,INF,-1,47,49]:
        var bad=data.duplicate(true);bad.profiles.bram.front_left.idle.cycle_ticks=value;lib.configure(bad)
        check(not lib.profiles.has("bram"),"bad idle cycle fallback")
    var app=root.get_node("App");app.presentation_preferences_path="user://bram-four-toggle-test.cfg"
    for mask in range(16):
        app.set_mara_sequence_preview(bool(mask&1));app.set_finn_motion_preview(bool(mask&2))
        app.set_oren_sequence_preview(bool(mask&4));app.set_bram_sequence_preview(bool(mask&8))
        app.load_presentation_preferences()
        for i in range(4):check(app.map_sequence_enabled(["mara","finn","oren","bram"][i]),"latest resources override all obsolete switch combinations")
        check(app.map_sequence_enabled("neri"),"other actor retains latest accepted idle")
    app.set_mara_sequence_preview(false);app.set_finn_motion_preview(false);app.set_oren_sequence_preview(false);app.set_bram_sequence_preview(false)
    print("BRAM_SEQUENCE checks=",checks," failures=",failures);quit(1 if failures else 0)
