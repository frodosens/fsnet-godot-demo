extends Button
func _ready():
    alignment=HORIZONTAL_ALIGNMENT_LEFT
    if custom_minimum_size==Vector2.ZERO:custom_minimum_size=Vector2(320,56)
    if not has_theme_font_size_override("font_size"):add_theme_font_size_override("font_size",28)
    for state in ["normal","hover","pressed","disabled","focus"]:
        var box=StyleBoxFlat.new();box.bg_color=Color(0,0,0,0)
        if state in ["hover","focus","pressed"]:box.bg_color=Color(0.22,0.27,0.21,0.55)
        box.content_margin_left=34;box.content_margin_right=10
        add_theme_stylebox_override(state,box)
    mouse_entered.connect(queue_redraw);mouse_exited.connect(queue_redraw)
    focus_entered.connect(queue_redraw);focus_exited.connect(queue_redraw)
func _draw():
    if not disabled and (is_hovered() or has_focus()):
        var center=Vector2(13,size.y*0.5)
        draw_colored_polygon(PackedVector2Array([center+Vector2(0,-5),center+Vector2(5,0),center+Vector2(0,5),center+Vector2(-5,0)]),Color("ce9a57"))
