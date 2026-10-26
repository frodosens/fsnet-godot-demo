extends SceneTree
const Content=preload("res://logic/content.gd")
var checks=0
var failures=0
func check(ok,label):
    checks+=1
    if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize():call_deferred("run")
func run():
    var data=Content.default_content();data.units[0].x=2
    var app=root.get_node("App");app.new_game(data)
    var game=load("res://main.tscn").instantiate();root.add_child(game);current_scene=game
    await process_frame;app.advance_story(true);game.hud.refresh_story()
    check(game.direction_textures.size()>=24,"all six independent four-view sets imported")
    check(app.session.submit({"kind":"equip","unit":0,"slot":5,"item":2}),"movement fixture equips boots through rules")
    for entry in [[Vector2i(3,6),"right"],[Vector2i(3,7),"front"],[Vector2i(2,7),"left"],[Vector2i(2,6),"back"]]:
        if entry[1]=="left":app.session.submit({"kind":"end_turn"});app.advance_story(true)
        check(app.session.submit({"kind":"move","unit":0,"x":entry[0].x,"y":entry[0].y}),"legal move for "+entry[1])
        game.battle=app.session.logic;game.refresh();game.motion.advance(10)
        var expected={"right":"front_right","front":"front_left","left":"back_left","back":"back_right"}[entry[1]] if game.iso_roles.has("knight") else entry[1]
        check(game.facing.mara==expected and game.figures[0].texture==game.direction_textures["mara:"+expected],"correct actual direction texture "+entry[1])
        if "--capture-directions" in OS.get_cmdline_user_args():
            assert(DisplayServer.get_name()!="headless")
            DirAccess.make_dir_recursive_absolute("/tmp/amber-direction-validation")
            for frame in range(4):await process_frame
            await RenderingServer.frame_post_draw
            assert(root.get_texture().get_image().save_png("/tmp/amber-direction-validation/"+entry[1]+".png")==OK)
        var state=game.battle.snapshot();game.refresh()
        check(game.facing.mara==expected and game.battle.snapshot()==state,"idle holds visual facing without rule mutation")
    print("DIRECTION_TESTS checks=",checks," failures=",failures)
    quit(0 if failures==0 else 1)
