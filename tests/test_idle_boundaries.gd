extends SceneTree
class Probe:
    extends "res://view/idle_library.gd"
    var decoded=0
    func decode(spec,canvas):
        decoded+=1
        return super.decode(spec,canvas)
var checks=0
func check(value):
    checks+=1
    assert(value)
func _initialize():call_deferred("run")
func run():
    var library=preload("res://view/idle_library.gd").new()
    var fallback=load("res://assets/sprites/iso4/knight_back_right_idle.png")
    check(library.sample("map","knight:back_right",0,fallback,false,"mara")!=fallback)
    check(library.sample("map","knight:back_right",0,fallback,false,"custom-knight")==fallback)
    check(library.sample("map","knight:back_right",0,fallback)==fallback)
    var spec={"frames":["assets/sprites/iso4/knight_front_right_idle.png"],"frame_ms":[400]}
    var probe=Probe.new("res://assets/animations/test-absent.json")
    probe.configure({"version":1,"map":{"custom-knight:front_right":spec,"knight:north":spec,":front_left":spec,"knight:front_left:extra":spec},"battle":{"custom_hero-7:right":{"frames":["assets/battle/mara/00_idle.png"],"frame_ms":[400]},"mara:back_right":spec}})
    check(probe.decoded==2);check(probe.errors.size()==4)
    check(probe.clips.map.has("custom-knight:front_right"));check(probe.clips.battle.has("custom_hero-7:right"))
    check(probe.sample("map","custom-knight:front_right",0,fallback,false,"another-unit")!=fallback)
    for bad in [null,42,"mara:","Mara:right","mara:front_right","mara/right"]:check(not probe.valid_key("battle",bad))
    if OS.get_name()=="Linux":
        var path="user://idle-unreadable-"+str(OS.get_process_id())+".json"
        var file=FileAccess.open(path,FileAccess.WRITE);file.store_string('{"version":1}');file.close()
        check(FileAccess.set_unix_permissions(path,0)==OK)
        check(FileAccess.file_exists(path));check(FileAccess.open(path,FileAccess.READ)==null)
        var unreadable=preload("res://view/idle_library.gd").new(path)
        var rejected=unreadable.errors.size()==1 and unreadable.errors[0].contains("cannot be opened")
        FileAccess.set_unix_permissions(path,384);DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
        check(rejected);check(unreadable.sample("map","knight:back_right",0,fallback)==fallback)
    else:print("Unreadable-file OS permissions fixture: not run on this platform")
    var content=preload("res://logic/content.gd").reference_content();content.units[1].role="knight"
    var app=root.get_node("App");check(app.new_game(content));change_scene_to_file("res://main.tscn")
    await process_frame;await process_frame
    while not app.next_story().is_empty():app.advance_story(true)
    var game=current_scene;game.refresh();var idle=game.get_node("MapIdle");idle.set_process(false)
    var snapshot=game.battle.snapshot();idle.advance(.4)
    check(game.battle.units[1].role=="knight" and game.battle.units[1].id=="finn")
    check(game.figures[1].texture==game.direction_textures["finn:"+game.facing.finn])
    check(game.figures[0].texture!=game.direction_textures["mara:"+game.facing.mara])
    check(game.battle.snapshot()==snapshot)
    print("IDLE_BOUNDARIES checks=",checks," failures=0");quit()
