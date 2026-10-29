extends SceneTree
# Linux actual-render capture; output stays outside Git. Uses real Lua commands.
var g
var app
func _initialize():call_deferred('run')
func frames(n):
    for i in range(n):await process_frame
func capture(name):
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png('/tmp/map-magic-'+name+'.png')
func prepare(healing=false):
    var data=preload('res://logic/content.gd').reference_content()
    data.units[2].x=5;data.units[2].y=6
    data.units[3].x=5;data.units[3].y=5
    data.units[4].x=4;data.units[4].y=5
    data.units[5].x=5;data.units[5].y=4
    if healing:data.units[3].x=4;data.units[3].y=6;data.units[3].controller='player'
    app.new_game(data);change_scene_to_file('res://main.tscn');await frames(10)
    while not app.next_story().is_empty():app.advance_story(true)
    g=current_scene;g.refresh();await frames(3)
    if healing:
        if not app.session.submit({'kind':'attack','unit':3,'target':0}):printerr('injury fixture failed');quit(1);return
        g.battle=app.session.logic;g.refresh();g.skip_presentation()
    g.map_magic.set_process(false);g.event_sequence.set_process(false)
func cast(command,label):
    if not app.session.submit(command):printerr('CAPTURE rejected ',command);quit(1);return
    g.battle=app.session.logic;g.refresh()
    var truth=g.battle.snapshot()
    g.map_magic._process(0.2);await capture(label+'-cast')
    g.map_magic._process(0.25);await capture(label+'-travel')
    g.map_magic._process(0.20);await capture(label+'-impact')
    g.map_magic._process(0.75);g.event_sequence._process(0)
    if g.battle.snapshot()!=truth:printerr('CAPTURE state changed');quit(1)
    await capture(label+'-settled')
func run():
    app=root.get_node('App');app.sfx_enabled=false;app.reduced_motion=false
    root.size=Vector2i(1280,800)
    await prepare();await cast({'kind':'ability','ability':'ember','unit':2,'target':3},'ember')
    await prepare();await cast({'kind':'ability','ability':'focus_bolt','unit':2,'target':3},'bolt')
    await prepare(true);await cast({'kind':'skill','unit':0,'target':0},'heal')
    print('MAP_MAGIC_CAPTURE actual_renderer=',RenderingServer.get_video_adapter_name(),' output=/tmp/map-magic-*.png')
    quit()
