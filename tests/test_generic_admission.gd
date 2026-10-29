extends "res://tests/support/test_case.gd"
const Art=preload("res://view/generic_map_art.gd")
const Seq=preload("res://view/map_sequence.gd")
func _initialize():call_deferred("run")
func run():
    var catalog=JSON.parse_string(FileAccess.get_file_as_string(Art.PATH))
    require(catalog.profiles.size()==6,"exact six verified identities")
    for id in Seq.CATALOG_IDS:
        var spec=catalog.profiles[id];var data=JSON.parse_string(FileAccess.get_file_as_string("res://"+spec.manifest))
        var a=Art.decode_profile(id,spec,data,true);require(not a.is_empty() and not a.static_fallback,"valid data")
        var ordinary=Seq.new("");ordinary.configure(data);require(ordinary.profiles.is_empty(),"generic schema not admitted by ordinary loader")
        for bad in [null,[],{},false,"text",{"version":2,"profiles":{id:null}}]:
            var fallback=Art.decode_profile(id,spec,bad,true);require(not fallback.is_empty() and fallback.static_fallback,"malformed motion falls back to own static identity")
            for d in Seq.DIRECTIONS:require(fallback.library.profiles[id][d].motion.textures==[fallback.map[d]],"fallback never borrows hero")
        for field in ["root","ticks","frames","flip_h"]:
            var bad=data.duplicate(true);bad.profiles[id].front_left.motion[field]=null
            require(Art.decode_profile(id,spec,bad,true).static_fallback,"invalid clip rejected")
        var bad=data.duplicate(true);bad.profiles[id].front_left.motion.frames[0]="assets/sprites/iso4/mara_seedance_mini_v2/motion/front_left/front_left_walk_00.png"
        require(Art.decode_profile(id,spec,bad,true).static_fallback,"foreign identity path cannot enter profile")
        bad=data.duplicate(true);bad.profiles[id].front_left.motion.frames[0]=spec.base+"../wrong.png"
        require(Art.decode_profile(id,spec,bad,true).static_fallback,"traversal cannot enter profile")
        bad=spec.duplicate(true);bad.base="user://";require(Art.decode_profile(id,bad,data,true).is_empty(),"unsafe catalog prefix rejected")
        bad=spec.duplicate(true);bad.idle.front_left=spec.base+"missing.png"
        require(Art.decode_profile(id,bad,data,true).is_empty(),"missing canonical identity not silently substituted")
        require(Art.decode_profile("unknown_mod",spec,data,true).is_empty(),"unknown Mod never inherits known identity")
        for d in Seq.DIRECTIONS:
            var entry=a.library.profiles[id][d]
            require(entry.idle.textures.size()==1 and entry.motion.textures.size()==8,"one held idle and eight gait frames")
            require(entry.idle.flip_h==d.ends_with("right") and entry.motion.flip_h==d.ends_with("right"),"four facings matching mirror state")
            require(entry.guard.get_size()==Vector2(160,160) and entry.motion.root==Vector2(80,144),"canonical canvas/root")
    print("GENERIC_ADMISSION checks=",checks," failures=0");quit()
