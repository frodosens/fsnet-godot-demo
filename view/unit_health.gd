extends Node3D
# Real raster meter, screen-size floor, and non-colour-only faction marker.
var fill:Sprite3D
var frame:Sprite3D
var backing:Sprite3D
var marker:Label3D
var selected=false
var previous_hp=-1
var damage_time=0.0
var rendered_size=Vector2.ZERO
var faction_ally=true
func _init():
    backing=make_sprite("",0)
    var texture=GradientTexture2D.new();texture.width=320;texture.height=24
    var gradient=Gradient.new();gradient.set_color(0,Color("101b20"));gradient.set_color(1,Color("101b20"));texture.gradient=gradient;backing.texture=texture
    fill=make_sprite("res://assets/ui/hud_v3/hp_fill.png",1);fill.region_enabled=true
    frame=make_sprite("res://assets/ui/hud_v3/hp_frame.png",2)
    marker=Label3D.new();marker.billboard=BaseMaterial3D.BILLBOARD_ENABLED;marker.font_size=32;marker.outline_size=8;marker.outline_modulate=Color("101b20");marker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(marker)
    process_priority=110
func make_sprite(path,priority):
    var sprite=Sprite3D.new()
    if not path.is_empty():sprite.texture=load(path)
    sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED;sprite.shaded=false
    sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;sprite.render_priority=priority
    sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(sprite);return sprite
func update_health(hp,max_hp,ally,is_selected=false):
    if previous_hp>=0 and hp<previous_hp:damage_time=0.45
    previous_hp=hp;selected=is_selected;faction_ally=ally
    var width=roundi(312.0*clampf(float(hp)/maxi(1,max_hp),0,1))
    fill.visible=width>0;fill.region_rect=Rect2(0,0,width,16);fill.offset=Vector2((width-312)*0.5,0)
    fill.modulate=Color("e9f2cf") if ally else Color("ed9279")
    marker.text="◆" if ally else "▲";marker.modulate=Color("e9f2cf") if ally else Color("ed9279")
    visible=hp>0
func _process(delta):
    damage_time=maxf(0,damage_time-delta)
    var camera=get_viewport().get_camera_3d()
    if not camera:return
    var physical=Vector2(get_tree().root.size);var logical=get_viewport().get_visible_rect().size
    var pixels_per_logical=minf(physical.x/logical.x,physical.y/logical.y)
    var width=maxf(54,54*pixels_per_logical);var height=maxf(8,8*pixels_per_logical)
    if selected or damage_time>0:width*=1.10;height+=1
    rendered_size=Vector2(width,height)
    var world_height=camera.size if camera.keep_aspect==Camera3D.KEEP_HEIGHT else camera.size*logical.y/logical.x
    var world_per_pixel=world_height/physical.y
    for sprite in [backing,fill,frame]:
        sprite.pixel_size=world_per_pixel*width/320.0;sprite.scale.y=(height/width)*(320.0/24.0)
    backing.position=Vector3.ZERO;fill.position=camera.global_basis.z*0.002;frame.position=camera.global_basis.z*0.004
    backing.scale=Vector3((width+4)/width,((height+4)/width)*(320.0/24.0),1)
    frame.modulate=Color(1.3,1.3,1.1) if selected or damage_time>0 else Color.WHITE
    marker.pixel_size=world_per_pixel*10.0/32.0
    marker.position=-camera.global_basis.x*(width*0.5+9)*world_per_pixel
