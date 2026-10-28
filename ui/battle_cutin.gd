extends CanvasLayer
# Presentation only: settled events, no command submission or state mutation.
const UI=preload("res://ui/style.gd")
const MARA=["00_idle","01_anticipation","02_dash","03_thrust","04_follow_through","05_recovery","06_return_step","07_settle_guard"]
const OREN=["00_idle","01_brace","02_hit","03_recover"]
const TIMELINE=[0,0,1,1,1,1,2,2,2,2,3,3,3,4,4,4,5,5,5,6,6,6,7,7]
var idle_library=preload("res://view/idle_library.gd").new()
var sound_player
var release_played=false
var impact_play_count=0
var sounds={}
var arena
var combat_status
var reference_background
var legacy_backdrop=[]
var layout_origin=Vector2.ZERO
var shade
var contact_points={}
var flash_material
var impact
var pending_events=[]
var hitstop_remaining=0.0
var hitstop_done=false
var feedback_strength=1.0
var active=false
var elapsed=0.0
var speed=1.0
var event={}
var surface
var attacker
var defender
var damage_label
var title
var last_seen_step=-1
var actor_sets={}
var defender_sets={}
var reserve_sets={}
var contact_target=Vector2.ZERO
var fx={}
var projectile
var tick_seconds=1.0/12.0
var release_tick=10
func _ready():
    layer=30
    surface=Control.new();surface.theme=UI.make_theme();surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(surface)
    shade=ColorRect.new();shade.color=Color(0.10,0.09,0.08,0.88);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);surface.add_child(shade)
    reference_background=TextureRect.new();reference_background.texture=load("res://assets/backgrounds/amber_bridge_battle/background.png");reference_background.position=Vector2.ZERO;reference_background.size=Vector2(1586,992);reference_background.mouse_filter=Control.MOUSE_FILTER_IGNORE;surface.add_child(reference_background)
    arena=Control.new();arena.mouse_filter=Control.MOUSE_FILTER_IGNORE;surface.add_child(arena)
    contact_points=JSON.parse_string(FileAccess.get_file_as_string("res://assets/battle/contact_points.json"))
    var stage=TextureRect.new();stage.position=Vector2(100,130);stage.size=Vector2(1080,480)
    var backdrop=GradientTexture2D.new();backdrop.width=128;backdrop.height=128;var gradient=Gradient.new();gradient.set_color(0,Color("182c2a"));gradient.set_color(1,Color("65704e"));backdrop.gradient=gradient;backdrop.fill_from=Vector2.ZERO;backdrop.fill_to=Vector2.DOWN;stage.texture=backdrop;arena.add_child(stage);legacy_backdrop.append(stage)
    for placement in [Vector2(110,205),Vector2(900,180),Vector2(720,130)]:
        var tree=TextureRect.new();tree.texture=load("res://assets/environment/props_v3/tree.png");tree.position=placement;tree.size=Vector2(300,300);tree.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;tree.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;tree.modulate=Color(0.48,0.58,0.52,0.85);arena.add_child(tree);legacy_backdrop.append(tree)
    var floor_panel=TextureRect.new();floor_panel.texture=load("res://assets/environment/v2/grass.png");floor_panel.stretch_mode=TextureRect.STRETCH_TILE;floor_panel.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;floor_panel.modulate=Color(0.65,0.72,0.61);floor_panel.position=Vector2(100,495);floor_panel.size=Vector2(1080,115);arena.add_child(floor_panel);legacy_backdrop.append(floor_panel)
    attacker=figure();defender=figure()
    flash_material=ShaderMaterial.new();flash_material.shader=load("res://view/hit_flash.gdshader");defender.material=flash_material
    impact=TextureRect.new();impact.size=Vector2(80,60);impact.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;impact.mouse_filter=Control.MOUSE_FILTER_IGNORE;arena.add_child(impact)
    projectile=TextureRect.new();projectile.size=Vector2(128,96);projectile.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;projectile.mouse_filter=Control.MOUSE_FILTER_IGNORE;arena.add_child(projectile)
    var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/battle/ranged_magic/manifest.json"))
    for id in manifest.characters:
        var data=manifest.characters[id];var textures=[]
        for frame in data.frames:textures.append(load("res://assets/battle/ranged_magic/"+frame.path))
        actor_sets[id]={"textures":textures,"timeline":data.timeline_24ticks,"tick_seconds":data.tick_ms/1000.0,"release":int(data.release_tick)}
    for effect in manifest.effects:fx[effect.state]=load("res://assets/battle/ranged_magic/"+effect.path)
    var enemies=JSON.parse_string(FileAccess.get_file_as_string("res://assets/battle/enemy_combat/manifest.json"))
    for id in ["oren","tessa","bram"]:
        var data=enemies.characters[id];var textures=[]
        for frame in data.frames:textures.append(load("res://assets/battle/enemy_combat/"+frame.path))
        actor_sets[id]={"textures":textures,"timeline":data.timeline,"tick_seconds":data.tick_ms/1000.0,"release":int(contact_points[id].contact_tick)}
    var mara_idle=load("res://assets/battle/mara/00_idle.png")
    for id in ["mara","finn","neri","tessa","bram"]:
        var data=enemies.characters[id+"_hit"];var textures=[]
        for frame in data.frames:textures.append(load("res://assets/battle/enemy_combat/"+frame.path))
        defender_sets[id]={"idle":mara_idle if id=="mara" else actor_sets[id].textures[0],"hit":textures[0],"recover":textures[1]}
    register_reserve_art()
    damage_label=UI.label("",42,Color("d5a18b"));damage_label.position=Vector2(850,275);arena.add_child(damage_label)
    damage_label.add_theme_font_override("font",UI.impact_font())
    damage_label.add_theme_color_override("font_shadow_color",Color("101916"));damage_label.add_theme_constant_override("shadow_offset_x",2);damage_label.add_theme_constant_override("shadow_offset_y",3)
    damage_label.add_theme_color_override("font_outline_color",Color("182421"));damage_label.add_theme_constant_override("outline_size",5)
    combat_status=preload("res://ui/combat_status.gd").new();surface.add_child(combat_status);combat_status.setup(self);title=combat_status.title_label
    sound_player=AudioStreamPlayer.new();sound_player.max_polyphony=2;add_child(sound_player)
    for name in ["swing","impact","arrow","magic","critical"]:sounds[name]=load("res://assets/audio/"+name+".wav")
    get_viewport().size_changed.connect(layout_surface)
    layout_surface()
    surface.hide()
func layout_surface():
    var viewport=get_viewport().get_visible_rect().size
    surface.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);surface.size=Vector2(1586,992)
    var factor=minf(viewport.x/1586.0,viewport.y/992.0);surface.scale=Vector2.ONE*factor;surface.position=(viewport-surface.size*factor)*0.5
    layout_origin=Vector2(160,149);arena.position=layout_origin
func if_not_enabled_stop():
    if not App.sfx_enabled:sound_player.stop()
func play_sound(name):
    if App.sfx_enabled and sounds.has(name):sound_player.volume_db=App.sfx_volume_db;sound_player.stream=sounds[name];sound_player.play()
func figure():
    var image=TextureRect.new();image.size=Vector2(384,320);image.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;image.mouse_filter=Control.MOUSE_FILTER_IGNORE;arena.add_child(image);return image
func register_reserve_art():
    var library=preload("res://view/reserve_art.gd")
    for id in library.IDS:
        var art=library.profile(id)
        if art.is_empty():continue
        reserve_sets[id]=art
        # Existing 24 ticks, melee contact tick 9. Recovery reuses anticipation.
        actor_sets[id]={"textures":[art.poses.idle_00,art.poses.anticipation,art.poses.contact],"timeline":[0,0,1,1,1,1,1,1,1,2,2,2,2,1,1,1,1,1,0,0,0,0,0,0],"tick_seconds":0.06,"release":9}
        defender_sets[id]={"idle":art.poses.idle_00,"hit":art.poses.hurt,"recover":art.poses.idle_00}
        var geo=art.geometry
        # Integer source coordinates denote pixel centers; flip in continuous
        # TextureRect coordinates (192-x), never mix with integer 191-x indexing.
        contact_points[id]={"weapon_tip":[geo.attack_contact_tip_xy[0]+0.5,geo.attack_contact_tip_xy[1]+0.5],"hurt_point":[192-(geo.hurt_body_anchor_xy[0]+0.5),geo.hurt_body_anchor_xy[1]+0.5],"hurt_radius":16,"contact_tick":9}
func sample_reserve_idle(id,time,fallback):
    if not reserve_sets.has(id):return fallback
    return reserve_sets[id].poses.idle_00 if App.reduced_motion or fposmod(time,0.9)<0.45 else reserve_sets[id].poses.idle_01
func consume(step,events,units=[],content={}):
    if step==last_seen_step:return
    finish();last_seen_step=step
    var authored=preload("res://view/authored_scene.gd").profile(content)
    var compatible=not authored.is_empty() and ResourceLoader.exists(authored.battle)
    if compatible:reference_background.texture=load(authored.battle)
    reference_background.visible=compatible
    for node in legacy_backdrop:node.visible=not compatible
    for item in preload("res://ui/combat_context.gd").annotate(events,units):
        if item.get("kind")!="attack" or (item.get("target")!="oren" and not defender_sets.has(item.get("target"))):continue
        if item.actor!="mara" and not actor_sets.has(item.actor):continue
        if item.actor=="neri" and item.get("ability") not in ["ember","focus_bolt"]:continue
        if reserve_sets.has(item.actor) and item.get("ability","attack")!="attack":continue # Only authored melee art; no invented spell animation.
        pending_events.append(item.duplicate(true))
    play_next()
func play_next():
    if pending_events.is_empty():finish();return
    event=pending_events.pop_front();elapsed=0.0;active=true;hitstop_done=false;hitstop_remaining=0.0;release_played=false
    tick_seconds=1.0/12.0 if event.actor=="mara" else actor_sets[event.actor].tick_seconds
    release_tick=int(contact_points.mara.contact_tick) if event.actor=="mara" else actor_sets[event.actor].release
    title.text=str(event.get("ability","attack")) if event.get("ability","attack")!="attack" else "普通攻击"
    title.text={"ember":"余烬","focus_bolt":"专注魔弹","strong_shot":"强力射击","rally":"鼓舞"}.get(title.text,title.text)
    feedback_strength=0.0 if App.reduced_motion else 1.0
    combat_status.show_event(event)
    surface.show();draw_tick(0)
func is_melee():return event.get("actor") in ["mara","oren","tessa","bram"] or reserve_sets.has(event.get("actor"))
func hit_tick():return release_tick if is_melee() else release_tick+4
func socket_point(values):return Vector2(values[0],values[1])
func hurt_screen_point():return arena.position+defender.position+contact_target*2.0
func weapon_screen_point():return arena.position+attacker.position+socket_point(contact_points[event.actor].weapon_tip)*2.0
func projectile_screen_point():return arena.position+projectile.position+socket_point(contact_points[event.actor].projectile_tip)*2.0
func draw_tick(frame):
    var tick=clampi(int(frame),0,23)
    var melee=is_melee();var critical=event.get("is_critical",false)
    if event.actor=="mara":attacker.texture=load("res://assets/battle/mara/"+MARA[TIMELINE[tick]]+".png")
    else:
        var data=actor_sets[event.actor];attacker.texture=data.textures[int(data.timeline[tick])]
    combat_status.update_health(event,tick>=hit_tick())
    var hit=hit_tick();var after=maxf(0.0,(frame-hit)*tick_seconds)
    var defend=0 if tick<release_tick-2 else (1 if tick<hit else (2 if tick<hit+4 else 3))
    if event.get("hp",1)==0 and tick>=hit:defend=2
    defender.flip_h=event.target!="oren"
    if event.target=="oren":defender.texture=load("res://assets/battle/oren/"+OREN[defend]+".png")
    else:
        var poses=defender_sets[event.target];defender.texture=poses.hit if defend==2 else (poses.recover if defend==3 else poses.idle)
    # Idle only in authored neutral windows. Guard/brace, hit and recovery
    # keep their own frames, including the final two settle/recover ticks.
    var idle_time=maxf(0,frame)*tick_seconds
    if tick<2:
        attacker.texture=idle_library.sample("battle",event.actor+":right",idle_time,attacker.texture,App.reduced_motion,event.actor)
        attacker.texture=sample_reserve_idle(event.actor,idle_time,attacker.texture)
    if defend==0:
        defender.texture=idle_library.sample("battle",event.target+(":left" if event.target=="oren" else ":right"),idle_time,defender.texture,App.reduced_motion,event.target)
        defender.texture=sample_reserve_idle(event.target,idle_time,defender.texture)
    contact_target=socket_point(contact_points[event.target].hurt_point)
    if event.actor=="elsbet":
        # High staff strike: select the head area, not a torso socket that would
        # translate the entire attacker's feet upward. Existing poses stay put.
        if reserve_sets.has(event.target):
            var head=reserve_sets[event.target].geometry.hurt_head_anchor_xy
            contact_target=Vector2(192-(head[0]+0.5),head[1]+0.5)
        else:
            var x=float(preload("res://view/reserve_art.gd").LEGACY_HEAD_X[event.target])+0.5
            contact_target=Vector2(192-x if defender.flip_h else x,60.5)
    if melee:
        # Contact may land anywhere in the authored torso hurt region, preserving grounded feet.
        var tip=socket_point(contact_points[event.actor].weapon_tip)
        contact_target.y=clampf(tip.y,contact_target.y-(8 if event.actor=="elsbet" else contact_points[event.target].get("hurt_radius",12)),contact_target.y+(8 if event.actor=="elsbet" else contact_points[event.target].get("hurt_radius",12)))
    defender.modulate.a=clampf(1.0-(tick-hit-2)/5.0,0,1) if event.get("hp",1)==0 and tick>=hit else 1.0
    defender.position=Vector2(700,205)
    var base=Vector2(180,205)
    if melee:
        # Align actual sword tip to actual hit-pose torso socket at impact.
        var contact=defender.position+(contact_target-socket_point(contact_points[event.actor].weapon_tip))*2.0
        var approach=clampf((frame-6.0)/(hit-6.0),0,1)
        if frame>=18:approach=clampf((24.0-frame)/6.0,0,1)
        attacker.position=base.lerp(contact,approach)
    else:attacker.position=base
    var intensity=(1.5 if critical else 1.0)*feedback_strength
    if tick>=hit:
        defender.position.x+=sin(clampf(after/0.40,0,1)*PI)*10.0*intensity
    flash_material.set_shader_parameter("flash_strength",(maxf(0,1.0-after/0.11)*0.85*feedback_strength) if tick>=hit else 0.0)
    arena.position=layout_origin+Vector2(sin(after*70.0)*3.0,-sin(after*45.0)*1.5)*maxf(0,1-after/0.22)*intensity if tick>=hit else layout_origin
    var target=defender.position+contact_target*2.0
    damage_label.visible=tick>=hit
    damage_label.text=("暴击 " if critical else "")+"−"+str(event.get("damage",0)) if tick>=hit else ""
    damage_label.add_theme_font_size_override("font_size",40 if critical else 34)
    damage_label.modulate=Color("f2cc87") if critical else Color("f0e5c9")
    var t=clampf(after/0.72,0,1)
    damage_label.position=target+(Vector2(-35,-190) if feedback_strength==0 else Vector2(-35+8*t,-190-35*4*t*(1-t)))
    damage_label.scale=Vector2.ONE*(1.0+maxf(0,1-after/0.12)*0.25*feedback_strength)
    damage_label.modulate.a=clampf((1.0-t)/0.25,0,1)
    projectile.hide();impact.hide()
    if melee and tick>=hit and after<0.16:
        impact.texture=fx.impact;impact.position=target-impact.size*0.5;impact.modulate.a=(1-after/0.16)*feedback_strength;impact.show()
    if not melee:
        var magic=event.actor=="neri"
        var origin=attacker.position+socket_point(contact_points[event.actor].release_point)*2.0
        if magic and tick>=5 and tick<release_tick:
            projectile.texture=fx.gather if tick<8 else fx.charge;projectile.position=origin-Vector2(64,48);projectile.show()
        elif tick>=release_tick and tick<=hit:
            projectile.texture=fx.bolt if magic else fx.arrow
            projectile.position=origin.lerp(target,clampf((frame-release_tick)/4.0,0,1))-socket_point(contact_points[event.actor].projectile_tip)*2.0;projectile.show()
        if tick>=hit and after<0.22:
            impact.texture=fx.impact if after<0.12 else fx.dissipate;impact.position=target-impact.size*0.5;impact.modulate.a=(1-after/0.22)*feedback_strength;impact.show()
func _process(delta):
    if not active:return
    if hitstop_remaining>0:
        hitstop_remaining=maxf(0,hitstop_remaining-delta*speed);return
    var next=elapsed+delta*speed;var contact_time=hit_tick()*tick_seconds
    var sound_time=(maxi(0,release_tick-3) if is_melee() else release_tick)*tick_seconds
    if not release_played and next>=sound_time:
        release_played=true;play_sound("swing" if is_melee() else ("arrow" if event.actor=="finn" else "magic"))
    if not hitstop_done and next>=contact_time:
        elapsed=contact_time;hitstop_done=true;impact_play_count+=1;play_sound("critical" if event.get("is_critical",false) else "impact");hitstop_remaining=(0.10 if event.get("is_critical",false) else 0.055)*feedback_strength
    else:elapsed=next
    if elapsed/tick_seconds>=24:play_next()
    else:draw_tick(elapsed/tick_seconds)
func finish():
    active=false;pending_events.clear();hitstop_remaining=0;elapsed=0
    if arena:arena.position=layout_origin
    if flash_material:flash_material.set_shader_parameter("flash_strength",0.0)
    if defender:defender.modulate=Color.WHITE
    if damage_label:damage_label.hide();damage_label.scale=Vector2.ONE
    if projectile:projectile.hide()
    if impact:impact.hide()
    if surface:surface.hide()
    if sound_player:sound_player.stop()
func _input(input):
    if active and input is InputEventKey and input.pressed and not input.echo and input.physical_keycode in [KEY_SPACE,KEY_ESCAPE,KEY_ENTER]:
        finish();get_viewport().set_input_as_handled()
