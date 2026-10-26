extends SceneTree
const Content=preload("res://logic/content.gd")
var checks=0
var failures=0
func check(ok,label):
    checks+=1
    if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize():call_deferred("run")
func run():
    var app=root.get_node("App");var data=Content.default_content();data.units[0].x=2;app.new_game(data)
    var game=load("res://main.tscn").instantiate();root.add_child(game);current_scene=game
    await process_frame;game.hud.advance(true)
    game.motion.set_process(false)
    # Explicit test doubles: coloured 1px textures exercise timing/lifecycle, NOT walk art.
    var frames=[]
    for color in [Color.RED,Color.GREEN,Color.BLUE,Color.WHITE]:
        var image=Image.create(1,1,false,Image.FORMAT_RGBA8);image.fill(color);frames.append(ImageTexture.create_from_image(image))
    if game.iso_roles.has("knight"):
        var supported=[{"x":2,"y":6},{"x":3,"y":6}]
        var missing=[{"x":2,"y":6},{"x":2,"y":7}]
        check(game.motion.path_has_frames("knight",supported),"iso proof supports true right-front gait")
        if not game.motion.frames.knight.has("front_left"):
            check(not game.motion.path_has_frames("knight",missing),"missing iso direction cannot slide or mix old flat gait")
    game.iso_roles.erase("knight")
    game.motion.frames.knight={"front":frames,"back":frames,"left":frames,"right":frames}
    app.session.submit({"kind":"equip","unit":0,"slot":5,"item":2});game.battle=app.session.logic;game.refresh()
    check(app.session.submit({"kind":"move","unit":0,"x":3,"y":6}),"real move emits canonical path")
    game.battle=app.session.logic;game.refresh();var state=game.battle.snapshot()
    check(game.motion.active() and game.battle.events[0].path.size()==2,"manifest playback consumes path")
    game.motion.advance(0.05);var first=game.figures[0].texture
    check(game.figures[0].position.x>2 and game.figures[0].position.x<3,"position interpolates along settled path")
    game.motion.advance(0.14)
    check(game.figures[0].texture!=first,"frame clock cycles distinct test frames")
    var step=game.battle.step;game.finish_turn()
    check(game.battle.step==step,"rapid UI action blocked during presentation")
    game.skip_presentation()
    check(not game.motion.active() and game.figures[0].position.x==3 and game.battle.snapshot()==state,"skip snaps to truth without rule mutation")
    app.session.submit({"kind":"move","unit":0,"x":2,"y":6});game.battle=app.session.logic;game.refresh();game.motion.advance(0.05)
    app.session.submit({"kind":"end_turn"});game.battle=app.session.logic;game.refresh()
    check(not game.motion.motions.has("mara") and game.figures[0].position.x==2,"new authoritative step interrupts old visual safely")
    var ongoing=game.motion.motions.duplicate(true)
    game.motion.consume(game.battle.step,game.battle.events)
    check(game.motion.motions==ongoing,"repeated same-step refresh does not restart movement")
    print("MOTION_TESTS checks=",checks," failures=",failures," mocked_art=true")
    quit(0 if failures==0 else 1)
