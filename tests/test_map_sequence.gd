extends SceneTree
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok,label):
    checks+=1
    if not ok:failures+=1;printerr("FAIL: ",label)
func run():
    var Library=preload("res://view/map_sequence.gd")
    var lib=Library.new();var data=JSON.parse_string(FileAccess.get_file_as_string(Library.PATH))
    check(lib.errors.is_empty() and lib.profiles.size()==7,"seven complete profiles loaded")
    if lib.profiles.is_empty():quit(1);return
    for direction in Library.DIRECTIONS:
        var entry=lib.profiles.mara[direction]
        for kind in ["idle","motion"]:
            var clip=entry[kind];var start=0
            check(clip.textures.size()==(6 if kind=="idle" else 8),"compact count")
            for i in range(clip.ends.size()):
                for tick in range(start,clip.ends[i]):
                    var phase=(tick+.5)/38.0
                    var actual=lib.idle("mara",direction,phase*38/24,entry.guard) if kind=="idle" else lib.motion("mara",direction,2+phase,entry.guard)
                    check(actual==clip.textures[i],"every weighted tick selects exact frame")
                start=clip.ends[i]
            check(lib.pick(clip,1)==clip.textures[0],"cycle wraps")
        check(lib.motion("another_knight",direction,.2,entry.guard)==null,"unit scoped")
        check(lib.motion("mara",direction,.2,null)==null,"neutral identity guard")
        check(lib.idle("mara",direction,1,entry.guard,true)==entry.idle.textures[0],"reduced motion")
        check(lib.motion("mara",direction,NAN,entry.guard)==null,"NaN fallback")
        check(lib.motion("mara",direction,-1,entry.guard)==null,"negative fallback")
    for value in [null,[],42,"bad"]:
        var bad=data.duplicate(true);bad.profiles.mara.front_right=value;lib.configure(bad)
        check(not lib.profiles.has("mara") and not lib.errors.is_empty(),"atomic bad direction fallback")
        bad=data.duplicate(true);bad.profiles.mara.front_right.motion=value;lib.configure(bad)
        check(not lib.profiles.has("mara"),"bad nested clip fallback")
    for field in ["frames","ticks","root"]:
        for value in [null,[],"bad",42]:
            var bad=data.duplicate(true);bad.profiles.mara.front_right.motion[field]=value;lib.configure(bad)
            check(not lib.profiles.has("mara"),"bad clip field fallback")
    for value in [null,{},"bad",NAN,INF,-1,0,1.5,39]:
        var bad=data.duplicate(true);bad.profiles.mara.front_right.motion.ticks[0]=value;lib.configure(bad)
        check(not lib.profiles.has("mara"),"invalid tick rejected")
    for value in ["../bad.png","assets/../bad.png","user://bad.png","assets/missing.png",null,{}]:
        var bad=data.duplicate(true);bad.profiles.mara.front_right.motion.frames[0]=value;lib.configure(bad)
        check(not lib.profiles.has("mara"),"unsafe/missing path rejected")
    for value in [[{},120],[64,null],[true,120],[64,INF],[64,NAN],[48,120]]:
        var bad=data.duplicate(true);bad.profiles.mara.front_right.motion.root=value;lib.configure(bad)
        check(not lib.profiles.has("mara"),"invalid root rejected")
    lib.configure(data);check(lib.profiles.size()==7,"valid reload")
    print("MAP_SEQUENCE checks=",checks," failures=",failures);quit(1 if failures else 0)
