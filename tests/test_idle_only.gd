extends "res://tests/support/test_case.gd"
func _initialize():call_deferred("run")
func run():
    var Lib=preload("res://view/map_sequence.gd");var lib=Lib.new()
    var data=JSON.parse_string(FileAccess.get_file_as_string(Lib.PATH))
    check(lib.errors.is_empty() and lib.profiles.size()==8,"eight profiles")
    for id in ["neri","adela","elsbet"]:
        for d in Lib.DIRECTIONS:
            var e=lib.profiles[id][d];var clip=e.idle;var start=0
            check(e.motion.is_empty(),"no new motion")
            for i in range(6):
                for tick in range(start,clip.ends[i]):check(lib.idle(id,d,(tick+.5)/24,e.guard)==clip.textures[i],"weighted idle tick")
                start=clip.ends[i]
            check(lib.motion(id,d,.4,e.guard)==null,"motion falls back")
            check(lib.textures_for(id,d,e.guard).size()==6,"idle cached textures")
            check(lib.idle(id,d,clip.ticks/24.0,e.guard)==clip.textures[0],"wrap")
        for value in [null,[],{},1,"true"]:
            var bad=data.duplicate(true);bad.profiles[id].idle_only=value;lib.configure(bad)
            check(not lib.profiles.has(id) and lib.profiles.has("bram"),"invalid flag atomic fallback")
        for value in [null,[],{},1,"true"]:
            var bad=data.duplicate(true);bad.profiles[id].motion_only=value;lib.configure(bad)
            check(not lib.profiles.has(id),"invalid companion flag safe")
        for kind in ["both","motion","missing","badclip"]:
            var bad=data.duplicate(true)
            if kind=="both":bad.profiles[id].motion_only=true
            elif kind=="motion":bad.profiles[id].front_left.motion={}
            elif kind=="missing":bad.profiles[id].front_left.erase("idle")
            else:bad.profiles[id].front_left.idle.ticks=[null]
            lib.configure(bad);check(not lib.profiles.has(id),"invalid profile rejected")
        lib.configure(data)
    var app=root.get_node("App");app.presentation_preferences_path="user://seven-toggle-test.cfg"
    DirAccess.remove_absolute(app.presentation_preferences_path);app.load_presentation_preferences()
    for id in ["mara","finn","oren","bram","neri","adela","elsbet"]:check(app.map_sequence_enabled(id),"latest default on")
    # Removed-toggle persistence is covered by test_latest_map_policy and its restart.
    print("IDLE_ONLY checks=",checks," failures=",failures);quit(1 if failures else 0)
