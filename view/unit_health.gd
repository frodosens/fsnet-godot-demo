extends Node3D
# Screen-facing meter bounded by the smallest opaque body width in its idle set.
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
var body_pixels=0.0
static var body_width_cache={}
static var idle_width_library
static func body_width(texture):
    if body_width_cache.has(texture):return body_width_cache[texture]
    var image=texture.get_image();var width=image.get_width();var height=image.get_height()
    var visited={};var largest=0;var result=0
    # Largest connected alpha>=0.5 component ignores transparent margins and isolated specks.
    for y in range(height):
        for x in range(width):
            var start=y*width+x
            if visited.has(start) or image.get_pixel(x,y).a<0.5:continue
            var queue=[start];visited[start]=true;var cursor=0;var left=x;var right=x
            while cursor<queue.size():
                var point=queue[cursor];cursor+=1;var px=point%width;var py=point/width
                left=mini(left,px);right=maxi(right,px)
                for dy in range(-1,2):
                    for dx in range(-1,2):
                        var nx=px+dx;var ny=py+dy;var next=ny*width+nx
                        if nx<0 or ny<0 or nx>=width or ny>=height or visited.has(next):continue
                        if image.get_pixel(nx,ny).a>=0.5:visited[next]=true;queue.append(next)
            if queue.size()>largest:largest=queue.size();result=right-left+1
    body_width_cache[texture]=result
    return result
func _ready():refresh_art_width()
func refresh_art_width():
    var game=get_parent();var unit=game.battle.units[unit_index]
    var textures=[]
    var allowed=["front_left","front_right","back_left","back_right"] if game.iso_roles.has(unit.role) else ["front","back","left","right"]
    for direction in allowed:
        if game.direction_textures.has(unit.id+":"+direction):textures.append(game.direction_textures[unit.id+":"+direction])
    if textures.is_empty():textures.append(game.figures[unit_index].texture)
    if idle_width_library==null:idle_width_library=preload("res://view/idle_library.gd").new()
    var reserve=preload("res://view/reserve_art.gd").profile(unit.id)
    if reserve.is_empty():
        for key in idle_width_library.clips.map:
            var clip=idle_width_library.clips.map[key]
            if key.begins_with(unit.role+":") and (clip.unit_ids.is_empty() or unit.id in clip.unit_ids):textures.append_array(clip.textures)
    var walks=preload("res://view/walk_library.gd").shared()
    for direction in allowed:
        var neutral=game.direction_textures.get(unit.id+":"+direction,game.figures[unit_index].texture)
        if reserve.is_empty():neutral=idle_width_library.sample("map",unit.role+":"+direction,0,neutral,true,unit.id)
        else:neutral=reserve.map.get(direction,neutral)
        textures.append_array(walks.textures_for(unit.id,direction,neutral))
        if get_node("/root/App").map_sequence_enabled(unit.id):textures.append_array(preload("res://view/map_sequence.gd").shared().textures_for(unit.id,direction,neutral))
    body_pixels=INF
    for texture in textures:
        var measured=body_width(texture)
        if measured>0:body_pixels=minf(body_pixels,measured)
    if not is_finite(body_pixels):body_pixels=0
func projected_body_width(camera,pixels_per_logical):
    var game=get_parent()
    var a=game.figure_pixel_position(unit_index,Vector2(48,100))
    var b=game.figure_pixel_position(unit_index,Vector2(48+body_pixels,100))
    return camera.unproject_position(a).distance_to(camera.unproject_position(b))*pixels_per_logical
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
    var outer_width=minf(54*pixels_per_logical,projected_body_width(camera,pixels_per_logical)*0.96)
    if outer_width<=0:return
    var outline=minf(1,outer_width*0.04)
    var width=outer_width-2*outline;var height=maxf(8,8*pixels_per_logical)
    if selected or damage_time>0:height+=1
    rendered_size=Vector2(outer_width,height+2)
    var world_height=camera.size if camera.keep_aspect==Camera3D.KEEP_HEIGHT else camera.size*logical.y/logical.x
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
    var game=get_parent()
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
