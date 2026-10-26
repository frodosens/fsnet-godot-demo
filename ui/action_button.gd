extends Button
var kind="move"
var hover_amount=0.0
var selected=false
var text_color=Color("eee2c6")
var visual_state=""
var transition:Tween
var assets={}
var symbol:TextureRect
var key_label:Label
var key_number="1"
var layout_position=Vector2.ZERO
var selection_shift=0.0
var plate:Control
class OptionPlate extends Control:
    var amount=0.0
    func _draw():
        var shape=PackedVector2Array([Vector2(66,12),Vector2(162,12),Vector2(174,24),Vector2(174,42),Vector2(164,52),Vector2(66,52)])
        draw_colored_polygon(shape,Color(0.16,0.21,0.20,0.80))
        var edge=PackedVector2Array(shape);edge.append(shape[0])
        draw_polyline(edge,Color(0.70,0.61,0.42,0.40+0.35*amount),1.0)
        draw_line(Vector2(72,15),Vector2(159,15),Color(0.88,0.80,0.62,0.12+0.18*amount),1.0)
func set_selected(value):
    if selected!=value:selected=value;update_visual()
func update_visual():
    if not is_inside_tree() or not is_visible_in_tree():return
    var state="disabled" if disabled else ("selected" if selected else ("focus" if has_focus() or is_hovered() else "normal"))
    if state==visual_state:return
    visual_state=state
    if transition:transition.kill()
    transition=create_tween();transition.set_parallel(true)
    var duration=0.0 if App.reduced_motion else 0.14
    transition.tween_property(self,"selection_shift",-14.0 if state=="selected" else 0.0,duration)
    transition.tween_property(self,"scale",Vector2.ONE*(1.0 if state=="selected" else 0.85),duration)
    transition.tween_property(self,"hover_amount",1.0 if state in ["selected","focus"] else 0.0,duration)
    transition.tween_method(tint_text,text_color,Color("b5b6a5") if state=="disabled" else (Color("f0d49b") if state=="selected" else Color("eee2c6")),duration)
func tint_text(color):
    text_color=color
    for name in ["font_color","font_hover_color","font_focus_color","font_pressed_color"]:add_theme_color_override(name,color)
func reset_motion():
    if transition:transition.kill()
    scale=Vector2.ONE*0.85;hover_amount=0.0;selection_shift=0.0;visual_state="";position=layout_position
func set_layout_position(value):
    layout_position=value;position=layout_position+Vector2(selection_shift,0)
func _exit_tree():reset_motion()
func _ready():
    alignment=HORIZONTAL_ALIGNMENT_LEFT;custom_minimum_size=Vector2(170,76);pivot_offset=Vector2(32,32)
    plate=OptionPlate.new();plate.show_behind_parent=true;plate.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(plate)
    key_number={"move":"1","attack":"2","skill":"3","item":"4"}[kind]
    add_theme_font_size_override("font_size",20)
    add_theme_color_override("font_outline_color",Color("1f2c2a"));add_theme_constant_override("outline_size",2)
    for state in ["normal","hover","pressed","disabled","focus"]:
        var box=StyleBoxEmpty.new();box.content_margin_left=108;box.content_margin_right=4;add_theme_stylebox_override(state,box)
    var names={"diamond":"action_unselected","diamond_selected":"action_selected","move":"icon_boot","attack":"icon_sword","skill":"icon_sparkles","item":"icon_pouch"}
    for key in ["diamond","diamond_selected",kind]:
        assets[key]=load("res://assets/ui/hud_v3/"+names[key]+".png")
    symbol=TextureRect.new();symbol.texture=assets[kind];symbol.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;symbol.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;symbol.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(symbol)
    var material=ShaderMaterial.new();material.shader=load("res://ui/action_icon.gdshader");symbol.material=material
    key_label=Label.new();key_label.text=key_number;key_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;key_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;key_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(key_label)
    visibility_changed.connect(func():
        if not is_visible_in_tree():reset_motion())
    mouse_entered.connect(update_visual);mouse_exited.connect(update_visual);focus_entered.connect(update_visual);focus_exited.connect(update_visual)
func _process(_delta):
    if not is_visible_in_tree():return
    update_visual()
    position=layout_position+Vector2(selection_shift,0)
    var view=get_viewport().get_visible_rect().size;var physical=get_window().size
    var physical_scale=minf(float(physical.x)/view.x,float(physical.y)/view.y)
    var font_size=clampi(ceili(16.0/maxf(physical_scale*0.85,0.1)),20,26) # Supported minimum window is 960x600; bound headless/uninitialized sizes.
    add_theme_font_size_override("font_size",font_size);key_label.add_theme_font_size_override("font_size",font_size)
    var extent=36.0
    symbol.position=Vector2(32,32)-Vector2.ONE*extent/2;symbol.size=Vector2.ONE*extent
    symbol.material.set_shader_parameter("ink",Color("b5b6a5") if disabled else (Color("fff0c2") if selected else Color("ead6b0")))
    key_label.position=Vector2(74,18);key_label.size=Vector2(26,28);key_label.modulate=Color("b5b6a5") if disabled else Color("eee2c6")
    plate.amount=hover_amount;plate.queue_redraw()
    queue_redraw()
func _draw():
    if assets.is_empty():return
    var center=Vector2(32,32)
    var extent=64.0
    var frame="diamond_selected" if selected and not disabled else "diamond"
    var tint=Color(0.72,0.72,0.68) if disabled else (Color(1.35,1.25,1.1) if selected else Color.WHITE)
    draw_texture_rect(assets[frame],Rect2(center-Vector2.ONE*extent/2,Vector2.ONE*extent),false,tint)
    draw_rect(Rect2(74,18,26,28),Color("80775c") if not disabled else Color("58615c"),false,1)
    if (selected or has_focus() or is_hovered()) and not disabled:
        draw_colored_polygon(PackedVector2Array([Vector2(-18,25),Vector2(-11,32),Vector2(-18,39),Vector2(-25,32)]),Color("dfa75f"))
