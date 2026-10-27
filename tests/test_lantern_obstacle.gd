extends SceneTree
const Content=preload("res://logic/content.gd")
const Runtime=preload("res://logic/runtime.gd")
const Authority=preload("res://logic/authority.gd")
const Session=preload("res://logic/session.gd")
var checks=0
var failures=0
var app
var capture_dir=OS.get_environment("AMBER_LANTERN_CAPTURE")
func check(ok,label):
    checks+=1
    if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize():call_deferred("run")
func frames():
    for i in range(3):await process_frame
func capture(label):
    if capture_dir=="" or DisplayServer.get_name()=="headless":return
    DirAccess.make_dir_recursive_absolute(capture_dir)
    await frames();await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(capture_dir.path_join(label+".png"))
func open_battle():
    change_scene_to_file("res://main.tscn");await frames()
    while not app.next_story().is_empty():app.advance_story(true)
    current_scene.refresh()
func run():
    app=root.get_node("App");app.save_root="user://lantern_obstacle_"+str(Time.get_ticks_usec())
    var data=Content.reference_content();var old=data.duplicate(true)
    old.revision=1;old.terrain[7]="D"+old.terrain[7].substr(1)
    check(Content.validate(data)=="" and Content.validate(old)=="","both content versions remain valid")
    var changes=[]
    for y in range(data.height):
        for x in range(data.width):
            if data.terrain[y][x]!=old.terrain[y][x]:changes.append(Vector2i(x,y))
    check(changes==[Vector2i(0,7)] and data.revision==2,"one terrain cell changed with explicit content revision")
    check(data.units==old.units and data.story==old.story and data.victory==old.victory and data.defeat==old.defeat,"spawns, story and objectives unchanged")
    # All traversable ground remains in the same component, ignoring units.
    var reached={Vector2i(4,7):true};var queue=[Vector2i(4,7)]
    while not queue.is_empty():
        var p=queue.pop_front()
        for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
            var q=p+d
            if q.x<0 or q.y<0 or q.x>=data.width or q.y>=data.height or reached.has(q) or data.terrain[q.y][q.x] in ["X","W"]:continue
            reached[q]=true;queue.append(q)
    for y in range(data.height):
        for x in range(data.width):
            if data.terrain[y][x] not in ["X","W"]:check(reached.has(Vector2i(x,y)),"walkable component connected "+str(Vector2i(x,y)))
    for unit in data.units:check(reached.has(Vector2i(unit.x,unit.y)),"spawn remains reachable "+unit.id)
    var server=Authority.new(data);var clients=[]
    for i in range(2):
        var client=Session.new();client.logic=Runtime.new(data);clients.append(client)
    var id=0
    for command in [{"kind":"move","unit":0,"x":1,"y":7},{"kind":"end_turn"},{"kind":"move","unit":0,"x":0,"y":7},{"kind":"move","unit":0,"x":0,"y":8}]:
        id+=1;command.step=server.logic.step+1
        var before=server.logic.snapshot()
        var reply=server.handle({"rules":server.logic.rules_hash,"content":server.logic.content_hash,"client":"lamp-test","id":id,"command":command})
        if id==3:check(not reply.get("accepted",false) and server.logic.snapshot()==before,"blocked destination rejected without RNG/action consumption")
        else:check(reply.get("accepted",false),"alternate road remains legal")
        for client in clients:check(client.synchronize(reply) and client.logic.state_hash()==server.logic.state_hash(),"server and both replica hashes agree")
    var old_logic=Runtime.new(old)
    check(old_logic.content_hash!=server.logic.content_hash,"new terrain changes content hash")
    var mismatch=server.handle({"rules":old_logic.rules_hash,"content":old_logic.content_hash,"client":"old-peer"})
    check(mismatch.has("error"),"mixed map versions rejected by existing network handshake")
    app.new_game(data);await open_battle()
    check(current_scene.scene_view.active,"new default terrain still uses exact approved background")
    check(app.session.submit({"kind":"move","unit":0,"x":1,"y":7}) and app.session.submit({"kind":"end_turn"}),"approach obstacle with real commands")
    current_scene.battle=app.session.logic;current_scene.refresh();current_scene.skip_presentation()
    while not app.next_story().is_empty():app.advance_story(true)
    current_scene.refresh()
    for size in [Vector2i(1280,800),Vector2i(960,600)]:
        root.size=size;await frames();current_scene.select_mode("move")
        var before=app.session.logic.snapshot()
        check(not current_scene.stage_move(Vector2i(0,7)) and not current_scene.preview_ghost.visible,"blocked cell has no confirm/ghost at "+str(size))
        check(not current_scene.preview_reachable.has(Vector2i(0,7)),"no movement fill on obstacle")
        await capture("blocked-"+str(size.x))
        check(current_scene.stage_move(Vector2i(0,8)),"adjacent front cell remains valid preview")
        for cell in current_scene.preview_path:check(Vector2i(cell.x,cell.y)!=Vector2i(0,7),"actual BFS path routes around blocked cell")
        check(app.session.logic.snapshot()==before,"preview/cancel does not change rules")
        await capture("detour-"+str(size.x))
        current_scene.clear_move_preview()
    check(app.save_slot("slot1")=="","new content save works")
    var new_state=app.session.logic.snapshot();check(app.load_slot("slot1") and app.session.logic.snapshot()==new_state,"new save exact snapshot roundtrip")
    # Genuine old content/save with Mara already standing on the newly blocked
    # coordinate: never mutate the embedded map or teleport her during load.
    app.new_game(old)
    for cmd in [{"kind":"move","unit":0,"x":1,"y":7},{"kind":"end_turn"},{"kind":"move","unit":0,"x":0,"y":7}]:check(app.session.submit(cmd),"old map reaches historic cell")
    var old_state=app.session.logic.snapshot();var old_hash=app.session.logic.state_hash()
    check(app.save_slot("slot2")=="","historic occupied-cell save writes")
    app.new_game(data);check(app.load_slot("slot2"),"historic save loads without migration")
    check(app.session.logic.snapshot()==old_state and app.session.logic.state_hash()==old_hash and app.session.logic.units[0].pos==Vector2i(0,7),"historic coordinates, RNG and full state preserved")
    await open_battle()
    check(not current_scene.scene_view.active and current_scene.scene_view.compatibility_message!="","old geometry uses explicit 3D compatibility view")
    check(current_scene.hud.net_label.text.contains("旧版地图") and current_scene.hud.net_label.tooltip_text.contains("不套用新障碍"),"visible old-save explanation")
    await capture("old-save-compatible")
    check(app.session.submit({"kind":"end_turn"}) and app.session.submit({"kind":"move","unit":0,"x":0,"y":8}),"historic unit can leave cell normally")
    var custom=data.duplicate(true);custom.id="custom_lantern_test";app.new_game(custom);await open_battle()
    check(not current_scene.scene_view.active and current_scene.scene_view.compatibility_message=="","custom maps not forced into painting or mislabelled old")
    print("LANTERN_OBSTACLE checks=",checks," failures=",failures)
    quit(1 if failures else 0)
