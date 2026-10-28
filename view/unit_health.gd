extends Node3D
# Fixed-width screen-facing meter; no runtime texture reads or silhouette scans.
var fill:Sprite3D
var frame:Sprite3D
var backing:Sprite3D
var marker:Label3D
var selected=false
var previous_hp=-1
var damage_time=0.0
var rendered_size=Vector2.ZERO
var faction_ally=true
var unit_index=-1
var horizontal_offset=0.0
# Base logical pixels before scene magnification; independent of actor art.
const FIXED_WIDTH=50.0
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
    var world_height=camera.size if camera.keep_aspect==Camera3D.KEEP_HEIGHT else camera.size*logical.y/logical.x
    var game=get_parent()
    # The adapter records the unzoomed camera before cover fitting. No texture reads.
    var reference_height=game.scene_view.saved_size if game.scene_view else world_height
    var magnification=reference_height/maxf(world_height,0.001)
    var outer_width=FIXED_WIDTH*pixels_per_logical*magnification
    if outer_width<=0:return
    var outline=minf(1,outer_width*0.04)
    var width=outer_width-2*outline;var height=maxf(8,8*pixels_per_logical)
    if selected or damage_time>0:height+=1
    rendered_size=Vector2(outer_width,height+2)
    var world_per_pixel=world_height/physical.y
    for sprite in [backing,fill,frame]:
        sprite.pixel_size=world_per_pixel*width/320.0;sprite.scale.y=(height/width)*(320.0/24.0)
    fill.scale.y*=1.30
    backing.position=Vector3.ZERO;fill.position=camera.global_basis.z*0.002;frame.position=camera.global_basis.z*0.004
    backing.scale=Vector3(outer_width/width,((height+2)/width)*(320.0/24.0),1)
    frame.modulate=Color(1.3,1.3,1.1) if selected or damage_time>0 else Color.WHITE
    marker.pixel_size=world_per_pixel*minf(10.0,outer_width)/32.0
    marker.position=camera.global_basis.y*(height*0.5+6)*world_per_pixel

    # Protect nearby faces without moving a meter multiple tiles away from its owner.
    if unit_index>=0 and unit_index<game.figures.size():
        var base=game.badge_position(unit_index)
        var center=camera.unproject_position(base)*pixels_per_logical
        horizontal_offset=0
        for offset in ([0.0,width+12.0,-width-12.0] if App.health_bar_avoidance else []):
            var rect=Rect2(center+Vector2(offset-outer_width*0.5,-height*0.5-12),Vector2(outer_width,height+13))
            var clear=true
            for i in range(game.figures.size()):
                if i==unit_index or game.battle.units[i].hp<=0:continue
                var top=camera.unproject_position(game.figure_pixel_position(i,Vector2(28,12)))*pixels_per_logical
                var bottom=camera.unproject_position(game.figure_pixel_position(i,Vector2(68,58)))*pixels_per_logical
                if rect.intersects(Rect2(top,bottom-top)):clear=false;break
            if clear:horizontal_offset=offset;break
        position=base+camera.global_basis.x*horizontal_offset*world_per_pixel
