# ARCHIVED: historical walk-frame diagnostic, not current idle-slide runtime.
extends SceneTree
var checks=0
var failures=0
func check(ok,label):
    checks+=1
    if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize():call_deferred("run")
func run():
    root.size=Vector2i(1280,800)
    var app=root.get_node("App");app.new_game(preload("res://logic/content.gd").reference_content());change_scene_to_file("res://main.tscn")
    for i in range(4):await process_frame
    while not app.next_story().is_empty():app.advance_story(true)
    var game=current_scene;game.refresh();game.motion.set_process(false)
    check(app.get("mara_layer_preview")==null,"removed experimental runtime setting")
    check(game.find_children("*","SubViewport",true,false).is_empty(),"no rig compositor instantiated")
    check(app.session.submit({"kind":"move","unit":0,"x":4,"y":6}),"real shared move accepted")
    game.battle=app.session.logic;game.refresh();var truth=game.battle.snapshot();var textures={}
    for i in range(4):
        game.motion.advance(0.125);var path=game.figures[0].texture.resource_path
        check(path.begins_with("res://assets/sprites/iso4/knight_back_right_walk_"),"whole-character source PNG used")
        textures[path]=true
    check(textures.size()==4,"all four existing whole-character poses sampled")
    game.skip_presentation();check(game.figures[0].texture.resource_path.ends_with("knight_back_right_idle.png"),"skip restores whole-character idle")
    check(game.battle.snapshot()==truth,"presentation preserves rule snapshot")
    print("SPRITE_FRAME_ROUTE checks=",checks," failures=",failures," active_route=whole_character_png existing_art_quality_not_reapproved=true")
    quit(1 if failures else 0)
