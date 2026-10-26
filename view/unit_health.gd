extends Node3D
# Small world-space art meter. Names and exact values belong to the selected HUD.
var fill: Sprite3D
func _init():
    fill=make_sprite("res://assets/ui/hud_v3/hp_fill.png",0)
    fill.region_enabled=true
    make_sprite("res://assets/ui/hud_v3/hp_frame.png",1)
func make_sprite(path,priority):
    var sprite=Sprite3D.new()
    sprite.texture=load(path);sprite.pixel_size=0.002
    sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED
    sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
    sprite.render_priority=priority
    sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(sprite)
    return sprite
func update_health(hp,max_hp,ally):
    var width=roundi(312.0*clampf(float(hp)/maxi(1,max_hp),0,1))
    fill.visible=width>0
    fill.region_rect=Rect2(0,0,width,16)
    fill.offset=Vector2((width-312)*0.5,0)
    fill.modulate=Color("c6d9b8") if ally else Color("db7463")
