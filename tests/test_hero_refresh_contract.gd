extends SceneTree
# Synthetic in-memory textures only: no candidate art is generated or registered.
class FixtureLibrary:
    extends "res://view/map_sequence.gd"
    var images={}
    func texture_at(path,canvas):
        if not path is String or not path.begins_with("fixture:"):return null
        var key=path+str(canvas)
        if not images.has(key):images[key]=ImageTexture.create_from_image(Image.create(canvas.x,canvas.y,false,Image.FORMAT_RGBA8))
        return images[key]
var checks=0
func check(value,label):
    checks+=1
    if not value:printerr("FAIL: ",label);quit(1)
    assert(value,label)
func clip(path,flip):return {"frames":[path],"ticks":[1],"cycle_ticks":1,"root":[80,144],"flip_h":flip}
func _initialize():
    var library=FixtureLibrary.new("user://absent-hero-fixture.json")
    var profile={"canvas":[160,160]}
    for direction in library.DIRECTIONS:
        var source=direction.replace("right","left")
        profile[direction]={"neutral_guard":"fixture:guard:"+direction,"idle":clip("fixture:"+source+":idle",direction.ends_with("right")),"motion":clip("fixture:"+source+":walk",direction.ends_with("right"))}
    var data={"version":2,"profiles":{"mara":profile}}
    library.configure(JSON.parse_string(JSON.stringify(data)))
    check(library.errors.is_empty() and library.profiles.has("mara"),"explicit 160 hero profile accepted")
    for direction in library.DIRECTIONS:
        var entry=library.profiles.mara[direction]
        check(entry.idle.root==Vector2(80,144) and entry.motion.root==Vector2(80,144),"shared idle/move anchor")
        check(entry.idle.flip_h==entry.motion.flip_h,"idle/move mirror continuity")
        check(entry.idle.textures[0].get_size()==Vector2(160,160),"explicit canvas retained")
    for bad in [[128,128],[160,136],null,"160"]:
        var invalid=data.duplicate(true);invalid.profiles.mara.canvas=bad;library.configure(invalid)
        check(library.profiles.is_empty(),"bad canvas fails closed")
    for mode in ["idle","motion"]:
        for root in [[64,120],[80,120],[80,145]]:
            var invalid=data.duplicate(true);invalid.profiles.mara.front_left[mode].root=root;library.configure(invalid)
            check(library.profiles.is_empty(),"bad root fails closed")
        var invalid=data.duplicate(true);invalid.profiles.mara.front_right[mode].flip_h=false;library.configure(invalid)
        check(library.profiles.is_empty(),"inconsistent right facing fails closed")
    var unknown={"version":2,"profiles":{"mod_hero":profile}};library.configure(unknown)
    check(library.profiles.is_empty(),"unregistered Mod ID retains fallback")
    for hero in ["finn","neri"]:
        library.configure({"version":2,"profiles":{hero:profile}});check(library.profiles.has(hero),"other agreed hero accepted")
    var legacy=data.duplicate(true);legacy.version=1
    for direction in library.DIRECTIONS:
        legacy.profiles.mara[direction].idle.root=[48,120]
        legacy.profiles.mara[direction].motion.root=[64,120]
    library.configure(legacy)
    check(library.errors.is_empty(),"legacy 96 idle /128 motion contract preserved")
    print("HERO_REFRESH_CONTRACT checks=",checks," failures=0 synthetic_textures_only=true");quit()
