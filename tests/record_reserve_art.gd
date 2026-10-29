extends SceneTree
# Actual runtime preview with existing legal rule fixtures. Use --write-movie to
# an absolute local path; never commit resulting screenshots or recordings.
var app
var game
var caption
func _initialize():call_deferred("run")
func wait_frames(n):
    for i in range(n):await process_frame
func scene(data):
    app.new_game(data);change_scene_to_file("res://main.tscn");await wait_frames(5);game=current_scene
    while not app.next_story().is_empty():app.advance_story(true)
    game.refresh()
func attack(actor,target):
    assert(app.session.submit({"kind":"attack","unit":actor,"target":target}))
    game.battle=app.session.logic;game.refresh()
    while game.presentation_active():await process_frame
    await wait_frames(12)
func run():
    root.size=Vector2i(1280,800);app=root.get_node("App");app.sfx_enabled=false
    var layer=CanvasLayer.new();layer.layer=100;root.add_child(layer)
    caption=Style.label("",20);caption.position=Vector2(24,118);layer.add_child(caption)
    caption.text="备用美术样板 · 既有规则承载，不是新职业"
    await scene(preload("res://tests/reserve_art_fixture.gd").content());await wait_frames(20)
    for direction in preload("res://view/reserve_art.gd").DIRECTIONS:
        caption.text="四斜向静态检视 · "+direction
        game.facing.adela=direction;game.facing.elsbet=direction
        await wait_frames(16)
    caption.text="地图移动：沿合法路径使用静态方向图"
    assert(app.session.submit({"kind":"move","unit":0,"x":3,"y":7}))
    game.battle=app.session.logic;game.refresh()
    while game.presentation_active():await process_frame
    await wait_frames(15)
    for actor in [0,3]:
        await scene(preload("res://tests/reserve_art_fixture.gd").content())
        game.selected=actor;game.hud.refresh();caption.text="阿黛拉 · 矛击" if actor==0 else "埃尔丝贝特 · 高位杖击"
        await wait_frames(15);await attack(actor,3 if actor==0 else 0)
    for id in ["adela","elsbet"]:
        var data=preload("res://tests/reserve_art_fixture.gd").content()
        data.units[0].id="mara";data.units[0].name="玛拉";data.units[3].id=id
        data.units[3].name="阿黛拉" if id=="adela" else "埃尔丝贝特"
        await scene(data);caption.text="防守待机／受击／恢复 · "+data.units[3].name
        await wait_frames(15);await attack(0,3)
    print("RESERVE_RECORD_COMPLETE normal_30fps_simulation=true actual_rule_commands=true")
    quit()
