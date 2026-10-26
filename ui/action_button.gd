extends Button
var kind="move"
var hover_amount=0.0
var selected=false
var text_color=Color("eee2c6")
var visual_state=""
var transition:Tween
var assets={}
func set_selected(value):
    if selected!=value:selected=value;update_visual()
func update_visual():
    if not is_inside_tree():return
    var state="disabled" if disabled else ("selected" if selected else ("focus" if has_focus() or is_hovered() else "normal"))
    if state==visual_state:return
    visual_state=state
    if transition:transition.kill()
    transition=create_tween();transition.set_parallel(true)
    transition.tween_property(self,"scale",Vector2.ONE*(1.04 if state in ["selected","focus"] else 1.0),0.12)
    transition.tween_property(self,"hover_amount",1.0 if state in ["selected","focus"] else 0.0,0.12)
    transition.tween_method(tint_text,text_color,Color("7b8880") if state=="disabled" else (Color("f0d49b") if state=="selected" else Color("eee2c6")),0.12)
func tint_text(color):
    text_color=color
    for name in ["font_color","font_hover_color","font_focus_color","font_pressed_color"]:add_theme_color_override(name,color)
func _exit_tree():
    if transition:transition.kill()
    scale=Vector2.ONE;hover_amount=0.0
func _ready():
    alignment=HORIZONTAL_ALIGNMENT_LEFT;custom_minimum_size=Vector2(170,64);pivot_offset=Vector2(32,32)
    add_theme_font_size_override("font_size",20)
    add_theme_color_override("font_outline_color",Color("1f2c2a"));add_theme_constant_override("outline_size",2)
    for state in ["normal","hover","pressed","disabled","focus"]:
        var box=StyleBoxEmpty.new();box.content_margin_left=72;box.content_margin_right=4;add_theme_stylebox_override(state,box)
    var names={"diamond":"action_unselected","diamond_selected":"action_selected","move":"icon_boot","attack":"icon_sword","skill":"icon_sparkles","item":"icon_pouch"}
    for key in ["diamond","diamond_selected",kind]:
        assets[key]=load("res://assets/ui/hud_v3/"+names[key]+".png")
    mouse_entered.connect(update_visual);mouse_exited.connect(update_visual);focus_entered.connect(update_visual);focus_exited.connect(update_visual)
func _process(_delta):
    update_visual();queue_redraw()
func _draw():
    if assets.is_empty():return
    var center=Vector2(32,32-hover_amount*2)
    var frame="diamond_selected" if selected and not disabled else "diamond"
    var tint=Color(0.55,0.55,0.55) if disabled else Color.WHITE
    draw_texture_rect(assets[frame],Rect2(center-Vector2(32,32),Vector2(64,64)),false,tint)
    draw_texture_rect(assets[kind],Rect2(center-Vector2(14,14),Vector2(28,28)),false,tint)
    draw_rect(Rect2(70,21,23,24),Color("80775c") if not disabled else Color("58615c"),false,1)
    if has_focus() and not disabled:
        draw_colored_polygon(PackedVector2Array([Vector2(-10,27),Vector2(-5,32),Vector2(-10,37),Vector2(-15,32)]),Color("dfa75f"))
